terraform {
  # Minimum versions only. The root configuration that calls this module sets
  # upper bounds. 1.9 is the first Terraform whose variable validation can refer
  # to other variables. Raise a minimum only when the module uses something
  # newer, say what in a comment, and treat it as a breaking change (feat!:).
  # Never write a vX.Y.Z string in this file: release-please rewrites them.
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}
