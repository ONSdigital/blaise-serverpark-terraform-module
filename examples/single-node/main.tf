data "google_compute_lb_ip_ranges" "whitelist" {
}

resource "google_service_account" "blaise" {
  account_id   = "blaise-compute"
  project      = var.project_id
  display_name = "Blaise compute service account"
}

module "blaise_server_park" {
  source = "../../."

  project_id = var.project_id
  zones      = var.node_zones
  region     = var.region
  env        = var.env

  vm_subnet_name          = "blaise-vms"
  vm_service_account_name = google_service_account.blaise.account_id
  load_balancer_whitelist = data.google_compute_lb_ip_ranges.whitelist.network

  server_park_name = "gusty"
  company_name     = "ONS"
  licensee         = "ONS"

  external_communication_port   = 8033
  management_communication_port = 8031

  instances = {
    node    = { roles = ["management", "session", "data", "cati", "dataentry", "resource", "web"] },
  }

  # csharp services
  blaise_services                      = var.blaise_services
  blaise_serial_number                 = data.google_kms_secret.blaise_serial.plaintext
  blaise_activation_code               = data.google_kms_secret.blaise_activation.plaintext
  blaise_admin_username                = "blaise"
  blaise_install_distributables_bucket = "${var.project_id}-winvm-data"

  azure_agent_poolname    = var.azure_agent_poolname
  azure_agent_input_token = data.google_kms_secret.azure_agent_token.plaintext
  azure_project_url       = var.azure_project_url

  service_azure_agent_name = "tel"
}
