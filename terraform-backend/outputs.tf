# aws-codebuild-docker-image/terraform-backend/outputs.tf

output "bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.tfstate.bucket
}

output "dynamodb_table" {
  description = "Name of the DynamoDB table for Terraform state locking"
  value       = aws_dynamodb_table.tfstate_lock.name
}
