provider "aws" {
  region = "us-east-1"
}

variable "password" {
  description = "Administrator password"
  sensitive   = true
}

data "aws_ami" "windows_2016" {
  most_recent = true
  filter {
    name   = "name"
    values = ["Windows_Server-2016-English-Full-Base-*"]
  }
  owners = ["amazon"]
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
}

resource "aws_subnet" "main" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.0.0/24"
  map_public_ip_on_launch = true
}

resource "aws_security_group" "winrm_rdp_sg" {
  name        = "winrm_rdp_sg"
  description = "Allow WinRM and RDP traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5985
    to_port     = 5986
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.main.id
}

locals {
  user_data = <<-EOT
                <powershell>
                $admin = [adsi]("WinNT://./Administrator,user")
                $admin.psbase.invoke("SetPassword", "${var.password}")
                Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
                Enable-PSRemoting -Force
                </powershell>
                EOT
}

resource "aws_instance" "dc01" {
  ami           = data.aws_ami.windows_2016.id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.main.id
  private_ip    = "10.0.0.50"
  user_data_base64     = base64encode(local.user_data)
  vpc_security_group_ids = [aws_security_group.winrm_rdp_sg.id]
  tags = {
    Name = "DC01"
  }
  provisioner "local-exec" {
    command = "ansible-playbook -i '${self.public_ip},' --extra-vars 'ansible_password=${var.password}' playbook.yml"
  }
}

resource "aws_instance" "web01" {
  ami           = data.aws_ami.windows_2016.id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.main.id
  private_ip    = "10.0.0.30"
  user_data     = local.user_data
  depends_on    = [aws_instance.dc01]
  vpc_security_group_ids = [aws_security_group.winrm_rdp_sg.id]
  tags = {
    Name = "WEB01"
  }
  provisioner "local-exec" {
    command = "ansible-playbook -i '${self.public_ip},' --extra-vars 'ansible_password=${var.password}' playbook.yml"
  }
}

resource "aws_instance" "ws01" {
  ami           = data.aws_ami.windows_2016.id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.main.id
  private_ip    = "10.0.0.10"
  user_data     = local.user_data
  depends_on    = [aws_instance.dc01]
  vpc_security_group_ids = [aws_security_group.winrm_rdp_sg.id]
  tags = {
    Name = "WS01"
  }
  provisioner "local-exec" {
    command = "ansible-playbook -i '${self.public_ip},' --extra-vars 'ansible_password=${var.password}' playbook.yml"
  }
}

