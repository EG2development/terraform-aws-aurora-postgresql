# A production-style call: every optional input that matters in production,
# and the outputs composed with other resources. Keep it simpler than the
# module itself.

provider "aws" {
  region = var.region
}

module "example" {
  source = "../.."

  name = var.name

  tags = {
    Environment = "prod"
    Team        = "platform"
  }
}
