terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.20"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 1.2"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "1.3.2"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 1.13.3"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 1.4"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 2.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 2.1"
    }
    template = {
      source  = "hashicorp/template"
      version = "~> 2.1"
    }
    kustomization = {
      source  = "kbst/kustomization"
      version = ">= 0.3.1"
    }
    mysql = {
      source  = "winebarrel/mysql"
      version = "1.9.0-p6"
    }
  }
  required_version = ">= 0.13"
}
