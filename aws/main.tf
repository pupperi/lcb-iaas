provider "aws" {
  profile = "default"
  region = var.aws_region
}

data "aws_availability_zones" "available" {}

resource "aws_vpc" "lcb-vpc" {
  cidr_block = var.vpc_fullcidr
  tags = {
    Name = "US-West-2-lcb-vpc"
  }
}

resource "aws_subnet" "lcb-public-subnet" {
  vpc_id = aws_vpc.lcb-vpc.id
  cidr_block = "10.0.128.0/24"
  availability_zone = "us-west-2a"
  tags = {
    Name = "lcb-public-subnet"
  }
}

resource "aws_subnet" "lcb-private-subnet-a" {
  vpc_id = aws_vpc.lcb-vpc.id
  cidr_block = "10.0.126.0/24"
  availability_zone = "us-west-2a"
  tags = {
    Name = "lcb-private-subnet-a"
  }
}

resource "aws_subnet" "lcb-private-subnet-b" {
  vpc_id = aws_vpc.lcb-vpc.id
  cidr_block = "10.0.127.0/24"
  availability_zone = "us-west-2b"
  tags = {
    Name = "lcb-private-subnet-b"
  }
}

resource "aws_network_acl" "lcb-network-acl" {
  vpc_id = aws_vpc.lcb-vpc.id
  egress {
    protocol = "-1"
    rule_no = 100
    action = "allow"
    cidr_block = "0.0.0.0/0"
    from_port = 0
    to_port = 0
  }
  ingress {
    protocol = "-1"
    rule_no = 100
    action = "allow"
    cidr_block = "0.0.0.0/0"
    from_port = 0
    to_port = 0
  }
  subnet_ids = [
    aws_subnet.lcb-public-subnet.id,
    aws_subnet.lcb-private-subnet-a.id,
    aws_subnet.lcb-private-subnet-b.id
  ]
  tags = {
    Name = "LCB ACL"
  }
}

resource "aws_internet_gateway" "lcb-igw" {
  vpc_id = aws_vpc.lcb-vpc.id
  tags = {
    Name = "lcb-igw"
  }
}

resource "aws_route_table" "lcb-public-rt" {
  vpc_id = aws_vpc.lcb-vpc.id
  tags = {
    Name = "lcb-public-rt"
  }
}

resource "aws_route" "lcb-public-routes" {
  route_table_id = aws_route_table.lcb-public-rt.id
  gateway_id = aws_internet_gateway.lcb-igw.id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route_table_association" "lcb-public-rt-association" {
  subnet_id = aws_subnet.lcb-public-subnet.id
  route_table_id = aws_route_table.lcb-public-rt.id
}

resource "aws_security_group" "lcb-web-sg" {
  name        = "lcb-sg"
  description = "Allow all inbound traffic"
  vpc_id      = aws_vpc.lcb-vpc.id
  tags = {
    Name = "lcb-web-sg"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "lcb-db-sg" {
  name        = "lcb-db-sg"
  description = "Allow all inbound traffic"
  vpc_id      = aws_vpc.lcb-vpc.id
  tags = {
    Name = "lcb-db-sg"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 3306
    to_port   = 3306
    protocol  = "tcp"

    # To keep this example simple, we allow incoming SSH requests from any IP. In real-world usage, you should only
    # allow SSH requests from trusted servers, such as a bastion host or VPN server.
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "lcb-php-instance" {
  ami                    = var.web_ami
  instance_type          = "t2.large"
  key_name               = var.lcb_key
  vpc_security_group_ids = [aws_security_group.lcb-web-sg.id]
  subnet_id              = aws_subnet.lcb-public-subnet.id
  associate_public_ip_address = true

  connection {
    type     = "ssh"
    user     = "ec2-user"
    password = ""
    host     = aws_instance.lcb-php-instance.public_ip
    #copy <private.pem> to your local instance to the home directory
    #chmod 600 id_rsa.pem
    private_key = file("/root/lcb-iaas/aws/lcb-key.pem")
  }

  tags = {
    Name = "lcb-php-instance"
  }
  volume_tags = {
    Name = "lcb-php-instance-volume"
  }
  provisioner "remote-exec" { #install apache, mysql client, php
    inline = [
      "sudo mkdir -p /var/www/html/",
      "sudo yum update -y",
      "sudo yum install -y httpd",
      "sudo service httpd start",
      "sudo usermod -a -G apache centos",
      "sudo chown -R centos:apache /var/www",
      "sudo yum install -y mysql php php-mysql"
      ]
  }
  provisioner "file" { #copy the index file form local to remote
   source      = "/root/lcb-iaas/temp/index.php"
    destination = "/tmp/index.php"
  }
  provisioner "remote-exec" {
   inline = [
    "sudo mv /tmp/index.php /var/www/html/index.php"
   ]
  }
}

resource "aws_db_subnet_group" "lcb-db-subnet-group" {
  name       = "main"
  subnet_ids = [aws_subnet.lcb-private-subnet-a.id,aws_subnet.lcb-private-subnet-b.id]

  tags = {
    Name = "My DB subnet group"
  }
}

resource "aws_db_instance" "rds-mysql" {
  allocated_storage    = 20
  db_subnet_group_name = aws_db_subnet_group.lcb-db-subnet-group.id
  engine               = var.rds_mysql_engine
  engine_version       = var.rds_mysql_version
  identifier           = "lcb-dev-db"
  instance_class       = var.rds_mysql_instance_class
  username             = var.rds_mysql_username
  password             = var.rds_mysql_password
  skip_final_snapshot  = true
  storage_encrypted    = false
  
  tags = {
    Environment = "lcb-dev"
  }
}
