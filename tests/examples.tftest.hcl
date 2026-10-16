# Each example plans successfully with its defaults.

mock_provider "aws" {}

run "basic_example_plans" {
  command = plan

  module {
    source = "./examples/basic"
  }

  assert {
    condition     = module.example.name == "example"
    error_message = "The basic example must plan with its default inputs."
  }
}

run "complete_example_plans" {
  command = plan

  module {
    source = "./examples/complete"
  }

  assert {
    condition     = module.example.name == "example-prod"
    error_message = "The complete example must plan with its default inputs."
  }
}
