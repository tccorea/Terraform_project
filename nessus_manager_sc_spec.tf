#This is for SC Specialist course lab
# Configure the AWS Provider
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

#Setting the region to us-east-1 and profile to ADM-Training-Admin-Role
provider "aws" {
  region  = "us-west-1"
  profile = "ADM-Training-Admin-Role"
}

# Create a VPC for the Nessus Manager
resource "aws_vpc" "nessus_internal_lab_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "nessus_manager_sc_lab_vpc"
    Class = "education-infrastructure"
  }
}

# Create a Public Subnet for Nessus Manager
resource "aws_subnet" "nessus_internal_lab_pub_subnet" {
  vpc_id            = aws_vpc.nessus_internal_lab_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = false

  tags = {
    Name = "nessus_manager_sc_lab_pub_subnet"
    Class = "education-infrastructure"
  }
}

# Create an Internet Gateway for manager and agent
resource "aws_internet_gateway" "nessus_internal_lab_ig" {
  vpc_id = aws_vpc.nessus_internal_lab_vpc.id

  tags = {
    Name = "nessus_manager_sc_lab_ig"
    Class = "education-infrastructure"
  }
}

# Create a Route Table with a public route
resource "aws_route_table" "nessus_internal_lab_ig_public_rt" {
  vpc_id = aws_vpc.nessus_internal_lab_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.nessus_internal_lab_ig.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id = aws_internet_gateway.nessus_internal_lab_ig.id
  }

  tags = {
    Name = "nessus_manager_sc_lab_pub_rt"
    Class = "education-infrastructure"
  }
}

#aws route table association for the public subnet
resource "aws_route_table_association" "nessus_internal_lab_route_assoc" {
  subnet_id      = aws_subnet.nessus_internal_lab_pub_subnet.id
  route_table_id = aws_route_table.nessus_internal_lab_ig_public_rt.id
}

# Create a Main Route Table with a private route to the internet gateway
resource "aws_route_table" "nessus_internal_lab_ig_public_rt" {
  vpc_id = aws_vpc.nessus_internal_lab_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.nessus_internal_lab_ig.id
  }

  tags = {
    Name = "nessus_manager_sc_lab_rt"
    Class = "education-infrastructure"
  }
}

# Create a Public Security Group for Nessus manager
resource "aws_security_group" "nessus_manager_sc_lab_secgrp" {
  name = "Nessus Manager Public Security Group"
  vpc_id = aws_vpc.nessus_internal_lab_vpc.id

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp" # Allow all traffic
    cidr_blocks = ["73.39.23.122/32"] # Allow from myip
  }

  # New ingress rule for port 8834
  ingress {
    from_port   = 8834
    to_port     = 8834
    protocol    = "tcp" # Assuming the service uses TCP, adjust if needed
    cidr_blocks = ["0.0.0.0/0"] # Allow from your IP (adjust based on requirements)
  }
  ingress {
    from_port = 443 # HTTPS
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow to anywhere
  }
  ingress {
    from_port = 8
    to_port = 0
    protocol = "icmp"
    description = "Allow PING"
  }

  ingress {
    from_port = 0
    to_port = 0
    protocol = "-1" # Allow all traffic
    cidr_blocks = ["10.0.1.0/24"] # Allow only within private subnet. This is for the Nessus agent
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1" # Allow all traffic
    cidr_blocks = ["0.0.0.0/0"] # Allow to anywhere
  }
  tags = {
    Class = "education-infrastructure"
    ClassResource = "TRUE"
  }
  lifecycle {
    create_before_destroy = true
  }
}

#security group for nessus agent:
resource "aws_security_group" "nessus_agent_sc_lab_secgrp" {
  name   = "Nessus Agent Public Security Group"
  vpc_id = aws_vpc.nessus_internal_lab_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp" # Allow all traffic
    cidr_blocks = ["73.39.23.122/32"] # Allow from myip
  }

  # New ingress rule for port 8834
  ingress {
    from_port   = 8834
    to_port     = 8834
    protocol    = "tcp" # Assuming the service uses TCP, adjust if needed
    cidr_blocks = ["0.0.0.0/0"] # Allow from your IP (adjust based on requirements)
  }

  ingress {
    from_port   = 443 # HTTPS
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow to anywhere
  }

  ingress {
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    description = "Allow PING"
  }

   ingress {
    from_port = 0
    to_port = 0
    protocol = "-1" # Allow all traffic
    cidr_blocks = ["10.0.1.0/24"] # Allow only within private subnet. This is for the Nessus agent
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # Allow all traffic
    cidr_blocks = ["0.0.0.0/0"] # Allow to anywhere
  }
  tags = {
    Class         = "education-infrastructure"
    ClassResource = "TRUE"
  }
  lifecycle {
    create_before_destroy = true
  }
}

