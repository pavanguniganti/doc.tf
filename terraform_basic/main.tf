### Creating the VPC

resource "aws_vpc" "task-vpc" {
    cidr_block = var.vpc_cidr
    instance_tenancy = "default"
    tags = {
      Name = "Task-terraform"
    }
}

### Creating the Internet gateway

resource "aws_internet_gateway" "task-IG" {
    vpc_id = aws_vpc.task-vpc.id
    tags = {
        Name = "Task-IG"
    }
}

### Creating the Route tables

resource "aws_route_table" "task-RT" {
    vpc_id = aws_vpc.task-vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.task-IG.id
    }
    tags = {
      Name = "Task-RT"
    }
}

### Creating the subnet

resource "aws_subnet" "task-subnet" {
    vpc_id = aws_vpc.task-vpc.id
    cidr_block = var.subnet_cidr
    map_public_ip_on_launch = true
    availability_zone = "us-east-1a"
    tags = {
      Name = "Task-subnet"
    } 
}

### Associating Subnet to Routetables

resource "aws_route_table_association" "route-01" {
    subnet_id = aws_subnet.task-subnet.id
    route_table_id = aws_route_table.task-RT.id 
}

### Creating the security groups

resource "aws_security_group" "task-SG" {
    vpc_id = aws_vpc.task-vpc.id

 ## Inbound Rules

 ## HTTP access from anywhere
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

 ## HTTPS access from anywhere
    
    ingress {
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

 ## SSH access to anywhere

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

 ## Out Bound rules

 ## Internet Gateway access to anywhere

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }    
    
    tags = {
        Name = "Task-SG"
    }
}

### Creating the instance

resource "aws_instance" "task-instance" {
    key_name = "loadbalancer"
    ami = "ami-04b70fa74e45c3917"
    count = 1
    instance_type = "t2.micro"
    vpc_security_group_ids = [aws_security_group.task-SG.id]
    subnet_id = aws_subnet.task-subnet.id
    associate_public_ip_address = true
    user_data = <<-EOF
                  #!/bin/bash
                  apt update -y
                  apt install -y apache2
                  systemctl start apache2
                  systemctl enable apache2
                  EOF
    tags = {
        Name = "Task-instance"
    }
}

### Creating the network interface

resource "aws_network_interface" "task-NI" {
    subnet_id = aws_subnet.task-subnet.id
    private_ip = "10.0.1.30"
    security_groups = [aws_security_group.task-SG.id]
    count = length(aws_instance.task-instance)
    attachment {
        instance = aws_instance.task-instance[count.index].id
        device_index = 1
    }
    tags = {
      Name = "Task-NI"
    }
}

### Creating Elastic IP's
resource "aws_eip" "eip" {
  vpc = true
  count = length(aws_instance.task-instance)
  tags = {
    Name = "task-eip"
  }
}

// Elastic IP Association
resource "aws_eip_association" "eip1" {
  count               = length(aws_instance.task-instance)
  allocation_id       = aws_eip.eip[count.index].id
  network_interface_id = aws_network_interface.task-NI[count.index].id
}

// creating a bucket
resource "aws_s3_bucket" "s3_bucket" {
    
    bucket = "bucketpavanbackend"
    acl = "private"
}

resource "aws_dynamodb_table" "dynamodb-terraform-state-lock" {
  name = "terraform-state-lock-dynamo1"
  hash_key = "LockID"
  read_capacity = 20
  write_capacity = 20
 
  attribute {
    name = "LockID"
    type = "S"
  }
}

terraform {
  backend "s3" {
    bucket = "bucketpavanbackend"
    dynamodb_table = "terraform-state-lock-dynamo1"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}

