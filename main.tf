provider "google" {
  project     = "hn2021"
  region      = "us-west1"
  zone        = "us-west1-b"
}

#########
# Locals
#########

locals {

  boot_disk = [
    {
      source_image = var.source_image 
      disk_size_gb = var.disk_size_gb
      disk_type    = var.disk_type
      disk_labels  = var.disk_labels
      auto_delete  = var.auto_delete
      boot         = "true"
    },
  ]

  all_disks = concat(local.boot_disk, var.additional_disks)

  shielded_vm_configs          = var.enable_shielded_vm ? [true] : []
  confidential_instance_config = var.enable_confidential_vm ? [true] : []

  gpu_enabled = var.gpu != null
  on_host_maintenance = (
    var.preemptible || var.enable_confidential_vm || local.gpu_enabled
    ? "TERMINATE"
    : var.on_host_maintenance
  )
}

####################
# Instance Template
####################
resource "google_compute_instance" "default" {
  name             = var.name
  project                 = var.project_id
  machine_type            = var.machine_type
  labels                  = var.labels
  metadata                = var.metadata
  tags                    = var.tags
  can_ip_forward          = var.can_ip_forward
  metadata_startup_script = var.startup_script
  min_cpu_platform        = var.min_cpu_platform
 
  dynamic "boot_disk" {
    for_each = local.all_disks
    content {
      auto_delete  = lookup(boot_disk.value, "auto_delete", null)
      device_name  = lookup(boot_disk.value, "device_name", null)
      mode         = lookup(boot_disk.value, "mode", null)


       dynamic "initialize_params" {
        for_each = var.initialize_params
        content {
          size       = initialize_params.value.size
          type       = initialize_params.value.type
          image       =initialize_params.value.image
        }
      }

    }
  }

  dynamic "service_account" {
    for_each = [var.service_account]
    content {
      email  = lookup(service_account.value, "email", null)
      scopes = lookup(service_account.value, "scopes", null)
    }
  }

  network_interface {
    network            = var.network
    subnetwork         = var.subnetwork
    subnetwork_project = var.subnetwork_project
    network_ip         = length(var.network_ip) > 0 ? var.network_ip : null
    dynamic "access_config" {
      for_each = var.access_config
      content {
        nat_ip       = access_config.value.nat_ip
        network_tier = access_config.value.network_tier
      }
    }
  }

  # dynamic "network_interface" {
  #   for_each = var.additional_networks
  #   content {
  #     network            = network_interface.value.network
  #     subnetwork         = network_interface.value.subnetwork
  #     subnetwork_project = network_interface.value.subnetwork_project
  #     network_ip         = length(network_interface.value.network_ip) > 0 ? network_interface.value.network_ip : null
  #     dynamic "access_config" {
  #       for_each = network_interface.value.access_config
  #       content {
  #         nat_ip       = access_config.value.nat_ip
  #         network_tier = access_config.value.network_tier
  #       }
  #     }
  #   }
  # }



  # scheduling must have automatic_restart be false when preemptible is true.
  scheduling {
    preemptible         = var.preemptible
    automatic_restart   = ! var.preemptible
    on_host_maintenance = local.on_host_maintenance
  }

  dynamic "shielded_instance_config" {
    for_each = local.shielded_vm_configs
    content {
      enable_secure_boot          = lookup(var.shielded_instance_config, "enable_secure_boot", shielded_instance_config.value)
      enable_vtpm                 = lookup(var.shielded_instance_config, "enable_vtpm", shielded_instance_config.value)
      enable_integrity_monitoring = lookup(var.shielded_instance_config, "enable_integrity_monitoring", shielded_instance_config.value)
    }
  }

  confidential_instance_config {
    enable_confidential_compute = var.enable_confidential_vm
  }

  dynamic "guest_accelerator" {
    for_each = local.gpu_enabled ? [var.gpu] : []
    content {
      type  = guest_accelerator.value.type
      count = guest_accelerator.value.count
    }
  }
}

resource "google_service_account" "sa" {
  account_id   = "my-service-account"
  display_name = "A service account that only Jane can use"
}

resource "google_service_account_iam_binding" "admin-account-iam" {
  service_account_id = google_service_account.sa.name
  role               = "roles/iam.serviceAccountUser"

  members = [
    "user:vjpatel8500@gmail.com",
  ]
}