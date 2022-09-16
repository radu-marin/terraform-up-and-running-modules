resource "aws_db_instance" "example" {
  identifier = "terraform-up-and-running-${var.db_name}-db"
  engine = "mysql"
  allocated_storage = 10
  instance_class = "db.t2.micro"
  db_name = var.db_name 
  username = var.db_username

  # Don't insert password in plain text, use smth like aws secrets manager
  # but there are also other 'secret store-data source' combos (check pg 140)
  # secret manager ex:
  # password = data.aws_secretsmanager_secret_version.db_password.secret_string

  # need to use export TF_VAR_db_password="(YOUR_DB_PASSWORD)" to setup (check variables.tf)
  password = var.db_password 
  # needed next 3 variables because it didn't want to destroy the RDS db
  skip_final_snapshot = true
  backup_retention_period = 0
  apply_immediately = true
}

# secret manager ex:
# data "aws_secretsmanager_secret_version" "db_password" {
#     secret_id = "mysql-master-password-stage"
# }
# retrieve with data.aws_secretsmanager_secret_version.db_password.secret_string.password
