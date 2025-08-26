#!/bin/bash

# CodeBuild Fleet Control Script
# This script provides manual control over the CodeBuild compute fleet for cost optimization

set -e

# Configuration
FLEET_NAME="codebuild-runners-fleet"
LAMBDA_FUNCTION_NAME="${FLEET_NAME}-controller"
AWS_REGION="${AWS_REGION:-us-east-1}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 {start|stop|status|monitor|init|switch_to_fleet|switch_to_ondemand|scheduled_control|enable_scheduler|disable_scheduler} [target_capacity]"
    echo ""
    echo "Commands:"
    echo "  start [capacity]     - Start the fleet with optional target capacity (default: 2)"
    echo "  stop                 - Stop the fleet (set capacity to minimum and disable scheduler)"
    echo "  status               - Show current fleet status"
    echo "  monitor              - Monitor fleet metrics in real-time"
    echo "  init                 - Initialize fleet scaling configuration"
    echo "  switch_to_fleet      - Switch CodeBuild projects to use fleet"
    echo "  switch_to_ondemand   - Switch CodeBuild projects back to on-demand (all if no PROJECT_NAMES)"
    echo "  scheduled_control    - Run scheduled fleet control based on time (business_hours/weekend/custom/smart)"
    echo "  enable_scheduler     - Enable EventBridge scheduler"
    echo "  disable_scheduler    - Disable EventBridge scheduler"
    echo ""
    echo "Examples:"
    echo "  $0 start             # Start with default capacity (2) and enable scheduler"
    echo "  $0 start 5           # Start with capacity of 5 and enable scheduler"
    echo "  $0 stop              # Stop the fleet and disable scheduler"
    echo "  $0 status            # Show current status"
    echo "  $0 monitor           # Monitor fleet metrics"
    echo "  $0 switch_to_fleet   # Switch projects to use fleet"
    echo "  $0 switch_to_ondemand # Switch ALL projects to on-demand"
    echo "  PROJECT_NAMES='runner-BJST,runner-aws-global-infra' $0 switch_to_ondemand # Switch specific projects"
    echo "  $0 enable_scheduler  # Enable EventBridge scheduler"
    echo "  $0 disable_scheduler # Disable EventBridge scheduler"
    echo ""
    echo "Environment variables:"
    echo "  PROJECT_NAMES        - Comma-separated list of CodeBuild project names for switch commands (optional for switch_to_ondemand)"
    echo "  SCHEDULE_TYPE        - Schedule type for scheduled_control (business_hours/weekend/custom/smart, default: business_hours)"
}

# Function to check if AWS CLI is available
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed or not in PATH"
        exit 1
    fi
}

# Function to check if Lambda function exists
check_lambda_function() {
    if ! aws lambda get-function --function-name "$LAMBDA_FUNCTION_NAME" --region "$AWS_REGION" &> /dev/null; then
        print_error "Lambda function $LAMBDA_FUNCTION_NAME not found in region $AWS_REGION"
        print_error "Make sure the compute fleet infrastructure is deployed"
        exit 1
    fi
}

# Function to start the fleet
start_fleet() {
    local target_capacity=${1:-2}

    print_status "Starting fleet with target capacity: $target_capacity"

    aws lambda invoke \
        --function-name "$LAMBDA_FUNCTION_NAME" \
        --region "$AWS_REGION" \
        --payload "{\"action\": \"start\", \"target_capacity\": $target_capacity}" \
        --cli-binary-format raw-in-base64-out \
        /tmp/fleet_response.json

    if [ $? -eq 0 ]; then
        print_success "Fleet start command sent successfully"
        echo "Response:"
        cat /tmp/fleet_response.json | jq -r '.body' | jq .
        # Preserve response file for GitHub Actions workflow summary
        if [ "$GITHUB_ACTIONS" = "true" ]; then
            echo "Response file preserved for workflow summary"
        else
            rm -f /tmp/fleet_response.json
        fi
    else
        print_error "Failed to start fleet"
        exit 1
    fi
}

