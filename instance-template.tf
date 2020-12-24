data "google_service_account" "default" {
  account_id = var.vm_service_account_name
}

data "google_compute_subnetwork" "default" {
  name = var.vm_subnet_name
}

resource "google_compute_firewall" "default" {
  name    = join("-", ["blaise", var.server_park_name])
  project = var.project_id
  network = data.google_compute_subnetwork.default.network

  allow {
    protocol = "tcp"
    ports = [
      "80",
      "443",
      "3389",
      var.external_communication_port,
      var.management_communication_port,
      var.that_other_blaise_port
    ]
  }

  source_ranges = concat(var.load_balancer_whitelist, data.google_compute_subnetwork.default.ip_cidr_range)

  target_tags = var.vm_tags
}

module "blaise_instance_template" {
  source               = "github.com/terraform-google-modules/terraform-google-vm/modules/instance_template"
  name_prefix          = var.server_park_name
  project_id           = var.project_id
  machine_type         = var.vm_machine_type
  source_image_family  = var.source_image_family
  source_image_project = var.source_image_project
  disk_type            = "pd-ssd"
  disk_size_gb         = 100
  auto_delete          = true
  subnetwork           = data.google_compute_subnetwork.default.self_link
  tags                 = var.vm_tags

  access_config = var.has_public_ip ? [
    {
      nat_ip       = ""
      network_tier = "PREMIUM"
    }
  ] : []

  service_account = {
    email  = data.google_service_account.default.email
    scopes = ["cloud-platform"]
  }

  additional_disks = [
    {
      disk_name    = "d-drive"
      device_name  = "D:\\"
      disk_size_gb = 10
      disk_type    = "pd-standard"
      auto_delete  = "true"
      boot         = "false"
    }
  ]
}
