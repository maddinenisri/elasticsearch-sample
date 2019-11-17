variable "aws_profile" {
  default = "default"
}

variable "region" {
  default = "us-east-1"
  description = "AWS Region"
}

variable "vpc" {
  description = "VPC ID where to launch ElasticSearch cluster"
}

variable "vpc_cidr" {
  description = "CIDR to allow connections to ElasticSearch"
}

variable "es_domain" {
  description = "ElasticSearch domain name"
}

variable "es_subnets" {
  type = "list"
  description = "List of VPC Subnet IDs to create ElasticSearch Endpoints in"
}