# Function to stop the fleet
stop_fleet() {
    print_status "Stopping fleet"

    aws lambda invoke \
        --function-name "$LAMBDA_FUNCTION_NAME" \
        --region "$AWS_REGION" \
        --payload '{"action": "stop"}' \
        --cli-binary-format raw-in-base64-out \
        /tmp/fleet_response.json

    if [ $? -eq 0 ]; then
        print_success "Fleet stop command sent successfully"
        echo "Response:"
        cat /tmp/fleet_response.json | jq -r '.body' | jq .
        # Preserve response file for GitHub Actions workflow summary
        if [ "$GITHUB_ACTIONS" = "true" ]; then
            echo "Response file preserved for workflow summary"
        else
            rm -f /tmp/fleet_response.json
        fi
    else
        print_error "Failed to stop fleet"
        exit 1
    fi
}

# Function to get fleet status
get_fleet_status() {
    print_status "Getting fleet status"

    aws lambda invoke \
        --function-name "$LAMBDA_FUNCTION_NAME" \
        --region "$AWS_REGION" \
        --payload '{"action": "status"}' \
        --cli-binary-format raw-in-base64-out \
        /tmp/fleet_response.json

    if [ $? -eq 0 ]; then
        print_success "Fleet status retrieved successfully"
        echo "Status:"
        cat /tmp/fleet_response.json | jq -r '.body' | jq .
        # Preserve response file for GitHub Actions workflow summary
        if [ "$GITHUB_ACTIONS" = "true" ]; then
            echo "Response file preserved for workflow summary"
        else
            rm -f /tmp/fleet_response.json
        fi
    else
        print_error "Failed to get fleet status"
        exit 1
    fi
}

# Function to initialize fleet
init_fleet() {
    print_status "Initializing fleet scaling configuration"

    aws lambda invoke \
        --function-name "$LAMBDA_FUNCTION_NAME" \
        --region "$AWS_REGION" \
        --payload '{"action": "init"}' \
        --cli-binary-format raw-in-base64-out \
        /tmp/fleet_response.json

    if [ $? -eq 0 ]; then
        print_success "Fleet initialization completed successfully"
        echo "Response:"
        cat /tmp/fleet_response.json | jq -r '.body' | jq .
        # Preserve response file for GitHub Actions workflow summary
        if [ "$GITHUB_ACTIONS" = "true" ]; then
            echo "Response file preserved for workflow summary"
        else
            rm -f /tmp/fleet_response.json
        fi
    else
        print_error "Failed to initialize fleet"
        exit 1
    fi
}

# Function to monitor fleet metrics
monitor_fleet() {
    print_status "Starting fleet monitoring (Press Ctrl+C to stop)"
    echo ""

    # Check if jq is available for JSON parsing
    if ! command -v jq &> /dev/null; then
        print_warning "jq is not installed. Installing basic monitoring without JSON parsing..."
        monitor_basic
        return
    fi

    # Monitor fleet metrics using CloudWatch
    while true; do
        clear
        echo "=== CodeBuild Fleet Monitoring ==="
        echo "Time: $(date)"
        echo "Region: $AWS_REGION"
        echo "Fleet: $FLEET_NAME"
        echo ""

        # Get fleet capacity
        capacity=$(aws cloudwatch get-metric-statistics \
            --namespace AWS/CodeBuild \
            --metric-name FleetCapacity \
            --dimensions Name=FleetName,Value="$FLEET_NAME" \
            --start-time "$(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%S)" \
            --end-time "$(date -u +%Y-%m-%dT%H:%M:%S)" \
            --period 300 \
            --statistics Average \
            --region "$AWS_REGION" \
            --query 'Datapoints[0].Average' \
            --output text 2>/dev/null || echo "N/A")

        # Get fleet utilization
        utilization=$(aws cloudwatch get-metric-statistics \
            --namespace AWS/CodeBuild \
            --metric-name FleetUtilization \
            --dimensions Name=FleetName,Value="$FLEET_NAME" \
            --start-time "$(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%S)" \
            --end-time "$(date -u +%Y-%m-%dT%H:%M:%S)" \
            --period 300 \
            --statistics Average \
            --region "$AWS_REGION" \
            --query 'Datapoints[0].Average' \
            --output text 2>/dev/null || echo "N/A")

        echo "Current Capacity: $capacity"
        echo "Current Utilization: $utilization%"
        echo ""

        # Show recent build status
        echo "Recent Builds:"
        aws codebuild list-builds-for-project \
            --project-name "runner-$(aws codebuild list-projects --region "$AWS_REGION" --query 'projects[?contains(name, `runner-`)][0]' --output text 2>/dev/null | sed 's/runner-//')" \
            --region "$AWS_REGION" \
            --max-items 5 \
            --query 'ids' \
            --output text 2>/dev/null | while read build_id; do
            if [ ! -z "$build_id" ]; then
                status=$(aws codebuild batch-get-builds --ids "$build_id" --region "$AWS_REGION" --query 'builds[0].buildStatus' --output text 2>/dev/null || echo "UNKNOWN")
                echo "  $build_id: $status"
            fi
        done

        sleep 10
    done
}

