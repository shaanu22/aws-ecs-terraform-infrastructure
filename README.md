```markdown

# AWS ECS Infrastructure with Terraform

A production-ready, scalable infrastructure setup on AWS that deploys a containerized NGINX application using ECS Fargate, with auto-scaling, load balancing, and CloudWatch monitoring.

## 🏗️ Architecture Overview

This project implements the following AWS architecture:

```
Internet
    ↓
Application Load Balancer (Public Subnets)
    ↓
ECS Fargate Tasks (Private Subnets)
    ↓
NAT Gateway → Internet
```

### Components:

- **VPC**: Isolated network with public/private subnets across 2 availability zones
- **ALB**: Application Load Balancer for traffic distribution
- **ECS Fargate**: Serverless container orchestration
- **Auto Scaling**: Automatic scaling based on CPU/Memory (1-3 tasks)
- **CloudWatch**: Monitoring and alarms
- **Security Groups**: Least privilege access control
- **S3**: Remote state management with native S3 lockfile (Terraform 1.9+, no DynamoDB required)

## 📋 Prerequisites

- AWS Account with appropriate permissions
- AWS CLI configured (`aws configure`)
- Terraform >= 1.9 (required for S3 native lockfile support)
- Git

## 🚀 Deployment Guide

**Note**: This guide uses partial backend configuration with `backend-config.tfvars` to avoid hardcoding credentials. The `backend.tf` file contains an empty backend block, and actual values are provided via the tfvars file during `terraform init`.

This deployment uses a **two-stage approach** following industry best practices:
1. **Stage 1**: Bootstrap the Terraform backend (S3)
2. **Stage 2**: Deploy the main infrastructure using remote state

### Stage 1: Setup Terraform Backend

```bash
# 1. Navigate to backend setup directory
cd terraform/backend-setup

# 2. Update terraform.tfvars with a unique bucket name
# Edit: state_bucket_name = "terraform-state-your-unique-id-12345"

# 3. Initialize Terraform (uses local state for bootstrapping)
terraform init

# 4. Review the plan
terraform plan

# 5. Apply the backend configuration
terraform apply -auto-approve

# 6. Save the outputs - you'll need these for Stage 2
terraform output
```

**Important**: Copy the S3 bucket name from the output and update `terraform/environments/dev/backend-config.tfvars` with your actual bucket name.

**Note About State Locking**: This project uses Terraform 1.9+'s native S3 lockfile feature (`use_lockfile = true`) instead of DynamoDB. This provides the same locking functionality without the additional cost and complexity of managing a DynamoDB table.

### Stage 2: Deploy Main Infrastructure

```bash
# 1. Navigate to the dev environment
cd terraform/environments/dev

# 2. Create/update backend-config.tfvars with your S3 bucket name from Stage 1
# The file should contain:
#   bucket       = "your-actual-bucket-name"
#   key          = "dev/terraform.tfstate"
#   region       = "us-east-1"
#   use_lockfile = true
#   encrypt      = true

# 3. (Optional) Customize terraform.tfvars
# Add your email for CloudWatch alarms if desired

# 4. Initialize Terraform with backend configuration
terraform init -backend-config=backend-config.tfvars

# 5. Validate the configuration
terraform validate

# 6. Review the deployment plan
terraform plan

# 7. Deploy the infrastructure
terraform apply -auto-approve

# 8. Wait 5-10 minutes for deployment to complete
```

### Access Your Application

After deployment completes, get your application URL:

```bash
terraform output alb_url
```

Test the application:

```bash
curl $(terraform output -raw alb_url)
```

You should see the NGINX welcome page in HTML format!

## 📁 Project Structure

```
aws-ecs-terraform-infrastructure/
├── README.md
├── .gitignore
├── terraform/
│   ├── backend-setup/        # Stage 1: Bootstrap remote state
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── terraform.tfvars
│   ├── modules/
│   │   ├── vpc/             
│   │   ├── alb/             
│   │   ├── ecs/              
│   │   └── monitoring/       
│   └── environments/
│       └── dev/              # Stage 2: Main infrastructure
│           ├── main.tf
│           ├── backend.tf
|           ├── backend-config.tfvars
│           ├── variables.tf
│           ├── outputs.tf
│           └── terraform.tfvars
```

## 🔒 Security Features

### Network Security
- **VPC Isolation**: Resources deployed in isolated VPC
- **Private Subnets**: ECS tasks run in private subnets (no direct internet access)
- **Public Subnets**: Only ALB exposed to internet
- **Security Groups**: 
  - ALB: Allows HTTP/HTTPS from anywhere
  - ECS Tasks: Only allows traffic from ALB

### IAM Security (Least Privilege)
- **Task Execution Role**: Minimal permissions for ECS agent
  - Pull container images from Docker Hub
  - Write to CloudWatch Logs
- **Task Role**: Minimal permissions for container
  - Write to CloudWatch Logs only

### State Management
- **S3 Encryption**: State file encrypted at rest (AES256)
- **Versioning**: State file versioning enabled (90-day retention)
- **State Locking**: S3 native lockfile prevents concurrent modifications (Terraform 1.9+)
- **No DynamoDB Required**: Uses S3's built-in locking mechanism via `use_lockfile = true`
- **Private Bucket**: All public access blocked

## 📊 Monitoring & Auto-Scaling

### Auto-Scaling Configuration
- **Minimum Tasks**: 1
- **Maximum Tasks**: 3
- **Scale-Out Triggers**: 
  - CPU > 70% for 1 minute
  - Memory > 80% for 1 minute
- **Scale-In Cooldown**: 5 minutes
- **Scale-Out Cooldown**: 1 minute

### CloudWatch Alarms
- **High CPU**: Alert when CPU > 80% for 10 minutes
- **High Memory**: Alert when Memory > 85% for 10 minutes
- **Container Insights**: Enabled for detailed metrics
- **SNS Notifications**: Email alerts (if configured)

## 🧪 Testing the Infrastructure

### 1. Verify Application is Running

```bash
# Get the ALB URL
cd terraform/environments/dev
terraform output alb_url

