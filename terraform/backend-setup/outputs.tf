output "s3_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.terraform_state.arn
}

output "backend_config" {
  description = "Backend configuration to use in your main Terraform code"
  value       = <<-EOT
  
  Copy this configuration to terraform/environments/dev/backend-config.tfvars:
  
  bucket       = "${aws_s3_bucket.terraform_state.id}"
  key          = "dev/terraform.tfstate"
  region       = "${var.aws_region}"
  use_lockfile = true
  encrypt      = true
  EOT
}
