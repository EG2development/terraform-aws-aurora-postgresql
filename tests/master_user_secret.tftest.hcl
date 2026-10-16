# The secret ARN output. It has its own file because test files keep state
# between runs: the cluster must be created by the run that overrides what
# RDS returns.

mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "111122223333" }
  }
  mock_data "aws_region" {
    defaults = { region = "eu-west-2" }
  }
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
  # The provider checks that this is an ARN, so the mock must return an ARN-shaped value.
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::111122223333:role/example-rds-monitoring" }
  }
}

variables {
  name           = "example"
  engine_version = "18.4"
  vpc_id         = "vpc-0123456789abcdef0"
  subnet_ids     = ["subnet-0aaaaaaaaaaaaaaa1", "subnet-0bbbbbbbbbbbbbbb2"]
}

run "master_user_secret_arn_comes_from_rds" {
  command = apply

  override_resource {
    target = aws_rds_cluster.main
    values = {
      master_user_secret = [{
        secret_arn    = "arn:aws:secretsmanager:eu-west-2:111122223333:secret:rds!cluster-00000000-0000-0000-0000-000000000000-AbCdEf"
        kms_key_id    = "arn:aws:kms:eu-west-2:111122223333:key/00000000-0000-0000-0000-000000000000"
        secret_status = "active"
      }]
    }
  }

  assert {
    condition     = output.master_user_secret_arn == "arn:aws:secretsmanager:eu-west-2:111122223333:secret:rds!cluster-00000000-0000-0000-0000-000000000000-AbCdEf"
    error_message = "master_user_secret_arn must be the ARN of the secret RDS manages."
  }
}
