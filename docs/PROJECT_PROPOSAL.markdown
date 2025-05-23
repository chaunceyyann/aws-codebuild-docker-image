# Project Proposal: Streamlined AMI and Container Image Creation Process on AWS

## Problem Statement

The current image pipeline for creating Amazon Machine Images (AMIs) and container images is **static**, lacking automated upgrades and difficult to maintain. This results in:
- **Manual Updates**: Time-consuming and error-prone processes for updating images with new packages or security patches.
- **Limited Automation**: Lack of a standardized, automated pipeline for building and validating images.
- **Maintenance Challenges**: Complex configurations make it hard to track versions or apply changes consistently.
- **Scalability Issues**: Inability to easily support diverse customer requirements or new operating systems.

To address these issues, we propose establishing a **streamlined, automated process** for creating and maintaining AMIs and container images on AWS, focusing on security, configurability, and ease of upgrades.

## Objective

**Streamline the AMI and Container Image Creation Process on AWS** by:
- Automating the creation of **Golden AMIs** and **Golden Container Images** with standardized, secure components.
- Supporting **Customized AMIs** and **Customized Container Images** with flexible, customer-defined configurations via YAML files.
- Simplifying upgrades and version control through **image recipes** and a single variable change.
- Implementing **validation workflows** to ensure YAML configurations are correctly formatted and meet requirements.
- Supporting multiple operating systems: **Amazon Linux 2023**, **Ubuntu 22.04**, **Windows Server 2022**, with plans for **CentOS** in the future.

This initiative will enhance security, reduce maintenance overhead, and improve scalability for customer workloads, aligning with Bank of America’s compliance and CI/CD optimization goals.

## High-Level Overview

The proposed solution introduces a modular, automated pipeline for creating two types of images:
1. **Golden AMIs and Golden Container Images**: Focus on OS-level security and readiness, including standardized components.
2. **Customized AMIs and Customized Container Images**: Allow customers to add specific components via YAML files, built on top of Golden images.

The pipeline leverages AWS services (e.g., EC2 Image Builder, CodeBuild, ECR) and integrates with GitHub Actions for automation, using Terraform for infrastructure management (e.g., `docker-image-4codebuild-repo`, `docker-image-4codebuild`). Image recipes define base images and components, with YAML validation ensuring compliance.

### Golden AMI Components
- **Falcon Sensor**: CrowdStrike agent for endpoint security.
- **CloudWatch Agent**: For metrics and log collection (not pre-installed, requires manual installation per [AWS documentation](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/install-CloudWatch-Agent-on-EC2-Instance.html)).
- **Time Synchronization**:
  - `chrony`: For precise timekeeping on Linux.
  - `systemd-timesyncd`: Alternative time sync daemon.
- **Prometheus Exporters**:
  - `node_exporter`: System metrics.
  - `process-exporter`: Process-level metrics.

### Golden Container Image Components
- Identical to Golden AMI components:
  - **Falcon Sensor**
  - **CloudWatch Agent** (requires installation, e.g., via Dockerfile).
  - **Time Synchronization**: `chrony`, `systemd-timesyncd`.
  - **Prometheus Exporters**: `node_exporter`, `process-exporter`.

### Customized AMI and Container Image Components
Customers can add the following components via YAML configuration, built on Golden images:
- **Splunk Indexer**: For log aggregation and analysis.
- **AWS CLI**: For interacting with AWS services.
- **Docker**: Container runtime.
- **Python**: General-purpose programming.
- **Node.js**: JavaScript runtime for server-side applications.
- **Terraform Ecosystem**:
  - `terraform`: Infrastructure as code.
  - `tflint`: Linting for Terraform code.
  - `terragrunt`: Wrapper for managing Terraform configurations.
  - **Terratest**: Automated testing for Terraform (optional).
  - **Terraform Cloud/Enterprise**: For state management and collaboration (alternative to S3 backend).
- **OPA (Open Policy Agent)**: Policy enforcement for compliance.
- **Java**: For Java-based applications.
- **Security Scanners**:
  - **Snyk**: Dependency and code scanning.
  - **Wiz**: Cloud security posture management (optional).
  - **Trivy**: Container image vulnerability scanning.
  - **Grype**: Alternative vulnerability scanner.

### Supported Operating Systems
- **Amazon Linux 2023**: Lightweight, AWS-optimized.
- **Ubuntu 22.04**: Popular for open-source workloads.
- **Windows Server 2022**: For Windows-based applications.
- **Future**: CentOS (planned for broader compatibility).

