terraform {

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.13.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.13.1"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14.0"
    }
  }
}

provider "azurerm" {
  features {}
}