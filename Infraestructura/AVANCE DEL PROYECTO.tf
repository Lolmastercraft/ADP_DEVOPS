#AVANCE DEL PROYECTO

#====================PROVEDOR====================
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

#====================SUBRED PUBLICA====================
resource "aws_subnet" "subred_pub" {
    vpc_id = aws_vpc.vpc_pro.id
    cidr_block = "10.13.0.0/24"
    map_public_ip_on_launch = true

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

#====================TABLAS DE RUTA PUBLICA====================
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

#==========ASOCIACION DE TABLAS DE RUTAS==========
resource "aws_route_table_association" "Asociaciones_Pro" {
    subnet_id = aws_subnet.subred_pub.id
    route_table_id = aws_route_table.tablaruta_pub.id
}

#====================SUBRED PRIVADA====================
resource "aws_subnet" "subred_pri" {
    vpc_id = aws_vpc.vpc_pro
    cidr_block = "10.14.0.0/24"
    map_public_ip_on_launch = false

    tags = {
        Name = "Subred-Privada"
    }
}

#==============NAT Gateway=============
resource "aws_eip" "nat_eip" {
  vpc = true
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.subred_pub.id

  tags = {
    Name = "NAT-Gateway-Pro"
  }
}

#===============TABLA DE RUTA PRIVADA===============
resource "aws_route_table" "tablaruta_priv" {
  vpc_id = aws_vpc.vpc_pro.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "TablaRuta-Priv"
  }
}

#=============ASOCIACION DE TABLA DE RUTA PRIVADA
resource "aws_route_table_association" "priv_association" {
  subnet_id      = aws_subnet.subred_pri.id
  route_table_id = aws_route_table.tablaruta_priv.id
}


#======================CREACION DE GRUPOS DE SEGURIDAD======================

#====================SG JUMP SERVER WINDOWS====================
resource "aws_security_group" "SG_JS_WIN" {
    vpc_id = aws_vpc.vpc_pro.id
    name = "SG_JS_WIN"
    description = "SG para jump server con OS Windows"

    #REGLAS DE ENTRADA==========
    
    #RDP
    ingress {
        from_port = 3389
        to_port = 3389
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"] #IPv4 de la pc
    }
    
    #REGLAS DE SALIDA==========
    #All TRAFIC
    egress{
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }  
}

#====================SG LINUX WEB SERVER====================
resource "aws_security_group" "SG-LIN-WEB" {
    vpc_id = aws_vpc.vpc_pro.id
    name = "SG-LIN-WEB"
    description = "SG para servidor web Linux"

    #REGLAS DE ENTRADA==========
    #SSH
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"] #IPv4 del JUMP
    }

    #HTTP
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    #REGLAS DE SALIDA====================
    #HTTP
    egress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

#====================CREACION DE INSTANCIAS====================

#INSTANCIA DE Windows Jump Server====================
resource "aws_instance" "Win-JS" {
    ami = "ami-0c765d44cf1f25d26"

    instance_type = "t2.medium"

    subnet_id = aws_subnet.subred_pub.id

    vpc_security_group_ids = [aws_security_group.SG_JS_WIN.id]

    associate_public_ip_address = true

    key_name = "vockey"

    tags = {
        Name = "Servidor Windows Jump Server"
    }
}

#INSTANCIA DE Linux Web Server
resource "aws_instance" "Lin-Web" {
    ami = "ami-084568db4383264d4"
    
    instance_type = "t2.micro"

    subnet_id = aws_subnet.subred_pri.id

    vpc_security_group_ids = [aws_security_group.SG-LIN-WEB]

    associate_public_ip_address = false

    key_name = "vockey"

    tags = {
        Name = "Linux Web Server"
    }

}

#====================OUTPUTS====================

#OUTPUT JUMP SERVER====================
output "public_ipWinJS" {
    description = "IP public del Windows Jump Server"
    value = aws_instance.Win-JS.public_ip
}

#OUTPUT LINUX WEB====================
output "public_ipLinWeb" {
    description = "IP public del Linux Web Server"
    value = aws_instance.Lin-Web.public_ip
}