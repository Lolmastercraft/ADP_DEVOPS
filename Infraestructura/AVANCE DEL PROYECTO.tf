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





terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
  required_version = ">= 1.0.0"
}

provider "aws" {
  region  = var.aws_region
  # Puedes usar credenciales por defecto (~/.aws/credentials) o variables de entorno:
  # access_key = var.aws_access_key
  # secret_key = var.aws_secret_key
}

variable "aws_region" {
  description = "Región de AWS donde crear la tabla"
  type        = string
  default     = "us-east-1"
}

variable "table_name" {
  description = "Nombre de la tabla DynamoDB"
  type        = string
  default     = "MiTablaProductos"
}

variable "hash_key" {
  description = "Nombre del atributo clave de partición (hash key)"
  type        = string
  default     = "ProductID"
}

variable "sort_key" {
  description = "Nombre del atributo clave de ordenación (sort key), vacío si no aplica"
  type        = string
  default     = ""
}

variable "billing_mode" {
  description = "Modo de facturación: PAY_PER_REQUEST (On-Demand) o PROVISIONED"
  type        = string
  default     = "PAY_PER_REQUEST"
}

variable "read_capacity" {
  description = "Capacidad de lectura si usas PROVISIONED"
  type        = number
  default     = 5
}

variable "write_capacity" {
  description = "Capacidad de escritura si usas PROVISIONED"
  type        = number
  default     = 5
}

resource "aws_dynamodb_table" "this" {
  name         = var.table_name
  billing_mode = var.billing_mode

  # Clave de partición (hash key)
  hash_key = var.hash_key

  # Si quieres sort key, y tu variable no está vacía:
  dynamic "range_key" {
    for_each = var.sort_key != "" ? [var.sort_key] : []
    content {
      range_key = range_key.value
    }
  }

  attribute {
    name = var.hash_key
    type = "S"    # S = String; N = Number; B = Binary
  }

  # Solo si usas sort key
  dynamic "attribute" {
    for_each = var.sort_key != "" ? [var.sort_key] : []
    content {
      name = attribute.value
      type = "S"
    }
  }

  # Si usas PROVISIONED, define capacities:
  provisioned_throughput {
    read_capacity  = var.billing_mode == "PROVISIONED" ? var.read_capacity  : null
    write_capacity = var.billing_mode == "PROVISIONED" ? var.write_capacity : null
  }

  tags = {
    Environment = "dev"
    Owner       = "ricardo"
  }
}