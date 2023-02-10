## VPC ALB Metrics

Code to deploy an MZR VPC, ALB, and 2 VMs to collect metrics from the ALB and look at how pool health is tracked.

<!-- BEGIN_TF_DOCS -->
## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_observability"></a> [observability](#module\_observability) | git::https://github.com/terraform-ibm-modules/terraform-ibm-observability-instances | main |
| <a name="module_resource_group"></a> [resource\_group](#module\_resource\_group) | git::https://github.com/terraform-ibm-modules/terraform-ibm-resource-group.git | v1.0.5 |
| <a name="module_security_group"></a> [security\_group](#module\_security\_group) | terraform-ibm-modules/vpc/ibm//modules/security-group | 1.1.1 |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | terraform-ibm-modules/vpc/ibm//modules/vpc | 1.1.1 |

## Resources

| Name | Type |
|------|------|
| [ibm_is_floating_ip.bastion](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.50.0/docs/resources/is_floating_ip) | resource |
| [ibm_is_instance.bastion](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.50.0/docs/resources/is_instance) | resource |
| [ibm_is_instance.pool1](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.50.0/docs/resources/is_instance) | resource |
| [ibm_is_instance.pool2](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.50.0/docs/resources/is_instance) | resource |
| [ibm_is_lb.alb](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.50.0/docs/resources/is_lb) | resource |
| [ibm_is_lb_listener.frontend](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.50.0/docs/resources/is_lb_listener) | resource |
| [ibm_is_lb_pool.pool1](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.50.0/docs/resources/is_lb_pool) | resource |
| [ibm_is_lb_pool.pool2](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.50.0/docs/resources/is_lb_pool) | resource |
| [ibm_is_lb_pool_member.pool1](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.50.0/docs/resources/is_lb_pool_member) | resource |
| [ibm_is_lb_pool_member.pool2](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.50.0/docs/resources/is_lb_pool_member) | resource |
| [ibm_is_ssh_key.generated_key](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.50.0/docs/resources/is_ssh_key) | resource |
| [local_file.ansible-inventory](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [null_resource.create_private_key](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [random_string.prefix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [tls_private_key.ssh](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [ibm_is_image.base](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.50.0/docs/data-sources/is_image) | data source |
| [ibm_is_ssh_key.sshkey](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.50.0/docs/data-sources/is_ssh_key) | data source |
| [ibm_is_zones.regional](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.50.0/docs/data-sources/is_zones) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allow_ip_spoofing"></a> [allow\_ip\_spoofing](#input\_allow\_ip\_spoofing) | Allow IP spoofing on the bastion instance primary interface. | `bool` | `false` | no |
| <a name="input_classic_access"></a> [classic\_access](#input\_classic\_access) | Allow classic access to the VPC. | `bool` | `false` | no |
| <a name="input_default_address_prefix"></a> [default\_address\_prefix](#input\_default\_address\_prefix) | The address prefix to use for the VPC. Default is set to auto. | `string` | `"auto"` | no |
| <a name="input_existing_resource_group"></a> [existing\_resource\_group](#input\_existing\_resource\_group) | The name of an existing resource group to use. If not specified, a new resource group will be created. | `string` | `""` | no |
| <a name="input_existing_ssh_key"></a> [existing\_ssh\_key](#input\_existing\_ssh\_key) | The name of an existing SSH key to use for the VM | `string` | `""` | no |
| <a name="input_frontend_rules"></a> [frontend\_rules](#input\_frontend\_rules) | A list of security group rules to be added to the Frontend security group | <pre>list(<br>    object({<br>      name      = string<br>      direction = string<br>      remote    = string<br>      tcp = optional(<br>        object({<br>          port_max = optional(number)<br>          port_min = optional(number)<br>        })<br>      )<br>      udp = optional(<br>        object({<br>          port_max = optional(number)<br>          port_min = optional(number)<br>        })<br>      )<br>      icmp = optional(<br>        object({<br>          type = optional(number)<br>          code = optional(number)<br>        })<br>      )<br>    })<br>  )</pre> | <pre>[<br>  {<br>    "direction": "inbound",<br>    "ip_version": "ipv4",<br>    "name": "inbound-http",<br>    "remote": "0.0.0.0/0",<br>    "tcp": {<br>      "port_max": 80,<br>      "port_min": 80<br>    }<br>  },<br>  {<br>    "direction": "inbound",<br>    "ip_version": "ipv4",<br>    "name": "inbound-https",<br>    "remote": "0.0.0.0/0",<br>    "tcp": {<br>      "port_max": 443,<br>      "port_min": 443<br>    }<br>  },<br>  {<br>    "direction": "inbound",<br>    "ip_version": "ipv4",<br>    "name": "inbound-ssh",<br>    "remote": "0.0.0.0/0",<br>    "tcp": {<br>      "port_max": 22,<br>      "port_min": 22<br>    }<br>  },<br>  {<br>    "direction": "inbound",<br>    "icmp": {<br>      "code": 0,<br>      "type": 8<br>    },<br>    "ip_version": "ipv4",<br>    "name": "inbound-icmp",<br>    "remote": "0.0.0.0/0"<br>  },<br>  {<br>    "direction": "outbound",<br>    "ip_version": "ipv4",<br>    "name": "all-outbound",<br>    "remote": "0.0.0.0/0"<br>  }<br>]</pre> | no |
| <a name="input_image_name"></a> [image\_name](#input\_image\_name) | The name of an existing OS image to use. You can list available images with the command 'ibmcloud is images'. | `string` | `"ibm-ubuntu-22-04-1-minimal-amd64-3"` | no |
| <a name="input_instance_profile"></a> [instance\_profile](#input\_instance\_profile) | The name of an existing instance profile to use. You can list available instance profiles with the command 'ibmcloud is instance-profiles'. | `string` | `"cx2-2x4"` | no |
| <a name="input_metadata_service_enabled"></a> [metadata\_service\_enabled](#input\_metadata\_service\_enabled) | Enable the metadata service on the bastion instance. | `bool` | `true` | no |
| <a name="input_owner"></a> [owner](#input\_owner) | The owner of the resources. Will be added as tags to all resources. | `string` | n/a | yes |
| <a name="input_pool_instance_count"></a> [pool\_instance\_count](#input\_pool\_instance\_count) | The number of instances to create in each pool. Default is 1 for testing. | `number` | `2` | no |
| <a name="input_project_prefix"></a> [project\_prefix](#input\_project\_prefix) | The prefix to use for all resources | `string` | `""` | no |
| <a name="input_region"></a> [region](#input\_region) | The region to deploy the resources to | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bastion_ip"></a> [bastion\_ip](#output\_bastion\_ip) | Public IP of the Bastion instance. |
| <a name="output_instance_ips"></a> [instance\_ips](#output\_instance\_ips) | Private IP of load balancer pool instances |
| <a name="output_lb_fqdn"></a> [lb\_fqdn](#output\_lb\_fqdn) | FQDN for the VPC ABL instance |
<!-- END_TF_DOCS -->