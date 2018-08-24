#!/bin/bash
#
# Script:       azure-create-vm.sh
# Source:       https://github.com/o-pod/azure
#
# Description:  Script for creating nice structure in Microsoft Azure cloud like this:
#                  Resource group:     servers
#                  Virtual network:    servers__virtual-network
#                  Availability set:   servers__availability-set
#                  VM:                 server-01
#                  Disk:               server-01__disk-01
#                  Network interface:  server-01__private-ip-01
# 
# Version:      0.1.0
# Date:         Aug 2018
# Depends:      azure-cli
#
# Author:       Oleg Podgaisky (o-pod)
# E-mail:       oleg-podgaisky@yandex.ru
#
# Usage:        1. Enter to Azure CLI:          az login -u azureUserName
#               2. Get available locations:     az account list-locations
#               3. Get available sizes for VM:  az vm list-sizes --location locationName
#               4. Set Network options below
#                  !!!ATTENTION: Disable commands in "Create network" if Network is already exist
#               5. Set User options
#               6. Set Availability set option if you want to create a cluster
#                  !!!ATTENTION: Disable block "if" in "Create Availability set" if Availability set is already exist
#               7. Set Virtual machine options
#
#=================================================================================================


az login -u AzureUserName

### Network options
location="southcentralus"
resource_group="servers"
virt_network="servers__virtual-network"
virt_network_range="10.0.0.0/16"
subnet="default"
subnet_range="10.0.0.0/24"

### User option
user="username"
ssh_key="ssh-public-key"

### Availability set options - set empty this if you don't want to create a cluster
availability_set="servers__availability-set"

### Virtual machine options
name="server-01"
image="UbuntuLTS"
ip="10.0.0.11"
interface_suffix="__private-ip-01"
disk_suffix="__disk-01"
size="Standard_B1s"   
storage_type="Premium_LRS"    # Disk types: SSD = "Premium_LRS"; HDD = "Standard_LRS"



### Create network
az group create --location ${location} --name ${resource_group}

az network vnet create --location ${location} --resource-group ${resource_group} --name ${virt_network} --address-prefixes ${virt_network_range}

az network vnet subnet create --resource-group ${resource_group} --vnet-name ${virt_network} --name ${subnet} --address-prefix ${subnet_range}



### Create Availability set (if variable availability_set is defined)
availability_set_as_option=""
if [ "${availability_set}" != "" ]; then
    az vm availability-set create --location ${location} --resource-group ${resource_group} --name ${availability_set}
    availability_set_as_option="--availability-set ${availability_set}"
fi



### Create VM
az network nic create --resource-group ${resource_group} --location ${location} --name ${name}${interface_suffix} --subnet ${subnet} --vnet-name ${virt_network} --private-ip-address ${ip}

az vm create --name ${name} --admin-username ${user} --ssh-key-value "${ssh_key}" --resource-group ${resource_group} --location ${location} --image ${image} --size ${size} --nics ${name}${interface_suffix} --storage-sku ${storage_type} ${availability_set_as_option}



### Normalize disk
az vm stop --name ${name} --resource-group ${resource_group}

disk_old=$(az vm get-instance-view --name ${name} --resource-group ${resource_group} | grep -o "${name}_OsDisk[0-9a-z\_]\{1,\}" | head -1)

az disk create --location ${location} --resource-group ${resource_group} --name ${name}${disk_suffix} --source ${disk_old} --sku ${storage_type}

az vm delete --name ${name} --resource-group ${resource_group} --yes

az vm create --name ${name} --resource-group ${resource_group} --location ${location} --size ${size} --nics ${name}${interface_suffix} --attach-os-disk ${name}${disk_suffix} --os-type Linux ${availability_set_as_option}

az disk delete --resource-group ${resource_group} --name ${disk_old} --yes


