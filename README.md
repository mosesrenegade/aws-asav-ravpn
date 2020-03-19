# aws-asav-ravpn
Terraform and Ansible Scripting for ASAv for AWS

### TBD: Ansible 

## Instructions

First, install the Terraform deployment toolkit from:
- [Terraform](https://www.terraform.io/)

Second, make sure you have a set of programmatic AWS Keys and that
you look at the top of the main.tf file in this repository. You
will be looking for the following text:

```
provider "aws" {
  region                  = "us-west-1"
  version                 = "~> 2.36.0"
  shared_credentials_file = "/home/user/.aws/credentials"
  profile                 = "default"
}
```

Make sure you have a [default] section in the credentials file.

Third, look for the following text:

```
locals {
  cisco_asav_name        = "asav-${random_pet.this.id}" 
  my_public_ip           = "1.2.3.4/32" # Change
  ssh_key_name           = var.key_name
  asav_public_facing_ip1 = "172.16.0.10"
  asav_public_facing_ip2 = "172.16.2.10"
}
```

Change your my_publc_ip so that it matches your external ip. 
Don't know your external ip? Use [IPChicken](www.ipchicken.com), or a similar
tool. 

Finally create an ssh deployment key in aws called:

cisco_asa_key

Make sure you keep it as you will be using it to logging in like so:

```$ ssh -i cisco_asa_key.pem admin@<ip>```

#### Notes to keep in mind

1. The cisco asa's that are built will be two of them.
2. The cisco asa's will be in the ```US-West-1``` datacenter which is 
Northern California
3. There will be a VPC built to support this with 4 subnets. 2 for one 
ASA and 2 for another. 
4. The AMI that ships is an AMI for US-West-1 find the AMI in the other
datacenters. 
5. The ASAv is an ASAv10.

#### TODOs

- Create a base ASAv config for RAVPN
- Use the ELB to direct traffic.


