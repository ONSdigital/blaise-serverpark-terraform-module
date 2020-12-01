output service_account {
  description = "VM service account"
  value       = data.google_service_account.default.account_id
}

output instances {
  description = "map of instance data used by the reverse proxy"
  value = [for idx, instance in google_compute_instance_from_template.instance :
    { name : instance.name,
      hostname : instance.name,
      fq_internal_name : "${instance.name}.${instance.zone}.c.${var.project_id}.internal"
    }
  ]
}

output hostnames {
  description = "list of instance hostnames"
  value       = [for x in google_compute_instance_from_template.instance : x.name]
}

output admin_username {
  description = "blaise admin username"
  value       = var.blaise_admin_username
}

output admin_password {
  description = "blaise admin password"
  sensitive   = true
  value       = random_password.blaise_admin_password.result
}

output windows_username {
  description = "windows root account username"
  value       = var.windows_username
}

output windows_password {
  description = "windows root account password"
  sensitive   = true
  value       = random_password.windows_password.result
}

output definition {
  description = "server park definition for passing to dependencies"
  value = {
    management_endpoint : "get-management-fqdn",
    name : var.server_park_name,
    cati_endpoint : "get-cati-instance-fqdn"
  }
}
