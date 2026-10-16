# The smallest useful call. Examples are complete root configurations: they
# have a provider block and call the module from the working copy, so CI
# validates the code in this repository.

provider "aws" {
  region = var.region
}

module "example" {
  # A real caller uses a pinned Git source instead; see README.md "Usage".
  source = "../.."

  name = var.name

  tags = {
    Environment = "example"
  }
}
