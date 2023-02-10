output "bastion_ip" {
  description = "Public IP of the Bastion instance."
  value       = ibm_is_floating_ip.bastion.address
}

output "instance_ips" {
  description = "Private IP of load balancer pool instances"
  value = concat(
    ibm_is_instance.pool1.*.primary_network_interface.0.primary_ipv4_address,
    ibm_is_instance.pool2.*.primary_network_interface.0.primary_ipv4_address
  )
}

output "lb_fqdn" {
  description = "FQDN for the VPC ABL instance"
  value       = ibm_is_lb.alb.hostname
}
