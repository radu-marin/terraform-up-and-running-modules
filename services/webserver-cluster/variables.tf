# #didn't use this anymore
# variable "environment" {
#   description = "The name of environment (dev/stage/prod)"
#   type = string
# }

variable "server_port" {
  description = "The port the server will use for HTTP requests"
  type = number
  #if no default value, tf. will ask interactively to enter value
  default = 8080
}

variable "cluster_name" {
  description = "The name to use for all the cluster resources"
  type = string
}

variable "instance_type" {
  description = "The type of EC2 Instances to run (e.g. t2.micro)"
  type        = string
}

variable "min_size" {
  description = "The minimum number of EC2 Instances in the ASG"
  type        = number
}

variable "max_size" {
  description = "The maximum number of EC2 Instances in the ASG"
  type        = number
}

variable "db_remote_state_bucket" {
description = "The name of the S3 bucket for the database's remote state"
  type        = string
}

variable "db_remote_state_key" {
description = "The path for the database's remote state in S3 (e.g. stage/data-storage/mysql/terraform.tfstate)"
  type        = string
}
