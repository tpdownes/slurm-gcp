/**
 * Copyright (C) SchedMD LLC.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

variable "project_id" {
  type        = string
  description = "Project ID to create resources in."
}

variable "slurm_cluster_name" {
  type        = string
  description = "Cluster name, used for resource naming and slurm accounting."

  validation {
    condition     = can(regex("^[a-z](?:[a-z0-9]{0,9})$", var.slurm_cluster_name))
    error_message = "Variable 'slurm_cluster_name' must be a match of regex '^[a-z](?:[a-z0-9]{0,9})$'."
  }
}

variable "partition_name" {
  description = "Name of Slurm partition."
  type        = string

  validation {
    condition     = can(regex("^[a-z](?:[a-z0-9]{0,6})$", var.partition_name))
    error_message = "Variable 'partition_name' must be a match of regex '^[a-z](?:[a-z0-9]{0,6})$'."
  }
}

variable "partition_conf" {
  description = <<EOD
Slurm partition configuration as a map.
See https://slurm.schedmd.com/slurm.conf.html#SECTION_PARTITION-CONFIGURATION
EOD
  type        = map(string)
  default     = {}
}

variable "partition_startup_scripts" {
  description = "List of scripts to be ran on compute VM startup."
  type = list(object({
    filename = string
    content  = string
  }))
  default = []
}

variable "partition_startup_scripts_timeout" {
  description = <<EOD
The timeout (seconds) applied to each script in partition_startup_scripts. If
any script exceeds this timeout, then the instance setup process is considered
failed and handled accordingly.

NOTE: When set to 0, the timeout is considered infinite and thus disabled.
EOD
  type        = number
  default     = 300
}

variable "partition_nodes" {
  description = <<EOD
Compute nodes contained with this partition.

* node_count_static      : number of persistant nodes.
* node_count_dynamic_max : max number of burstable nodes.
* group_name             : node group unique identifier.
* node_conf              : map of Slurm node line configuration.

See module slurm_instance_template.
EOD
  type = list(object({
    node_count_static      = number
    node_count_dynamic_max = number
    group_name             = string
    node_conf              = map(string)
    access_config = list(object({
      nat_ip       = string
      network_tier = string
    }))
    additional_disks = list(object({
      disk_name    = string
      device_name  = string
      disk_size_gb = number
      disk_type    = string
      disk_labels  = map(string)
      auto_delete  = bool
      boot         = bool
    }))
    additional_networks = list(object({
      network            = string
      subnetwork         = string
      subnetwork_project = string
      network_ip         = string
      nic_type           = string
      stack_type         = string
      queue_count        = number
      access_config = list(object({
        nat_ip       = string
        network_tier = string
      }))
      ipv6_access_config = list(object({
        network_tier = string
      }))
      alias_ip_range = list(object({
        ip_cidr_range         = string
        subnetwork_range_name = string
      }))
    }))
    bandwidth_tier         = string
    can_ip_forward         = bool
    disable_smt            = bool
    disk_auto_delete       = bool
    disk_labels            = map(string)
    disk_size_gb           = number
    disk_type              = string
    enable_confidential_vm = bool
    enable_oslogin         = bool
    enable_shielded_vm     = bool
    enable_spot_vm         = bool
    gpu = object({
      count = number
      type  = string
    })
    instance_template    = string
    labels               = map(string)
    machine_type         = string
    metadata             = map(string)
    min_cpu_platform     = string
    on_host_maintenance  = string
    preemptible          = bool
    reservation_name     = string
    maintenance_interval = string
    service_account = object({
      email  = string
      scopes = list(string)
    })
    shielded_instance_config = object({
      enable_integrity_monitoring = bool
      enable_secure_boot          = bool
      enable_vtpm                 = bool
    })
    spot_instance_config = object({
      termination_action = string
    })
    source_image_family  = string
    source_image_project = string
    source_image         = string
    tags                 = list(string)
  }))

  validation {
    condition = alltrue([
      for x in var.partition_nodes : can(regex("^[a-z](?:[a-z0-9]{0,5})$", x.group_name))
    ])
    error_message = "Items 'group_name' must be a match of regex '^[a-z](?:[a-z0-9]{0,5})$'."
  }

  validation {
    condition = alltrue([
      for x in var.partition_nodes : x.node_count_static >= 0
    ])
    error_message = "Items 'node_count_static' must be >= 0."
  }

  validation {
    condition = alltrue([
      for x in var.partition_nodes : x.node_count_dynamic_max >= 0
    ])
    error_message = "Items 'node_count_dynamic_max' must be >= 0."
  }

  validation {
    condition = alltrue([
      for x in var.partition_nodes : sum([x.node_count_static, x.node_count_dynamic_max]) > 0
    ])
    error_message = "Sum of 'node_count_static' and 'node_count_dynamic_max' must be > 0."
  }

  validation {
    condition = alltrue([
      for x in var.partition_nodes
      : contains(["STOP", "DELETE"], x.spot_instance_config.termination_action) if x.spot_instance_config != null
    ])
    error_message = "Value of spot_instance_config.termination_action must be one of: STOP; DELETE."
  }

  validation {
    condition = alltrue([
      for x in var.partition_nodes
      : x.enable_spot_vm == x.preemptible if x.enable_spot_vm == true && x.instance_template == null
    ])
    error_message = "Required: preemptible=true when enable_spot_vm=true."
  }

  validation {
    condition = alltrue([
      for x in var.partition_nodes
      : length(x.access_config) <= 1
    ])
    error_message = "At most one access config currently supported (per partition_nodes group/object)."
  }
}

variable "subnetwork_project" {
  description = "The project the subnetwork belongs to."
  type        = string
  default     = null
}

variable "subnetwork" {
  description = "The subnetwork to attach instances to. A self_link is prefered."
  type        = string
  default     = ""
}

variable "region" {
  description = "The region of the subnetwork."
  type        = string
  default     = ""
}

variable "zone_target_shape" {
  description = <<EOD
Strategy for distributing VMs across zones in a region.
ANY
  GCE picks zones for creating VM instances to fulfill the requested number of VMs
  within present resource constraints and to maximize utilization of unused zonal
  reservations.
ANY_SINGLE_ZONE (default)
  GCE always selects a single zone for all the VMs, optimizing for resource quotas,
  available reservations and general capacity.
BALANCED
  GCE prioritizes acquisition of resources, scheduling VMs in zones where resources
  are available while distributing VMs as evenly as possible across allowed zones
  to minimize the impact of zonal failure.
EOD
  type        = string
  default     = "ANY_SINGLE_ZONE"
  validation {
    condition     = contains(["ANY", "ANY_SINGLE_ZONE", "BALANCED"], var.zone_target_shape)
    error_message = "Allowed values for zone_target_shape are \"ANY\", \"ANY_SINGLE_ZONE\", or \"BALANCED\"."
  }
}

variable "zone_policy_allow" {
  description = <<EOD
Partition nodes will prefer to be created in the listed zones. If a zone appears
in both zone_policy_allow and zone_policy_deny, then zone_policy_deny will take
priority for that zone.
EOD
  type        = set(string)
  default     = []

  validation {
    condition = alltrue([
      for x in var.zone_policy_allow : length(regexall("^[a-z]+-[a-z]+[0-9]-[a-z]$", x)) > 0
    ])
    error_message = "Must be a match of regex '^[a-z]+-[a-z]+[0-9]-[a-z]$'."
  }
}

variable "zone_policy_deny" {
  description = <<EOD
Partition nodes will not be created in the listed zones. If a zone appears in
both zone_policy_allow and zone_policy_deny, then zone_policy_deny will take
priority for that zone.
EOD
  type        = set(string)
  default     = []

  validation {
    condition = alltrue([
      for x in var.zone_policy_deny : length(regexall("^[a-z]+-[a-z]+[0-9]-[a-z]$", x)) > 0
    ])
    error_message = "Must be a match of regex '^[a-z]+-[a-z]+[0-9]-[a-z]$'."
  }
}

variable "enable_job_exclusive" {
  description = <<EOD
Enables job exclusivity. A job will run exclusively on the scheduled nodes.
EOD
  type        = bool
  default     = false
}

variable "enable_placement_groups" {
  description = <<EOD
Enables job placement groups. Instances will be colocated for a job.
EOD
  type        = bool
  default     = false
}

variable "enable_reconfigure" {
  description = <<EOD
Enables automatic Slurm reconfigure on when Slurm configuration changes (e.g.
slurm.conf.tpl, partition details). Compute instances and resource policies
(e.g. placement groups) will be destroyed to align with new configuration.

NOTE: Requires Python and Google Pub/Sub API.

*WARNING*: Toggling this will impact the running workload. Deployed compute nodes
will be destroyed and their jobs will be requeued.
EOD
  type        = bool
  default     = false
}

variable "network_storage" {
  description = <<EOD
Storage to mounted on all instances in this partition.
* server_ip     : Address of the storage server.
* remote_mount  : The location in the remote instance filesystem to mount from.
* local_mount   : The location on the instance filesystem to mount to.
* fs_type       : Filesystem type (e.g. "nfs").
* mount_options : Raw options to pass to 'mount'.
EOD
  type = list(object({
    server_ip     = string
    remote_mount  = string
    local_mount   = string
    fs_type       = string
    mount_options = string
  }))
  default = []
}

variable "partition_feature" {
  description = <<-EOD
    Any nodes with these features will be automatically put into this partition.
    NOTE: meant to be used for external dynamic nodes that register.
  EOD
  type        = string
  default     = null
}
