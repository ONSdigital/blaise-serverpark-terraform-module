terraform {
  backend "gcs" {
  }
  required_version = "0.12.28"
}

provider "google" {
  version = "3.42.0"
  project = var.project_id
  region  = var.region
}

provider "random" {
  version = "~> 2.2"
}
