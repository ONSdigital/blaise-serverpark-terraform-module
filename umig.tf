locals {
  role_label_concatenation_char = "-"
}

resource "random_id" "name_suffix" {
  count       = length(var.instances)
  byte_length = 4
}

resource "random_password" "windows_password" {
  length      = 16
  special     = false
  min_numeric = 2
  min_lower   = 2
  min_upper   = 2
  
}

resource "random_password" "blaise_admin_password" {
  length  = 16
  special = false
}

resource "random_password" "machinekey" {
  length  = 16
  upper   = true
  lower   = false
  special = false
}

resource "google_compute_instance_from_template" "instance" {
  for_each = var.instances
  name     = join("-", ["blaise", var.server_park_name, each.key])
  zone     = join("-", [var.region, var.zones])

  source_instance_template = module.blaise_instance_template.self_link

  # metadata overrides all metadata in the template, so we have to do it all here.
  metadata = merge(local.blaise_install_vars,
    local.blaise_runtime_vars,
    {
      "BLAISE_SERVERPARK"         = var.server_park_name,
      "BLAISE_ADMIN_NODE_NAME"    = join("-", ["blaise", var.server_park_name, keys(var.instances)[0]]), # we need this before building the group...
      "BLAISE_MACHINEKEY"         = random_password.machinekey.result,
      "BLAISE_SERIALNUMBER"       = var.blaise_serial_number,
      "BLAISE_ACTIVATIONCODE"     = var.blaise_activation_code,
      "BLAISE_ADMINUSER"          = var.blaise_admin_username,
      "BLAISE_ADMINPASS"          = random_password.blaise_admin_password.result,
      "BLAISE_GCP_BUCKET"         = var.blaise_install_distributables_bucket,
      "BLAISE_WINDOWS_USERNAME"   = var.windows_username,
      "BLAISE_WINDOWS_PASSWORD"   = random_password.windows_password.result,
      "BLAISE_CLOUDSQL_CONNECT"   = var.cloudsql_connect,
      "BLAISE_CLOUDSQL_USER"      = var.cloudsql_user,
      "BLAISE_CLOUDSQL_PW"        = var.cloudsql_pw,
      "ENV_PROJECT_ID"            = var.project_id
      "ENV_BLAISE_ADMIN_USER"     = var.blaise_admin_username,
      "ENV_BLAISE_ADMIN_PASSWORD" = random_password.blaise_admin_password.result,

      # azure csharp stuff
      "BLAISE_AZURE_PROJECT_URL"        = var.azure_project_url,
      "BLAISE_AZURE_AGENT_INPUT_TOKEN"  = var.azure_agent_input_token,
      "BLAISE_AZURE_AGENT_ENV_NAME"     = var.azure_agent_envname,
      "BLAISE_SERVICES_LIST"            = var.blaise_services,

      # server park roles
      "BLAISE_MANAGEMENTSERVER" = contains(each.value.roles, "management") ? "1" : "0",
      "BLAISE_WEBSERVER"        = contains(each.value.roles, "webserver") ? "1" : "0",
      "BLAISE_DATAENTRYSERVER"  = contains(each.value.roles, "dataentry") ? "1" : "0",
      "BLAISE_DATASERVER"       = contains(each.value.roles, "data") ? "1" : "0",
      "BLAISE_RESOURCESERVER"   = contains(each.value.roles, "resource") ? "1" : "0",
      "BLAISE_SESSIONSERVER"    = contains(each.value.roles, "session") ? "1" : "0",
      "BLAISE_AUDITTRAILSERVER" = contains(each.value.roles, "audittrail") ? "1" : "0",
      "BLAISE_CATISERVER"       = contains(each.value.roles, "cati") ? "1" : "0"

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
      name = each.key
      type = "server-park"
      "server_park_name" = var.server_park_name # deprecate this
      "blaise_server_park_name" = var.server_park_name
      "blaise_server_park_roles" = join(local.role_label_concatenation_char, each.value.roles)
    }
  )
}


resource "google_compute_instance_group" "serverpark" {
  name      = join("-", ["blaise", var.server_park_name, var.zones])
  project   = var.project_id
  zone      = join("-", [var.region, var.zones])
  instances = [for x in google_compute_instance_from_template.instance : x.self_link]

  named_port {
    name = "blaise-external-communication-port"
    port = var.external_communication_port
  }

  named_port {
    name = "blaise-management-communication-port"
    port = var.management_communication_port
  }
}
