locals {
  prefix      = var.project_prefix != "" ? var.project_prefix : "${random_string.prefix.0.result}-lab"
  ssh_key_ids = var.existing_ssh_key != "" ? [data.ibm_is_ssh_key.sshkey[0].id] : [ibm_is_ssh_key.generated_key[0].id]

  at_endpoint = "https://api.${var.region}.logging.cloud.ibm.com"

  tags = [
    "owner:${var.owner}",
    "provider:ibm",
    "region:${var.region}",
    "vpc:${local.prefix}-vpc",
    "tfworkspace:${terraform.workspace}"
  ]

  frontend_rules = [
    for r in var.frontend_rules : {
      name       = r.name
      direction  = r.direction
      remote     = lookup(r, "remote", null)
      ip_version = lookup(r, "ip_version", null)
      icmp       = lookup(r, "icmp", null)
      tcp        = lookup(r, "tcp", null)
      udp        = lookup(r, "udp", null)
    }
  ]

  zones = length(data.ibm_is_zones.regional.zones)
  vpc_zones = {
    for zone in range(local.zones) : zone => {
      zone = "${var.region}-${zone + 1}"
    }
  }
}


module "resource_group" {
  source                       = "git::https://github.com/terraform-ibm-modules/terraform-ibm-resource-group.git?ref=v1.0.5"
  resource_group_name          = var.existing_resource_group == null ? "${local.prefix}-resource-group" : null
  existing_resource_group_name = var.existing_resource_group
}

resource "random_string" "prefix" {
  count   = var.project_prefix != "" ? 0 : 1
  length  = 4
  special = false
  upper   = false
}

