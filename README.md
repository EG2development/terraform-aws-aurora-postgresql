# terraform-aws-__MODULE__

This module: __DESCRIPTION__.

<!-- One paragraph: what the module creates, with which secure defaults, and
     for whom. A reader with no knowledge of your project must be able to
     adopt it from this file alone. -->

This module deliberately does not manage:

- Provider configuration and state. No `provider` or `backend` block; the calling
  root configuration chooses Region, credentials, default tags and where state lives.
- Account-wide settings. Anything that exists once per account belongs in the
  caller, because two calls to this module would fight over it.
- IAM identities that use the resource. Grant access in your own IAM policies with
  the ARN outputs.

## Usage

```hcl
module "__MODULE__" {
  source = "git::https://github.com/EG2development/terraform-aws-__MODULE__.git?ref=v0.0.0" # x-release-please-version

  name = "example"

  tags = {
    Team = "platform"
  }
}
```

Pin `?ref=` to a release tag, never to a branch; release-please keeps the line above
at the current release. Outside the organisation that owns this repository, pin the
release's full commit SHA instead. Run `terraform init` after changing `source`.

## Examples

| Example | Shows |
| --- | --- |
| [`examples/basic`](examples/basic) | The smallest useful call |
| [`examples/complete`](examples/complete) | A production-style call |

## Documentation

| You want to | Read |
| --- | --- |
| Deploy it for the first time | [Tutorial](docs/tutorials/first-deployment.md) |
| Do a common task | [How-to](docs/how-to/common-task.md) |
| Look up every resource, name and permission | [Reference](docs/reference/resources-and-permissions.md) |
| Understand why it is built this way | [Design decisions](docs/explanation/design-decisions.md) |

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.9.0 |
| aws | >= 6.0 |

## Providers

| Name | Version |
| ---- | ------- |
| aws | >= 6.0 |

## Resources

| Name | Type |
| ---- | ---- |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Name of the resource this module manages. Changing it replaces the resource. | `string` | n/a | yes |
| tags | Tags for every resource. A Name tag equal to var.name is added unless this map sets Name. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| account\_id | AWS account the module was planned in. Placeholder: remove with the data source in main.tf. |
| name | Name of the managed resource. |
| tags | Tags applied to every resource, including the generated Name tag. |
<!-- END_TF_DOCS -->

## Defaults and security decisions

| Decision | Default | Why | How to change it |
| --- | --- | --- | --- |
| <!-- e.g. Encryption --> | <!-- KMS, AWS managed key --> | <!-- encrypted with nothing to manage --> | <!-- `kms_key_arn` --> |

## Security scanning

Checkov runs on every pull request. No checks are skipped.
<!-- If ci.yml passes checkov-skip-checks, list each ID here with the reason. -->

## Upgrading

Read [`CHANGELOG.md`](CHANGELOG.md) for every version between yours and the new one,
change `?ref=`, run `terraform init`, and review the plan. A minor or patch release
plans no changes unless you opt into something new. A major release lists what to do
here:

<!-- ### To v2.0.0 -->

## Versioning and releases

Semantic versions, tags `vMAJOR.MINOR.PATCH`, created by release-please from
Conventional Commit pull-request titles. Patch: a fix that changes no plan. Minor: a
new optional input, output or off-by-default resource. Major: anything that can change
or replace an existing caller's resources, or raise a minimum version. Details:
[the standard](https://github.com/EG2development/terraform-module-standards/blob/main/docs/standard.md),
[release runbook](https://github.com/EG2development/terraform-module-standards/blob/main/docs/runbooks/release.md).

## Contributing and ownership

See [`CONTRIBUTING.md`](CONTRIBUTING.md). The team in
[`.github/CODEOWNERS`](.github/CODEOWNERS) reviews every change and owns releases.
Report vulnerabilities as described in [`SECURITY.md`](SECURITY.md).
