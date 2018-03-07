variable "project" {}
variable "cluster_name" {}
variable "username" {}
variable "password" {}

module "gke" {
  source           = "github.com/vbrinza/terraform-google-gke-cluster"
  project          = "${var.project}"
  cluster_name     = "${var.cluster_name}"
  username         = "${var.username}"
  password         = "${var.password}"
}
