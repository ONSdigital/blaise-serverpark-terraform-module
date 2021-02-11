variable project_id { type = string }
variable region { type = string }
variable zones { type = string }
variable env { type = string }
#variable network { type = string }
#variable subnet_cidr { type = string }
variable vm_subnet_name { type = string }
variable load_balancer_whitelist { type = list(string) }

variable vm_service_account_name {
  type        = string
  description = "blaise VM service account"
}

variable azure_agent_envname { type = string }
variable azure_agent_input_token { type = string }
variable azure_project_url { type = string }
variable service_azure_agent_name { type = string }

variable blaise_services { type = string }

#variable blaise_install_vars { type = map }
#variable blaise_runtime_vars { type = map }

variable blaise_serial_number { type = string }
variable blaise_activation_code { type = string }
variable blaise_admin_username { type = string }
#variable blaise_admin_password { type = string }
variable blaise_install_distributables_bucket { type = string }
variable blaise_dqs_bucket { type = string }
variable blaise_nifi_bucket { type = string }
variable blaise_nisra_bucket { type = string }

#CloudSQL Information
variable cloudsql_connect { type = string }
variable cloudsql_ip { type = string }
variable cloudsql_user { type = string }
variable cloudsql_pw { type = string }

variable windows_username {
  type        = string
  default     = "windows"
  description = "username for windows account"
}
#variable windows_password { type = string }

variable instances {
  type = map(object({
    roles = list(string)
  }))
  description = "map serverpark instances: each entry has a list of roles"
  default = {
    basic = { roles = ["management", "cati", "data", "session", "resource"] },
  }

  #
  # examples:
  #  [
  #   { roles = ["management", "data", "resource", "dataentry"] },   # management server with data, resource and data entry roles
  #   { roles = ["cati", "session"] }, # first cati/session server
  #   { roles = ["cati", "session"] }, # second cati/session server
  #  ]
  #
  #  # management server with four web/data servers
  #  [
  #   { roles = ["management", "data", "resource"] },
  #   { roles = ["web", "data"] },
  #   { roles = ["web", "data"] },
  #   { roles = ["web", "data"] },
  #   { roles = ["web", "data"] }
  #  ]
  #
}

variable labels {
  type        = map
  description = "labels to append to each VM instance"
  default     = {}
}


variable vm_tags {
  type    = list(string)
  default = ["blaise"]
}

variable vm_machine_type {
  type    = string
  default = "n2-highmem-2"
}

variable source_image_family {
  type    = string
  default = "windows-2019"
}

variable source_image_project {
  type    = string
  default = "windows-cloud"
}

variable server_park_name {
  type        = string
  description = "server park name"
}

variable azuredevopsdns {
  type        = string
  description = "azure devops dns"
}

variable company_name {
  type        = string
  description = "company name of licensee"
}

variable licensee {
  type        = string
  description = "name of the license holder"
}

variable has_public_ip {
  type        = bool
  description = "if true, VMs will be created with public IP addresses"
  default     = false
}

variable external_communication_port {
  type        = number
  description = "port used by blaise server manager"
  default     = 8031
}

variable that_other_blaise_port {
  type        = number
  description = "?"
  default     = 8032
}

variable management_communication_port {
  type        = number
  description = "port used for nodes to communicate"
  default     = 8033
}


locals {
  blaise_install_vars = {
    "BLAISE_COMPANYNAME"                 = var.company_name,
    "BLAISE_LICENSEE"                    = var.licensee,
    "BLAISE_EXTERNALCOMMUNICATIONPORT"   = var.external_communication_port,
    "BLAISE_MANAGEMENTCOMMUNICATIONPORT" = var.management_communication_port,
    "BLAISE_INSTALLDIR"                  = "\"C:\\Blaise5\"",
    "BLAISE_DEPLOYFOLDER"                = "\"D:\\Blaise5\"",
    "BLAISE_INSTALLATIONTYPE"            = "Server",

    # roles
    "BLAISE_MANAGEMENTSERVER" = 0,
    "BLAISE_WEBSERVER"        = 0, # requires IIS
    "BLAISE_DATAENTRYSERVER"  = 0,
    "BLAISE_DATASERVER"       = 0,
    "BLAISE_RESOURCESERVER"   = 0,
    "BLAISE_SESSIONSERVER"    = 0,
    "BLAISE_AUDITTRAILSERVER" = 0,
    "BLAISE_CATISERVER"       = 0,

    "BLAISE_IISWEBSERVERPORT" = 80,
    "BLAISE_REGISTERASPNET"   = 1,
    "BLAISE_MACHINEKEY"       = ""
  }

  blaise_runtime_vars = {
    "BLAISE_SERVER_BINDING"         = "HTTP",
    "BLAISE_SERVER_HOST_NAME"       = "localhostx",
    "CONNECTION_EXPIRES_IN_MINUTES" = 60,
    "LIBRARY_DIRECTORY"             = "D:\\Blaise5\\Surveys\\"
  }
}
