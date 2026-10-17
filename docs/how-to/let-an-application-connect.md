# How to let an application connect

An application needs two things: a network path to the cluster port, and a database
user to sign in as. The module creates neither for you by default.

## Open the network path

Choose one of these for each client security group, not both: AWS rejects a second,
identical rule.

**With the module input.** The label becomes the rule description
("PostgreSQL from app"). Labels must be known when you plan; the group IDs need not
be.

```hcl
module "aurora" {
  # ...
  allowed_security_group_ids = { app = aws_security_group.app.id }
}
```

**With your own rule**, for example to admit a CIDR block or to keep a rule your
configuration already manages:

```hcl
resource "aws_vpc_security_group_ingress_rule" "from_app" {
  security_group_id            = module.aurora.security_group_id
  description                  = "PostgreSQL from app"
  ip_protocol                  = "tcp"
  from_port                    = module.aurora.cluster_port
  to_port                      = module.aurora.cluster_port
  referenced_security_group_id = aws_security_group.app.id
}
```

If the application's own security group limits egress, allow it out to the cluster:

```hcl
resource "aws_vpc_security_group_egress_rule" "to_database" {
  security_group_id            = aws_security_group.app.id
  description                  = "PostgreSQL to the database"
  ip_protocol                  = "tcp"
  from_port                    = module.aurora.cluster_port
  to_port                      = module.aurora.cluster_port
  referenced_security_group_id = module.aurora.security_group_id
}
```

## Sign in with IAM authentication

1. Connect as the master user (its credentials are in the secret named by the
   `master_user_secret_arn` output) and create a user that signs in with IAM:

   ```sql
   CREATE USER app_user;
   GRANT rds_iam TO app_user;
   GRANT CONNECT ON DATABASE app TO app_user;
   ```

   Then grant it the schema and table privileges it needs.

2. Allow the application's IAM role to sign in as that user:

   ```hcl
   data "aws_caller_identity" "current" {}
   data "aws_partition" "current" {}
   data "aws_region" "current" {}

   resource "aws_iam_role_policy" "connect_as_app_user" {
     name = "connect-as-app-user"
     role = aws_iam_role.app.id

     policy = jsonencode({
       Version = "2012-10-17"
       Statement = [{
         Effect   = "Allow"
         Action   = "rds-db:connect"
         Resource = "arn:${data.aws_partition.current.partition}:rds-db:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:dbuser:${module.aurora.cluster_resource_id}/app_user"
       }]
     })
   }
   ```

3. In the application, generate a token with the AWS SDK's RDS signer and use it as
   the password, over TLS. From a shell, to test:

   ```bash
   HOST="<cluster_endpoint>"
   export PGPASSWORD="$(aws rds generate-db-auth-token --hostname "${HOST}" --port 5432 \
     --username app_user --region eu-west-2)"
   psql "host=${HOST} port=5432 dbname=app user=app_user sslmode=verify-full sslrootcert=global-bundle.pem" \
     -c 'SELECT current_user;'
   ```

   A token is valid for 15 minutes and is needed only to open a connection. Get the
   certificate bundle from `https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem`.

## Sign in with a password instead

Create the user with `CREATE USER app_user WITH PASSWORD '...';`, keep the password
in a Secrets Manager secret of your own, and give the application
`secretsmanager:GetSecretValue` on that secret only. Do not give applications the
master user's secret.
