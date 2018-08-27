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
# Version:      0.2.0
# Date:         Aug 2018
# Depends:      azure-cli
#
# Author:       Oleg Podgaisky (o-pod)
# E-mail:       oleg-podgaisky@yandex.ru
#
# Usage:        1. Set azureUserName for entering into CLI
#               2. Get available locations:        az account list-locations
#               3. Get available sizes for VM:     az vm list-sizes --location locationName
#               4. Set Network options below
#               5. Set User options
#               6. Set Availability Set option if you want to create a cluster
#               7. Set Virtual machine options
#
#======================================================================================================


az login -u AzureUserName
echo

### Network options
#
location="southcentralus"
resource_group="servers"
virt_network="servers__virtual-network"
virt_network_range="10.0.0.0/16"
subnet="default"
subnet_range="10.0.0.0/24"

### User option
#
user="username"
ssh_key="ssh-public-key"

### Availability set options - set empty this if you don't want to create a cluster
#
availability_set="servers__availability-set"

### Virtual machine options
#
name="server-01"
image="UbuntuLTS"
ip="10.0.0.11"
interface_suffix="__private-ip-01"
disk_suffix="__disk-01"
size="Standard_B1s"           # Available sizes:  az vm list-sizes --location locationName
storage_type="Premium_LRS"    # Disk types:   SSD = "Premium_LRS"; HDD = "Standard_LRS"



### Create Resource group
#
echo "=== Creating a Resource group..."
existence=$(az group exists --name ${resource_group})
if [ "${existence}" == "true" ]; then
    echo "The Resource group \"${resource_group}\" is already exist."
    echo "Skipped!!!"
else
    az group create --location ${location} --name ${resource_group}
fi
echo



### Create Virtual network and Subnet
#
echo "=== Creating a new Virtual network..."
existence=$(az network vnet list | grep "name" | grep "${virt_network}")
if [ "${existence}" != "" ]; then
    echo "The Virtual network \"${virt_network}\" is already exist."
    echo "Skipped!!!"
else
    az network vnet create --location ${location} --resource-group ${resource_group} --name ${virt_network} --address-prefixes ${virt_network_range}
fi
echo

echo "=== Creating a Subnet in the Virtual network..."
existence=$(az network vnet subnet list --resource-group ${resource_group} --vnet-name ${virt_network} | grep "name" | grep "${subnet}")
if [ "${existence}"  != "" ]; then
    echo "The Subnet \"${subnet}\" is already exist in the Virtual network \"${virt_network}\"."
    echo "Skipped!!!"
else
    az network vnet subnet create --resource-group ${resource_group} --vnet-name ${virt_network} --name ${subnet} --address-prefix ${subnet_range}
fi
echo



### Create Availability set (if variable availability_set is defined)
#
availability_set_as_option=""
if [ "${availability_set}" != "" ]; then
    echo "=== Creating an Availability set..."
    existence=$(az vm availability-set list --resource-group ${resource_group} | grep "name" | grep "${availability_set}")
    if [ "${existence}"  != "" ]; then
        echo "The Availability set \"${availability_set}\" is already exist."
        echo "Skipped!!!"
    else
        az vm availability-set create --location ${location} --resource-group ${resource_group} --name ${availability_set}
        availability_set_as_option="--availability-set ${availability_set}"
    fi
fi
echo



### Create Network interface
#
echo "=== Creating a Network interface..."
existence=$(az network nic list --resource-group ${resource_group} | grep "name" | grep "${name}${interface_suffix}")
if [ "${existence}" != "" ]; then
    echo "The Network interface \"${name}${interface_suffix}\" is already exist."
    echo "Skipped!!!"
else
    az network nic create --resource-group ${resource_group} --location ${location} --name ${name}${interface_suffix} --subnet ${subnet} --vnet-name ${virt_network} --private-ip-address ${ip}
fi
echo



### Create raw VM (will be deleted after disk normalization)
#
echo "=== Creating a raw Virtual machine..."
existence=$(az vm list --resource-group ${resource_group} | grep "name" | grep "${name}")
if [ "${existence}" != "" ]; then

    echo "The Virtual machine \"${name}\" is already exist."
    echo "Skipped!!!"
    exit
else
    az vm create --name ${name} --admin-username ${user} --ssh-key-value "${ssh_key}" --resource-group ${resource_group} --location ${location} --image ${image} --size ${size} --nics ${name}${interface_suffix} --storage-sku ${storage_type} ${availability_set_as_option}
fi
echo



### Normalize disk name
#
az vm stop --name ${name} --resource-group ${resource_group}

echo "=== Creating a new disk with nice name..."
disk_old=$(az vm get-instance-view --name ${name} --resource-group ${resource_group} | grep -o "${name}_OsDisk[0-9a-z\_]\{1,\}" | head -1)

az disk create --location ${location} --resource-group ${resource_group} --name ${name}${disk_suffix} --source ${disk_old} --sku ${storage_type}

echo "=== Deteling raw Virtual machine..."
az vm delete --name ${name} --resource-group ${resource_group} --yes

echo "=== Creating a Virtual machine..."
az vm create --name ${name} --resource-group ${resource_group} --location ${location} --size ${size} --nics ${name}${interface_suffix} --attach-os-disk ${name}${disk_suffix} --os-type Linux ${availability_set_as_option}

echo "=== Deleting raw disk"
az disk delete --resource-group ${resource_group} --name ${disk_old} --yes

