terraform {
  # Minimum versions only: the root configuration that calls this module sets
  # upper bounds. 1.9 is the first Terraform whose variable validation can
  # refer to other variables, which this module uses. CI tests 1.9.8 (the
  # newest patch of that minor) and the latest release.
  # aws 6.0 has every argument the module sets.
  # Raising either minimum is a breaking change (feat!:). Never write a version
  # string with a leading "v" in this file: release-please rewrites them.
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}
