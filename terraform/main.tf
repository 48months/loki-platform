locals {
  name = "loki-${var.env}"
  tags = merge(var.tags, {
    Environment = var.env
    Component   = "loki"
  })
}

# ---------------------------------------------------------------- S3 storage

resource "aws_s3_bucket" "loki" {
  bucket        = var.bucket_name
  force_destroy = false
  tags          = local.tags
}

resource "aws_s3_bucket_public_access_block" "loki" {
  bucket                  = aws_s3_bucket.loki.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "loki" {
  bucket = aws_s3_bucket.loki.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Backstop only. The Loki compactor deletes at retention_days, so this rule
# (retention_days + 10) never removes data earlier than the compactor would.
resource "aws_s3_bucket_lifecycle_configuration" "loki" {
  bucket = aws_s3_bucket.loki.id

  rule {
    id     = "backstop-expiry"
    status = "Enabled"

    filter {}

    expiration {
      days = var.retention_days + 10
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

# ------------------------------------------------------------ IAM for the host

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "loki" {
  name               = "${local.name}-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
  tags               = local.tags
}

data "aws_iam_policy_document" "loki_s3" {
  statement {
    sid       = "ListBucket"
    actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
    resources = [aws_s3_bucket.loki.arn]
  }

  statement {
    sid       = "ObjectAccess"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.loki.arn}/*"]
  }
}

resource "aws_iam_role_policy" "loki_s3" {
  name   = "${local.name}-s3"
  role   = aws_iam_role.loki.id
  policy = data.aws_iam_policy_document.loki_s3.json
}

# Admin access through Session Manager, so no SSH key or port 22 is needed.
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.loki.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "loki" {
  name = "${local.name}-profile"
  role = aws_iam_role.loki.name
  tags = local.tags
}

# ------------------------------------------------------------- network

resource "aws_security_group" "loki" {
  name        = "${local.name}-sg"
  description = "Loki monolithic host: push and query on 3100 from EKS nodes and Grafana"
  vpc_id      = var.vpc_id
  tags        = local.tags

  ingress {
    description     = "Loki HTTP push and query from EKS nodes and Grafana"
    from_port       = 3100
    to_port         = 3100
    protocol        = "tcp"
    security_groups = [var.eks_node_security_group_id, var.grafana_security_group_id]
  }

  egress {
    description = "S3 access and Loki release download (via NAT or endpoints)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ------------------------------------------------------------- Loki host

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_instance" "loki" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = var.private_subnet_id
  vpc_security_group_ids      = [aws_security_group.loki.id]
  iam_instance_profile        = aws_iam_instance_profile.loki.name
  associate_public_ip_address = false
  monitoring                  = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = var.disk_gb
    encrypted   = true
  }

  user_data_replace_on_change = true
  user_data = templatefile("${path.module}/templates/user_data.sh.tftpl", {
    loki_version  = var.loki_version
    loki_sha256   = var.loki_sha256
    memory_max    = var.loki_memory_max
    config_base64 = base64encode(templatefile("${path.module}/templates/loki-config.yaml.tftpl", {
      region             = var.region
      bucket             = aws_s3_bucket.loki.id
      retention_hours    = var.retention_days * 24
      ingestion_rate_mb  = var.ingestion_rate_mb
      ingestion_burst_mb = var.ingestion_burst_mb
      schema_start_date  = var.schema_start_date
    }))
  })

  # AMI moves with each "most_recent" lookup. Replace it deliberately, not on every plan.
  lifecycle {
    ignore_changes = [ami]
  }

  tags = merge(local.tags, { Name = local.name })
}