## Design Details

### Image Types
1. **Golden AMI and Golden Container Image**:
   - Focus on **OS-level security and readiness**.
   - Pre-configured with Falcon sensor, CloudWatch agent, time sync, and Prometheus exporters.
   - Serve as secure, standardized base images for all workloads.
   - Stored in AWS EC2 (AMIs) and ECR (containers, e.g., `643843550246.dkr.ecr.us-east-1.amazonaws.com/docker-image-4codebuild-repo`).

2. **Customized AMI and Customized Container Image**:
   - Built on Golden images, with customer-specified components (e.g., Splunk, Terraform, Snyk).
   - Configured via **YAML files** submitted by customers, defining desired packages and settings.
   - Focus on **variety and configurability** to meet diverse workload needs.

### Image Recipes
- **Definition**: Image recipes specify the **base image** (e.g., Amazon Linux 2023, Ubuntu 22.04) and **components** (e.g., Falcon sensor, Splunk) to be installed.
- **Structure**:
  - Base image identifier (e.g., AMI ID, container base image like `amazonlinux:2023`).
  - List of components and their versions (e.g., `terraform=1.6.6`, `trivy=0.53.0`).
- **Upgrade and Version Control**:
  - Updates are simplified by changing a single variable in the recipe (e.g., `terraform=1.7.0`).
  - Versioned images stored in ECR with immutable tags (e.g., `v1.0.0`, verified in previous test with `docker-image-4codebuild-test-repo`).
- **Example Recipe (Container)**:
  ```yaml
  base_image: amazonlinux:2023
  components:
    falcon_sensor: latest
    cloudwatch_agent: 1.247354.0
    chrony: 4.2
    node_exporter: 1.8.0
    terraform: 1.6.6
  ```

### Customer YAML Configuration
- **Purpose**: Customers provide a YAML file to specify additional components on top of Golden images.
- **Format**:
  ```yaml
  image_type: container
  base_image: golden-container-amazonlinux2023
  components:
    splunk_indexer: 9.3.0
    aws_cli: 2.17.0
    docker: 27.0.3
    python: 3.10
    trivy: 0.53.0
  ```
- **Validation**:
  - A **YAML validator** (e.g., implemented in Python with `PyYAML` or `jsonschema`) checks:
    - Correct syntax and structure.
    - Supported components and versions.
    - Compliance with security requirements (e.g., no deprecated packages).
  - Integrated into a GHA workflow to reject invalid YAML files before image creation.
- **Storage**: YAML files are stored in the GitHub repo (`aws-codebuild-docker-image`) or an S3 bucket for processing.

### Pipeline Workflow
1. **Infrastructure Setup** (Current Setup):
   - Terraform in `terraform/` creates:
     - ECR repository (`docker-image-4codebuild-repo`).
     - CodeBuild project (`docker-image-4codebuild`) as a GHA runner.
     - S3 bucket (`docker-image-4codebuild-tfstate`) and DynamoDB table (`docker-image-4codebuild-tfstate-lock`) for state management.
   - GHA workflow (`deploy-infra.yml`) automates Terraform deployment.

2. **Golden Image Creation**:
   - **AMI**: Use EC2 Image Builder to create Golden AMIs with components (Falcon sensor, CloudWatch agent, etc.).
   - **Container**: Build Golden container images using Dockerfiles, pushed to ECR (`docker-image-4codebuild-repo`).
   - Automated via GHA workflows, triggered daily or on recipe updates.

3. **Custom Image Creation**:
   - Customer submits YAML file via GitHub repo or API.
   - GHA workflow validates YAML, builds customized image on top of Golden image, and pushes to ECR (e.g., with unique tags like `v${{ github.run_id }}` for immutability).
   - Example: Static Code Scanner or CodeBuild container image.

4. **Validation and Security**:
   - YAML validator ensures compliance.
   - Security scanners (Trivy, Grype, Snyk) run during image builds, integrated into GHA workflows (e.g., `build-docker-image.yml`, to be provided).
   - CloudWatch agent (installed manually, per AWS documentation) collects metrics/logs for monitoring.

### Example: Customized Container Image
- **Use Case**: Static Code Scanner for CodeBuild.
- **YAML Configuration**:
  ```yaml
  image_type: container
  base_image: golden-container-ubuntu2204
  components:
    aws_cli: 2.17.0
    terraform: 1.6.6
    tflint: 0.53.0
    snyk: 1.1292.0
    trivy: 0.53.0
    python: 3.10
  ```
