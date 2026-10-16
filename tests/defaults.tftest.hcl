# What a caller gets from the required inputs alone. A change to any of these
# assertions changes infrastructure for existing callers: that is a major
# release. Tests mock the provider: no credentials, nothing created.

mock_provider "aws" {}

variables {
  name = "example"
}

run "defaults" {
  command = plan

  assert {
    condition     = output.name == "example"
    error_message = "The name output must report var.name."
  }

  assert {
    condition     = output.tags == tomap({ Name = "example" })
    error_message = "Only a Name tag is added when var.tags is empty."
  }
}

run "tags_merge_with_name" {
  command = plan

  variables {
    tags = { Team = "platform" }
  }

  assert {
    condition     = output.tags == tomap({ Name = "example", Team = "platform" })
    error_message = "Caller tags must be merged with the generated Name tag."
  }
}