# Function for basic monitoring without jq
monitor_basic() {
    while true; do
        clear
        echo "=== CodeBuild Fleet Monitoring (Basic) ==="
        echo "Time: $(date)"
        echo "Region: $AWS_REGION"
        echo "Fleet: $FLEET_NAME"
        echo ""

        # Get fleet status
        get_fleet_status

        echo ""
        echo "Refreshing in 30 seconds... (Press Ctrl+C to stop)"
        sleep 30
    done
}

# Function to switch projects to fleet
switch_to_fleet() {
    print_status "Switching CodeBuild projects to use fleet"

    if [ -z "$PROJECT_NAMES" ]; then
        print_error "PROJECT_NAMES environment variable is required"
        print_error "Example: PROJECT_NAMES='runner-BJST,runner-aws-global-infra' $0 switch_to_fleet"
        exit 1
    fi

    # Convert comma-separated list to JSON array
    project_names_json=$(echo "$PROJECT_NAMES" | tr ',' '\n' | jq -R . | jq -s .)

    aws lambda invoke \
        --function-name "$LAMBDA_FUNCTION_NAME" \
        --region "$AWS_REGION" \
        --payload "{\"action\": \"switch_to_fleet\", \"project_names\": $project_names_json}" \
        --cli-binary-format raw-in-base64-out \
        /tmp/fleet_response.json

    if [ $? -eq 0 ]; then
        print_success "Projects switched to fleet successfully"
        echo "Response:"
        cat /tmp/fleet_response.json | jq -r '.body' | jq .
        # Preserve response file for GitHub Actions workflow summary
        if [ "$GITHUB_ACTIONS" = "true" ]; then
            echo "Response file preserved for workflow summary"
        else
            rm -f /tmp/fleet_response.json
        fi
    else
        print_error "Failed to switch projects to fleet"
        exit 1
    fi
}

# Function to switch projects to on-demand
switch_to_ondemand() {
    print_status "Switching CodeBuild projects to on-demand compute"

    if [ -z "$PROJECT_NAMES" ]; then
        print_warning "PROJECT_NAMES not provided, switching ALL GitHub projects to on-demand"
        aws lambda invoke \
            --function-name "$LAMBDA_FUNCTION_NAME" \
            --region "$AWS_REGION" \
            --payload '{"action": "switch_to_ondemand"}' \
            --cli-binary-format raw-in-base64-out \
            /tmp/fleet_response.json
    else
        print_status "Switching specified projects to on-demand compute"
        # Convert comma-separated list to JSON array
        project_names_json=$(echo "$PROJECT_NAMES" | tr ',' '\n' | jq -R . | jq -s .)

        aws lambda invoke \
            --function-name "$LAMBDA_FUNCTION_NAME" \
            --region "$AWS_REGION" \
            --payload "{\"action\": \"switch_to_ondemand\", \"project_names\": $project_names_json}" \
            --cli-binary-format raw-in-base64-out \
            /tmp/fleet_response.json
    fi

    if [ $? -eq 0 ]; then
        print_success "Projects switched to on-demand compute successfully"
        echo "Response:"
        cat /tmp/fleet_response.json | jq -r '.body' | jq .
        # Preserve response file for GitHub Actions workflow summary
        if [ "$GITHUB_ACTIONS" = "true" ]; then
            echo "Response file preserved for workflow summary"
        else
            rm -f /tmp/fleet_response.json
        fi
    else
        print_error "Failed to switch projects to on-demand compute"
        exit 1
    fi
}

