# VM Initialisation

Blaise VMs are initialised by an initialisation script uploaded by `terraform` and configured by variables in the metadata server (also uploaded by `terraform`).

## Prerequisites
### Azure Personal Access Token

A Personal Access Token (PAT) needs to be in place before using the scripts. This allows the agent that will be created to register.
You can [create a New Token](https://dev.azure.com/blaise-gcp/_usersSettings/tokens) in the blaise-gcp project.
Currently we give full access, but this needs to be limited to what is needed.

New/regenerated [tokens must be added to terraform encrypted with KMS](https://github.com/ONSdigital/blaise-gcp-terraform#creating-kms-secrets), and the encrypted ciphertext included in the `.tfvars`.

### Agent Pools

An agent pool allows us to manage multiple agents at once. There should be one agent pool per environment, e.g. ons-blaise-dev for dev, with access permission to all pipelines.
You can add an agent pool from the [project settings](https://dev.azure.com/blaise-gcp/csharp/_settings/agentqueues).

**The agent pool must exist before running this script.**

**Do not use the main agent pools for your sandbox**

## VM-Startup

The initialisation script runs various Powershell commands:

1. Configures the firewall.
2. Disables Windows updates.
3. Set Timezone to GMT (with daylight savings).
4. Attaches and formats the D drive:
    + [Initialize-Disk](https://docs.microsoft.com/en-us/powershell/module/storage/initialize-disk)
    + [New-Partition](https://docs.microsoft.com/en-us/powershell/module/storage/new-partition)
    + [Format-Volume](https://docs.microsoft.com/en-us/powershell/module/storage/format-volume)
5. Creates a user on the VM with name and password from the metadata server variables `BLAISE_WINDOWS_USERNAME` and `BLAISE_WINDOWS_PASSWORD` (8 character minimum)
    + [New-LocalUser](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.localaccounts/new-localuser)
    + [ConvertTo-SecureString](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.security/convertto-securestring)
6. Installs the AzureAgent that will be used for deploying the C# services to the Blaise VMs.
    + Azure Agent installer is downloaded from the GCP bucket with the Blaise redistributables
    + [Download file](https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/v2-windows?view=azure-devops#download-and-configure-the-agent)
    + [Unattended install](https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/v2-windows?view=azure-devops#unattended-config)
7. Installs ISS.
    + [Install-WindowsFeature](https://docs.microsoft.com/en-us/powershell/module/servermanager/install-windowsfeature)
      This process is long, and can appear to be stalled; let it continue.
8. Copies `Blaise` redistributables from a GCP bucket to `C:\dev`
    + `gsutil`
    + [Expand-Archive](https://docs.microsoft.com/en-us/powershell/module/Microsoft.PowerShell.Archive/Expand-Archive)
9. Installs the Blaise software using parameters from the environment (on the GCP VMs the environment variables are set by the script to be values pulled from the metadata server).
    + [Invoke-RestMethod](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/invoke-restmethod) pulls values from the metadata server. (404 if the variable is not present, but also splurges a load of junk to stdout).
    + `msiexec`

The Blaise installer script pulls values from the VM [metadata server](https://cloud.google.com/compute/docs/storing-retrieving-metadata):

+ `BLAISE_GCP_BUCKET`: GCP bucket holding the Blaise installer
+ `BLAISE_LICENSEE` : name of the license holder
+ `BLAISE_SERIALNUMBER`: Blaise serial number
+ `BLAISE_ACTIVATIONCODE`: Blaise activation code
+ `BLAISE_INSTALLDIR`: Blaise install directory (where Blaise software will be installed)
+ `BLAISE_DEPLOYFOLDER`: Blaise deployment directory (where survey information will be stored)
+ `BLAISE_ADMINUSER`: Blaise administrator username
+ `BLAISE_ADMINPASS`: Blaise administrator password
+ `BLAISE_SERVERPARK`: Server park to which this instance belongs
+ `BLAISE_AZURE_AGENT_TOKEN`: Personal Access Token used to register the agent
+ `BLAISE_WINDOWS_USERNAME`: Username for the windows VM user account
+ `BLAISE_WINDOWS_PASSWORD`: Password for the windows VM user account

These values should be set in your `terraform.tfvars` file and are referenced in `vm.tf`. __If the values are not present on the metadata server the installer script will throw an error__.


### Monitoring Startup Script
The process is very long running (~20 minutes). ["Windows instances experience a longer startup time because of the sysprep process."](https://cloud.google.com/compute/docs/instances/windows/creating-managing-windows-instances#start_check)

The installer writes output which can be monitored on the serial ports of the VMs [more](https://cloud.google.com/compute/docs/instances/viewing-serial-port-output):

```bash
gcloud compute instances tail-serial-port-output $VM_NAME --zone $GCP_ZONE --port 1
```

or

```bash
gcloud compute instances get-serial-port-output $VM_NAME --zone $GCP_ZONE --port 1
```

### Testing Startup Script
The startup script can be tested on the machine by RDPing onto it and running ([info](https://cloud.google.com/compute/docs/startupscript?hl=en_US#providing_a_startup_script_for_windows_instances):

```powershell
C:\Program Files\Google\Compute Engine\metadata_scripts\run_startup_scripts.cmd
```

## Forced Re-execution of the Startup Script

Running `terraform taint ; terraform plan ; terraform apply` on the VM nodes causes the startup script to be executed by provisioning a new VM.
There is no way to 'invoke' the startup script via `terraform`.

A bug in `terraform` means that the new VMs will __not__ be added to the `blaise`.`compute_instance_group`, and will not be monitored by the load balancer health check.
__No testing has been performed to see whether a VM not monitored by the health check still recieves traffic from the load balancer___.

For more information on the bug see [this issue](https://github.com/terraform-providers/terraform-provider-google/issues/54).

To force recreation of the VMs to run a startup script, apply these taints:

```bash
terraform taint google_compute_disk.d-drive[0]
terraform taint google_compute_disk.d-drive[1]
terraform taint google_compute_disk.d-drive[2]
terraform taint google_compute_disk.d-drive[3]
terraform taint google_compute_disk.d-drive[4]

terraform taint google_compute_instance.node[0]
terraform taint google_compute_instance.node[1]
terraform taint google_compute_instance.node[2]
terraform taint google_compute_instance.node[3]
terraform taint google_compute_instance.node[4]

terraform taint google_compute_instance_group.blaise
terraform taint google_compute_global_forwarding_rule.default
terraform taint google_compute_backend_service.blaise-services
terraform taint google_compute_url_map.blaise-services
terraform taint google_compute_target_https_proxy.https-proxy
terraform taint google_compute_global_forwarding_rule.default
```

Note: this will delete the `d-drives` and all data stored on them.

If your terraform state is in a GCP bucket, you will probably recieve:
```
Error 429: The rate of change requests to the object <bucket-name>/<workspace>.tflock exceeds the rate limit
```

