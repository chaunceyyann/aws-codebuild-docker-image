import json
import logging
import os
import subprocess
import tempfile
from datetime import datetime

import boto3
import requests

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
codeartifact = boto3.client("codeartifact")
sts = boto3.client("sts")

# Package definitions with their latest version check URLs
PACKAGES = {
    "trivy": {
        "type": "binary",
        "check_url": (
            "https://api.github.com/repos/aquasecurity/trivy/releases/latest"
        ),
        "download_template": (
            "https://github.com/aquasecurity/trivy/releases/download/"
            "{version}/trivy_{version}_Linux-64bit.tar.gz"
        ),
        "asset_name": "trivy",
    },
    "grype": {
        "type": "binary",
        "check_url": ("https://api.github.com/repos/anchore/grype/releases/latest"),
        "download_template": (
            "https://github.com/anchore/grype/releases/download/"
            "{version}/grype_{version}_linux_amd64.tar.gz"
        ),
        "asset_name": "grype",
    },
    "semgrep": {
        "type": "binary",
        "check_url": (
            "https://api.github.com/repos/returntocorp/semgrep/releases/latest"
        ),
        "download_template": (
            "https://github.com/returntocorp/semgrep/releases/download/"
            "{version}/semgrep-v{version}-ubuntu-16.04.tgz"
        ),
        "asset_name": "semgrep",
    },
    "checkov": {"type": "pip", "package_name": "checkov"},
    "tflint": {
        "type": "binary",
        "check_url": (
            "https://api.github.com/repos/terraform-linters/" "tflint/releases/latest"
        ),
        "download_template": (
            "https://github.com/terraform-linters/tflint/releases/download/"
            "{version}/tflint_linux_amd64.zip"
        ),
        "asset_name": "tflint",
    },
    "bandit": {"type": "pip", "package_name": "bandit"},
    "terraform": {
        "type": "binary",
        "check_url": ("https://checkpoint-api.hashicorp.com/v1/check/terraform"),
        "download_template": (
            "https://releases.hashicorp.com/terraform/{version}/"
            "terraform_{version}_linux_amd64.zip"
        ),
        "asset_name": "terraform",
    },
    "falcon-sensor": {
        "type": "binary",
        "check_url": (
            "https://api.github.com/repos/CrowdStrike/" "falcon-sensor/releases/latest"
        ),
        "download_template": (
            "https://github.com/CrowdStrike/falcon-sensor/releases/download/"
            "{version}/falcon-sensor-{version}.tar.gz"
        ),
        "asset_name": "falcon-sensor",
    },
}


def get_auth_token():
    """Get CodeArtifact authorization token"""
    try:
        response = sts.get_service_bearer_token(
            serviceName="codeartifact", region=os.environ.get("AWS_REGION", "us-east-1")
        )
        return response["token"]
    except Exception as e:
        logger.error(f"Failed to get auth token: {e}")
        raise


def get_repository_endpoint(domain, repository, format_type):
    """Get repository endpoint URL"""
    try:
        response = codeartifact.get_repository_endpoint(
            domain=domain, repository=repository, format=format_type
        )
        return response["repositoryEndpoint"]
    except Exception as e:
        logger.error(f"Failed to get repository endpoint: {e}")
        raise


def get_latest_version(package_info):
    """Get the latest version of a package"""
    try:
        if package_info["type"] == "binary":
            response = requests.get(package_info["check_url"])
            response.raise_for_status()
            data = response.json()

            if "tag_name" in data:
                # GitHub releases
                version = data["tag_name"].lstrip("v")
            elif "current_version" in data:
                # HashiCorp checkpoint API
                version = data["current_version"]
            else:
                logger.warning(f"Could not determine version for {package_info}")
                return None

        elif package_info["type"] == "pip":
            # For pip packages, we'll use PyPI API
            pypi_url = f"https://pypi.org/pypi/{package_info['package_name']}/json"
            response = requests.get(pypi_url)
            response.raise_for_status()
            data = response.json()
            version = data["info"]["version"]

        return version
    except Exception as e:
        logger.error(f"Failed to get latest version for {package_info}: {e}")
        return None


