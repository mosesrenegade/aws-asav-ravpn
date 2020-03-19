#!/bin/bash

# This script starts everything

echo "[-] We are now planning the deployment"
terraform plan -out main.plan

echo "[-] We are now going to apply changes" 
terraform apply "main.plan"

echo "[-] Populating the inventory in ansible"
terraform output
