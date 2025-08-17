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
        "action": "start" | "stop" | "status" | "init" | "switch_to_fleet" | "switch_to_ondemand" | "scheduled_control",
        "target_capacity": <number> (optional, for start action)
        "project_names": ["project1", "project2"] (optional, for switch actions)
        "schedule_type": "business_hours" | "weekend" | "custom" (for scheduled_control)
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
        elif action == "scheduled_control":
            schedule_type = event.get("schedule_type", "business_hours")
            return handle_scheduled_control(schedule_type)
        elif action == "enable_scheduler":
            return enable_scheduler(fleet_name)
        elif action == "disable_scheduler":
            return disable_scheduler(fleet_name)
        else:
            return {
                "statusCode": 400,
                "body": json.dumps(
                    {
                        "error": f"Invalid action: {action}. Must be start, stop, status, init, switch_to_fleet, switch_to_ondemand, scheduled_control, enable_scheduler, or disable_scheduler."
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
    """Start the fleet by setting target capacity, switching projects to use fleet, and enabling scheduler"""
    try:
        # First get the fleet ARN
        fleet_response = codebuild.batch_get_fleets(names=[fleet_name])
        if not fleet_response.get("fleets"):
            raise ValueError(f"Fleet {fleet_name} not found")

        fleet_arn = fleet_response["fleets"][0]["arn"]

        # Update the fleet with target capacity
        codebuild.update_fleet(arn=fleet_arn, baseCapacity=target_capacity)

        # Switch all projects to use fleet for optimal performance
        logger.info("Switching all projects to use fleet for optimal performance")
        switch_result = switch_projects_to_fleet(
            [], fleet_arn
        )  # Empty list = switch all projects

        # Enable the EventBridge scheduler
        events_client = boto3.client("events")
        rule_name = f"{fleet_name}-schedule"

        try:
            events_client.enable_rule(Name=rule_name)
            logger.info(f"Enabled EventBridge scheduler rule: {rule_name}")
            scheduler_enabled = True
        except Exception as e:
            logger.warning(f"Could not enable EventBridge scheduler: {str(e)}")
            scheduler_enabled = False

        logger.info(
            f"Started fleet {fleet_name} with target capacity: {target_capacity} and switched projects to use fleet"
        )

        return {
            "statusCode": 200,
            "body": json.dumps(
                {
                    "message": f"Fleet {fleet_name} started successfully and projects switched to use fleet",
                    "target_capacity": target_capacity,
                    "fleet_name": fleet_name,
                    "projects_switched": json.loads(switch_result["body"])[
                        "updated_projects"
                    ],
                    "scheduler_enabled": scheduler_enabled,
                }
            ),
        }
    except Exception as e:
        logger.error(f"Error starting fleet: {str(e)}")
        raise


def stop_fleet(fleet_name, target_capacity):
    """Stop the fleet by setting target capacity to minimum, switching projects to on-demand, and optionally disabling scheduler"""
    try:
        # First get the fleet ARN
        fleet_response = codebuild.batch_get_fleets(names=[fleet_name])
        if not fleet_response.get("fleets"):
            raise ValueError(f"Fleet {fleet_name} not found")

        fleet_arn = fleet_response["fleets"][0]["arn"]

        # Update the fleet with minimum capacity
        codebuild.update_fleet(arn=fleet_arn, baseCapacity=target_capacity)

        # Switch all projects to on-demand to truly "turn off" fleet usage
        logger.info("Switching all projects to on-demand to minimize fleet costs")
        switch_result = switch_projects_to_ondemand(
            []
        )  # Empty list = switch all projects

        # Optionally disable the EventBridge scheduler
        events_client = boto3.client("events")
        rule_name = f"{fleet_name}-schedule"

        try:
            events_client.disable_rule(Name=rule_name)
            logger.info(f"Disabled EventBridge scheduler rule: {rule_name}")
            scheduler_disabled = True
        except Exception as e:
            logger.warning(f"Could not disable EventBridge scheduler: {str(e)}")
            scheduler_disabled = False

        logger.info(
            f"Stopped fleet {fleet_name} with target capacity: {target_capacity} and switched projects to on-demand"
        )

        return {
            "statusCode": 200,
            "body": json.dumps(
                {
                    "message": f"Fleet {fleet_name} stopped successfully and projects switched to on-demand",
                    "target_capacity": target_capacity,
                    "fleet_name": fleet_name,
                    "projects_switched": json.loads(switch_result["body"])[
                        "updated_projects"
                    ],
                    "scheduler_disabled": scheduler_disabled,
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
        if not fleet_arn:
            raise ValueError("FLEET_ARN environment variable is required")

        # If no project names provided, get all GitHub projects
        if not project_names:
            logger.info(
                "No project names provided, switching all GitHub projects to use fleet"
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
            environment = project["environment"]

            # Update project to use fleet
            codebuild.update_project(
                name=project_name,
                environment={
                    "type": environment["type"],
                    "computeType": "BUILD_GENERAL1_SMALL",  # Small compute for fleet
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
                    "computeType": "BUILD_GENERAL1_SMALL",  # Small compute for on-demand
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


def enable_scheduler(fleet_name):
    """Enable the EventBridge scheduler for the fleet"""
    try:
        events_client = boto3.client("events")
        rule_name = f"{fleet_name}-schedule"

        events_client.enable_rule(Name=rule_name)
        logger.info(f"Enabled EventBridge scheduler rule: {rule_name}")

        return {
            "statusCode": 200,
            "body": json.dumps(
                {
                    "message": f"Scheduler enabled for fleet {fleet_name}",
                    "fleet_name": fleet_name,
                    "rule_name": rule_name,
                    "status": "ENABLED",
                }
            ),
        }
    except Exception as e:
        logger.error(f"Error enabling scheduler: {str(e)}")
        raise


def disable_scheduler(fleet_name):
    """Disable the EventBridge scheduler for the fleet"""
    try:
        events_client = boto3.client("events")
        rule_name = f"{fleet_name}-schedule"

        events_client.disable_rule(Name=rule_name)
        logger.info(f"Disabled EventBridge scheduler rule: {rule_name}")

        return {
            "statusCode": 200,
            "body": json.dumps(
                {
                    "message": f"Scheduler disabled for fleet {fleet_name}",
                    "fleet_name": fleet_name,
                    "rule_name": rule_name,
                    "status": "DISABLED",
                }
            ),
        }
    except Exception as e:
        logger.error(f"Error disabling scheduler: {str(e)}")
        raise


def handle_scheduled_control(schedule_type):
    """Handle scheduled fleet control based on time and schedule type"""
    try:
        import datetime

        # Use datetime.timezone for timezone handling (available in Python 3.9+ Lambda runtime)
        # pytz is not needed as we can use datetime.timezone
        # Get environment variables
        fleet_name = os.environ.get("FLEET_NAME")
        target_capacity_on = int(os.environ.get("TARGET_CAPACITY_ON", 2))
        target_capacity_off = int(os.environ.get("TARGET_CAPACITY_OFF", 1))

        if not fleet_name:
            raise ValueError("FLEET_NAME environment variable is required")

        # Get current time in UTC and convert to US Eastern Time (handles DST automatically)
        utc_now = datetime.datetime.utcnow()

        # Use a simple offset approach for Eastern Time (EST/EDT)
        # EST = UTC-5, EDT = UTC-4 (DST)
        # This is a simplified approach - for production, consider using a more robust timezone library
        eastern_offset = -5  # Default to EST (UTC-5)

        # Simple DST detection: March 2nd Sunday to November 1st Sunday
        # This is a simplified approach - for production, use a proper timezone library
        current_month = utc_now.month
        current_day = utc_now.day
        current_weekday = utc_now.weekday()  # Monday = 0, Sunday = 6

        # DST starts: Second Sunday in March (March 8-14)
        # DST ends: First Sunday in November (November 1-7)
        is_dst = (
            (current_month > 3 and current_month < 11)  # April-October
            or (
                current_month == 3 and current_day >= 8 + (6 - current_weekday) % 7
            )  # March 2nd Sunday onwards
            or (
                current_month == 11 and current_day < 1 + (6 - current_weekday) % 7
            )  # November before 1st Sunday
        )

        if is_dst:
            eastern_offset = -4  # EDT (UTC-4)

        eastern_now = utc_now + datetime.timedelta(hours=eastern_offset)
        current_hour = eastern_now.hour
        current_weekday = eastern_now.weekday()  # Monday = 0, Sunday = 6

        logger.info(f"Scheduled control triggered: {schedule_type}")
        logger.info(f"UTC time: {utc_now}")
        logger.info(f"Eastern time: {eastern_now} (DST: {is_dst})")
        logger.info(f"Hour: {current_hour}, Weekday: {current_weekday}")

        if schedule_type == "business_hours":
            # Business hours: Monday-Friday, 8 AM - 6 PM Eastern Time
            is_business_hours = (
                current_weekday < 5  # Monday-Friday
                and 8 <= current_hour < 18  # 8 AM - 6 PM Eastern
            )

            if is_business_hours:
                logger.info("Business hours detected - starting fleet")
                return start_fleet(fleet_name, target_capacity_on)
            else:
                logger.info("Outside business hours - stopping fleet")
                return stop_fleet(fleet_name, target_capacity_off)

        elif schedule_type == "weekend":
            # Weekend mode: Fleet off on weekends
            is_weekend = current_weekday >= 5  # Saturday = 5, Sunday = 6

            if is_weekend:
                logger.info("Weekend detected - stopping fleet")
                return stop_fleet(fleet_name, target_capacity_off)
            else:
                logger.info("Weekday detected - starting fleet")
                return start_fleet(fleet_name, target_capacity_on)

        elif schedule_type == "custom":
            # Custom schedule: Fleet on during work hours (9 AM - 5 PM Eastern)
            is_work_hours = (
                current_weekday < 5  # Monday-Friday
                and 9 <= current_hour < 17  # 9 AM - 5 PM Eastern
            )

            if is_work_hours:
                logger.info("Work hours detected - starting fleet")
                return start_fleet(fleet_name, target_capacity_on)
            else:
                logger.info("Outside work hours - stopping fleet")
                return stop_fleet(fleet_name, target_capacity_off)

        elif schedule_type == "smart":
            # Smart scheduling: Adaptive based on typical work patterns
            # Weekdays: 7 AM - 7 PM Eastern (extended hours for remote work)
            # Weekends: Fleet off
            is_work_time = (
                current_weekday < 5  # Monday-Friday
                and 7 <= current_hour < 19  # 7 AM - 7 PM Eastern
            )

            if is_work_time:
                logger.info("Smart work time detected - starting fleet")
                return start_fleet(fleet_name, target_capacity_on)
            else:
                logger.info("Outside smart work time - stopping fleet")
                return stop_fleet(fleet_name, target_capacity_off)

        else:
            raise ValueError(f"Unknown schedule type: {schedule_type}")

    except Exception as e:
        logger.error(f"Error in scheduled control: {str(e)}")
        raise
