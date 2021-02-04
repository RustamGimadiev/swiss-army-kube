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

output "db" {
  value = aws_db_instance.default.endpoint
}
