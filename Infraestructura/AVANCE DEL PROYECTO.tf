#====================PROVEEDOR====================
provider "aws" {
  region = "us-east-1"
}

#====================VPC====================
resource "aws_vpc" "vpc_pro" {
  cidr_block = "10.13.0.0/20"

  tags = {
    Name = "VPC-Pro"
  }
}

#====================SUBRED PÚBLICA====================
resource "aws_subnet" "subred_pub" {
  vpc_id                   = aws_vpc.vpc_pro.id
  cidr_block               = "10.13.0.0/24"
  map_public_ip_on_launch  = true

  tags = {
    Name = "Subred-Pub"
  }
}

#====================GATEWAY====================
resource "aws_internet_gateway" "gateway_pro" {
  vpc_id = aws_vpc.vpc_pro.id

  tags = {
    Name = "Gateway-Pro"
  }
}

#====================TABLA DE RUTA PÚBLICA====================
resource "aws_route_table" "tablaruta_pub" {
  vpc_id = aws_vpc.vpc_pro.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gateway_pro.id
  }

  tags = {
    Name = "TablaRuta-Pro"
  }
}

#==========ASOCIACIÓN DE TABLA DE RUTA PÚBLICA==========
resource "aws_route_table_association" "asoc_pub" {
  subnet_id      = aws_subnet.subred_pub.id
  route_table_id = aws_route_table.tablaruta_pub.id
}


#======================GRUPOS DE SEGURIDAD======================

# SG PARA JUMP SERVER WINDOWS
resource "aws_security_group" "SG_JS_WIN" {
  vpc_id      = aws_vpc.vpc_pro.id
  name        = "SG_JS_WIN"
  description = "SG para jump server con OS Windows"

  ingress {
    from_port   = 3389
    to_port     = 3389
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

# SG PARA LINUX WEB SERVER
resource "aws_security_group" "SG_LIN_WEB" {
  vpc_id      = aws_vpc.vpc_pro.id
  name        = "SG_LIN_WEB"
  description = "SG para servidor web Linux"

  # SSH desde Jump Server
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP público
  ingress {
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
}


#====================INSTANCIAS====================

# Jump Server Windows
resource "aws_instance" "Win_JS" {
  ami                         = "ami-0c765d44cf1f25d26"
  instance_type               = "t2.medium"
  subnet_id                   = aws_subnet.subred_pub.id
  vpc_security_group_ids      = [aws_security_group.SG_JS_WIN.id]
  associate_public_ip_address = true
  key_name                    = "vockey"

  tags = {
    Name = "Servidor Windows Jump Server"
  }
}

# Linux Web Server
resource "aws_instance" "Lin_Web" {
  ami                         = "ami-084568db4383264d4"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.subred_pub.id       
  vpc_security_group_ids      = [aws_security_group.SG_LIN_WEB.id]
  associate_public_ip_address = true                            
  key_name                    = "vockey"

  tags = {
    Name = "Linux Web Server"
  }
}


#====================OUTPUTS====================

output "public_ipWinJS" {
  description = "IP pública del Windows Jump Server"
  value       = aws_instance.Win_JS.public_ip
}

output "public_ipLinWeb" {
  description = "IP pública del Linux Web Server"
  value       = aws_instance.Lin_Web.public_ip
}
