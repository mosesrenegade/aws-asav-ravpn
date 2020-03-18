# This is the minimum build terraform I am using, there are newer builds
terraform {
  required_version = ">=0.12.12"
}

# This may not be the latest build, please check
provider "aws" {
  region                  = "us-west-1"
  version                 = "~> 2.36.0"
  shared_credentials_file = "/home/sec588/.aws/credentials"
  profile                 = "default"
}

# Let's create an SSH Key for our KeyPair

variable "key_name" {
  default = "cisco_asa_key" # You can change this
}

# Let's make the name random

resource "random_pet" "this" {
  length    = 1
  separator = ""
}

#resource "tls_private_key" "asa_keypair" {
#  algorithm = "RSA"
#  rsa_bits  = 4096
#}

#resource "aws_key_pair" "generated_key" {
#  key_name   = var.key_name
#  public_key = tls_private_key.asa_keypair.public_key_openssh
#}

# These are local variables that may or may not be needed for the day0-config

locals {
  cisco_asav_name        = "asav-${random_pet.this.id}" 
  my_public_ip           = "96.71.19.172/32"
  ssh_key_name           = var.key_name
  asav_public_facing_ip1 = "172.16.0.10"
  asav_public_facing_ip2 = "172.16.2.10"
}

# This will add our networks, this is important because we need to create a VPC first
resource "aws_vpc" "asav_aws_vpc" {
  cidr_block = "172.16.0.0/16"

  tags = {
    Name = "asav-example-vpc"
  }
}

# Here we need to build an internet gateway to allow inbound outbound access, you may already have this
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.asav_aws_vpc.id

  tags = {
    Name = "asav-internet-gateway"
  }
}

# This is the routing table for the ASAv, "default out to the internet".
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.asav_aws_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }

  tags = {
    Name = "asav-route-table"
  }
}

# Attach network subnet 1 to the routing table for internet access
resource "aws_route_table_association" "dia_route_table1" {
  subnet_id      = aws_subnet.aws_public_subnet1.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "dia_route_table2" {
  subnet_id      = aws_subnet.aws_public_subnet2.id
  route_table_id = aws_route_table.public_route_table.id
}

# Private Internal Network
resource "aws_subnet" "aws_private_subnet1" {
  vpc_id            = aws_vpc.asav_aws_vpc.id
  cidr_block        = "172.16.1.0/24"
  availability_zone = "us-west-1a"

  tags = {
    Name = "asav-private-subnet-1"
  }
}

resource "aws_subnet" "aws_private_subnet2" {
  vpc_id            = aws_vpc.asav_aws_vpc.id
  cidr_block        = "172.16.3.0/24"
  availability_zone = "us-west-1a"

  tags = {
    Name = "asav-private-subnet-2"
  }
}

# Public Network
resource "aws_subnet" "aws_public_subnet1" {
  vpc_id            = aws_vpc.asav_aws_vpc.id
  cidr_block        = "172.16.0.0/24"
  availability_zone = "us-west-1a"

  tags = {
    Name = "asav-public-subnet1"
  }
}

resource "aws_subnet" "aws_public_subnet2" {
  vpc_id            = aws_vpc.asav_aws_vpc.id
  cidr_block        = "172.16.2.0/24"
  availability_zone = "us-west-1a"
  
  tags = {
    Name = "asav-public-subnet2"
  }
}

# We do need to attach some type of security group the ASAv, 
# this could be allow all, this one is applied to the public interface

resource "aws_security_group" "cisco_asav_public" {
  name        = "CiscoASAvPublicSecGroup"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.asav_aws_vpc.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [local.my_public_ip]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.my_public_ip]
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [local.my_public_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "asav-Public-Security-Group"
  }
}

# Security Group for private Interface

resource "aws_security_group" "cisco_asav_private" {
  name        = "CiscoASAvPrivateSecGroup"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.asav_aws_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "asav-Private-SecurityGroup"
  }
}

resource "aws_network_interface" "asav_private_interface1" {
  subnet_id         = aws_subnet.aws_private_subnet1.id
  private_ips       = ["172.16.1.10"]
  source_dest_check = false

  security_groups = [
    aws_security_group.cisco_asav_private.id
  ]

  tags = {
    Name = "asav-private-interface1"
  }
}

resource "aws_network_interface" "asav_public_interface1" {
  subnet_id         = aws_subnet.aws_public_subnet1.id
  private_ips       = [local.asav_public_facing_ip1]
  source_dest_check = false

  security_groups = [
    aws_security_group.cisco_asav_public.id
  ]

  tags = {
    Name = "asav-public-interface1"
  }
}

resource "aws_network_interface" "asav_private_interface2" {
  subnet_id         = aws_subnet.aws_private_subnet2.id
  private_ips       = ["172.16.3.10"]
  source_dest_check = false

  security_groups = [
    aws_security_group.cisco_asav_private.id
  ]

  tags = {
    Name = "asav-private-interface1"
  }
}

resource "aws_network_interface" "asav_public_interface2" {
  subnet_id         = aws_subnet.aws_public_subnet2.id
  private_ips       = [local.asav_public_facing_ip2]
  source_dest_check = false

  security_groups = [
    aws_security_group.cisco_asav_public.id
  ]

  tags = {
    Name = "asav-public-interface1"
  }
}


resource "aws_eip" "cisco_asav_elastic_public_ip1" {
  vpc                       = true
  network_interface         = aws_network_interface.asav_public_interface1.id
  associate_with_private_ip = local.asav_public_facing_ip1

  depends_on = [
    aws_internet_gateway.internet_gateway
  ]
}

resource "aws_eip" "cisco_asav_elastic_public_ip2" {
  vpc                       = true
  network_interface         = aws_network_interface.asav_public_interface2.id
  associate_with_private_ip = local.asav_public_facing_ip2

  depends_on = [
    aws_internet_gateway.internet_gateway
  ]
}

# Build the ASAv
resource "aws_instance" "cisco_asav1" {
  # This AMI is only valid in us-west-1 region, with this specific instance type
  ami           = "ami-09041ae21d57240c4"
  instance_type = "c3.large"
  key_name      = "cisco_asa_key"

  network_interface {
    network_interface_id = aws_network_interface.asav_private_interface1.id
    device_index         = 0
  }

  network_interface {
    network_interface_id = aws_network_interface.asav_public_interface1.id
    device_index         = 1
  }

  user_data = file("day0-config.txt")

  tags = {
    Name = "asav"
  }
}

# Build the ASAv
resource "aws_instance" "cisco_asav2" {
  # This AMI is only valid in us-west-1 region, with this specific instance type
  ami           = "ami-09041ae21d57240c4"
  instance_type = "c3.large"
  key_name      = "cisco_asa_key"

  network_interface {
    network_interface_id = aws_network_interface.asav_private_interface2.id
    device_index         = 0
  }

  network_interface {
    network_interface_id = aws_network_interface.asav_public_interface2.id
    device_index         = 1
  }

  user_data = file("day0-config.txt")

  tags = {
    Name = "asav"
  }
}

output "asav_public_ip1" {
  value = aws_eip.cisco_asav_elastic_public_ip1.public_ip
}

output "asav_public_ip2" {
  value = aws_eip.cisco_asav_elastic_public_ip2.public_ip
}
