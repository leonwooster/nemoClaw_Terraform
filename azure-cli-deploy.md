# NemoClaw Azure CLI Deployment Guide (Windows CMD)

This guide deploys a Linux VM on Azure using Azure CLI from Windows CMD.

**Budget:** RM100–RM200/month total (VM + networking + storage)

---

## Prerequisites

- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) installed
- Logged in: `az login`
- Subscription set: `az account set --subscription "0953cb14-6136-4c9e-8662-51c7d5423a38"`
- Register DevTestLab provider (needed for auto-shutdown):
  ```cmd
  az provider register --namespace Microsoft.DevTestLab --wait
  ```

---

## Set Variables

Paste this block into CMD. Edit values as needed.

```cmd
set RG=nemoclaw-rg
set LOCATION=southeastasia
set PREFIX=nemoclaw
set VM_NAME=nemoclaw-vm
set VM_SIZE=Standard_D2as_v4
set ADMIN_USER=azureuser
set COMPUTER_NAME=nemoclawvm
set OS_DISK_SIZE=30
set OS_DISK_TYPE=StandardSSD_LRS
set IMAGE_PUBLISHER=Canonical
set IMAGE_OFFER=0001-com-ubuntu-server-jammy
set IMAGE_SKU=22_04-lts-gen2
set VNET_CIDR=10.10.0.0/16
set SUBNET_CIDR=10.10.1.0/24
set SSH_SOURCE_CIDR=0.0.0.0/0
set APP_PORT=3000
set APP_SOURCE_CIDR=0.0.0.0/0
set TAGS=project=nemoclaw environment=dev owner=leon costcenter=experimentation
```

> **Important:** CMD variables are session-only. If you close the terminal, set them again.

---

## Step 0 — Check VM Size Availability

Always check first to avoid SkuNotAvailable errors:

```cmd
az vm list-skus --location %LOCATION% --size %VM_SIZE% --output table
```

Look at the **Restrictions** column. If it says `NotAvailableForSubscription` for all zones, pick a different size or zone.

To see which zones are available:

```cmd
az vm list-skus --location %LOCATION% --resource-type virtualMachines --query "[?starts_with(name,'Standard_B') || starts_with(name,'Standard_D2a')].{Name:name, Zones:locationInfo[0].zones, Restrictions:restrictions[0].reasonCode}" --output table
```

**Budget-friendly VM sizes (monthly estimates):**

| VM Size           | vCPU | RAM    | Est. Cost (RM) |
|-------------------|------|--------|-----------------|
| Standard_B1s      | 1    | 1 GB   | ~30             |
| Standard_B1ms     | 1    | 2 GB   | ~50             |
| Standard_B2s      | 2    | 4 GB   | ~100            |
| Standard_D2as_v4  | 2    | 8 GB   | ~150            |
| Standard_B2ms     | 2    | 8 GB   | ~200            |

Add ~RM25 for networking + storage on top of the VM cost.

> **Note:** B-series VMs may have capacity issues in Southeast Asia. Standard_D2as_v4 in zone 2 or 3 is more reliable.

---

## Step 1 — Resource Group

```cmd
az group create --name %RG% --location %LOCATION% --tags %TAGS%
```

---

## Step 2 — Virtual Network & Subnet

```cmd
az network vnet create ^
  --resource-group %RG% ^
  --name %PREFIX%-vnet ^
  --address-prefix %VNET_CIDR% ^
  --subnet-name %PREFIX%-subnet ^
  --subnet-prefix %SUBNET_CIDR% ^
  --tags %TAGS%
```

---

## Step 3 — Public IP (Zone-Redundant)

```cmd
az network public-ip create ^
  --resource-group %RG% ^
  --name %PREFIX%-pip ^
  --sku Standard ^
  --allocation-method Static ^
  --zone 1 2 3 ^
  --tags %TAGS%
```

> The public IP must be zone-redundant to work with a zonal VM (Step 6).

---

## Step 4 — Network Security Group & Rules

