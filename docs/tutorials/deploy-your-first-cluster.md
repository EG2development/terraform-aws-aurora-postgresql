# Tutorial: deploy your first cluster

In this tutorial you create an Aurora PostgreSQL cluster in two private subnets,
read the master password that RDS generated, connect with `psql` from inside the
VPC, and remove the cluster again. It takes about 30 minutes, most of it waiting for
AWS. It costs a little: Aurora Serverless v2 bills per capacity-unit hour, and the
cluster never scales below 0.5 units.

## Before you start

- Terraform 1.16 or later, and credentials for a sandbox AWS account that may create
  RDS clusters, DB subnet groups, security groups and IAM roles, and read Secrets
  Manager secrets.
- A VPC with two private subnets in different Availability Zones. The
  [terraform-aws-vpc tutorial](https://github.com/EG2development/terraform-aws-vpc/blob/main/docs/tutorials/deploy-your-first-vpc.md)
  creates one.
- A host inside that VPC with the AWS CLI, `jq` and a PostgreSQL client, for example
  an EC2 instance you reach with Session Manager. Note its security group ID.
- Read access to this repository (`git ls-remote https://github.com/EG2development/terraform-aws-aurora-postgresql.git`
  lists its tags).

## 1. Choose an engine version

```bash
aws rds describe-db-engine-versions --engine aurora-postgresql \
  --query 'DBEngineVersions[].EngineVersion' --output text --region eu-west-2
```

Pick the newest version in the list. This tutorial uses `18.4`; replace it if your
Region does not offer it.

## 2. Write the configuration

Create an empty directory and a file `main.tf` in it. Replace the three IDs with
your VPC, your two private subnets and your host's security group:

```hcl
terraform {
  required_version = ">= 1.16.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

provider "aws" {
  region = "eu-west-2"
}

module "aurora" {
  source = "git::https://github.com/EG2development/terraform-aws-aurora-postgresql.git?ref=v1.0.0"

  name           = "tutorial"
  engine_version = "18.4"
  vpc_id         = "vpc-0123456789abcdef0"
  subnet_ids     = ["subnet-0aaaaaaaaaaaaaaa1", "subnet-0bbbbbbbbbbbbbbb2"]

  allowed_security_group_ids = { "tutorial-host" = "sg-0123456789abcdef0" }
}

output "cluster_endpoint" {
  value = module.aurora.cluster_endpoint
}

output "master_user_secret_arn" {
  value = module.aurora.master_user_secret_arn
}
```

## 3. Create the cluster

```bash
terraform init
terraform apply
```

Read the plan before you type `yes`. You should see seven resources: the DB subnet
group, the security group and its ingress rule for your host, the cluster, one
instance, and the monitoring role with its policy attachment. The apply takes 10 to
15 minutes.

## 4. Read the master password

Copy the two outputs; you need them on the host:

```bash
terraform output -raw cluster_endpoint
terraform output -raw master_user_secret_arn
```

On the host inside the VPC, set them and load the password into the environment
without printing it:

```bash
HOST="<cluster_endpoint>"
SECRET_ARN="<master_user_secret_arn>"
export PGPASSWORD="$(aws secretsmanager get-secret-value --secret-id "${SECRET_ARN}" \
  --query SecretString --output text --region eu-west-2 | jq -r .password)"
```

On your own machine, the same secret is
`aws secretsmanager get-secret-value --secret-id "$(terraform output -raw master_user_secret_arn)"`.
Its `SecretString` holds the user name and password as JSON.

## 5. Connect with psql

Still on the host, download the RDS certificate bundle so `psql` can verify the
server, then connect:

```bash
curl -sSo global-bundle.pem https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem
psql "host=${HOST} port=5432 dbname=postgres user=postgres sslmode=verify-full sslrootcert=global-bundle.pem" \
  -c 'SELECT version();'
```

You see one row naming PostgreSQL 18.4. The connection worked because your host's
security group is in `allowed_security_group_ids`; from anywhere else it times out.

## 6. Clean up

Deletion protection is on, so a plain `terraform destroy` fails. Turn it off first:
add `deletion_protection = false` to the module block, then run

```bash
terraform apply
terraform destroy
```

The destroy takes about 10 minutes. RDS keeps a final snapshot, `tutorial-final`,
and the log group `/aws/rds/cluster/tutorial/postgresql`; both outlive the cluster
and cost storage. Delete them when you no longer need them:

```bash
aws rds delete-db-cluster-snapshot --db-cluster-snapshot-identifier tutorial-final --region eu-west-2
aws logs delete-log-group --log-group-name /aws/rds/cluster/tutorial/postgresql --region eu-west-2
```

A later cluster named `tutorial` cannot be destroyed while the snapshot
`tutorial-final` still exists.

## Next steps

- [Let an application connect](../how-to/let-an-application-connect.md), with a
  security group rule and IAM authentication.
- [Add a reader for high availability](../how-to/add-a-reader-for-high-availability.md)
  before production traffic depends on the cluster.
