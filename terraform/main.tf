provider "aws" {
  profile                  = var.aws_profile
  region                   = var.region
  version                  = ">= 2.36.0"
}

provider "archive" {
  version = "~> 1.3"
}

resource "aws_dynamodb_table" "app_table" {
  name              = "app_table"
  read_capacity     = 20
  write_capacity    = 20
  hash_key          = "entityId"
  range_key         = "timestamp"

  stream_enabled    = true
  stream_view_type  = "NEW_AND_OLD_IMAGES"

  attribute {
    name = "entityId"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  tags = {
    Environment      = "Development"
  }
}

resource "aws_iam_role" "lambda_role" {
  name = "iam_for_lambda_of_dynamodb_to_es"

  path = "/"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
POLICY
}

data "aws_iam_policy_document" "lambda_role_policy_document" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = [
      "arn:aws:logs:*:*:*",
    ]
  }

  statement {
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DeleteNetworkInterface"
    ]

    resources = [
      "*",
    ]
  }

  statement {
    actions = [
      "dynamodb:DescribeStream",
      "dynamodb:GetRecords",
      "dynamodb:GetShardIterator",
      "dynamodb:ListStreams"
    ]

    resources = [
      aws_dynamodb_table.app_table.stream_arn,
    ]
  }
}

resource "aws_iam_policy" "lambda_role_policy" {
  name   = "lambda_role_policy"
  path   = "/"
  policy = data.aws_iam_policy_document.lambda_role_policy_document.json
}

resource "aws_iam_role_policy_attachment" "lambda_role_attach_lambda_role_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_role_policy.arn
}

resource "aws_iam_service_linked_role" "es" {
  aws_service_name = "es.amazonaws.com"
}

resource "aws_elasticsearch_domain" "sample_domain" {
  domain_name           = var.es_domain
  elasticsearch_version = "7.1"

  cluster_config {
    instance_type = "t2.small.elasticsearch"
    instance_count = 1
  }

  ebs_options {
    ebs_enabled = true
    volume_size = 10
    volume_type = "standard"
  }

  snapshot_options {
    automated_snapshot_start_hour = 23
  }


  access_policies = <<CONFIG
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "es:*",
            "Principal": {
              "AWS": "${aws_iam_role.lambda_role.arn}"
            },
            "Effect": "Allow",
            "Resource": "*"
        }
    ]
}
CONFIG

  advanced_options = {
    "rest.action.multi.allow_explicit_index" = "true"
  }

  vpc_options {
    subnet_ids = var.es_subnets
    security_group_ids = [
      aws_security_group.es_sg.id
    ]
  }

  tags = {
    Domain = "TestDomain"
  }

  depends_on = [
    "aws_iam_service_linked_role.es",
  ]
}

data "archive_file" "lambda_src_zip" {
  type = "zip"
  source_file = "index.js"
  output_path = "lambda_function.zip"
}

resource "aws_lambda_function" "ingest_dynamo_to_es_function" {
  function_name = "ingest_dynamo_to_es"
  filename      = "lambda_function.zip"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = "nodejs10.x"
  source_code_hash = data.archive_file.lambda_src_zip.output_base64sha256

  vpc_config {
    security_group_ids = [aws_security_group.lambda-vpc-sg.id]
    subnet_ids = var.es_subnets
  }

  environment {
    variables = {
      ES_ENDPOINT = aws_elasticsearch_domain.sample_domain.endpoint
      ES_REGION   = var.region
    }
  }
}

resource "aws_lambda_event_source_mapping" "lambda_event_maps_dynamodb" {
  event_source_arn  = aws_dynamodb_table.app_table.stream_arn
  function_name     = aws_lambda_function.ingest_dynamo_to_es_function.arn
  starting_position = "LATEST"
}

resource "aws_security_group" "lambda-vpc-sg" {
  name = "lambda-es-${var.es_domain}-sg"
  description = "Allow inbound traffic to ElasticSearch from VPC CIDR"
  vpc_id = var.vpc

  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = [
      var.vpc_cidr
    ]
  }

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = [
      var.vpc_cidr
    ]
  }

  egress {
    from_port = 0
    protocol = "-1"
    to_port = 0
    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }
}

resource "aws_security_group" "es_sg" {
  name = "${var.es_domain}-sg"
  description = "Allow inbound traffic to ElasticSearch from VPC CIDR"
  vpc_id = var.vpc

  ingress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [
      var.vpc_cidr
    ]
  }
}