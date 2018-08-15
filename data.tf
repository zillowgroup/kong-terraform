# AWS Data
data "aws_vpc" "vpc" {
  state = "available"

  tags {
    Name = "${var.vpc_name}"
  }
}

data "aws_region" "current" {}

data "aws_subnet_ids" "public" {
  vpc_id = "${data.aws_vpc.vpc.id}"

  tags {
    Type = "${var.public_subnets}"
  }
}

data "aws_subnet_ids" "private" {
  vpc_id = "${data.aws_vpc.vpc.id}"

  tags {
    Type = "${var.private_subnets}"
  }
}

data "aws_security_group" "default" {
  vpc_id = "${data.aws_vpc.vpc.id}"

  tags {
    Name = "${var.default_security_group}"
  }
}
