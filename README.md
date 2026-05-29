# Terraform Multi-Cloud Infrastructure Guide

---

## Terraform Core Commands (Same for ALL clouds)

| Goal | Command |
|---|---|
| First-time setup | `terraform init` |
| Preview changes | `terraform plan` |
| Deploy / update | `terraform apply` |
| See live outputs | `terraform output` |
| List all resources | `terraform state list` |
| **Delete everything** | `terraform destroy` |

---

# GCP (Google Cloud Platform)

## One-Time Setup

```bash
# Install Terraform
brew tap hashicorp/tap && brew install hashicorp/tap/terraform

# Install Google Cloud CLI
brew install --cask google-cloud-sdk

# Login
gcloud auth login
gcloud auth application-default login

# Verify your project
gcloud projects list
```

## provider.tf
```hcl
terraform {
  required_providers {
    google = { source = "hashicorp/google", version = "~> 5.0" }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
```

## terraform.tfvars (fill in your values — never commit this file)
```hcl
project_id  = "your-gcp-project-id"
region      = "us-central1"
app_name    = "myapp"
db_password = "your-strong-password"
```

## Deploy
```bash
terraform init
terraform plan
terraform apply
```

## Connect to Postgres (after gcloud is installed)
```bash
gcloud sql connect <db-instance-name> \
  --user=<db-user> \
  --database=<db-name> \
  --project=<project-id>
```

Useful psql commands once connected:
```sql
\dt              -- list tables
\l               -- list databases
SELECT current_database();
\q               -- exit
```

## Push Docker Image to Artifact Registry
```bash
gcloud auth configure-docker <region>-docker.pkg.dev

docker build -t <region>-docker.pkg.dev/<project-id>/<repo-name>/app:latest .
docker push  <region>-docker.pkg.dev/<project-id>/<repo-name>/app:latest
```

Then update the `image` field in `cloud_run.tf` and run `terraform apply`.

## Delete Everything
```bash
terraform destroy
```

## Billing Commands
```bash
# List billing accounts
gcloud billing accounts list

# Check if billing is enabled on a project
gcloud billing projects describe <project-id>

# Unlink billing from a project (stops all charges)
gcloud billing projects unlink <project-id>
```

---

## GCP Services We Use

| Resource | Terraform File |
|---|---|
| GCP APIs (Cloud Run, SQL, Artifact Registry, Compute) | `main.tf` |
| Cloud Storage Bucket | `main.tf` |
| Artifact Registry (Docker) | `main.tf` |
| Cloud SQL Postgres 15 | `database.tf` |
| Cloud Run Service | `cloud_run.tf` |

## Example: Add More GCP Services

### Cloud Pub/Sub
```hcl
resource "google_pubsub_topic" "my_topic" {
  name = "my-topic"
}
```

### Document AI
```hcl
resource "google_document_ai_processor" "doc_processor" {
  location     = "us"
  display_name = "my-doc-processor"
  type         = "FORM_PARSER_PROCESSOR"
}
```

### Vertex AI (Gemini / Embeddings)
```hcl
resource "google_project_service" "vertex_ai" {
  service = "aiplatform.googleapis.com"
}
# No resource block needed — Vertex AI is API-driven.
# Enable the API above, then call it from your app code.
```

---

# AWS (Amazon Web Services)

## One-Time Setup
```bash
brew install awscli
aws configure   # enter: Access Key ID, Secret Key, region, output format
```

## provider.tf
```hcl
terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = var.region
}
```

## terraform.tfvars
```hcl
region      = "us-east-1"
app_name    = "myapp"
db_password = "your-strong-password"
```

## Deploy / Destroy
```bash
terraform init
terraform plan
terraform apply
terraform destroy
```

## Billing Commands
```bash
# View current month cost breakdown
aws ce get-cost-and-usage \
  --time-period Start=$(date +%Y-%m-01),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics "UnblendedCost"

# List all running EC2 instances (check for unexpected resources)
aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,State.Name]' --output table

# List all S3 buckets
aws s3 ls

# List all Lambda functions
aws lambda list-functions --query 'Functions[*].FunctionName'

# Disable billing alerts / set budget (via console recommended)
# https://console.aws.amazon.com/billing/home#/budgets
```

## Example: AWS Lambda
```hcl
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_src"
  output_path = "${path.module}/lambda.zip"
}

resource "aws_lambda_function" "my_function" {
  function_name    = "${var.app_name}-function"
  runtime          = "python3.11"
  handler          = "main.handler"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  role             = aws_iam_role.lambda_role.arn

  environment {
    variables = {
      APP_NAME = var.app_name
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  name = "${var.app_name}-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
```

## Example: CloudWatch (Logs + Alarm)
```hcl
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/aws/lambda/${var.app_name}"
  retention_in_days = 7
}

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.app_name}-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 5

  dimensions = {
    FunctionName = aws_lambda_function.my_function.function_name
  }
}
```

