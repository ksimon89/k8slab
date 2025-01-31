terraform {
  required_providers {
    vsphere = {
      source = "hashicorp/vsphere"
    }
  }
}

provider "vsphere" {
  vsphere_server        = var.vsphere_server
  user                  = var.vsphere_user
  password              = var.vsphere_password
  allow_unverified_ssl  = true
}

data "vsphere_datacenter" "datacenter" {
  name = "YWL"
}

data "vsphere_datastore" "datastore" {
  name          = "M2_SSD_Datastore1"
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_compute_cluster" "cluster" {
  name          = "YWL"
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_network" "network" {
  name          = "VM Network"
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_virtual_machine" "template" {
  name          = "Server Templates/K8S-TMPv1"
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

# data "vsphere_guest_os_customization" "windows" {
#   name = "windows"
# }

resource "vsphere_virtual_machine" "k8smaster" {
  name             = "k8s-master${count.index}"
  count            = 1
  resource_pool_id = data.vsphere_compute_cluster.cluster.resource_pool_id
  datastore_id     = data.vsphere_datastore.datastore.id
  num_cpus         = 2
  memory           = 4096
  guest_id         = data.vsphere_virtual_machine.template.guest_id
  scsi_type        = data.vsphere_virtual_machine.template.scsi_type
  network_interface {
    network_id   = data.vsphere_network.network.id
    adapter_type = data.vsphere_virtual_machine.template.network_interface_types[0]
  }
  disk {
    label            = "disk0"
    size             = data.vsphere_virtual_machine.template.disks.0.size
    thin_provisioned = data.vsphere_virtual_machine.template.disks.0.thin_provisioned
  }
  clone {
    template_uuid = data.vsphere_virtual_machine.template.id
  }
}

resource "vsphere_virtual_machine" "k8sworkers" {
  name             = "k8s-worker-node${count.index}"
  count            = 3 
  resource_pool_id = data.vsphere_compute_cluster.cluster.resource_pool_id
  datastore_id     = data.vsphere_datastore.datastore.id
  num_cpus         = 2
  memory           = 8192
  guest_id         = data.vsphere_virtual_machine.template.guest_id
  scsi_type        = data.vsphere_virtual_machine.template.scsi_type
  network_interface {
    network_id   = data.vsphere_network.network.id
    adapter_type = data.vsphere_virtual_machine.template.network_interface_types[0]
  }
  disk {
    label            = "disk0"
    size             = data.vsphere_virtual_machine.template.disks.0.size
    thin_provisioned = data.vsphere_virtual_machine.template.disks.0.thin_provisioned
  }
  clone {
    template_uuid = data.vsphere_virtual_machine.template.id
    customize {
      # ... other configuration ...
      network_interface {
        ipv4_address = ""
        ipv4_netmask = 24
      }
      ipv4_gateway = "192.168.0.1"
      linux_options {
        host_name   ="k8s-worker-node${count.index}"
        domain      ="youthfulwealth.local"
      }
    }
  }
}

# Snapshot k8smaster
resource "vsphere_virtual_machine_snapshot" "k8smaster_snapshot" {
  count                = length(vsphere_virtual_machine.k8smaster)
  virtual_machine_uuid = vsphere_virtual_machine.k8smaster[count.index].id
  snapshot_name        = "snapshot-k8smaster-${count.index}-${formatdate("YYYY-MM-DD-hh-mm", timestamp())}"
  description          = "Snapshot for K8s Master Node ${count.index} created by Terraform"
  memory               = true
  quiesce              = true
}

# Snapshot k8sworkers
resource "vsphere_virtual_machine_snapshot" "k8sworkers_snapshot" {
  count                = length(vsphere_virtual_machine.k8sworkers)
  virtual_machine_uuid = vsphere_virtual_machine.k8sworkers[count.index].id
  snapshot_name        = "snapshot-k8sworker-${count.index}-${formatdate("YYYY-MM-DD-hh-mm", timestamp())}"
  description          = "Snapshot for K8s Worker Node ${count.index} created by Terraform"
  memory               = true
  quiesce              = true
}

output "k8s_master_ip" {
  value = vsphere_virtual_machine.k8smaster[0].default_ip_address
}

output "k8s_worker_ips" {
  value = [for vm in vsphere_virtual_machine.k8sworkers : vm.default_ip_address]
}

output "k8smaster_snapshot_names" {
  value = vsphere_virtual_machine_snapshot.k8smaster_snapshot[*].snapshot_name
}

output "k8sworkers_snapshot_names" {
  value = vsphere_virtual_machine_snapshot.k8sworkers_snapshot[*].snapshot_name
}