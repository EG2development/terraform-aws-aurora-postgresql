# Every validation block rejects bad input at plan time, before any API call.

mock_provider "aws" {}

run "rejects_uppercase_name" {
  command = plan

  variables {
    name = "Example"
  }

  expect_failures = [var.name]
}

run "rejects_empty_name" {
  command = plan

  variables {
    name = ""
  }

  expect_failures = [var.name]
}
