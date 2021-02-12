data "google_compute_image" "blaise_image" {
  project = var.source_image_project
  family  = var.source_image_family
}

resource "google_compute_disk" "mgmt_node_d" {
  name = "blaise-${var.server_park_name}-mgmt-node-d-dribe"
  size = 10
  type = "pd-standard"
}

resource "google_compute_instance" "mgmt_node" {
  name         = "blaise-${var.server_park_name}-mgmt-node"
  project   = var.project_id
  zone         = join("-", [var.region, var.zones])
  machine_type = var.vm_machine_type
  tags         = var.vm_tags
  hostname     = var.mgmt_node_hostname

  boot_disk {
    initialize_params {
      image = data.google_compute_image.blaise_image.self_link
      size  = 100
      type  = "pd-ssd"
    }

    auto_delete = true
  }

  network_interface {
    subnetwork = data.google_compute_subnetwork.default.self_link
  }

  service_account {
    email  = data.google_service_account.default.email
    scopes = ["cloud-platform"]
  }

  attached_disk {
    source      = google_compute_disk.mgmt_node_d.self_link
    device_name = "D:\\"
  }

  metadata = merge(local.blaise_install_vars,
    local.blaise_runtime_vars,
    {
      "BLAISE_SERVERPARK"         = var.server_park_name,
      "BLAISE_MACHINEKEY"         = random_password.machinekey.result,
      "BLAISE_SERIALNUMBER"       = var.blaise_serial_number,
      "BLAISE_ACTIVATIONCODE"     = var.blaise_activation_code,
      "BLAISE_ADMINUSER"          = var.blaise_admin_username,
      "BLAISE_ADMINPASS"          = random_password.blaise_admin_password.result,
      "BLAISE_GCP_BUCKET"         = var.blaise_install_distributables_bucket,
      "BLAISE_WINDOWS_USERNAME"   = var.windows_username,
      "BLAISE_WINDOWS_PASSWORD"   = random_password.windows_password.result,
      "BLAISE_CLOUDSQL_CONNECT"   = var.cloudsql_connect,
      "BLAISE_CLOUDSQL_IP"        = var.cloudsql_ip
      "BLAISE_CLOUDSQL_USER"      = var.cloudsql_user,
      "BLAISE_CLOUDSQL_PW"        = var.cloudsql_pw,
      "ENV_PROJECT_ID"            = var.project_id
      "ENV_BLAISE_ADMIN_USER"     = var.blaise_admin_username,
      "ENV_BLAISE_ADMIN_PASSWORD" = random_password.blaise_admin_password.result,

      # azure csharp stuff
      "BLAISE_AZURE_PROJECT_URL"       = var.azure_project_url,
      "BLAISE_AZURE_AGENT_INPUT_TOKEN" = var.azure_agent_input_token,
      "BLAISE_AZURE_AGENT_ENV_NAME"    = var.azure_agent_envname,
      "BLAISE_SERVICES_LIST"           = var.blaise_services,

      # server park roles
      "BLAISE_MANAGEMENTSERVER" = "1",
      "BLAISE_WEBSERVER"        = "1",
      "BLAISE_DATAENTRYSERVER"  = "1",
      "BLAISE_DATASERVER"       = "1",
      "BLAISE_RESOURCESERVER"   = "1",
      "BLAISE_SESSIONSERVER"    = "1",
      "BLAISE_AUDITTRAILSERVER" = "1",
      "BLAISE_CATISERVER"       = "1",

      # scripts
      "SCRIPT_LOGS_CONFIG_TEMPLATE" = file("${path.module}/vm-scripts/log-config/winvm-blaise-service-log-template.conf"),
      "SCRIPT_LOGS_SERVICE_FAILURE" = file("${path.module}/vm-scripts/log-config/winvm-service-unexpected-failure.ps1"),
      "SCRIPT_LOGS_SERVICE_STATUS"  = file("${path.module}/vm-scripts/log-config/winvm-service-status.ps1"),
      "windows-startup-script-ps1"  = file("${path.module}/vm-scripts/winvm-init-script.ps1"),
      "windows-shutdown-script-ps1" = file("${path.module}/vm-scripts/winvm-shutdown-script.ps1")
  })

  labels = merge(
    var.labels,
    {
      name               = "mgmt-node"
      type               = "server-park"
      "server_park_name" = var.server_park_name
    }
  )
}
