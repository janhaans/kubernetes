variable "user_name" {
  type = string
  default = "kees"
}

variable "user_name_tags" {
  type = map(string)
  default = {
    Name = "kees"
  }
}

variable "policy_arn" {
  type = map(string)
}