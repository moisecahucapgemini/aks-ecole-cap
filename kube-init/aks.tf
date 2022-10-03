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
data "azurerm_client_config" "current" {}
data "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-mocahu"
  resource_group_name = "rg-test-aks-mocahu"
}
# Configuration du provider kub et kubectl
provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.aks.kube_config.0.host
  username               = azurerm_kubernetes_cluster.aks.kube_config.0.username
  password               = azurerm_kubernetes_cluster.aks.kube_config.0.password
  client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.cluster_ca_certificate)
}
provider "kubectl" {
  host                   = azurerm_kubernetes_cluster.aks.kube_config.0.host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.cluster_ca_certificate)
  load_config_file       = false
}
# Configuration du provider kubectl
data "kubectl_file_documents" "keyvaultfile" {
  content = file("keyvault.yaml")
}
# etape 1 config storage
resource "kubectl_manifest" "keyvaultinstall" {
  for_each  = data.kubectl_file_documents.keyvaultfile.manifests
  yaml_body = each.value
  depends_on = [
    azurerm_kubernetes_cluster.aks
  ]
}
# etape 2 lancement des instances web
data "kubectl_file_documents" "yamlfile" {
  content = file("deployment-nginx.yaml")
}
resource "kubectl_manifest" "yamlinstall" {
  for_each  = data.kubectl_file_documents.yamlfile.manifests
  yaml_body = each.value
  depends_on = [
    azurerm_kubernetes_cluster.aks,kubectl_manifest.keyvaultinstall
  ]
}