az vmss list --resource-group MC_rg-test-aks-mocahu_aks-mocahu_westeurope --query '[].name |[0]' | Out-File -Encoding utf8NoBOM -NoNewline -Force name.txt
$name = az vmss list --resource-group MC_rg-test-aks-mocahu_aks-mocahu_westeurope --query '[].name |[0]'
az vmss identity assign -g MC_rg-test-aks-mocahu_aks-mocahu_westeurope -n $name