# Test the endpoint
curl $(terraform output -raw alb_url)
```
You should see the NGINX welcome page HTML.

Copy the ALB url and paste on your web browser address bar; you should see the NGINX welcome page.


### 2. Test Auto-Scaling

Generate load to trigger auto-scaling:

```bash
# Install Apache Bench (if not installed)
# Ubuntu/Debian: sudo apt-get install apache2-utils
# macOS: brew install apache2-utils

# Generate load (replace with your ALB DNS)
ab -n 10000 -c 100 $(terraform output -raw alb_url)/
```

Monitor scaling in AWS Console:
- Navigate to: ECS → Clusters → aws-ecs-demo-cluster → Services
- Watch the "Running" task count (in the Tasks section) increase from 1 to 2 or 3 or watch "Deployments and tasks" column show the running tasks 


### 3. Check CloudWatch Metrics

**Via AWS Console:**
- Navigate to: CloudWatch → Metrics → All metrics → ECS → ClusterName, ServiceName
- View: CPUUtilization and MemoryUtilization

**Via AWS CLI:**
```bash
# Get CPU metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=aws-ecs-demo-service Name=ClusterName,Value=aws-ecs-demo-cluster \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```


### 4. View Logs

```bash
# List log streams
aws logs describe-log-streams \
  --log-group-name /ecs/aws-ecs-demo \
  --order-by LastEventTime \
  --descending \
  --max-items 5


# View recent logs
aws logs tail /ecs/aws-ecs-demo --follow
```

## 🛠️ Common Operations

### View All Resources

```bash
cd terraform/environments/dev
terraform show
```

### Update Infrastructure

1. Modify Terraform files as needed
2. Review changes:
   ```bash
   terraform plan
   ```
3. Apply changes:
   ```bash
   terraform apply -auto-approve
   ```

### Scale Tasks Manually

```bash
# Edit terraform/environments/dev/main.tf
# Change desired_count in the ecs module

terraform apply -auto-approve
```

## 🗑️ Cleanup

### Destroy Main Infrastructure

```bash
cd terraform/environments/dev
terraform destroy
```

**Confirm by typing `yes` when prompted.**

### Destroy Backend (Optional)
```bash
cd terraform/backend-setup
terraform destroy
```

**Note**: If you get a "BucketNotEmpty" error, you must first empty the S3 bucket:


**Option 1: Simple deletion (works for most cases)**

```bash
# Replace with your actual bucket name
aws s3 rm s3://your-bucket-name --recursive
```


**Option 2: Complete cleanup including all versions (if versioning is enabled)**

```bash
# Replace with your actual bucket name
BUCKET_NAME="your-bucket-name"

# Delete all object versions
aws s3api delete-objects \
  --bucket $BUCKET_NAME \
  --delete "$(aws s3api list-object-versions \
    --bucket $BUCKET_NAME \
    --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}')"

# Delete all delete markers
aws s3api delete-objects \
  --bucket $BUCKET_NAME \
  --delete "$(aws s3api list-object-versions \
    --bucket $BUCKET_NAME \
    --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}')"

# Then retry destroy
terraform destroy
```


**Option 3: Via AWS Console (easiest)**

1. Go to S3 Console
2. Select the bucket
3. Click "Empty"
4. Confirm by typing "permanently delete"
5. Return to terminal and run `terraform destroy`


**Warning**: This will delete your state files. Only do this if you are completely done with the project.


## 📝 License


This project is provided as-is for educational and demonstration purposes.

## 👤 Author

[Samuel Taiwo]
