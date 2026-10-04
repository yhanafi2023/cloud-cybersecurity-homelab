# Create a VPC
resource "aws_vpc" "homelab_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "Cybersecurity Homelab VPC"
  }

}

# Create Public Subnet
resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.homelab_vpc.id
  cidr_block = var.public_subnet_cidr

  tags = {
    Name = "Cybersecurity Homelab Public Subnet"
  }

}

# Create Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.homelab_vpc.id

  tags = {
    Name = "Cybersecurity Homelab IGW"
  }

}

# Create Route Table
resource "aws_route_table" "route-table" {
  vpc_id = aws_vpc.homelab_vpc.id

}

# Create Route to IGW in Route Table
resource "aws_route" "internet" {
  route_table_id         = aws_route_table.route-table.id
  destination_cidr_block = "0.0.0.0/0" # Replace with your VPC CIDR block
  gateway_id             = aws_internet_gateway.igw.id
}

# Associate Route Table to Public Sunet
resource "aws_route_table_association" "subnet_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.route-table.id
}

# Who may connect IN to the lab: your home IP + the lab boxes themselves (VPC range).
# Your IP comes from the TF_VAR_my_public_ip environment variable (see .env.example).
locals {
  allowed_cidrs = ["${var.my_public_ip}/32", aws_vpc.homelab_vpc.cidr_block]
}

# Create Security Group for Windows and Kali Linux Instances.
resource "aws_security_group" "win-kali-security-group" {
  name_prefix = "win-kali-"
  description = "Example security group allowing SSH, RDP, and ICMP"
  vpc_id      = aws_vpc.homelab_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = local.allowed_cidrs
  }

  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = local.allowed_cidrs
  }

  ingress {
    from_port   = -1 # ICMP type and code (-1 means all)
    to_port     = -1 # ICMP type and code (-1 means all)
    protocol    = "icmp"
    cidr_blocks = local.allowed_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # Allow all outbound traffic
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Cybersecurity Homelab Windows / Kali Security Group"
  }

}

# Create Security Group for Linux Security Tools Instance.
resource "aws_security_group" "linux-security-tools" {
  name_prefix = "security-tools-"
  description = "Ingress and egress rules for Security Tools Box"
  vpc_id      = aws_vpc.homelab_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = local.allowed_cidrs
  }

  ingress {
    from_port   = -1 # ICMP type and code (-1 means all)
    to_port     = -1 # ICMP type and code (-1 means all)
    protocol    = "icmp"
    cidr_blocks = local.allowed_cidrs
  }

  ingress {
    from_port   = 5900
    to_port     = 5920
    protocol    = "tcp"
    cidr_blocks = local.allowed_cidrs
  }

  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "udp"
    cidr_blocks = local.allowed_cidrs
  }

  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = local.allowed_cidrs
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = local.allowed_cidrs
  }

  ingress {
    from_port   = 9997
    to_port     = 9997
    protocol    = "tcp"
    cidr_blocks = local.allowed_cidrs
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = local.allowed_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # Allow all outbound traffic
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Cybersecurity Homelab Linux Security Tools Security Group"
  }

}

# Look up the latest Windows Server 2022 AMI (the original hardcoded AMI was retired by AWS).
data "aws_ami" "windows_2022" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }
}

# Look up the latest Ubuntu 22.04 AMI from Canonical (free, no Marketplace subscription).
data "aws_ami" "ubuntu_2204" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# Create Windows Instance.
resource "aws_instance" "windows" {
  ami           = data.aws_ami.windows_2022.id
  instance_type = "t3.micro" # Free tier eligible (t2.micro is not on newer accounts)

  # "standard" = no surprise charges if the CPU bursts for too long (t3 defaults to "unlimited").
  credit_specification {
    cpu_credits = "standard"
  }
  subnet_id = aws_subnet.public_subnet.id

  key_name = var.aws_key

  vpc_security_group_ids      = [aws_security_group.win-kali-security-group.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size = 30    # Specify the desired size in GB
    volume_type = "gp3" # Cheaper than the AMI's default gp2
  }

  tags = {
    Name = "Cybersecurity Homelab [Windows Server 2022]"
  }

}

# Crate Kali Attacker Instance.
resource "aws_instance" "kali" {
  ami           = "ami-0b02670313196539c" # Kali Linux 2023.3 (AWS Marketplace, us-east-2 only - subscribe once before applying)
  instance_type = "t3.micro"              # Free tier eligible (t2.micro is not on newer accounts)

  # "standard" = no surprise charges if the CPU bursts for too long (t3 defaults to "unlimited").
  credit_specification {
    cpu_credits = "standard"
  }
  subnet_id = aws_subnet.public_subnet.id

  key_name = var.aws_key

  vpc_security_group_ids      = [aws_security_group.win-kali-security-group.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size = 12    # Specify the desired size in GB
    volume_type = "gp3" # Cheaper than the AMI's default gp2
  }

  # Automates the video's rdp.sh: upgrade Kali, install the Xfce desktop + xrdp, start xrdp.
  # Runs once on first boot and takes a while (the 2023 image has years of updates to install).
  user_data = <<-EOT
    #!/bin/bash
    # Kali rotated its repo signing key in 2025; the 2023 image only has the old one.
    wget -q https://archive.kali.org/archive-keyring.gpg -O /usr/share/keyrings/kali-archive-keyring.gpg
    apt-get update
    export DEBIAN_FRONTEND=noninteractive
    apt-get full-upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
    apt-get install -y kali-desktop-xfce xorg xrdp
    systemctl enable --now xrdp
  EOT

  tags = {
    Name = "Cybersecurity Homelab [Kali]"
  }

}

# Create Security Tools Instance.
resource "aws_instance" "security-tools" {
  ami           = data.aws_ami.ubuntu_2204.id
  instance_type = "m7i-flex.large" # Free tier eligible, same 2 vCPU / 8 GB RAM as the original t3.large
  subnet_id     = aws_subnet.public_subnet.id

  key_name = var.aws_key

  vpc_security_group_ids      = [aws_security_group.linux-security-tools.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size = 30    # Specify the desired size in GB
    volume_type = "gp3" # Cheaper than the AMI's default gp2
  }

  # Install an XFCE desktop reachable over RDP (replaces the paid Netspectrum Ubuntu Desktop AMI).
  user_data = <<-EOT
    #!/bin/bash
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y xfce4 xfce4-goodies xrdp
    echo xfce4-session > /home/ubuntu/.xsession
    chown ubuntu:ubuntu /home/ubuntu/.xsession
    adduser xrdp ssl-cert
    systemctl enable --now xrdp

    # Firefox from Mozilla's APT repo (Ubuntu's own "firefox" package is a snap, which often fails under xrdp).
    install -d -m 0755 /etc/apt/keyrings
    wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O /etc/apt/keyrings/packages.mozilla.org.asc
    echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" > /etc/apt/sources.list.d/mozilla.list
    printf 'Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
' > /etc/apt/preferences.d/mozilla
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y firefox
  EOT

  tags = {
    Name = "Cybersecurity Homelab [Security Tools]"
  }

}

# Output Windows IP Address.
output "instance_public_ip_win" {
  value = "Windows Box IP Address: ${aws_instance.windows.public_ip}"
}

# Output Kali IP Address.
output "instance_public_ip_kali" {
  value = "Kali Box IP Address: ${aws_instance.kali.public_ip}"
}

# Output Security Tools IP Address.
output "instance_public_ip_security-tools" {
  value = "Security Tools Box IP Address: ${aws_instance.security-tools.public_ip}"
}