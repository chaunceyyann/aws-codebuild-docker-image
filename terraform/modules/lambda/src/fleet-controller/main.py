import json
import logging
import os

import boto3

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
codebuild = boto3.client("codebuild")


def lambda_handler(event, context):
    """
    Lambda function to control CodeBuild fleet scaling

    Expected event format:
    {
        "action": "start" | "stop" | "status" | "init" | "switch_to_fleet" | "switch_to_ondemand",
        "target_capacity": <number> (optional, for start action)
        "project_names": ["project1", "project2"] (optional, for switch actions)
    }
    """

    fleet_name = os.environ.get("FLEET_NAME")
    target_capacity_on = int(os.environ.get("TARGET_CAPACITY_ON", 2))
    target_capacity_off = int(os.environ.get("TARGET_CAPACITY_OFF", 1))
    fleet_arn = os.environ.get("FLEET_ARN")

    if not fleet_name:
        raise ValueError("FLEET_NAME environment variable is required")

    try:
        # Parse the event
        action = event.get("action", "status")
        target_capacity = event.get("target_capacity", target_capacity_on)
        project_names = event.get("project_names", [])

        logger.info(f"Processing action: {action} for fleet: {fleet_name}")

        if action == "start":
            return start_fleet(fleet_name, target_capacity)
        elif action == "stop":
            return stop_fleet(fleet_name, target_capacity_off)
        elif action == "status":
            return get_fleet_status(fleet_name)
        elif action == "init":
            return init_fleet(fleet_name, target_capacity_on)
        elif action == "switch_to_fleet":
            return switch_projects_to_fleet(project_names, fleet_arn)
        elif action == "switch_to_ondemand":
            return switch_projects_to_ondemand(project_names)
        else:
            return {
                "statusCode": 400,
                "body": json.dumps(
                    {
                        "error": f"Invalid action: {action}. Must be start, stop, status, init, switch_to_fleet, or switch_to_ondemand."
                    }
                ),
            }

    except Exception as e:
        logger.error(f"Error processing fleet control: {str(e)}")
        return {
            "statusCode": 500,
            "body": json.dumps({"error": f"Internal server error: {str(e)}"}),
        }


def start_fleet(fleet_name, target_capacity):
    """Start the fleet by setting target capacity"""
    try:
        # First get the fleet ARN
        fleet_response = codebuild.batch_get_fleets(names=[fleet_name])
        if not fleet_response.get("fleets"):
            raise ValueError(f"Fleet {fleet_name} not found")

        fleet_arn = fleet_response["fleets"][0]["arn"]

        # Update the fleet with target capacity
        codebuild.update_fleet(arn=fleet_arn, baseCapacity=target_capacity)

        logger.info(
            f"Started fleet {fleet_name} with target capacity: {target_capacity}"
        )

        return {
            "statusCode": 200,
            "body": json.dumps(
                {
                    "message": f"Fleet {fleet_name} started successfully",
                    "target_capacity": target_capacity,
                    "fleet_name": fleet_name,
                }
            ),
        }
    except Exception as e:
        logger.error(f"Error starting fleet: {str(e)}")
        raise


def stop_fleet(fleet_name, target_capacity):
    """Stop the fleet by setting target capacity to minimum"""
    try:
        # First get the fleet ARN
        fleet_response = codebuild.batch_get_fleets(names=[fleet_name])
        if not fleet_response.get("fleets"):
            raise ValueError(f"Fleet {fleet_name} not found")

        fleet_arn = fleet_response["fleets"][0]["arn"]

        # Update the fleet with target capacity
        codebuild.update_fleet(arn=fleet_arn, baseCapacity=target_capacity)

        logger.info(
            f"Stopped fleet {fleet_name} with target capacity: {target_capacity}"
        )

        return {
            "statusCode": 200,
            "body": json.dumps(
                {
                    "message": f"Fleet {fleet_name} stopped successfully",
                    "target_capacity": target_capacity,
                    "fleet_name": fleet_name,
                }
            ),
        }
    except Exception as e:
        logger.error(f"Error stopping fleet: {str(e)}")
        raise


