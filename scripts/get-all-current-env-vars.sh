#!/bin/bash

# Variables
subscription="7c80f223-75b8-44d1-a155-09bd30bd62bd"
resourceGroupName="UUFSolver"
appName="UUF-Solver"
outputFile="env-vars.json"

# Get all current environment variables from the Azure App Service
az webapp config appsettings list --resource-group $resourceGroupName --name $appName --output json > $outputFile

echo "Environment variables have been saved to $outputFile"