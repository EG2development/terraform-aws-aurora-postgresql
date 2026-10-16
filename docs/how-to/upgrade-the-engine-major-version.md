# How to upgrade the engine major version

A major version upgrade, for example from 17 to 18, changes the cluster in place. The
database is unavailable while it runs, and it cannot be undone in place: the way back
is a restore from a snapshot into a new cluster. Plan it into a maintenance window,
after testing your application against the new version.

Set these first:

```bash
CLUSTER="payments-prod"   # the module's name input
TARGET="18.4"             # the version you are moving to
REGION="eu-west-2"
SNAPSHOT="${CLUSTER}-before-${TARGET//./-}"
```

## 1. Check that the target is a valid upgrade

```bash
CURRENT="$(aws rds describe-db-clusters --db-cluster-identifier "${CLUSTER}" \
  --query 'DBClusters[0].EngineVersion' --output text --region "${REGION}")"
aws rds describe-db-engine-versions --engine aurora-postgresql --engine-version "${CURRENT}" \
  --query 'DBEngineVersions[0].ValidUpgradeTarget[?IsMajorVersionUpgrade==`true`].EngineVersion' \
  --output text --region "${REGION}"
```

If `TARGET` is not in the list, upgrade in two steps through a version that is, or
first move to a newer minor version of your current major.

## 2. Take a snapshot

```bash
aws rds create-db-cluster-snapshot --db-cluster-identifier "${CLUSTER}" \
  --db-cluster-snapshot-identifier "${SNAPSHOT}" --region "${REGION}"
aws rds wait db-cluster-snapshot-available \
  --db-cluster-snapshot-identifier "${SNAPSHOT}" --region "${REGION}"
```

## 3. Change the module call

```hcl
module "aurora" {
  # ...
  engine_version              = "18.4"
  allow_major_version_upgrade = true
  apply_immediately           = true
}
```

`apply_immediately = true` makes the upgrade run during this apply, inside your
window, rather than at the next scheduled maintenance window.

## 4. Check the plan

```bash
terraform plan
```

The plan must show, and nothing else:

- `aws_rds_cluster.main` will be updated in place: `engine_version` to the target,
  `allow_major_version_upgrade` and `apply_immediately` to `true`,
- each `aws_rds_cluster_instance.main[n]` will be updated in place: `engine_version`
  to the target (it follows the cluster).

If any resource "must be replaced", stop: something other than the version changed.

## 5. Apply in the window

```bash
terraform apply
```

Then confirm the new version:

```bash
aws rds describe-db-clusters --db-cluster-identifier "${CLUSTER}" \
  --query 'DBClusters[0].[EngineVersion,Status]' --output text --region "${REGION}"
```

The output shows the target version and `available`.

## 6. Refresh statistics and close the door again

1. Connect as the master user and run `ANALYZE;` in each database. Upgrades to
   PostgreSQL versions before 18 do not carry the optimiser statistics over.
2. Set `allow_major_version_upgrade = false` and `apply_immediately = false`. Do not
   just delete the `apply_immediately` line: the provider would keep the stored
   `true`. Run `terraform plan`, check that only those two arguments change, in place,
   and apply.
3. Delete the snapshot once the application has run correctly on the new version
   for as long as you need a way back:
   `aws rds delete-db-cluster-snapshot --db-cluster-snapshot-identifier "${SNAPSHOT}" --region "${REGION}"`.
