#!/bin/bash

# Direct Fleet Control Script for GitHub Actions
# This script provides direct AWS CLI fleet control without Lambda dependencies

set -e

# Configuration
FLEET_NAME="codebuild-runners-fleet"
AWS_REGION="${AWS_REGION:-us-east-1}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

show_usage() {
    echo "Usage: $0 {start|stop|status|scale} [size]"
    echo ""
    echo "Commands:"
    echo "  start [size]    - Start fleet with specified size (default: 2)"
    echo "  stop            - Stop fleet (set capacity to 0)"
    echo "  status          - Show current fleet and project status"
    echo "  scale <size>    - Scale fleet to specific size"
    echo ""
    echo "Examples:"
    echo "  $0 start        # Start with default capacity (2)"
    echo "  $0 start 5      # Start with capacity of 5"
    echo "  $0 stop         # Stop the fleet"
    echo "  $0 scale 3      # Scale to 3 instances"
    echo "  $0 status       # Show current status"
}

get_fleet_info() {
    aws codebuild batch-get-fleets \
        --names $FLEET_NAME \
        --region $AWS_REGION \
        --query 'fleets[0]' \
        --output json 2>/dev/null || echo "null"
}

get_fleet_arn() {
    get_fleet_info | jq -r '.arn // "null"'
}

get_current_capacity() {
    get_fleet_info | jq -r '.baseCapacity // 0'
}

switch_projects_to_fleet() {
    local fleet_arn=$1
    print_info "Switching CodeBuild projects to use fleet..."

    # Get all runner projects
    local projects=$(aws codebuild list-projects \
        --region $AWS_REGION \
        --query 'projects[?starts_with(@, `runner-`)]' \
        --output text)

    if [ -z "$projects" ]; then
        print_warning "No runner projects found"
        return
    fi

    for project in $projects; do
        print_info "  📝 Updating project: $project"
        aws codebuild update-project \
            --name $project \
            --region $AWS_REGION \
            --environment '{
                "type": "LINUX_CONTAINER",
                "computeType": "BUILD_GENERAL1_SMALL",
                "image": "aws/codebuild/amazonlinux-x86_64-standard:5.0",
                "fleet": {"fleetArn": "'$fleet_arn'"}
            }' > /dev/null
    done

    print_success "Projects switched to use fleet"
}

switch_projects_to_ondemand() {
    print_info "Switching CodeBuild projects to on-demand..."

    # Get all runner projects
    local projects=$(aws codebuild list-projects \
        --region $AWS_REGION \
        --query 'projects[?starts_with(@, `runner-`)]' \
        --output text)

    if [ -z "$projects" ]; then
        print_warning "No runner projects found"
        return
    fi

    for project in $projects; do
        print_info "  📝 Updating project: $project"
        aws codebuild update-project \
            --name $project \
            --region $AWS_REGION \
            --environment '{
                "type": "LINUX_CONTAINER",
                "computeType": "BUILD_GENERAL1_SMALL",
                "image": "aws/codebuild/amazonlinux-x86_64-standard:5.0"
            }' > /dev/null
    done

    print_success "Projects switched to on-demand"
}

start_fleet() {
    local size=${1:-2}
    local fleet_arn=$(get_fleet_arn)

    if [ "$fleet_arn" == "null" ]; then
        print_error "Fleet $FLEET_NAME not found!"
        exit 1
    fi

    local current_capacity=$(get_current_capacity)

    if [ "$current_capacity" -eq "$size" ]; then
        print_info "Fleet already running with capacity: $size"
        return
    fi

    print_info "⚡ Starting fleet with capacity: $size"
    aws codebuild update-fleet \
        --arn $fleet_arn \
        --base-capacity $size \
        --region $AWS_REGION

    # Switch projects to use fleet
    switch_projects_to_fleet $fleet_arn

    print_success "✅ Fleet started with capacity: $size"
}

