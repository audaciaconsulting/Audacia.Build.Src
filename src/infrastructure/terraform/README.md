# Terraform Pipeline Steps

## Contents

- [Overview](#overview)
- [Steps](#steps)
- [Prerequisites](#prerequisites)
- [Example Pipeline](#example-pipeline)

## Overview

The Terraform steps can be used to create the basic Azure resources needed for an environment, including:
- Azure SQL database, including a staging database
- App service for each app, including staging slots
- Storage accounts
- Key vault

A pipeline using these steps should be run once per environment. The environment to provision (e.g. QA or UAT) can be configured as a pipeline parameter, and a job can even be defined to create some Azure DevOps variable groups to save information about the resources that are created.

## Tasks

### get-resource-name.yaml

The `get-resource-name` step gets the `name` variable from the Terraform inputs (specifically from the `terraform.tfvars` file) and sets a `ResourceName` pipeline variable. The `ResourceName` is used as the basis for naming Azure resources and is also used to get the name of the storage container in which Terraform state is stored.

### set-variable.yaml

The `set-variable` step adds a variable to the `terraform.tfvars` file. The given variable should already be defined in the `variables.tf` file.

### expand-variables.yaml

The `expand-variables` step adds each Terraform output as a pipeline variable so that they can be consumed by subsequent pipeline steps.

### destroy.yaml

The `destroy` step deletes previously provisioned resources. If no resources are passed in as parameters then all resources are deleted; otherwise just the list of resources passed into the step are deleted.

## Prerequisites

Before running a provision pipeline there are a few things that need to be done.

### Define Terraform Script and Related Files

All Terraform steps take a parameter called `terraformDirectory`. This directory should contain four files:
- `main.tf`: this is the main Terraform script that contains the definitions of the resources to create
- `outputs.tf`: this defines the values that should be output by Terraform; they can be added as pipeline variables for use in subsequent steps by using the [`expand-variables` step](#expand-variablesyaml)
- `variables.tf`: this defines the inputs to the Terraform script
- `terraform.tfvars`: this specifies values for the inputs defined in `variables.tf`; not all variables must have values defined here, as the [`set-variable` step](#set-variableyaml) can set values dynamically using pipeline variables and/or parameters

See [example pipeline](#example-pipeline) for details on examples of each of these files.

### New Azure DevOps Service Connections

Two service connections are required. These are created in Azure DevOps within Project Settings. You should select the type 'Azure Resource Manager', and the Authentication Method 'Service principal (automatic)'.
- 'Environment' connection, which is used for the deployments
    - This service connection should be created for the appropriate subscription but without a specific resource group (as it doesn't exist yet)
    - The underlying Azure AD Service Principal also needs to be given the 'Terraform Deployment' role on the appropriate subscription - note this is a custom role that is already present in our Dev/Test subscription, and will have to be created in any other subscription being targeted; it is based on the Contributor role, and adds permissions to be able to read and write role assignments
    - The principal needs contributor access on the subscription as it needs permission to actually create the resource group and resources within it; the role assignment permissions are needed as it has to grant an app service roles on a blob storage container
    - Because both service connections will be given the same display name, it is advisable to set the above role before creating the second service connection, so you can be sure it has been granted to the correct service principal
- 'Terraform' connection, which is the service principal used by Terraform when initialising and populating state storage
    - This service connection should be created for our Dev/Test subscription and the `audacia-devops` resource group

## Example Pipeline

The example pipeline `provision.pipeline.yaml` in the `examples/infrastructure/terraform` folder in Audacia.Build can be used as the basis for a provisioning pipeline. The pipeline does the following:
1. Creates two self-signed certificates, for token signing and token encryption respectively
1. Sets a number of Terraform variables, such as the environment suffix to apply to Azure resources
1. Provisions the Azure resources
1. Sets the Terraform output values as pipeline variables

It will provision an environment with a standard architecture containing a UI app, an API and an Identity app.

### Modifying the Pipeline

There are a few things within the pipeline and Terraform files that must be modified before it is used.
- Set the correct variable group name in `provision.pipeline.yaml` (see [defining variables](#defining-variables) for more information)
- Set the correct `terraformDirectory` in `provision.pipeline.yaml` (see [Terraform directory](#terraform-directory) for more information)
- Set the correct `name` property in `terraform.tfvars` (see [get-resource-name.yaml](#get-resource-nameyaml) for more information)
- Confirm that other properties in `terraform.tfvars` are correct
- Confirm that the resources defined in the Terraform script `main.tf` are correct for your requirements

### Defining Variables

There are a number of variables required by the pipeline. They can be defined in a variable group or as pipeline parameters.

One approach is to use a pipeline parameter to specify an 'environment', and then use this to lookup a variable group containing the rest of the variables. This is the approach used in the example `provision.pipeline.yaml` pipeline.

The pipeline contains an `environmentName` parameter, which maps to an Azure DevOps environment. A variable group called `{MyProject}.Provision.{Environment}` should be created in Azure DevOps (where `{Environment}` is the `environmentName` pipeline parameter); for example, for the QA environment project for Gridfox, the group would be `Gridfox.Provision.QA`. This group needs the following variables:
- 'AlertEmailAddress': an email address which will be used as the recipient of the action group which will be created in Azure for the default Applicantion Insight alerts which will be created
- `AzureEnvironmentSuffix`: the value to suffix to Azure resources, e.g. if the suffix is "qa", a resource might be `gridfox-api-qa`; this can be left blank for production if desired
- `EnvironmentId`: a unique id for the environment, which is currently just used to suffix the storage account container  that stores Terraform state
- `EnvironmentServicePrincipal`: the name of a service connection in Azure DevOps that can be used to create the environment resources in Azure
- `TerraformServicePrincipal`: the name of a service connection in Azure DevOps that has access to the `audacia-devops` resource group in the dev/test subscription, as this contains the storage account to which Terraform state will be saved
- `SqlUsername`: the desired username for the Azure SQL database user
- `SqlPassword`: any sufficiently complex string; this will be used as the Azure SQL user's password
- `TokenSigningCertificatePassword`: any random string; this will be used as the password to upload the token signing certificate and should be recorded in LastPass
- `TokenEncryptionCertificatePassword`: any random string; this will be used as the password to upload the token encryption certificate and should be recorded in LastPass

### Terraform Directory

The directory `examples/infrastructure/terraform/terraform/` contains the files described [here](#define-terraform-script-and-related-files). The `main.tf` script defines the following Azure resources:
- App Service Plan
- Application Insights
- Azure SQL Server
- Azure SQL Database (including staging database and a firewall rule for the office IP address)
- App Service for an API
- App Service for an Identity app
- App Service for a UI app
- Pfx certificates for token signing and encryption
- Storage Account, Container and Blob (including role assignment to grant the Identity app access; this is used for storing data protection keys)
- Key Vault and Key (including access policy to grant the Identity app access; this is used for storing encryption keys for the data protection keys)

The App Service definition is specified in a Terraform 'module' rather than inline in the `main.tf` script. This module is defined in the files in the `modules/app_service/` directory.

### Creating Azure DevOps Variable Groups

The Provision pipeline can optionally creates some variable groups for the resources it creates. If you include this job in the pipeline (see `examples/infrastructure/terraform/jobs/provisioned-variables.job.yaml`) then the build service account needs to be granted extra permissions on the Library. To do this:
1. Go to Pipelines - Library in Azure DevOps
1. Go to Security
1. Find the '{Your Azure DevOps Project} Build Service' user and set their role as 'Creator'