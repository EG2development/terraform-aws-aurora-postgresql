variable "region" {
  description = "AWS Region to create the resources in."
  type        = string
  default     = "eu-west-2"
}

variable "name" {
  description = "Name of the resource."
  type        = string
  default     = "example"
}
