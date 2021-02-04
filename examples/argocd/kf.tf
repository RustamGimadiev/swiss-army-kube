resource "aws_db_subnet_group" "default" {
  name       = "kubeflow"
  subnet_ids = ["subnet-077cb43130ab68a9a", "subnet-0f0f33d6895c61edb"]

  tags = local.tags
}

resource "aws_db_instance" "default" {
  engine                 = "mysql"
  engine_version         = "5.7.31"
  instance_class         = "db.t3.micro"
  name                   = "kubeflow"
  username               = "rootuser"
  password               = "rootpasswd"
  vpc_security_group_ids = [module.kubernetes.this.worker_security_group_id]
  db_subnet_group_name   = aws_db_subnet_group.default.name
  publicly_accessible    = true
  allocated_storage      = 20
}

resource "aws_kms_ciphertext" "pass" {
  key_id    = module.argocd.state.kms_key_id
  plaintext = base64encode(aws_db_instance.default.password)
}


provider "mysql" {
  endpoint = aws_db_instance.default.endpoint
  username = aws_db_instance.default.username
  password = aws_db_instance.default.password
}

resource "mysql_database" "cachedb" {
  name = "cache"
}

resource "mysql_database" "pipelines" {
  name = "pipelines"
}

resource "mysql_database" "metadata" {
  name = "metadata"
}

resource "local_file" "creds" {
  filename = "apps/mysql-secret-demo.yaml"
  content = yamlencode(
    {
      apiVersion = "v1"
      kind       = "Secret"
      metadata = {
        name      = "mysql-secret"
        namespace = "demo"
      }
      type = "Opaque"
      data = {
        username = base64encode(aws_db_instance.default.username)
        password = "KMS_ENC:${aws_kms_ciphertext.pass.ciphertext_blob}:"
      }
    }
  )
}
resource "aws_iam_user_policy" "aws_ro" {
  name = "test"
  user = aws_iam_user.aws.name

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_user" "aws" {
  name = "${module.kubernetes.this.cluster_id}_demo"
}

resource "aws_iam_access_key" "aws" {
  user = aws_iam_user.aws.name
}

resource "aws_kms_ciphertext" "a" {
  key_id    = module.argocd.state.kms_key_id
  plaintext = base64encode(aws_iam_access_key.aws.secret)
}

resource "local_file" "aws" {
  filename = "apps/aws-secret.yaml"
  content = yamlencode(
    {
      apiVersion = "v1"
      kind       = "Secret"
      metadata = {
        name      = "aws-secret"
        namespace = "demo"
      }
      type = "Opaque"
      data = {
        accesskey = base64encode(aws_iam_access_key.aws.id)
        secretkey = "KMS_ENC:${aws_kms_ciphertext.a.ciphertext_blob}:"
      }
    }
  )
}

output "db" {
  value = aws_db_instance.default.endpoint
}

module "iam_role" {
  source                        = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                       = "~> v3.6.0"
  create_role                   = true
  role_name                     = "${module.kubernetes.this.cluster_id}_demo"
  provider_url                  = replace(module.kubernetes.this.cluster_oidc_issuer_url, "https://", "")
  role_policy_arns              = ["arn:aws:iam::aws:policy/AmazonS3FullAccess"]
  oidc_fully_qualified_subjects = ["system:serviceaccount:demo:*"]
}

output "role" {
  value = module.iam_role.this_iam_role_arn
}

