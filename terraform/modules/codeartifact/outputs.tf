output "domain_arn" {
  description = "ARN of the CodeArtifact domain"
  value       = aws_codeartifact_domain.main.arn
}

output "domain_name" {
  description = "Name of the CodeArtifact domain"
  value       = aws_codeartifact_domain.main.domain
}

output "npm_repository_arn" {
  description = "ARN of the npm repository"
  value       = aws_codeartifact_repository.npm.arn
}

output "npm_repository_name" {
  description = "Name of the npm repository"
  value       = aws_codeartifact_repository.npm.repository
}

output "pip_repository_arn" {
  description = "ARN of the pip repository"
  value       = aws_codeartifact_repository.pip.arn
}

output "pip_repository_name" {
  description = "Name of the pip repository"
  value       = aws_codeartifact_repository.pip.repository
}

output "maven_repository_arn" {
  description = "ARN of the Maven repository"
  value       = aws_codeartifact_repository.maven.arn
}

output "maven_repository_name" {
  description = "Name of the Maven repository"
  value       = aws_codeartifact_repository.maven.repository
}

output "generic_repository_arn" {
  description = "ARN of the generic repository"
  value       = aws_codeartifact_repository.generic.arn
}

output "generic_repository_name" {
  description = "Name of the generic repository"
  value       = aws_codeartifact_repository.generic.repository
}

output "internal_repository_arn" {
  description = "ARN of the internal repository"
  value       = aws_codeartifact_repository.internal.arn
}

output "internal_repository_name" {
  description = "Name of the internal repository"
  value       = aws_codeartifact_repository.internal.repository
}

output "codeartifact_access_policy_arn" {
  description = "ARN of the CodeArtifact access policy"
  value       = aws_iam_policy.codeartifact_access.arn
}

output "package_updater_lambda_arn" {
  description = "ARN of the package updater Lambda function"
  value       = aws_lambda_function.package_updater.arn
}
