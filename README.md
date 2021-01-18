# Blaise Serverpark Infrastructure GCP

This is a terraform module to create and setup infrastructure to support 
a [Blaise 5](http://help.blaise.com/Blaise.html?about_blaise.htm)
[serverpark](http://help.blaise.com/Blaise.html?smservers.htm).

This module will:

+ create an initialise Windows VMs to host the Blaise 5 runtime
+ create and initialise a GCP firewall controlling access to the VMs
+ create user accounts on the Windows VMs
+ download a Blaise 5 installer from a GCP bucket
+ download other requistes for the serverpark
    + Azure Devops Agent
    + MySQL ODBC driver
    + GCP CloudSQL proxy
+ install all this stuff

After `terraform apply` has completed, the infrastructure setup will contain
the requested Windows VMs, firewalls allowing communication to and between
the VMs and output a set of variables describing the endpoints and credentials
required to connect to the VMs.

After VM creation, a [GCP Windows VM startup script](https://cloud.google.com/compute/docs/startupscript#providing_a_startup_script_for_windows_instances)
runs which performs setup of Windows, Azure Devops Agents, Blaise 5, MySQL Connector
and GCP SQL Proxy. Startup script is found [here](vm-scripts/winvm-init-script.ps1)

## Usage

Add the module to your terraform as usual.

See the `./examples` directory for examples which can be initialised and planned.

## Monitoring

The progress of VM setup can be monitored with the VM serial-port 1 output in the console
or by running:

```bash
gcloud compute instances tail-serial-port-output $INSTANCE_NAME --zone $INSTANCE_ZONE
```

## Verification of install

The easiest way to check the Blaise 5 install is to check the serial port output.
Alternatively, IAPing onto the VM will allow exploration of the VM setup.
`IAP Desktop` is a recommended tool for this action (https://github.com/GoogleCloudPlatform/iap-desktop/wiki).


## Usage


```
module "my_server_park" {
  source = "github.com/ONSdigital/blaise-serverpark-terraform-module.git?v0.1"

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
```

# Inputs

| Name | Description |
| --- | --- |
| azure_agent_envname | azure devops agent environment |
| azure_agent_input_token | Personal Access Token (PAT) for the azure devops agent |
| azure_project_url | Azure Devops project URL used by the agent |
| blaise_services | C# services running alongside the Blaise 5 install (deprecated) |
| blaise_serial_number | Blaise 5 Serial number used by the installer | 
| blaise_activation_code | Blaise 5 Activation Code used by the installer | 
| blaise_admin_username | Blaise 5 Administrator username used by the installer and to connect to the instance with `servermanager.exe` |
| blaise_install_distributables_bucket | GCP Storage bucket containing the install files. VM Service Account must have read access to this bucket | 
| cloudsql_connect | cloudsql_connect |
| cloudsql_user | cloudsql user name for the sql proxy |
| cloudsql_pw | cloudsql password for the sql proxy | 
| company_name | name of the company which owns the serial number and activation code; used by the Blaise 5 installer |
| env | Environment name (sandbox|dev|preprod) |
| external_communication_port | port used by blaise server manager; defaults to `8031` |
| has_public_ip | if true: creates a public IP for the instance |
| instances | map of instances, where `key` is the name of the VM instance and `roles` entry for each item is a list of roles the Blaise install can perform.<br /> Valid values are: [`management`, `cati`, `data`, `session`, `resource`, `dataentry`, `audittrail`] <br /> Instance names are patterned: `blaise-<server_park_name>-<instances_map_key>`.<br />NOTE: a serverpark can only have one of each `management, cati, data` role, and multiple `session, resource, dataentry` roles. |
| labels | map of key-value pairs to add as VM labels |
| load_balancer_whitelist | ip_cidrs for GCP load balancers |
| licensee | licensee of the serial number and activation code; used by the Blaise 5 installer | 
| management_communication_port | port used by blaise nodes to communicate with non-management nodes; defaults to `8033` |
| project_id | GCP project name |
| region | GCP VM instance region |
| source_image_family | GCP OS image to use on the VM instances |
| source_image_project | GCP OS image project to use on the VM instances |
| server_park_name | name of the serverpark. Instances will be named with the pattern `blaise-<server_park_name>-<instance_map_key>` |
| service_azure_agent_name | Azure Devops Agent name |
| that_other_blaise_port | |
| vm_subnet_name | GCP subnet hosting the VMs | 
| vm_service_account_name | VM service account |
| vm_tags | list of tags to add to the VMs (for networking etc) |
| vm_machine_type | GCP machine type to use for each VM instance |
| windows_username | Username for the Windows VM account |
| zones | GCP VM instance zone |

# Outputs

| Name | Description |
| --- | --- |
| service_account | VM service account ID for adding roles |
| instances | list of instances, containing the name, hostname, fully qualified internal name |
| hostnames | list of instance hostnames |
| admin_username | Blaise 5 admin username |
| admin_password | Blaise 5 admin password |
| windows_username | Windows account username |
| windows_password | Windows account password |
| definition | server park definition for passing to dependencies; map containing `management-node-endpoint`, `server_park_name`, `cati-node-endpoint`. NB: incomplete |
