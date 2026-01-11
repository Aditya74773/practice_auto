provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "app_server" {
  ami           = "ami-0c7217cdde317cfec" # Ubuntu 22.04 LTS (us-east-1)
  instance_type = "t2.micro"
  
  # UPDATED: Using the correct Key Pair name from your AWS Console
  key_name      = "Aadii_new"

  tags = {
    Name = "Jenkins-Grafana-Instance"
  }

  vpc_security_group_ids = [aws_security_group.allow_traffic.id]
}

resource "aws_security_group" "allow_traffic" {
  name        = "allow_ssh_grafana"
  description = "Allow SSH and Grafana inbound traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
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

# CRITICAL: This output block allows Jenkins to grab the IP
output "instance_ip" {
  value = aws_instance.app_server.public_ip
}