def get_fleet_status(fleet_name):
    """Get the current status of the fleet and all GitHub-connected CodeBuild projects"""
    try:
        # Get fleet status
        fleet_response = codebuild.batch_get_fleets(names=[fleet_name])

        if not fleet_response.get("fleets"):
            raise ValueError(f"Fleet {fleet_name} not found")

        fleet_info = fleet_response["fleets"][0]
        scaling_config = fleet_info.get("scalingConfiguration", {})

        fleet_status = {
            "fleet_name": fleet_name,
            "fleet_arn": fleet_info.get("arn"),
            "base_capacity": fleet_info.get("baseCapacity"),
            "environment_type": fleet_info.get("environmentType"),
            "compute_type": fleet_info.get("computeType"),
            "target_capacity": scaling_config.get("targetCapacity"),
            "max_capacity": scaling_config.get("maxCapacity"),
            "min_capacity": scaling_config.get("minCapacity"),
            "status": fleet_info.get("status"),
        }

        # Get all CodeBuild projects
        projects_response = codebuild.list_projects()
        all_projects = projects_response.get("projects", [])

        # Filter for projects that are likely GitHub runners (start with 'runner-')
        github_projects = []
        for project_name in all_projects:
            if project_name.startswith("runner-"):
                try:
                    # Get detailed project info
                    project_response = codebuild.batch_get_projects(
                        names=[project_name]
                    )
                    if project_response.get("projects"):
                        project = project_response["projects"][0]
                        environment = project.get("environment", {})

                        # Determine if project uses fleet or on-demand
                        uses_fleet = "fleet" in environment
                        compute_type = environment.get("computeType", "UNKNOWN")

                        github_projects.append(
                            {
                                "project_name": project_name,
                                "source_location": project.get("source", {}).get(
                                    "location", "UNKNOWN"
                                ),
                                "uses_fleet": uses_fleet,
                                "compute_type": compute_type,
                                "environment_type": environment.get("type", "UNKNOWN"),
                                "status": (
                                    "ACTIVE"
                                    if project.get("lastModified")
                                    else "INACTIVE"
                                ),
                            }
                        )
                except Exception as e:
                    logger.warning(
                        f"Could not get details for project {project_name}: {str(e)}"
                    )
                    # Add basic info if detailed info fails
                    github_projects.append(
                        {
                            "project_name": project_name,
                            "source_location": "UNKNOWN",
                            "uses_fleet": "UNKNOWN",
                            "compute_type": "UNKNOWN",
                            "environment_type": "UNKNOWN",
                            "status": "UNKNOWN",
                        }
                    )

        # Sort projects by name
        github_projects.sort(key=lambda x: x["project_name"])

        status = {
            "fleet": fleet_status,
            "github_projects": github_projects,
            "summary": {
                "total_github_projects": len(github_projects),
                "projects_using_fleet": len(
                    [p for p in github_projects if p["uses_fleet"] == True]
                ),
                "projects_using_ondemand": len(
                    [p for p in github_projects if p["uses_fleet"] == False]
                ),
                "projects_unknown": len(
                    [p for p in github_projects if p["uses_fleet"] == "UNKNOWN"]
                ),
            },
        }

        logger.info(
            f"Retrieved status for fleet {fleet_name} and {len(github_projects)} GitHub projects"
        )

        return {"statusCode": 200, "body": json.dumps(status, indent=2)}
    except Exception as e:
        logger.error(f"Error getting fleet status: {str(e)}")
        raise


