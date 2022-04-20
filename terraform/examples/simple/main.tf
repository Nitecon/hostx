provider "aws" {
  region = var.region
}

resource "aws_vpc" "vpc" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = var.name
    Env  = var.env
  }
}

# This will be used by the public subnets
resource "aws_internet_gateway" "ig" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.name}-igw"
    Env  = var.env
  }
}

# Public subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.vpc.id
  count                   = length(var.public_subnets_cidr)
  cidr_block              = element(var.public_subnets_cidr, count.index)
  availability_zone       = element(var.availability_zones, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.env}-${element(var.availability_zones, count.index)}-public"
    Env  = var.env
  }
}

# Public subnets route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name        = "${var.name}-public-route-table"
    Environment = var.env
  }
}

# Add route for public route table to internet gateway
resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.ig.id
}

# Associate the public route table to public subnets
resource "aws_route_table_association" "public" {
  count          = length(var.public_subnets_cidr)
  subnet_id      = element(aws_subnet.public.*.id, count.index)
  route_table_id = aws_route_table.public.id
}

data "aws_iam_policy_document" "AWSLambdaTrustPolicy" {
  version = "2012-10-17"
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "lambda_general_execution_policy" {
  version = "2012-10-17"
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    effect  = "Allow"
    resources = ["*"]
  }
}

resource "aws_iam_policy" "hostx_execution_policy" {
  name = "${var.app}-lambda-execution-policy"
  description = "Execution policy for hostx lambda function"
  policy = data.aws_iam_policy_document.lambda_general_execution_policy.json
}

resource "aws_iam_role" "lambda_iam_role" {
  assume_role_policy = data.aws_iam_policy_document.AWSLambdaTrustPolicy.json
  name               = "${var.app}-iam-role-lambda-trigger"
}

resource "aws_iam_role_policy_attachment" "attach_execution_policy" {
  role       = aws_iam_role.lambda_iam_role.name
  policy_arn = aws_iam_policy.hostx_execution_policy.arn
}

data "aws_caller_identity" "current" {}

data "aws_s3_bucket" "contentBucket" {
  bucket = var.contentBucket
}

data "aws_iam_policy_document" "hostx_data_access" {
  version = "2012-10-17"
  statement {
    actions = ["s3:ListBucket"]
    effect  = "Allow"
    resources = [data.aws_s3_bucket.contentBucket.arn]
  }
  statement {
    actions = ["s3:GetObject"]
    effect  = "Allow"
    resources = ["${data.aws_s3_bucket.contentBucket.arn}/*"]
  }
}

resource "aws_iam_policy" "hostx" {
  name = "${var.app}-lambda-access-policy"
  description = "A test policy"
  policy = data.aws_iam_policy_document.hostx_data_access.json
}

resource "aws_iam_role_policy_attachment" "hostx-policy-attach" {
  role       = aws_iam_role.lambda_iam_role.name
  policy_arn = aws_iam_policy.hostx.arn
}

resource "aws_lambda_function" "hostx" {
  function_name    = var.app
  filename         = var.zipfile
  handler          = "bin/hostx"
  source_code_hash = filebase64sha256(var.zipfile)
  role             = aws_iam_role.lambda_iam_role.arn
  runtime          = "go1.x"
  memory_size      = 128
  timeout          = 30
  tags            = {
    HostX = "1.0"
    // add any additional tags you require here...
  }
  environment {
    variables = {
      INDEX_FILE = var.indexFile
      ERROR_DIR = var.errorsRoot
      BUCKET = var.contentBucket
      PREFIX = var.siteRoot
      USE_REWRITE = var.useRewriteMode
      DEBUG = var.useDebugMode
      CORS = var.cors
      REQUEST_NO_CACHE = var.noCachePaths
      CACHE_EXPIRE_TTL=var.CacheExpire
      CACHE_PURGE_TTL=var.CachePurge
      USE_CACHE=var.UseCaching
      STORAGE_TYPE = var.StorageType
    }
  }
}

resource "aws_lambda_permission" "allow_alb_to_invoke_lambda" {
  statement_id  = "AllowExecutionFromALB"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.hostx.function_name
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_alb_target_group.main.arn
}

data "aws_iam_policy_document" "hostx_exec_role_policy" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:*:*:*"
    ]
  }
}

resource "aws_cloudwatch_log_group" "loggroup" {
  name              = "/aws/lambda/${aws_lambda_function.hostx.function_name}"
  retention_in_days = var.lambda_logs_expiration_days
  tags = {
    CreatedFor = var.app
    LogOrigin = "Lambda"
    OriginArn = aws_lambda_function.hostx.arn
  }
}

resource "aws_security_group" "web_access" {
  name        = "loadbalancer-ingress"
  description = "Allow HTTP/HTTPS inbound traffic"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description      = "TLS from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "HTTP from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web_access"
  }
}

resource "aws_alb" "main" {
  name = var.app
  # launch lbs in public or private subnets based on "internal" variable
  internal        = false
  subnets         = aws_subnet.public.*.id
  security_groups = [aws_security_group.web_access.id]
  depends_on = [
    aws_security_group.web_access,
  ]
  access_logs {
    enabled = false
    bucket = var.contentBucket
    prefix = "logs"
  }
  tags            = {
    CreatedFor = var.app
    // Add any additional ALB tags here...
  }
}


resource "aws_alb_target_group" "main" {
  name        = var.app
  port        = 443
  protocol    = "HTTPS"
  vpc_id      = aws_vpc.vpc.id
  target_type = "lambda"
  tags            = {
    TargetType = "Lambda"
    TargetName = var.app
  }
}

resource "aws_lb_target_group_attachment" "main" {
  target_group_arn = aws_alb_target_group.main.arn
  target_id        = aws_lambda_function.hostx.arn
  depends_on       = [aws_lambda_permission.allow_alb_to_invoke_lambda]
}

resource "aws_acm_certificate" "hostx_cert" {
  domain_name       = var.fqdn
  validation_method = "DNS"
}

data "aws_route53_zone" "hostx" {
  name         = var.r53domain
  private_zone = false
}

resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.hostx.zone_id
  name    = var.fqdn
  type    = "CNAME"
  ttl     = "60"
  records = [aws_alb.main.dns_name]
}

resource "aws_route53_record" "hostx" {
  for_each = {
  for dvo in aws_acm_certificate.hostx_cert.domain_validation_options : dvo.domain_name => {
    name   = dvo.resource_record_name
    record = dvo.resource_record_value
    type   = dvo.resource_record_type
  }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.hostx.zone_id
}

resource "aws_acm_certificate_validation" "hostx" {
  certificate_arn         = aws_acm_certificate.hostx_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.hostx : record.fqdn]
}

resource "aws_alb_listener" "main" {
  load_balancer_arn = aws_alb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate.hostx_cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.main.arn
  }
}

resource "aws_lb_listener_rule" "main_hostname" {
  listener_arn = aws_alb_listener.main.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.main.arn
  }

  condition {
    host_header {
      values = [var.fqdn]
    }
  }
}

resource "aws_alb_listener" "redirector" {
  load_balancer_arn = aws_alb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}