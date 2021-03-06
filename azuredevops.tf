terraform {
  required_providers {
    azuredevops = {
      source = "microsoft/azuredevops"
      version = "0.1.1"
    }
  }
}

data "azuredevops_project" "csharp" {
  name = "csharp"
}

resource "azuredevops_variable_group" "azure_var_group" {
  project_id   = data.azuredevops_project.csharp.id
  name         = var.project_id
  description  = "Variable group for ${var.project_id}"
  allow_access = true

  variable {
    name  = "ENV_BLAISE_SERVER_HOST_NAME"
    value = google_compute_instance_from_template.instance["node"].name
  }
  variable {
    name  = "ENV_BLAISE_EXTERNAL_SERVER_HOST_NAME"
    value = var.azuredevopsdns
  }
  variable {
    name  = "ENV_BLAISE_SERVER_PARK_NAME"
    value = var.server_park_name
  }
  variable {
    name  = "ENV_BLAISE_ADMIN_USER"
    value = var.blaise_admin_username
  }
  variable {
    name         = "ENV_BLAISE_ADMIN_PASSWORD"
    secret_value = random_password.blaise_admin_password.result
    is_secret    = true
  }
  variable {
    name  = "ENV_BLAISE_INTERNAL_SERVER_BINDING"
    value = "HTTP"
  }
   variable {
    name  = "ENV_BLAISE_EXTERNAL_SERVER_BINDING"
    value = "HTTPS"
  }
  variable {
    name  = "ENV_BLAISE_CONNECTION_PORT"
    value = var.management_communication_port
  }
  variable {
    name  = "ENV_BLAISE_REMOTE_CONNECTION_PORT"
    value = var.external_communication_port
  }
  variable {
    name  = "ENV_LIBRARY_DIRECTORY"
    value = "D:\\Blaise5\\Surveys\\"
  }
  variable {
    name  = "ENV_CONNECTION_EXPIRES_IN_MINUTES"
    value = 60
  }
  variable {
    name  = "ENV_BLAISE_GCP_BUCKET"
    value = var.blaise_install_distributables_bucket
  }
  variable {
    name  = "ENV_BLAISE_DQS_BUCKET"
    value = var.blaise_dqs_bucket
  }
  variable {
    name  = "ENV_BLAISE_NIFI_BUCKET"
    value = var.blaise_nifi_bucket
  }
  variable {
    name  = "ENV_BLAISE_NISRA_BUCKET"
    value = var.blaise_nisra_bucket
  }
  variable {
    name  = "ENV_RESTAPI_URL"
    value = "restapi.${var.region}-a.c.${var.project_id}.internal:90"
  }
  variable {
    name  = "ENV_TOBI_URL"
    value = "https://tobi-ui-dot-${var.project_id}.nw.r.appspot.com/"
  }
  variable {
    name  = "ENV_CLOUDSQL_CONNECT"
    value = var.cloudsql_connect
  }
  variable {
    name  = "ENV_DQS_URL"
    value = "https://dqs-ui-dot-${var.project_id}.nw.r.appspot.com/"
  }
  ##Below is Used by restAPI not CloudSQL Proxy
  variable {
    name         = "ENV_DB_CONNECTIONSTRING"
    secret_value = "User Id=${var.cloudsql_user};Server=${var.cloudsql_ip};Database=blaise;Password=${var.cloudsql_pw}"
    is_secret    = true
  }
  variable {
    name  = "ENV_VM_SERVICEACCOUNT"
    value = data.google_service_account.default.email
  } 
}