def init_fleet(fleet_name, target_capacity):
    """Initialize the fleet with initial scaling configuration"""
    try:
        # First get the fleet ARN
        fleet_response = codebuild.batch_get_fleets(names=[fleet_name])
        if not fleet_response.get("fleets"):
            raise ValueError(f"Fleet {fleet_name} not found")

        fleet_arn = fleet_response["fleets"][0]["arn"]

        # Update the fleet with target capacity
        codebuild.update_fleet(arn=fleet_arn, baseCapacity=target_capacity)

        logger.info(
            f"Initialized fleet {fleet_name} with target capacity: {target_capacity}"
        )

        return {
            "statusCode": 200,
            "body": json.dumps(
                {
                    "message": f"Fleet {fleet_name} initialized successfully",
                    "target_capacity": target_capacity,
                    "fleet_name": fleet_name,
                }
            ),
        }
    except Exception as e:
        logger.error(f"Error initializing fleet: {str(e)}")
        raise


def switch_projects_to_fleet(project_names, fleet_arn):
    """Switch CodeBuild projects to use the fleet"""
    try:
        if not project_names:
            raise ValueError("project_names is required for switch_to_fleet action")

        if not fleet_arn:
            raise ValueError("FLEET_ARN environment variable is required")

        updated_projects = []
        for project_name in project_names:
            # Get current project configuration
            project_response = codebuild.batch_get_projects(names=[project_name])
            if not project_response.get("projects"):
                logger.warning(f"Project {project_name} not found, skipping")
                continue

            project = project_response["projects"][0]
            environment = project["environment"]

            # Update project to use fleet
            codebuild.update_project(
                name=project_name,
                environment={
                    "type": environment["type"],
                    "computeType": "BUILD_GENERAL1_SMALL",  # Required for fleet
                    "image": environment["image"],
                    "imagePullCredentialsType": environment.get(
                        "imagePullCredentialsType"
                    ),
                    "privilegedMode": environment.get("privilegedMode", False),
                    "fleet": {"fleetArn": fleet_arn},
                },
            )
            updated_projects.append(project_name)
            logger.info(f"Switched project {project_name} to use fleet")

        return {
            "statusCode": 200,
            "body": json.dumps(
                {
                    "message": f"Switched {len(updated_projects)} projects to use fleet",
                    "updated_projects": updated_projects,
                    "fleet_arn": fleet_arn,
                }
            ),
        }
    except Exception as e:
        logger.error(f"Error switching projects to fleet: {str(e)}")
        raise


def switch_projects_to_ondemand(project_names):
    """Switch CodeBuild projects back to on-demand compute"""
    try:
        # If no project names provided, get all GitHub projects
        if not project_names:
            logger.info(
                "No project names provided, switching all GitHub projects to on-demand"
            )
            projects_response = codebuild.list_projects()
            all_projects = projects_response.get("projects", [])

            # Filter for projects that are likely GitHub runners (start with 'runner-')
            project_names = [
                name for name in all_projects if name.startswith("runner-")
            ]

            if not project_names:
                raise ValueError("No GitHub runner projects found to switch")

        updated_projects = []
        for project_name in project_names:
            # Get current project configuration
            project_response = codebuild.batch_get_projects(names=[project_name])
            if not project_response.get("projects"):
                logger.warning(f"Project {project_name} not found, skipping")
                continue

            project = project_response["projects"][0]
            environment = project.get("environment", {})

            # Update project to use on-demand compute
            codebuild.update_project(
                name=project_name,
                environment={
                    "type": environment["type"],
                    "computeType": "BUILD_GENERAL1_MEDIUM",  # Back to original compute type
                    "image": environment["image"],
                    "imagePullCredentialsType": environment.get(
                        "imagePullCredentialsType"
                    ),
                    "privilegedMode": environment.get("privilegedMode", False),
                },
            )
            updated_projects.append(project_name)
            logger.info(f"Switched project {project_name} to on-demand compute")

        return {
            "statusCode": 200,
            "body": json.dumps(
                {
                    "message": f"Switched {len(updated_projects)} projects to on-demand compute",
                    "updated_projects": updated_projects,
                }
            ),
        }
    except Exception as e:
        logger.error(f"Error switching projects to on-demand: {str(e)}")
        raise
