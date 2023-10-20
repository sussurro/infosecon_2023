provider "aws" {
  region = "us-east-1"
}

variable "password" {
  description = "Administrator password"
  sensitive   = true
}
variable "user_password" {
  description = "User password"
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

  ingress {
    from_port   = 0 
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/24"]
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
		cmd.exe /c winrm quickconfig -q
		cmd.exe /c winrm quickconfig '-transport:http'
		cmd.exe /c winrm set "winrm/config" '@{MaxTimeoutms="1800000"}'
		cmd.exe /c winrm set "winrm/config/winrs" '@{MaxMemoryPerShellMB="1024"}'
		cmd.exe /c winrm set "winrm/config/service" '@{AllowUnencrypted="true"}'
		cmd.exe /c winrm set "winrm/config/client" '@{AllowUnencrypted="true"}'
		cmd.exe /c winrm set "winrm/config/service/auth" '@{Basic="true"}'
		cmd.exe /c winrm set "winrm/config/client/auth" '@{Basic="true"}'
		cmd.exe /c winrm set "winrm/config/service/auth" '@{CredSSP="true"}'
		cmd.exe /c winrm set "winrm/config/listener?Address=*+Transport=HTTP" '@{Port="5985"}'

                </powershell>
                EOT
}

resource "aws_instance" "dc01" {
  ami           = data.aws_ami.windows_2016.id
  instance_type = "t2.large"
  subnet_id     = aws_subnet.main.id
  private_ip    = "10.0.0.50"
  user_data_base64     = base64encode(local.user_data)
  vpc_security_group_ids = [aws_security_group.winrm_rdp_sg.id]
  tags = {
    Name = "DC01"
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command = " while ! nc -z ${self.public_ip} 5985 ; do sleep 1; done;"
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command = " sleep 30"
  }


  provisioner "local-exec" {
    command = "ansible-playbook -i '${self.public_ip},' --extra-vars 'ansible_password=${var.password} ansible_connection=winrm ansible_winrm_port=5985 ansible_winrm_server_cert_validation=ignore ansible_winrm_scheme=http ansible_user=Administrator' make_dc.yml"
  }
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command = " while ! nc -z ${self.public_ip} 5985 ; do sleep 1; done;"
  }
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command = " sleep 300"
  }
  provisioner "local-exec" {
    command = "ansible-playbook -i '${self.public_ip},' --extra-vars 'ansible_password=${var.password} ansible_connection=winrm ansible_winrm_port=5985 ansible_winrm_server_cert_validation=ignore ansible_winrm_scheme=http ansible_user=Administrator user_password=${var.user_password}' configure_dc.yml"
  }
}

resource "aws_instance" "web01" {
  ami           = data.aws_ami.windows_2016.id
  instance_type = "t2.large"
  subnet_id     = aws_subnet.main.id
  private_ip    = "10.0.0.30"
  user_data     = local.user_data
  depends_on    = [aws_instance.dc01]
  vpc_security_group_ids = [aws_security_group.winrm_rdp_sg.id]
  tags = {
    Name = "WEB01"
  }
  root_block_device {
    volume_size           = "100"
    volume_type           = "gp2"
    delete_on_termination = true
  }
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command = " while ! nc -z ${self.public_ip} 5985 ; do sleep 1; done;"
  }
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command = " sleep 60 "
  }
  provisioner "local-exec" {
    command = "ansible-playbook -i '${self.public_ip},' --extra-vars 'ansible_password=${var.password} ansible_connection=winrm ansible_winrm_port=5985 ansible_winrm_server_cert_validation=ignore ansible_winrm_scheme=http ansible_user=Administrator' chocolatey.yml"
  }
  provisioner "local-exec" {
    command = "ansible-playbook -i '${self.public_ip},' --extra-vars 'ansible_password=${var.password} ansible_connection=winrm ansible_winrm_port=5985 ansible_winrm_server_cert_validation=ignore ansible_winrm_scheme=http ansible_user=Administrator' join_domain.yml"
  }
  provisioner "local-exec" {
    command = "ansible-playbook -i '${self.public_ip},' --extra-vars 'ansible_password=${var.password} ansible_connection=winrm ansible_winrm_port=5985 ansible_winrm_server_cert_validation=ignore ansible_winrm_scheme=http ansible_user=Administrator' make_share.yml"
  }
}

resource "aws_instance" "ws01" {
  ami           = data.aws_ami.windows_2016.id
  instance_type = "t2.medium"
  subnet_id     = aws_subnet.main.id
  private_ip    = "10.0.0.10"
  user_data     = local.user_data
  depends_on    = [aws_instance.dc01]
  vpc_security_group_ids = [aws_security_group.winrm_rdp_sg.id]
  tags = {
    Name = "WS01"
  }

  root_block_device {
    volume_size           = "100"
    volume_type           = "gp2"
    delete_on_termination = true
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command = " while ! nc -z ${self.public_ip} 5985 ; do sleep 1; done;"
  }
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command = " sleep 60 "
  }
  provisioner "local-exec" {
    command = "ansible-playbook -i '${self.public_ip},' --extra-vars 'ansible_password=${var.password} ansible_connection=winrm ansible_winrm_port=5985 ansible_winrm_server_cert_validation=ignore ansible_winrm_scheme=http ansible_user=Administrator' chocolatey.yml"
  }
  provisioner "local-exec" {
    command = "ansible-playbook -i '${self.public_ip},' --extra-vars 'ansible_password=${var.password} ansible_connection=winrm ansible_winrm_port=5985 ansible_winrm_server_cert_validation=ignore ansible_winrm_scheme=http ansible_user=Administrator' join_domain.yml"
  }
}



resource "aws_instance" "attack" {
  ami           = data.aws_ami.windows_2016.id
  instance_type = "t2.xlarge"
  subnet_id     = aws_subnet.main.id
  private_ip    = "10.0.0.210"
  user_data     = local.user_data
  vpc_security_group_ids = [aws_security_group.winrm_rdp_sg.id]
  tags = {
    Name = "attack"
  }

  root_block_device {
    volume_size           = "100"
    volume_type           = "gp2"
    delete_on_termination = true
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command = " while ! nc -z ${self.public_ip} 5985 ; do sleep 1; done;"
  }
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command = " sleep 60 "
  }
  provisioner "local-exec" {
    command = "ansible-playbook -i '${self.public_ip},' --extra-vars 'ansible_password=${var.password} ansible_connection=winrm ansible_winrm_port=5985 ansible_winrm_server_cert_validation=ignore ansible_winrm_scheme=http ansible_user=Administrator' chocolatey.yml"
  }
}



output "DC01_public_ip" {
  description = "The public IP address of DC01 instance."
  value       = aws_instance.dc01.public_ip
}


output "WEB01_public_ip" {
  description = "The public IP address of WEB01 instance."
  value       = aws_instance.web01.public_ip
}


output "WS01_public_ip" {
  description = "The public IP address of WS01 instance."
  value       = aws_instance.ws01.public_ip
}
output "Attack_public_ip" {
  description = "The public IP address of WS01 instance."
  value       = aws_instance.attack.public_ip
}

