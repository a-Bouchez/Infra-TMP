# Valores calculados a partir de las variables
locals {
  nombre = "${var.proyecto}-${var.ambiente}"
}

# Imagen (AMI) de Amazon Linux 2023 más reciente
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-*-x86_64"]
  }
}

# Par de claves para acceso SSH
resource "aws_key_pair" "acceso" {
  key_name   = "${local.nombre}-key"
  public_key = file(pathexpand("~/.ssh/id_rsa.pub"))
}

# Firewall de la instancia
resource "aws_security_group" "web" {
  name        = "${local.nombre}-sg"
  description = "Acceso SSH y HTTP"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.nombre}-sg"
  }
}

# Máquina virtual
resource "aws_instance" "servidor" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  availability_zone      = "${var.aws_region}${var.zona}"
  key_name               = aws_key_pair.acceso.key_name
  vpc_security_group_ids = [aws_security_group.web.id]

  tags = {
    Name = "${local.nombre}-web"
  }
}
