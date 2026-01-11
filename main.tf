provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "app_server" {
  ami           = "ami-0c7217cdde317cfec" # Ubuntu 22.04 LTS (Update for your region)
  instance_type = "t2.micro"
  key_name      = "my-key"                # Your AWS Key Pair name

  tags = {
    Name = "Jenkins-Grafana-Instance"
  }

  # Allow SSH and Grafana port
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

output "instance_ip" {
  value = aws_instance.app_server.public_ip
}