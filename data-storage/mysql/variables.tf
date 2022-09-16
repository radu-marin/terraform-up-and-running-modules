variable "db_name" {
  description = "The name of the database"
  type = string
}

variable "db_username" {
  description = "The username of the database"
  type = string
}

# to use this variable enter in CLI:
# export TF_VAR_db_password="(YOUR_DB_PASSWORD)"
variable "db_password" {
  description = "Create password for the database" 
  type = string
}