- **Process**:
  - GHA workflow validates YAML.
  - Builds image using Dockerfile extending Golden Ubuntu 22.04 image.
  - Runs Snyk and Trivy scans, pushes to ECR (`docker-image-4codebuild-repo:static-scanner-v1.0.0`).
- **Outcome**: Secure, customized image for static code analysis, versioned and immutable.

## Benefits
- **Automation**: Eliminates manual updates, streamlining image creation and upgrades.
- **Security**: Golden images ensure OS-level security; scanners (Trivy, Grype, Snyk) enforce compliance.
- **Configurability**: YAML-based customization supports diverse customer needs.
- **Version Control**: Image recipes simplify upgrades (change one variable, e.g., `terraform=1.7.0`).
- **Scalability**: Supports multiple OSes (Amazon Linux 2023, Ubuntu 22.04, Windows Server 2022, future CentOS).
- **Maintainability**: Centralized state management (S3/DynamoDB) and GHA workflows reduce overhead.

## Implementation Plan
1. **Phase 1: Infrastructure Setup** (Complete):
   - Terraform (`terraform/`) deploys ECR, CodeBuild, S3 backend (`docker-image-4codebuild-tfstate`), DynamoDB (`docker-image-4codebuild-tfstate-lock`).
   - GHA workflow (`deploy-infra.yml`) automates infrastructure.

2. **Phase 2: Golden Image Pipeline**:
   - Develop EC2 Image Builder pipelines for Golden AMIs.
   - Create Dockerfiles for Golden container images, pushed to ECR.
   - Implement GHA workflow for daily builds.

3. **Phase 3: Custom Image Pipeline**:
   - Develop YAML validator (Python, `PyYAML`).
   - Create GHA workflow (`build-docker-image.yml`) for custom images, integrating Trivy/Grype/Snyk.
   - Test with example use cases (e.g., Static Code Scanner, CodeBuild image).

4. **Phase 4: Expansion**:
   - Add CentOS support.
   - Integrate Terraform Cloud/Enterprise (optional).
   - Implement CloudWatch alarms for pipeline monitoring.

## Risks and Mitigations
- **Risk**: YAML validation errors block customer workflows.
  - **Mitigation**: Provide clear YAML schema documentation and error messages.
- **Risk**: Security scanner false positives delay builds.
  - **Mitigation**: Configure scanner thresholds (e.g., fail on HIGH/CRITICAL for Trivy/Grype).
- **Risk**: CloudWatch agent installation complexity.
  - **Mitigation**: Automate installation in Dockerfiles (e.g., `yum install amazon-cloudwatch-agent` for Amazon Linux).
- **Risk**: Immutable ECR tags require unique tags.
  - **Mitigation**: Use dynamic tags (e.g., `v${{ github.run_id }}`), verified in `test_ecr.tf`.

## Context
- **Current Project**: `aws-codebuild-docker-image` (`master`, account ID `643843550246`) uses Terraform for `docker-image-4codebuild-repo` (ECR) and `docker-image-4codebuild` (CodeBuild runner), with S3/DynamoDB backend.
- **Previous Issue**: “Something isn’t working” with CodePipeline (e.g., GitHub Connection ARN, IAM). This proposal replaces CodePipeline with GHA, addressing maintenance issues.
- **Technical**: `Dockerfile` includes OpenSSL to prevent `SSL_ERROR_SYSCALL`, supporting Git operations (Oh My Posh troubleshooting).
- **Financial**: $24,000 401(k) (30% BAC, 60% S&P 500, 10% Russell 2000 G1) and $14,024.20 brokerage suggest CI/CD optimization enhances SRE efficiency at Bank of America.

## Next Steps
- **Implement Golden Image Pipeline**: Develop EC2 Image Builder and Dockerfile-based workflows.
- **Create Second GHA Workflow**: Provide `build-docker-image.yml` for custom image builds, scans, and ECR pushes.
- **Develop YAML Validator**: Build Python-based validator for customer YAML files.
- **Test Pipeline**: Validate Golden and custom images (e.g., Static Code Scanner, CodeBuild).
- **Clarify**:
  - GitHub repo owner (username/organization)?
  - Status of `codebuild-docker-image-4codebuild-...` runner setup?
  - Specific scanner configurations (e.g., Trivy/Grype thresholds)?
  - Details on “something isn’t working” for further debugging?
- **Provide Feedback**: Confirm if this proposal meets needs or requires adjustments (e.g., additional components, OSes).