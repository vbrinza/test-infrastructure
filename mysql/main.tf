variable "name" {default="test1"}
variable "database_version" {default="MYSQL_5_7"}
variable "project" {}
variable "region" {default="europe-west1"}
variable "db_name" {}
variable "user_name" {}

module "mysql-db" {
  source           = "github.com/vbrinza/terraform-google-sql-db"
  name             = "${var.name}"
  database_version = "${var.database_version}"
  project          = "${var.project}"
  region           = "${var.region}"
  db_name          = "${var.db_name}"
  user_name        = "${var.user_name}"
}
