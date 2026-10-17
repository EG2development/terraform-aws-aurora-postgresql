# How to add a reader for high availability

With one instance, a failure of that instance or its Availability Zone leaves the
cluster without a writer until Aurora replaces it. A reader in another zone gives
Aurora an instance to promote instead.

Set these first:

```bash
CLUSTER="payments-prod"   # the module's name input
REGION="eu-west-2"
```

## Add the reader

1. Set `instance_count = 2` in the module call:

   ```hcl
   module "aurora" {
     # ...
     instance_count = 2
   }
   ```

2. Run `terraform plan` and check that it adds exactly one resource,
   `aws_rds_cluster_instance.main[1]` (identifier `<name>-instance-2`), and changes
   nothing else.
3. Run `terraform apply`. The new instance takes about ten minutes; the writer keeps
   serving throughout.

## Check that the instances are in different zones

RDS chooses each instance's zone from the subnet group; the module does not.

```bash
aws rds describe-db-instances --filters "Name=db-cluster-id,Values=${CLUSTER}" \
  --query 'DBInstances[].[DBInstanceIdentifier,AvailabilityZone]' --output table --region "${REGION}"
aws rds describe-db-clusters --db-cluster-identifier "${CLUSTER}" \
  --query 'DBClusters[0].DBClusterMembers[].[DBInstanceIdentifier,IsClusterWriter]' --output table --region "${REGION}"
```

If both instances are in the same zone, replace the one that is **not** the writer
and check again. For `<name>-instance-2`:

```bash
terraform apply -replace='module.aurora.aws_rds_cluster_instance.main[1]'
```

## Use the reader

- Send read-only queries to the `cluster_reader_endpoint` output. Writes always go to
  `cluster_endpoint`, which follows the writer.
- To prove failover works, in a quiet period run
  `aws rds failover-db-cluster --db-cluster-identifier "${CLUSTER}" --region "${REGION}"`
  and watch your application reconnect. The writer is now the other instance.

## Remove a reader later

Lowering `instance_count` deletes the highest-numbered instance, even when it is the
writer at that moment. Check `IsClusterWriter` first; if the instance to be deleted is
the writer, move the writer away before you apply:

```bash
aws rds failover-db-cluster --db-cluster-identifier "${CLUSTER}" \
  --target-db-instance-identifier "${CLUSTER}-instance-1" --region "${REGION}"
```
