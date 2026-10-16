# Replace this file with the module's resources.
#
# Rules that keep a module shareable (terraform-module-standards/docs/standard.md):
#   - no provider or backend block: the caller configures both
#   - read nothing outside this directory (no parent-directory paths)
#   - every name, identifier, region and secret is an input
#   - drive count/for_each from a bool input, never from a null check on a
#     value that may be unknown at plan time ("Invalid count argument")
#   - choose resource names once; renaming one later needs a moved block and
#     a major release
#   - a module grants its own resources the IAM they need and nothing more;
#     callers compose extra permissions onto the roles it outputs
#   - no project or environment inputs: take a name and tags
#
# The data source below exists only so the template passes every check as it
# is (tflint flags a declared provider that nothing uses). Delete it.
data "aws_caller_identity" "current" {}

locals {
  tags = tomap(merge({ Name = var.name }, var.tags))
}
