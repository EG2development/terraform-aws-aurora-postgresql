# Design decisions

Why the module is shaped the way it is, and what it leaves out on purpose.

## One cluster and its edge, nothing inside the database

The module creates the cluster, its instances, and the two things that sit at its
edge: the subnet group that decides where instances get addresses, and the security
group that decides who reaches them. What happens inside PostgreSQL — schemas,
migrations, users, grants — changes with the application and is run by people or
tools that hold database credentials. Mixing it into the infrastructure module would
tie every schema change to a Terraform apply, and give Terraform state a reason to
hold credentials.

## The master password is managed by RDS by default

A password Terraform sets is stored in plain text in the state file, and anyone who
can read the state can read the password; `sensitive = true` only hides it from plan
output. With `manage_master_user_password`, RDS generates the password, keeps it in
a Secrets Manager secret and rotates it. Terraform only ever sees the secret's ARN.
Access to the password becomes an IAM question, and it is answered in one place.

`master_password` is still there for the cases this does not fit: a cluster adopted
from a configuration that already set its password, where turning management on
would replace a password that clients still use; and tools that can read a password
from configuration but cannot call Secrets Manager. The two modes are mutually
exclusive, and the input says what it weakens.

## `engine_version` has no default

A default version would be one of two bad things. A fixed default goes stale and
starts new clusters on an old major version; a moving default would upgrade every
caller's database the day the module changes it. The major version determines
extension availability, behaviour and the support window, so it is a decision the
owner of the database makes and writes down. Minor versions, which carry security
fixes, are applied automatically by default.

## Deletion protection and a final snapshot by default

Deleting a database is the one infrastructure change that cannot be repaired by
applying again. Deletion protection stops a delete from any client, not only
Terraform: a wrong `terraform destroy`, a script, a person in the console. The final
snapshot covers the case where the delete was intended but the data was still
needed. Both cost little, and turning them off for a sandbox is one line each.

## No egress rules

A database answers connections; it does not need to start them. Security groups are
stateful, so replies to clients need no egress rule. With no rule, a compromised or
misused database session cannot reach the internet or other services. Features that
make PostgreSQL call out, such as importing from S3 or invoking Lambda, need egress
and an IAM role; callers who use them add an egress rule to `security_group_id`.

## Ingress is the caller's, with one convenience

Who may connect is a property of the application, not of the database. The module
therefore admits nobody by default. `allowed_security_group_ids` covers the common
case — a few application security groups — with one rule each, keyed by labels that
are known at plan time so the rules can be planned before the groups exist. Anything
else, such as a CIDR block, is a rule on `security_group_id` in the caller's
configuration.

## IAM database authentication is on

Turning it on changes nothing for password users. It makes password-free access
possible: an application role with `rds-db:connect` on one database user signs in
with a token that lives for 15 minutes, so there is no long-lived application
password to store, rotate or leak. AWS recommends it for applications that open fewer
than about 200 new connections per second; above that, use passwords or a
connection pool.

## The subnet group lives here

A DB subnet group exists only for the database: it chooses which subnets, and so
which zones, instances may use. Putting it in the network module couples the network
to one database and gives a second database nowhere to go. Here, each cluster takes
the private subnets as an input and owns its group. `db_subnet_group_name` exists so
that a group created elsewhere under an established name can be adopted without
renaming it, which would replace the cluster.

## Serverless v2 by default

Aurora Serverless v2 scales each instance between a minimum and maximum capacity in
small steps, without a restart. For most services that is cheaper than an instance
sized for the peak, and it removes a sizing decision on day one. Provisioned instance
classes remain one input away for steady, high load where a fixed instance is cheaper.
The minimum stays at 0.5 capacity units: scaling to zero would make the first query
after a quiet period wait for the database to resume.

## Performance Insights uses the storage key

Performance Insights stores query text, which can contain data. When the caller
supplies a customer managed key for the data, the same key encrypts Performance
Insights, so the key's policy governs both and no second key input is needed.

## Names and addresses are stable

Resource names inside the module are fixed (`main`, `aurora`, `rds_monitoring`) and
every derived name follows `<name>-<suffix>`. Callers who migrate from an
in-repository database module with the same names keep their resource addresses, and
the [reference](../reference/names-tags-and-iam.md) is the contract: changing any of
those names is a breaking change.

## Left out on purpose

| Not included | Why |
| --- | --- |
| Parameter groups | Settings such as `rds.force_ssl` or query logging depend on the workload and on the data's privacy; a later minor release can accept a group the caller creates. The default parameter group of the engine version applies |
| Global databases and cross-Region replicas | A separate design with its own failover runbook and costs |
| Babelfish | A different product surface (SQL Server compatibility) with its own parameters |
| RDS Proxy | A separate resource with its own IAM and secrets; create it next to the module from its outputs |
| AWS Backup plans | Set per account or organisation, where retention and vaults are governed |
| Auto-pause to zero capacity | Makes the first query after a quiet period wait for the database to resume |
| Data API | Opens an HTTPS path to the database that bypasses the security group |
| Custom endpoints | Rarely needed; the writer and reader endpoints cover most routing |
| Choosing each instance's zone | RDS places instances in the subnet group's zones; the [how-to](../how-to/add-a-reader-for-high-availability.md) shows how to check them |
| Retention of the exported log groups | RDS creates them; set retention on `/aws/rds/cluster/<name>/<type>` in the caller's configuration |
| Write-only `master_password_wo` | Keeps a supplied password out of state, but needs Terraform 1.11; a future minor release can add it as an optional input |
