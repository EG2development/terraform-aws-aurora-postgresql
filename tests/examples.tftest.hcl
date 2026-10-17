# The examples are real configurations. Each must plan against the mocked
# provider, so an example that stops working fails CI.

mock_provider "aws" {
  mock_data "aws_region" {
    defaults = { region = "eu-west-2" }
  }
  mock_data "aws_caller_identity" {
    defaults = { account_id = "111122223333" }
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
  vpc_id     = "vpc-0123456789abcdef0"
  subnet_ids = ["subnet-0aaaaaaaaaaaaaaa1", "subnet-0bbbbbbbbbbbbbbb2"]
}

run "basic_example_plans" {
  command = plan

  module {
    source = "./examples/basic"
  }

  assert {
    condition     = module.aurora.db_subnet_group_name == "example-db-subnet"
    error_message = "The basic example creates the cluster's subnet group."
  }
}

run "complete_example_plans" {
  command = plan

  module {
    source = "./examples/complete"
  }

  assert {
    condition     = module.aurora.instance_identifiers == ["example-prod-instance-1", "example-prod-instance-2"]
    error_message = "The complete example creates a writer and a reader."
  }
}
