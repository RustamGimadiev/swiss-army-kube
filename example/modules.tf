module "kubernetes" {
  source = "../modules/kubernetes"

  environment     = var.environment
  project         = var.project
  cluster_name    = var.cluster_name
  vpc_id          = module.network.vpc_id
  subnets         = module.network.private_subnets
  admin_arns      = var.admin_arns
  cluster_version = var.cluster_version
}

module "network" {
  source = "../modules/network"

  availability_zones = var.availability_zones
  environment        = var.environment
  project            = var.project
  cluster_name       = var.cluster_name
  network            = var.network
}

module "system" {
  module_depends_on = [module.network.vpc_id, module.kubernetes.cluster_name, module.kubernetes.node_groups]
  source            = "../modules/system"

  environment        = var.environment
  project            = var.project
  cluster_name       = var.cluster_name
  vpc_id             = module.network.vpc_id
  aws_private        = var.aws_private
  domains            = var.domains
  mainzoneid         = var.mainzoneid
  config_path        = "${path.module}/kubeconfig_${var.cluster_name}"
  cert_manager_email = var.cert_manager_email
  cluster_oidc_url   = module.kubernetes.cluster_oidc_url
}

# Ingress
module "nginx" {
  module_depends_on = [module.system.cert-manager, module.kubernetes.node_groups]
  source            = "../modules/ingress/nginx"

  cluster_name = var.cluster_name
  aws_private  = var.aws_private
  domains      = var.domains
  config_path  = "${path.module}/kubeconfig_${var.cluster_name}"

  #Need oauth2-proxy github auth? Use id and secret in base64
  github-auth          = var.github-auth
  github-client-id     = var.github-client-id
  github-org           = var.github-org
  github-client-secret = var.github-client-secret
  cookie-secret        = var.cookie-secret
}

#Scaling
module "aws-cluster-autoscaler" {
  module_depends_on = [module.kubernetes.node_groups]
  source            = "../modules/scaling"

  cluster_name    = var.cluster_name
  namespace       = "kube-system"
  autoscaler_conf = {}
}

# Monitoring
#module "prometheus" {
#  module_depends_on = [module.system.cert-manager,module.nginx.nginx-ingress, module.kubernetes.node_groups]
#  source            = "../modules/monitoring/prometheus"
#
#  cluster_name = var.cluster_name
#  domains      = var.domains
#  grafana_password = var.grafana_password
#  config_path  = "${path.module}/kubeconfig_${var.cluster_name}"
#}

# Logging
#module "loki" {
#  module_depends_on = [module.system.cert-manager,module.nginx.nginx-ingress, module.kubernetes.node_groups]
#  source            = "../modules/logging/loki"
#
#  cluster_name = var.cluster_name
#  domains      = var.domains
#  config_path  = "${path.module}/kubeconfig_${var.cluster_name}"
#}

#module "efk" {
#  module_depends_on     = [module.system.cert-manager,module.nginx.nginx-ingress, module.kubernetes.node_groups]
#  source                = "../modules/logging/efk"
#  domains               = var.domains
#  config_path           = "${path.module}/kubeconfig_${var.cluster_name}"
#  elasticsearch-curator = var.elasticsearch-curator
#  logstash              = var.logstash
#  filebeat              = var.filebeat
#  success_limit         = var.success_limit
#  failed_limit          = var.failed_limit
#  elasticDataSize       = var.elasticDataSize
#}

#ARGO CD
#module "argo-cd" {
#  module_depends_on = [module.system.cert-manager,module.nginx.nginx-ingress, module.kubernetes.node_groups]
#  source            = "../modules/cicd/argo-cd"
#
#  domains = var.domains
#}

#module "argo-artifacts" {
#  module_depends_on = [module.system.cert-manager,module.argo-events.argo_events_namespace,module.nginx.nginx-ingress, module.kubernetes.node_groups]
#  source            = "../modules/cicd/argo-artifacts"
#
#  aws_region            = var.aws_region
#  cluster_name          = var.cluster_name
#  environment           = var.environment
#  project               = var.project
#  argo_events_namespace = module.argo-events.argo_events_namespace
#}

#module "argo-events" {
#  module_depends_on = [module.system.cert-manager,module.nginx.nginx-ingress, module.kubernetes.node_groups]
#  source            = "../modules/cicd/argo-events"
#}

#module "argo-workflow" {
#  module_depends_on = [module.system.cert-manager,module.nginx.nginx-ingress, module.kubernetes.node_groups]
#  source            = "../modules/cicd/argo-workflow"
#
#  aws_region    = var.aws_region
#  aws_s3_bucket = module.argo-artifacts.aws_s3_bucket
#}

module "jenkins" {
  module_depends_on = [module.system.cert-manager, module.nginx.nginx-ingress, module.kubernetes.node_groups]
  source            = "../modules/cicd/jenkins"

  domains          = var.domains
  jenkins_password = var.jenkins_password

  environment      = var.environment
  project          = var.project
  cluster_name     = var.cluster_name
  cluster_oidc_url = module.kubernetes.cluster_oidc_url
  cluster_oidc_arn = module.system.oidc_arn

  master_policy = var.master_policy
  agent_policy  = var.agent_policy

  config_path = "${path.module}/kubeconfig_${var.cluster_name}"
}
