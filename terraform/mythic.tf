
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]  # Canonical's owner ID for public Ubuntu AMIs
}


resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  vpc_id = aws_vpc.main.id
  description = "Allow SSH inbound traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 0 
    to_port     = 0
    protocol    = "all"
    cidr_blocks = ["10.0.0.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "all"
    cidr_blocks = ["0.0.0.0/0"]
  }


  tags = {
    Name = "allow_ssh"
  }
}

resource "aws_instance" "ubuntu_instance" {
  ami             = data.aws_ami.ubuntu.id
  instance_type   = "t2.medium"
  subnet_id     = aws_subnet.main.id
  private_ip    = "10.0.0.100"
  security_groups = [aws_security_group.allow_ssh.id]
  user_data       = templatefile("${path.module}/user_data.sh.tpl",{})

  root_block_device {
    volume_size           = "100"
    volume_type           = "gp2"
    delete_on_termination = true
  }


  tags = {
    Name = "UbuntuLTS"
  }
}

variable "github_users" {
  description = "List of GitHub usernames"
  type        = list(string)
  default     = ["sussurro","d3vnu11u1z" ]  # Update this with the GitHub usernames you want.
}


output "ubuntu_public_ip" {
  description = "The public IP address of ubuntu instance."
  value       = aws_instance.ubuntu_instance.public_ip
}

