provider "aws" {
 region = "${var.aws_region}"
 profile = "${var.aws_profile}"
}

#VPC 

resource "aws_vpc" "Indusface_Interview_VPC" {
  cidr_block = "172.16.0.0/16"
  enable_dns_hostnames = true 
  tags = {
    Name = "Indusface_Interview_VPC"
  }
}

resource "aws_internet_gateway" "Indusface_Interview_Internet_Gateway" {
 vpc_id = "${aws_vpc.Indusface_Interview_VPC.id}"
 tags {
      Name = "Indusface_Interview_Internet_Gateway"
}
}



resource "aws_subnet" "Indusface_Interview_Public_Subnet" {
  vpc_id = "${aws_vpc.Indusface_Interview_VPC.id}"
  cidr_block = "172.16.0.0/24"
  tags {
      Name = "Indusface_Interview_Public_Subnet"
}
} 

resource "aws_subnet" "Indusface_Interview_Private_Subnet" {
  vpc_id = "${aws_vpc.Indusface_Interview_VPC.id}"
  cidr_block = "172.16.1.0/24"
  map_public_ip_on_launch = false
  tags {
      Name = "Indusface_Interview_Private_Subnet"
}
}


resource "aws_route_table"  "Indusface_Interview_Public_Route_Table"  {
 vpc_id = "${aws_vpc.Indusface_Interview_VPC.id}"
 route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.Indusface_Interview_Internet_Gateway.id}"
       }
 tags {
       Name = "Indusface_Interview_Public_Route_Table"
      }
}



# Subnet Associations

resource "aws_route_table_association" "Indusface_Interview_Public_Subnet" {
  subnet_id = "${aws_subnet.Indusface_Interview_Public_Subnet.id}"
  route_table_id = "${aws_route_table.Indusface_Interview_Public_Route_Table.id}"
}



# Security Group 

resource "aws_security_group" "Indusface_Interview_Public_SG" {
  name = "Indusface_Interview_Public_SG"
  description = "Used for public and private instances for load balancer access"
  vpc_id = "${aws_vpc.Indusface_Interview_VPC.id}"

  #SSH 

  ingress {
    from_port   = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #HTTP 

  ingress {
    from_port   = 80
    to_port   = 80
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #Outbound internet access

  ingress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  } 
}

resource "aws_eip" "elastic_eip" {
  vpc      = true
  depends_on = ["aws_internet_gateway.Indusface_Interview_Internet_Gateway"]
} 


resource "aws_key_pair" "auth" {
 key_name = "${var.key_name}"
 public_key = "${file(var.public_key_path)}"  
}


resource "aws_instance" "Indusface_Interview_Load_Balancer" {
  instance_type = "t2.micro"
  ami = "ami-2581aa40"

root_block_device {
 volume_type = "gp2"
 volume_size = "20"
 delete_on_termination = "true"
}
  tags {
    Name = "Indusface_Interview_Load_Balancer"
  }

  key_name = "${aws_key_pair.auth.id}"
  
  subnet_id = "${aws_subnet.Indusface_Interview_Public_Subnet.id}"
  vpc_security_group_ids = ["${aws_security_group.Indusface_Interview_Public_SG.id}"]

}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = "${aws_instance.Indusface_Interview_Load_Balancer.id}"
  allocation_id = "${aws_eip.elastic_eip.id}"
}



resource "aws_eip" "nat_eip" {
  vpc      = true
  depends_on = ["aws_internet_gateway.Indusface_Interview_Internet_Gateway"]
}

resource "aws_nat_gateway" "Indusface_Interview_NAT_Gateway" {
    allocation_id = "${aws_eip.nat_eip.id}"
    subnet_id = "${aws_subnet.Indusface_Interview_Public_Subnet.id}"
    depends_on = ["aws_internet_gateway.Indusface_Interview_Internet_Gateway"]
}

resource "aws_route_table" "Indusface_Interview_Private_Route_Table" {
    vpc_id = "${aws_vpc.Indusface_Interview_VPC.id}"
 
    tags {
        Name = "Private route table"
    }
}
 
resource "aws_route" "private_route" {
	route_table_id  = "${aws_route_table.Indusface_Interview_Private_Route_Table.id}"
	destination_cidr_block = "0.0.0.0/0"
	nat_gateway_id = "${aws_nat_gateway.Indusface_Interview_NAT_Gateway.id}"
}

resource "aws_route_table_association" "Indusface_Interview_Private_Subnet_association" {
  subnet_id = "${aws_subnet.Indusface_Interview_Private_Subnet.id}"
  route_table_id = "${aws_route_table.Indusface_Interview_Private_Route_Table.id}"
}

resource "aws_security_group" "Indusface_Interview_Private_SG" {
  name        = "Indusface_Interview_Private_SG"
  description = "Used for private instances"
  vpc_id      = "${aws_vpc.Indusface_Interview_VPC.id}"
  

  # Access from other security groups

  ingress {
    from_port    = 22
    to_port      = 22
    protocol     = "tcp"
    cidr_blocks       = ["0.0.0.0/0"]
    security_groups = ["${aws_security_group.Indusface_Interview_Public_SG.id}"]
  }
  ingress {
    from_port    = 80
    to_port      = 80
    protocol     = "tcp"
    cidr_blocks       = ["0.0.0.0/0"]
    security_groups = ["${aws_security_group.Indusface_Interview_Public_SG.id}"]
  }
  ingress {
    from_port    = 443
    to_port      = 443
    protocol     = "tcp"
    cidr_blocks       = ["0.0.0.0/0"]
    security_groups = ["${aws_security_group.Indusface_Interview_Public_SG.id}"]
  }

}

resource "aws_instance" "Indusface_Interview_Web_Server" {
  instance_type = "t2.micro"
  ami = "ami-2581aa40"

root_block_device {
 volume_type = "gp2"
 volume_size = "20"
 delete_on_termination = "true"
}
  tags {
    Name = "Indusface_Interview_Web_Server"
  }

  key_name = "${aws_key_pair.auth.id}"
  
  subnet_id = "${aws_subnet.Indusface_Interview_Private_Subnet.id}"
  vpc_security_group_ids = ["${aws_security_group.Indusface_Interview_Private_SG.id}"]

}

