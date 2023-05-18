provider "logdna" {
  alias      = "at"
  servicekey = module.observability.activity_tracker_resource_key != null ? module.observability.activity_tracker_resource_key : ""
  url        = local.at_endpoint
}

provider "logdna" {
  alias      = "ld"
  servicekey = module.observability.logdna_resource_key != null ? module.observability.logdna_resource_key : ""
  url        = local.at_endpoint
}

provider "ibm" {
  region = var.region
}