## Example: S3 Bucket
```hcl
resource "aws_s3_bucket" "storage" {
  bucket        = "${var.app_name}-storage"
  force_destroy = true
}
```

## Example: RDS Postgres
```hcl
resource "aws_db_instance" "postgres" {
  identifier          = "${var.app_name}-db"
  engine              = "postgres"
  engine_version      = "15"
  instance_class      = "db.t3.micro"
  allocated_storage   = 20
  db_name             = "${var.app_name}_db"
  username            = "${var.app_name}_user"
  password            = var.db_password
  skip_final_snapshot = true
}
```

---

# Azure

## One-Time Setup
```bash
brew install azure-cli
az login
```

## provider.tf
```hcl
terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 3.0" }
  }
}

provider "azurerm" {
  features {}
}
```

## terraform.tfvars
```hcl
location       = "East US"
app_name       = "myapp"
resource_group = "myapp-rg"
db_password    = "your-strong-password"
```

## Deploy / Destroy
```bash
terraform init
terraform plan
terraform apply
terraform destroy
```

## Billing Commands
```bash
# List all subscriptions
az account list --output table

# Show current subscription
az account show

# View cost for current month
az consumption usage list --top 10 --output table

# List all resource groups (check for leftover resources)
az group list --output table

# Delete a resource group (deletes everything inside it)
az group delete --name <resource-group-name> --yes

# Disable a subscription (stops all charges)
az account set --subscription <subscription-id>
az rest --method post \
  --url "https://management.azure.com/subscriptions/<subscription-id>/providers/Microsoft.Subscription/cancel?api-version=2021-10-01"
```

## Resource Group (required for ALL Azure resources)
```hcl
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group
  location = var.location
}
```

## Example: Azure Functions
```hcl
resource "azurerm_storage_account" "func_storage" {
  name                     = "${var.app_name}funcstore"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_service_plan" "func_plan" {
  name                = "${var.app_name}-func-plan"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "Y1"
}

resource "azurerm_linux_function_app" "func" {
  name                       = "${var.app_name}-function"
  resource_group_name        = azurerm_resource_group.rg.name
  location                   = azurerm_resource_group.rg.location
  storage_account_name       = azurerm_storage_account.func_storage.name
  storage_account_access_key = azurerm_storage_account.func_storage.primary_access_key
  service_plan_id            = azurerm_service_plan.func_plan.id

  site_config {
    application_stack {
      python_version = "3.11"
    }
  }

  app_settings = {
    FUNCTIONS_WORKER_RUNTIME = "python"
  }
}
```

## Example: Azure OpenAI
```hcl
resource "azurerm_cognitive_account" "openai" {
  name                = "${var.app_name}-openai"
  resource_group_name = azurerm_resource_group.rg.name
  location            = "East US"
  kind                = "OpenAI"
  sku_name            = "S0"
}

resource "azurerm_cognitive_deployment" "gpt4o" {
  name                 = "gpt-4o"
  cognitive_account_id = azurerm_cognitive_account.openai.id

  model {
    format  = "OpenAI"
    name    = "gpt-4o"
    version = "2024-05-13"
  }

  scale {
    type     = "Standard"
    capacity = 10
  }
}
```

## Example: Azure Document Intelligence
```hcl
resource "azurerm_cognitive_account" "doc_intelligence" {
  name                = "${var.app_name}-doc-intel"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  kind                = "FormRecognizer"
  sku_name            = "S0"
}

output "doc_intelligence_endpoint" {
  value = azurerm_cognitive_account.doc_intelligence.endpoint
}

output "doc_intelligence_key" {
  value     = azurerm_cognitive_account.doc_intelligence.primary_access_key
  sensitive = true
}
```

## Example: Azure Blob Storage
```hcl
resource "azurerm_storage_account" "storage" {
  name                     = "${var.app_name}storage"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "container" {
  name                  = "uploads"
  storage_account_name  = azurerm_storage_account.storage.name
  container_access_type = "private"
}
```

## Example: Azure Container Apps (like Cloud Run)
```hcl
resource "azurerm_container_app_environment" "env" {
  name                = "${var.app_name}-env"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}

resource "azurerm_container_app" "app" {
  name                         = "${var.app_name}-app"
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  template {
    container {
      name   = "app"
      image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
      cpu    = 0.5
      memory = "1Gi"
    }
  }

  ingress {
    external_enabled = true
    target_port      = 80
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
}
```

---

## How to Add Any New Service

1. Copy the relevant example block above into a `.tf` file
2. Add any new variables to `variables.tf` and values to `terraform.tfvars`
3. Run:
   ```bash
   terraform plan    # preview
   terraform apply   # deploy
   ```

Terraform only changes what's different — existing resources are untouched.
