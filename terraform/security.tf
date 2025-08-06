# aws-codebuild-docker-image/terraform/security.tf

# Shared security group for all CodeBuild projects
resource "aws_security_group" "codebuild_sg" {
  name        = "shared-codebuild-sg"
  description = "Shared security group for all CodeBuild projects"
  vpc_id      = module.vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "shared-codebuild-sg"
  }
}
