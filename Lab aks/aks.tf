data "azurerm_client_config" "current" {}
#Creation du RG
resource "azurerm_resource_group" "rg" {
  name     = "rg-test-aks-mocahu"
  location = "West Europe"
}
######################################################################################## CONFIG RESEAU
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.prefix}-vnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.10.0.0/16"]
}
#Creation du subet pour node
resource "azurerm_subnet" "subnetnode" {
  name                 = "subnetnode"
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = azurerm_resource_group.rg.name
  address_prefixes     = ["10.10.1.0/24"]
}
#Creation du subnet pour gateway
resource "azurerm_subnet" "subnetgateway" {
  name                 = "subnetgateway"
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = azurerm_resource_group.rg.name
  address_prefixes     = ["10.10.10.0/24"]
}
#Creation du subnet pour container
resource "azurerm_subnet" "subnetaci" {
  name                 = "subnetaci"
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = azurerm_resource_group.rg.name
  address_prefixes     = ["10.10.3.0/24"]

    delegation {
    name = "aciDelegation"
    service_delegation {
        name    = "Microsoft.ContainerInstance/containerGroups"
        actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}
################################################################################### GATEWAY
# Public Ip 
resource "azurerm_public_ip" "test" {
  name                = "publicIp1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"

}
########################################################################################### AKS KUBERNETES
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-mocahu"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "aks-mocahu"

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_D2_v2"
    vnet_subnet_id = azurerm_subnet.subnetnode.id
  }
  
  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
  }
  aci_connector_linux {
    subnet_name = azurerm_subnet.subnetaci.name
  }
  ingress_application_gateway {
    gateway_name = "gatewayaks"
    subnet_id = azurerm_subnet.subnetgateway.id
 }
  key_vault_secrets_provider {
   secret_rotation_enabled = true
   secret_rotation_interval = "5m"
  
 }
  identity {
    type = "SystemAssigned"
  }
  private_cluster_enabled = false
  azure_policy_enabled             = true
  http_application_routing_enabled = false
  tags = {
    Environment = "ecole-cap"
  }
}
# Ajout des droits au cluster en tant que network contributor
resource "azurerm_role_assignment" "roleaks" {
  scope                = azurerm_subnet.subnetaci.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.aks.identity.0.principal_id
}
#Ajout des droits au cluster en tant que contributeur
resource "azurerm_role_assignment" "roleaks2" {
  scope                = azurerm_resource_group.rg.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_kubernetes_cluster.aks.identity.0.principal_id
}
#Création du key vault
resource "azurerm_key_vault" "keyvault" {
  name                        = "keyvaultakscapgeminis"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  enable_rbac_authorization = true

  sku_name = "standard"

  access_policy {
    object_id = azurerm_kubernetes_cluster.aks.identity.0.principal_id
    tenant_id = data.azurerm_client_config.current.tenant_id
    key_permissions = [
      "Get","List","Create"
    ]

    secret_permissions = [
      "Backup","Delete","Get","List","Purge","Recover","Restore","Set"
    ]

    storage_permissions = [
      "Backup", "Delete", "DeleteSAS", "Get", "GetSAS", "List", "ListSAS", "Purge", "Recover", "RegenerateKey", "Restore", "Set", "SetSAS" ,"Update"
    ]
  }
  access_policy {
    object_id = "e1cecebc-bd46-41b5-9faa-85c0b206e788"
    tenant_id = data.azurerm_client_config.current.tenant_id
    key_permissions = [
      "Get","List","Create"
    ]

    secret_permissions = [
      "Backup","Delete","Get","List","Purge","Recover","Restore","Set"
    ]

    storage_permissions = [
      "Backup", "Delete", "DeleteSAS", "Get", "GetSAS", "List", "ListSAS", "Purge", "Recover", "RegenerateKey", "Restore", "Set", "SetSAS" ,"Update"
    ]
  }
}
#Attribution du role
resource "azurerm_role_assignment" "rolemoise" {
  scope                = azurerm_key_vault.keyvault.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = "e1cecebc-bd46-41b5-9faa-85c0b206e788"
} 
#ajout du secret dans le key vault
resource "azurerm_key_vault_secret" "secretvault" {
  name         = "secret-aks"
  value        = "<html><h1>Hello</h1></br><h1>Hi! My name is </h1></html>"
  key_vault_id = azurerm_key_vault.keyvault.id
  depends_on = [
    azurerm_role_assignment.rolemoise,azurerm_role_assignment.roleaks2,azurerm_key_vault.keyvault
  ]

# activation des droits pour le vmss   
}
resource "null_resource" "test"{
  provisioner "local-exec" {
    command = "az vmss list --resource-group MC_rg-test-aks-mocahu_aks-mocahu_westeurope --query '[].name |[0]'| Out-File -NoNewline name.txt; $name = az vmss list --resource-group MC_rg-test-aks-mocahu_aks-mocahu_westeurope --query '[].name |[0]' ; az vmss identity assign -g MC_rg-test-aks-mocahu_aks-mocahu_westeurope -n $name"
    interpreter = ["PowerShell", "-Command"]
  }
  depends_on = [ azurerm_key_vault_secret.secretvault]
}
# Passage des données via un fichier de variable
data "local_file" "namevmss" {
    filename = "name.txt"
  depends_on = [null_resource.test]
}# Recuperation des data du VMSS

data "azurerm_virtual_machine_scale_set" "vmss" {
  name                = data.local_file.namevmss.content
  resource_group_name = "MC_rg-test-aks-mocahu_aks-mocahu_westeurope"
}
resource "azurerm_role_assignment" "rolevmmss" {
  scope                = azurerm_key_vault.keyvault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = data.azurerm_virtual_machine_scale_set.vmss.identity.0.principal_id
}
# Donne les droits au VMSS
resource "azurerm_key_vault_access_policy" "example" {
  key_vault_id = azurerm_key_vault.keyvault.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_virtual_machine_scale_set.vmss.identity.0.principal_id
  depends_on = [
    azurerm_key_vault.keyvault
  ]
  key_permissions = [
      "Get","List","Create"
    ]

    secret_permissions = [
      "Backup","Delete","Get","List","Purge","Recover","Restore","Set"
    ]

    storage_permissions = [
      "Backup", "Delete", "DeleteSAS", "Get", "GetSAS", "List", "ListSAS", "Purge", "Recover", "RegenerateKey", "Restore", "Set", "SetSAS" ,"Update"
    ]
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
    azurerm_key_vault.keyvault,azurerm_key_vault_access_policy.example,azurerm_key_vault_secret.secretvault
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
    azurerm_kubernetes_cluster.aks,kubectl_manifest.keyvaultinstall,azurerm_key_vault.keyvault,azurerm_key_vault_secret.secretvault
  ]
}
output "client_certificate" {
  value     = azurerm_kubernetes_cluster.aks.kube_config.0.client_certificate
  sensitive = true
}

output "kube_config" {
  value = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive = true
} 