# Create an EC2 Instance Nessus manager
resource "aws_instance" "nessus_manager_sc_lab_instance" {
  ami           = "ami-XXXXXXXXXXXXXXXXXX" #
  instance_type = "t3.large"
  subnet_id     = aws_subnet.nessus_internal_lab_pub_subnet.id
  vpc_security_group_ids = [aws_security_group.nessus_manager_sc_lab_secgrp.id]
  associate_public_ip_address = true
  key_name      = "training-support"
#  key_name      = aws_key_pair.training_key_pair.key_name
  #Start nesssus and enable ssm agent
  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
              systemctl start nessusd
              systemctl enable nessusd
              systemctl enable amazon-ssm-agent
              systemctl start amazon-ssm-agent
              sudo yum install ec2-instance-connect
              EOF

  tags = {
    Name = "nessus_manager_sc_lab_instance"
    Class = "education-infrastructure"
  }
}

#Create an EC2 Instance Nessus agent
resource "aws_instance" "nessus_agent_1_sc_lab_instance" {
  ami           = "ami-XXXXXXXXXXXXXXXXXX" #Nessus agent AMI
  instance_type = "t3.medium"
  subnet_id     = aws_subnet.nessus_internal_lab_pub_subnet.id
  vpc_security_group_ids = [aws_security_group.nessus_agent_sc_lab_secgrp.id]
  #associate_public_ip_address = false
  key_name      = "training-support"
  #key_name      = aws_key_pair.training_key_pair.key_name
  #Start nesssus agent and enable ssm agent
    user_data = <<-EOF
                #!/bin/bash
                sudo yum update -y
                rpm -ivh /tmp/NessusAgent-10.5.1-el9.x86_64.rpm
                sleep 30
                systemctl start nessusagent
                systemctl enable nessusagent
                /opt/nessus_agent/sbin/nessuscli agent link --key=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX9 --host=10.0.1.202 --port=8834
                EOF

    tags = {
        Name = "nessus_agent_sc_lab_instance"
        Class = "education-infrastructure"
    }
    }

#EIP for the nessus manager
resource "aws_eip" "nessus_manager_sc_lab_pub_ip" {
  vpc = true # Set to true if your instance is in a VPC
}

# Associate the EIP with the instance
resource "aws_eip_association" "nessus_manager_sc_lab_instance_association" {
  allocation_id = aws_eip.nessus_manager_sc_lab_pub_ip.allocation_id
  instance_id = aws_instance.nessus_manager_sc_lab_instance.id
}

#EIP for the nessus agent
resource "aws_eip" "nessus_agent_sc_lab_pub_ip" {
    vpc = true # Set to true if your instance is in a VPC
}

# Associate the EIP with the instance
resource "aws_eip_association" "nessus_agent_sc_lab_instance_association" {
    allocation_id = aws_eip.nessus_agent_sc_lab_pub_ip.allocation_id
    instance_id = aws_instance.nessus_agent_1_sc_lab_instance.id
}

# Create a DNS record
resource "aws_route53_record" "nessus-manager" {
  name           = "nessus-manager-sc2.labs.university.tenable.com"
  type           = "A"
  zone_id        = "XXXXXXXXXXXX"
  ttl            = "300"
  records        = [aws_eip.nessus_manager_sc_lab_pub_ip.public_ip]
}


# Create a DNS record
resource "aws_route53_record" "nessus-agent-53" {
  name           = "nessus-agent-sc2.labs.university.tenable.com"
  type           = "A"
  zone_id        = "XXXXXXXXXX"
  ttl            = "300"
  records        = [aws_eip.nessus_agent_sc_lab_pub_ip.public_ip]
}

# Output the public IP address of the instance
output "public_ip" {
  value = aws_instance.nessus_manager_sc_lab_instance.public_ip
}

output "public_ip_agent" {
  value = aws_instance.nessus_agent_1_sc_lab_instance.public_ip
}

#output for Nessus manager dns
output "nessus_manager_dns" {
  description = "DNS Name of Nessus Scanner 02"
  value       = aws_route53_record.nessus-manager.fqdn
}