stop_fleet() {
    local fleet_arn=$(get_fleet_arn)

    if [ "$fleet_arn" == "null" ]; then
        print_error "Fleet $FLEET_NAME not found!"
        exit 1
    fi

    local current_capacity=$(get_current_capacity)

    if [ "$current_capacity" -eq 0 ]; then
        print_info "Fleet already stopped"
        return
    fi

    print_info "🛑 Stopping fleet (setting capacity to 0)"
    aws codebuild update-fleet \
        --arn $fleet_arn \
        --base-capacity 0 \
        --region $AWS_REGION

    # Switch projects to on-demand
    switch_projects_to_ondemand

    print_success "✅ Fleet stopped"
}

show_status() {
    print_info "📊 Fleet Status Report"
    echo "===================="

    local fleet_info=$(get_fleet_info)

    if [ "$fleet_info" == "null" ]; then
        print_error "Fleet $FLEET_NAME not found!"
        exit 1
    fi

    local capacity=$(echo $fleet_info | jq -r '.baseCapacity')
    local status=$(echo $fleet_info | jq -r '.status')
    local compute_type=$(echo $fleet_info | jq -r '.computeType')
    local environment_type=$(echo $fleet_info | jq -r '.environmentType')

    echo "🏭 Fleet Name: $FLEET_NAME"
    echo "📊 Capacity: $capacity instances"
    echo "🟢 Status: $status"
    echo "💻 Compute Type: $compute_type"
    echo "🐧 Environment: $environment_type"

    # Cost estimation
    if [ "$capacity" -gt 0 ]; then
        local hourly_cost=$(echo "$capacity * 0.05" | bc -l 2>/dev/null || echo "~0.05 per instance")
        echo "💰 Estimated hourly cost: \$${hourly_cost}"
    else
        echo "💰 Current cost: \$0.00 (fleet stopped)"
    fi

    echo ""
    echo "🔗 GitHub Runner Projects:"

    # Get all runner projects
    local projects=$(aws codebuild list-projects \
        --region $AWS_REGION \
        --query 'projects[?starts_with(@, `runner-`)]' \
        --output text)

    if [ -z "$projects" ]; then
        print_warning "No runner projects found"
        return
    fi

    for project in $projects; do
        local uses_fleet=$(aws codebuild batch-get-projects \
            --names $project \
            --region $AWS_REGION \
            --query 'projects[0].environment.fleet.fleetArn' \
            --output text 2>/dev/null || echo "None")

        if [ "$uses_fleet" != "None" ] && [ "$uses_fleet" != "" ] && [ "$uses_fleet" != "null" ]; then
            echo "  ✅ $project (using fleet)"
        else
            echo "  ⚪ $project (on-demand)"
        fi
    done
}

scale_fleet() {
    local size=$1

    if [ -z "$size" ] || ! [[ "$size" =~ ^[0-9]+$ ]]; then
        print_error "Scale command requires a numeric size argument"
        show_usage
        exit 1
    fi

    local fleet_arn=$(get_fleet_arn)

    if [ "$fleet_arn" == "null" ]; then
        print_error "Fleet $FLEET_NAME not found!"
        exit 1
    fi

    local current_capacity=$(get_current_capacity)

    if [ "$current_capacity" -eq "$size" ]; then
        print_info "Fleet already at capacity: $size"
        return
    fi

    print_info "📊 Scaling fleet from $current_capacity to $size"
    aws codebuild update-fleet \
        --arn $fleet_arn \
        --base-capacity $size \
        --region $AWS_REGION

    # If scaling up from 0, switch projects to fleet
    if [ "$current_capacity" -eq 0 ] && [ "$size" -gt 0 ]; then
        switch_projects_to_fleet $fleet_arn
    # If scaling down to 0, switch projects to on-demand
    elif [ "$size" -eq 0 ]; then
        switch_projects_to_ondemand
    fi

    print_success "✅ Fleet scaled to capacity: $size"
}

# Main script logic
case $1 in
    "start")
        start_fleet $2
        ;;
    "stop")
        stop_fleet
        ;;
    "status")
        show_status
        ;;
    "scale")
        scale_fleet $2
        ;;
    *)
        show_usage
        exit 1
        ;;
esac
