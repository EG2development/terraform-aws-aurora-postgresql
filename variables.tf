# Every input has a description and a type. Optional inputs default to the
# secure choice. Inputs that weaken a default are named for what they weaken.

variable "name" {
  description = "Name of the resource this module manages. Changing it replaces the resource."
  type        = string
  nullable    = false

  validation {
    condition     = length(var.name) >= 1 && var.name == lower(var.name)
    error_message = "name must be non-empty and lower-case."
  }
}

variable "tags" {
  description = "Tags for every resource. A Name tag equal to var.name is added unless this map sets Name."
  type        = map(string)
  default     = {}
  nullable    = false
}