def upload_binary_package(domain, repository, package_name, package_info, version):
    """Upload binary package to CodeArtifact"""
    try:
        # Download the binary
        download_url = package_info["download_template"].format(version=version)
        logger.info(f"Downloading {download_url}")

        response = requests.get(download_url, stream=True)
        response.raise_for_status()

        # Create temporary file
        with tempfile.NamedTemporaryFile(delete=False) as temp_file:
            for chunk in response.iter_content(chunk_size=8192):
                temp_file.write(chunk)
            temp_file_path = temp_file.name

        # Upload to CodeArtifact
        with open(temp_file_path, "rb") as f:
            codeartifact.upload_package_version_asset(
                domain=domain,
                repository=repository,
                format="generic",
                namespace="security-tools",
                package=package_name,
                packageVersion=version,
                assetName=f"{package_name}-{version}.tar.gz",
                asset=f.read(),
            )

        # Clean up
        os.unlink(temp_file_path)
        logger.info(f"Successfully uploaded {package_name} version {version}")

    except Exception as e:
        logger.error(f"Failed to upload {package_name}: {e}")
        if "temp_file_path" in locals():
            os.unlink(temp_file_path)


def upload_pip_package(domain, repository, package_name, package_info, version):
    """Upload pip package to CodeArtifact"""
    try:
        # For pip packages, we'll use pip download and then upload
        with tempfile.TemporaryDirectory() as temp_dir:
            # Download package
            subprocess.run(
                [
                    "pip",
                    "download",
                    "--index-url",
                    "https://pypi.org/simple/",
                    "--dest",
                    temp_dir,
                    f"{package_name}=={version}",
                ],
                check=True,
                capture_output=True,
            )

            # Find the downloaded file
            for file in os.listdir(temp_dir):
                if file.endswith(".whl") or file.endswith(".tar.gz"):
                    file_path = os.path.join(temp_dir, file)
                    with open(file_path, "rb") as f:
                        codeartifact.upload_package_version_asset(
                            domain=domain,
                            repository=repository,
                            format="pypi",
                            namespace="security-tools",
                            package=package_name,
                            packageVersion=version,
                            assetName=file,
                            asset=f.read(),
                        )
                    logger.info(
                        f"Successfully uploaded {package_name} " f"version {version}"
                    )
                    break

    except Exception as e:
        logger.error(f"Failed to upload pip package {package_name}: {e}")


def check_and_update_package(domain, repository, package_name, package_info):
    """Check if package needs updating and update if necessary"""
    try:
        # Get latest version
        latest_version = get_latest_version(package_info)
        if not latest_version:
            return False

        # Check if version already exists in repository
        try:
            codeartifact.describe_package_version(
                domain=domain,
                repository=repository,
                format=package_info["type"],
                namespace="security-tools",
                package=package_name,
                packageVersion=latest_version,
            )
            logger.info(f"{package_name} version {latest_version} already exists")
            return False
        except codeartifact.exceptions.ResourceNotFoundException:
            # Version doesn't exist, upload it
            logger.info(f"Uploading {package_name} version {latest_version}")

            if package_info["type"] == "binary":
                upload_binary_package(
                    domain, repository, package_name, package_info, latest_version
                )
            elif package_info["type"] == "pip":
                upload_pip_package(
                    domain, repository, package_name, package_info, latest_version
                )

            return True

    except Exception as e:
        logger.error(f"Error checking/updating {package_name}: {e}")
        return False


def handler(event, context):
    """Main Lambda handler"""
    try:
        domain = os.environ["DOMAIN_NAME"]
        generic_repo = os.environ["GENERIC_REPOSITORY"]
        pip_repo = os.environ["PIP_REPOSITORY"]

        logger.info(f"Starting package update for domain: {domain}")

        updated_count = 0

        for package_name, package_info in PACKAGES.items():
            try:
                if package_info["type"] == "binary":
                    updated = check_and_update_package(
                        domain, generic_repo, package_name, package_info
                    )
                elif package_info["type"] == "pip":
                    updated = check_and_update_package(
                        domain, pip_repo, package_name, package_info
                    )

                if updated:
                    updated_count += 1

            except Exception as e:
                logger.error(f"Failed to process {package_name}: {e}")
                continue

        logger.info(f"Package update completed. Updated {updated_count} packages.")

        return {
            "statusCode": 200,
            "body": json.dumps(
                {
                    "message": (f"Successfully updated {updated_count} packages"),
                    "timestamp": datetime.now().isoformat(),
                }
            ),
        }

    except Exception as e:
        logger.error(f"Lambda execution failed: {e}")
        return {
            "statusCode": 500,
            "body": json.dumps(
                {"error": str(e), "timestamp": datetime.now().isoformat()}
            ),
        }
