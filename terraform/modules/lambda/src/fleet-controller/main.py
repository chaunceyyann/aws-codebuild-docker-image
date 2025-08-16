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
        "action": "start" | "stop" | "status" | "init",
        "target_capacity": <number> (optional, for start action)
    }
    """

    fleet_name = os.environ.get("FLEET_NAME")
    target_capacity_on = int(os.environ.get("TARGET_CAPACITY_ON", 2))
    target_capacity_off = int(os.environ.get("TARGET_CAPACITY_OFF", 0))

    if not fleet_name:
        raise ValueError("FLEET_NAME environment variable is required")

    try:
        # Parse the event
        action = event.get("action", "status")
        target_capacity = event.get("target_capacity", target_capacity_on)

        logger.info(f"Processing action: {action} for fleet: {fleet_name}")

        if action == "start":
            return start_fleet(fleet_name, target_capacity)
        elif action == "stop":
            return stop_fleet(fleet_name, target_capacity_off)
        elif action == "status":
            return get_fleet_status(fleet_name)
        elif action == "init":
            return init_fleet(fleet_name, target_capacity_on)
        else:
            return {
                "statusCode": 400,
                "body": json.dumps(
                    {
                        "error": f"Invalid action: {action}. Must be start, stop, status, or init."
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
        response = codebuild.update_fleet_scaling_configuration(
            fleetName=fleet_name, targetCapacity=target_capacity
        )

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
    """Stop the fleet by setting target capacity to 0"""
    try:
        response = codebuild.update_fleet_scaling_configuration(
            fleetName=fleet_name, targetCapacity=target_capacity
        )

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
    """Get the current status of the fleet"""
    try:
        response = codebuild.describe_fleet(fleetName=fleet_name)

        fleet_info = response["fleet"]
        scaling_config = fleet_info.get("scalingConfiguration", {})

        status = {
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

        logger.info(f"Retrieved status for fleet {fleet_name}")

        return {"statusCode": 200, "body": json.dumps(status)}
    except Exception as e:
        logger.error(f"Error getting fleet status: {str(e)}")
        raise


def init_fleet(fleet_name, target_capacity):
    """Initialize the fleet with initial scaling configuration"""
    try:
        response = codebuild.update_fleet_scaling_configuration(
            fleetName=fleet_name, targetCapacity=target_capacity
        )

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
