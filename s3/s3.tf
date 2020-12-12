terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 2.70"
    }
  }
}

provider "aws" {
  profile = "default"
  region  = var.region
}

# Note that "pkcom" is a name for my specific bucket. Unfortunately,
# terraform doesn't support parameterized resource names at the time
# of writing: https://github.com/hashicorp/terraform/issues/571

resource "aws_s3_bucket" "pkcom" {
  bucket = var.bucketName
  acl    = "public-read"
  policy = <<EOF
{
    "Version": "2008-10-17",
    "Statement": [
    {
        "Sid": "PublicReadForGetBucketObjects",
        "Effect": "Allow",
        "Principal": {
            "AWS": "*"
         },
         "Action": "s3:GetObject",
         "Resource": ["arn:aws:s3:::${var.bucketName}/*",
         "arn:aws:s3:::${var.bucketName}"
         ]
    }]
}
EOF

  website {
    index_document = "index.html"
    error_document = "error.html"

    routing_rules = <<EOF
[{
    "Condition": {
        "KeyPrefixEquals": "docs/"
    },
    "Redirect": {
        "ReplaceKeyPrefixWith": "documents/"
    }
}]
EOF
  }
}

data "aws_s3_bucket" "pkcom" {
  bucket = var.bucketName
}

resource "aws_cloudfront_distribution" "pkcomCFDistro" {
  aliases = var.customDomains
  origin {
    origin_id   = var.s3OriginId
    domain_name = data.aws_s3_bucket.pkcom.website_endpoint

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["SSLv3", "TLSv1", "TLSv1.1", "TLSv1.2"]
    }

  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  logging_config {
    include_cookies = false
    bucket          = "${var.property}-log.s3.amazonaws.com"
  }

  default_cache_behavior {
    # TODO: restrict below whitelist
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = var.s3OriginId

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 3600
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
  }

  viewer_certificate {
    acm_certificate_arn = var.acmCertARN
    ssl_support_method = "sni-only"
  }
}