resource "tls_private_key" "ssh" {
  count     = var.existing_ssh_key != "" ? 0 : 1
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "ibm_is_ssh_key" "generated_key" {
  count          = var.existing_ssh_key != "" ? 0 : 1
  name           = "${local.prefix}-${var.region}-key"
  public_key     = tls_private_key.ssh.0.public_key_openssh
  resource_group = module.resource_group.resource_group_id
  tags           = local.tags
}

resource "null_resource" "create_private_key" {
  count = var.existing_ssh_key != "" ? 0 : 1
  provisioner "local-exec" {
    command = <<-EOT
      echo '${tls_private_key.ssh.0.private_key_pem}' > ./'${local.prefix}'.pem
      chmod 400 ./'${local.prefix}'.pem
    EOT
  }
}

module "observability" {
  source = "git::https://github.com/terraform-ibm-modules/terraform-ibm-observability-instances?ref=main"
  providers = {
    logdna.at = logdna.at
    logdna.ld = logdna.ld
  }
  resource_group_id          = module.resource_group.resource_group_id
  region                     = var.region
  sysdig_instance_name       = "${local.prefix}-monitoring-instance"
  enable_platform_metrics    = true
  activity_tracker_provision = false
  logdna_provision           = true
  logdna_instance_name       = "${local.prefix}-logging-instance"
  sysdig_plan                = "graduated-tier"
  logdna_plan                = "7-day"
  logdna_tags                = local.tags
  sysdig_tags                = local.tags
}

module "vpc" {
  source                      = "terraform-ibm-modules/vpc/ibm//modules/vpc"
  version                     = "1.1.1"
  create_vpc                  = true
  vpc_name                    = "${local.prefix}-vpc"
  resource_group_id           = module.resource_group.resource_group_id
  classic_access              = false
  default_address_prefix      = "auto"
  default_network_acl_name    = "${local.prefix}-default-network-acl"
  default_security_group_name = "${local.prefix}-default-security-group"
  default_routing_table_name  = "${local.prefix}-default-routing-table"
  vpc_tags                    = local.tags
  locations                   = [local.vpc_zones[0].zone, local.vpc_zones[1].zone, local.vpc_zones[2].zone]
  number_of_addresses         = "128"
  create_gateway              = true
  subnet_name                 = "${local.prefix}-frontend-subnet"
  public_gateway_name         = "${local.prefix}-pub-gw"
  gateway_tags                = local.tags
}

module "security_group" {
  source                = "terraform-ibm-modules/vpc/ibm//modules/security-group"
  version               = "1.1.1"
  create_security_group = true
  name                  = "${local.prefix}-frontend-sg"
  vpc_id                = module.vpc.vpc_id[0]
  resource_group_id     = module.resource_group.resource_group_id
  security_group_rules  = local.frontend_rules
}

resource "ibm_is_instance" "bastion" {
  name                     = "${local.prefix}-bastion"
  vpc                      = module.vpc.vpc_id[0]
  image                    = data.ibm_is_image.base.id
  profile                  = var.instance_profile
  resource_group           = module.resource_group.resource_group_id
  metadata_service_enabled = var.metadata_service_enabled

  boot_volume {
    name = "${local.prefix}-bastion-volume"
  }

  primary_network_interface {
    subnet            = module.vpc.subnet_ids[0]
    allow_ip_spoofing = var.allow_ip_spoofing
    security_groups   = [module.security_group.security_group_id[0]]
  }

  user_data = file("${path.module}/init.yaml")
  zone      = local.vpc_zones[0].zone
  keys      = local.ssh_key_ids
  tags      = concat(local.tags, ["zone:${local.vpc_zones[0].zone}"])
}

resource "ibm_is_instance" "pool1" {
  count                    = var.pool_instance_count
  name                     = "${local.prefix}-pool1-${count.index}"
  vpc                      = module.vpc.vpc_id[0]
  image                    = data.ibm_is_image.base.id
  profile                  = var.instance_profile
  resource_group           = module.resource_group.resource_group_id
  metadata_service_enabled = var.metadata_service_enabled

  boot_volume {
    name = "${local.prefix}-pool1-${count.index}-bootvol"
  }

  primary_network_interface {
    subnet            = module.vpc.subnet_ids[0]
    allow_ip_spoofing = var.allow_ip_spoofing
    security_groups   = [module.security_group.security_group_id[0]]
  }

  user_data = templatefile("${path.module}/instance_template.tftpl", {
    logdna_ingestion_key     = module.observability.logdna_ingestion_key,
    region                   = var.region,
    vpc_tag                  = "vpc:${local.prefix}-vpc",
    monitoring_ingestion_key = module.observability.sysdig_access_key
  })
  zone = local.vpc_zones[0].zone
  keys = local.ssh_key_ids
  tags = concat(local.tags, ["zone:${local.vpc_zones[0].zone}"])
}

resource "ibm_is_instance" "pool2" {
  count                    = var.pool_instance_count
  name                     = "${local.prefix}-pool2-${count.index}"
  vpc                      = module.vpc.vpc_id[0]
  image                    = data.ibm_is_image.base.id
  profile                  = var.instance_profile
  resource_group           = module.resource_group.resource_group_id
  metadata_service_enabled = var.metadata_service_enabled

  boot_volume {
    name = "${local.prefix}-pool2-${count.index}-bootvol"
  }

  primary_network_interface {
    subnet            = module.vpc.subnet_ids[1]
    allow_ip_spoofing = var.allow_ip_spoofing
    security_groups   = [module.security_group.security_group_id[0]]
  }

  user_data = templatefile("${path.module}/instance_template.tftpl", {
    logdna_ingestion_key     = module.observability.logdna_ingestion_key,
    region                   = var.region,
    vpc_tag                  = "vpc:${local.prefix}-vpc",
    monitoring_ingestion_key = module.observability.sysdig_access_key
  })
  zone = local.vpc_zones[1].zone
  keys = local.ssh_key_ids
  tags = concat(local.tags, ["zone:${local.vpc_zones[1].zone}"])
}

resource "ibm_is_floating_ip" "bastion" {
  name           = "${local.prefix}-bastion-public-ip"
  resource_group = module.resource_group.resource_group_id
  target         = ibm_is_instance.bastion.primary_network_interface[0].id
  tags           = concat(local.tags, ["zone:${local.vpc_zones[0].zone}"])
}

resource "ibm_is_lb" "alb" {
  name            = "${local.prefix}-vpc-alb"
  subnets         = [module.vpc.subnet_ids[0], module.vpc.subnet_ids[1]]
  logging         = true
  resource_group  = module.resource_group.resource_group_id
  type            = "public"
  security_groups = [module.security_group.security_group_id[0]]
  tags            = local.tags
}

resource "ibm_is_lb_pool" "pool1" {
  name           = "${local.prefix}-pool-1"
  lb             = ibm_is_lb.alb.id
  algorithm      = "round_robin"
  protocol       = "http"
  health_delay   = 60
  health_retries = 5
  health_timeout = 30
  health_type    = "http"
}

resource "ibm_is_lb_pool" "pool2" {
  name           = "${local.prefix}-pool-2"
  lb             = ibm_is_lb.alb.id
  algorithm      = "round_robin"
  protocol       = "http"
  health_delay   = 60
  health_retries = 5
  health_timeout = 30
  health_type    = "http"
}

resource "ibm_is_lb_listener" "frontend" {
  lb           = ibm_is_lb.alb.id
  port         = "80"
  protocol     = "http"
  default_pool = ibm_is_lb_pool.pool1.id
}

resource "ibm_is_lb_pool_member" "pool1" {
  count          = var.pool_instance_count
  lb             = ibm_is_lb.alb.id
  pool           = element(split("/", ibm_is_lb_pool.pool1.id), 1)
  port           = 80
  target_address = element(ibm_is_instance.pool1.*.primary_network_interface.0.primary_ip.0.address, count.index)
  weight         = 50
}

resource "ibm_is_lb_pool_member" "pool2" {
  count          = var.pool_instance_count
  lb             = ibm_is_lb.alb.id
  pool           = element(split("/", ibm_is_lb_pool.pool2.id), 1)
  port           = 80
  target_address = element(ibm_is_instance.pool2.*.primary_network_interface.0.primary_ip.0.address, count.index)
  weight         = 50
}

resource "local_file" "ansible-inventory" {
  content = templatefile("${path.module}/inventory.tmpl",
    {
      instances = concat(
        ibm_is_instance.pool1.*,
        ibm_is_instance.pool2.*
      )
      bastion_ip = ibm_is_floating_ip.bastion.address
    }
  )
  filename = "${path.module}/inventory.ini"
}