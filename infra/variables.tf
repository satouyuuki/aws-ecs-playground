variable "prefix" {
  default     = "sbcntr"
  description = "Project prefix used for naming resources"
}

variable "allowed_cidr_blocks" {
  type        = list(string)
  default     = ["0.0.0.0/0"]
  description = "List of CIDR blocks allowed to access the ALB"
}
