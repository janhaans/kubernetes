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
  type = string
  default = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}