```cmd
az network nsg create ^
  --resource-group %RG% ^
  --name %PREFIX%-nsg ^
  --tags %TAGS%

az network nsg rule create ^
  --resource-group %RG% ^
  --nsg-name %PREFIX%-nsg ^
  --name Allow-SSH ^
  --priority 100 ^
  --direction Inbound ^
  --access Allow ^
  --protocol Tcp ^
  --source-address-prefixes %SSH_SOURCE_CIDR% ^
  --destination-port-ranges 22

az network nsg rule create ^
  --resource-group %RG% ^
  --nsg-name %PREFIX%-nsg ^
  --name Allow-App-Port ^
  --priority 110 ^
  --direction Inbound ^
  --access Allow ^
  --protocol Tcp ^
  --source-address-prefixes %APP_SOURCE_CIDR% ^
  --destination-port-ranges %APP_PORT%
```

---

## Step 5 — Network Interface

```cmd
az network nic create ^
  --resource-group %RG% ^
  --name %PREFIX%-nic ^
  --vnet-name %PREFIX%-vnet ^
  --subnet %PREFIX%-subnet ^
  --public-ip-address %PREFIX%-pip ^
  --network-security-group %PREFIX%-nsg ^
  --tags %TAGS%
```

---

## Step 6 — Create the VM

Uses `--generate-ssh-keys` so Azure creates the SSH key pair at `~/.ssh/id_rsa` automatically.

```cmd
az vm create ^
  --resource-group %RG% ^
  --name %VM_NAME% ^
  --computer-name %COMPUTER_NAME% ^
  --size %VM_SIZE% ^
  --zone 2 ^
  --nics %PREFIX%-nic ^
  --image %IMAGE_PUBLISHER%:%IMAGE_OFFER%:%IMAGE_SKU%:latest ^
  --os-disk-size-gb %OS_DISK_SIZE% ^
  --storage-sku %OS_DISK_TYPE% ^
  --admin-username %ADMIN_USER% ^
  --generate-ssh-keys ^
  --custom-data cloud-init.yaml ^
  --patch-mode ImageDefault ^
  --tags %TAGS%
```

> **SkuNotAvailable?** Change `VM_SIZE` to one from the table in Step 0.
> **Zone 2 unavailable?** Try `--zone 3` instead.

---

## Step 7 — Auto-Shutdown Schedule

This shuts down the VM daily at 1600 UTC (12:00 AM Malaysia time) to save costs.

```cmd
az vm auto-shutdown ^
  --resource-group %RG% ^
  --name %VM_NAME% ^
  --time 1600
```

> If you get a `ConcurrentUpdate` error, wait a minute and retry.

---

## Step 8 — Verify & Connect

```cmd
REM Get public IP
az network public-ip show --resource-group %RG% --name %PREFIX%-pip --query ipAddress -o tsv
```

Copy the IP from the output, then SSH:

```cmd
ssh %ADMIN_USER%@<PUBLIC_IP>
```

Once inside the VM, check cloud-init:

```bash
cat /var/log/bootstrap-nemoclaw.log
cloud-init status --long
```

App URL: `http://<PUBLIC_IP>:3000`

---

## Cleanup (Delete Everything)

```cmd
az group delete --name %RG% --yes --no-wait
```

This removes the resource group and all resources inside it.

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| SkuNotAvailable | Run Step 0 to find available sizes. B-series often has capacity issues — try D2as_v4 |
| Zone restriction | Check which zones are free in Step 0. Use `--zone 2` or `--zone 3` |
| SSH timeout | Check NSG: `az network nsg rule list --resource-group %RG% --nsg-name %PREFIX%-nsg -o table` |
| cloud-init not running | SSH in: `cloud-init status --long` and `cat /var/log/cloud-init-output.log` |
| ConcurrentUpdate on auto-shutdown | Wait 1-2 minutes and retry the command |
| High cost | Use auto-shutdown (Step 7). Deallocate when idle: `az vm deallocate --resource-group %RG% --name %VM_NAME%` |
| Start VM after deallocate | `az vm start --resource-group %RG% --name %VM_NAME%` |
| Variables lost | CMD variables are session-only. Re-run the "Set Variables" block if you reopen the terminal |