# Function to run scheduled control
scheduled_control() {
    print_status "Running scheduled fleet control"

    # Default to business hours if no schedule type specified
    SCHEDULE_TYPE=${SCHEDULE_TYPE:-"business_hours"}

    print_status "Using schedule type: $SCHEDULE_TYPE"

    aws lambda invoke \
        --function-name "$LAMBDA_FUNCTION_NAME" \
        --region "$AWS_REGION" \
        --payload "{\"action\": \"scheduled_control\", \"schedule_type\": \"$SCHEDULE_TYPE\"}" \
        --cli-binary-format raw-in-base64-out \
        /tmp/fleet_response.json

    if [ $? -eq 0 ]; then
        print_success "Scheduled control completed successfully"
        echo "Response:"
        cat /tmp/fleet_response.json | jq -r '.body' | jq .
        # Preserve response file for GitHub Actions workflow summary
        if [ "$GITHUB_ACTIONS" = "true" ]; then
            echo "Response file preserved for workflow summary"
        else
            rm -f /tmp/fleet_response.json
        fi
    else
        print_error "Failed to run scheduled control"
        exit 1
    fi
}

# Function to enable scheduler
enable_scheduler() {
    print_status "Enabling EventBridge scheduler"

    aws lambda invoke \
        --function-name "$LAMBDA_FUNCTION_NAME" \
        --region "$AWS_REGION" \
        --payload "{\"action\": \"enable_scheduler\"}" \
        --cli-binary-format raw-in-base64-out \
        /tmp/fleet_response.json

    if [ $? -eq 0 ]; then
        print_success "Scheduler enabled successfully"
        echo "Response:"
        cat /tmp/fleet_response.json | jq -r '.body' | jq .
        # Preserve response file for GitHub Actions workflow summary
        if [ "$GITHUB_ACTIONS" = "true" ]; then
            echo "Response file preserved for workflow summary"
        else
            rm -f /tmp/fleet_response.json
        fi
    else
        print_error "Failed to enable scheduler"
        exit 1
    fi
}

# Function to disable scheduler
disable_scheduler() {
    print_status "Disabling EventBridge scheduler"

    aws lambda invoke \
        --function-name "$LAMBDA_FUNCTION_NAME" \
        --region "$AWS_REGION" \
        --payload "{\"action\": \"disable_scheduler\"}" \
        --cli-binary-format raw-in-base64-out \
        /tmp/fleet_response.json

    if [ $? -eq 0 ]; then
        print_success "Scheduler disabled successfully"
        echo "Response:"
        cat /tmp/fleet_response.json | jq -r '.body' | jq .
        # Preserve response file for GitHub Actions workflow summary
        if [ "$GITHUB_ACTIONS" = "true" ]; then
            echo "Response file preserved for workflow summary"
        else
            rm -f /tmp/fleet_response.json
        fi
    else
        print_error "Failed to disable scheduler"
        exit 1
    fi
}

# Main script logic
main() {
    # Check prerequisites
    check_aws_cli
    check_lambda_function

    case "$1" in
        start)
            start_fleet "$2"
            ;;
        stop)
            stop_fleet
            ;;
        status)
            get_fleet_status
            ;;
        monitor)
            monitor_fleet
            ;;
        init)
            init_fleet
            ;;
        switch_to_fleet)
            switch_to_fleet
            ;;
        switch_to_ondemand)
            switch_to_ondemand
            ;;
        scheduled_control)
            scheduled_control
            ;;
        enable_scheduler)
            enable_scheduler
            ;;
        disable_scheduler)
            disable_scheduler
            ;;
        *)
            show_usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
