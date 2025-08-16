#!/bin/bash

# CodeBuild Fleet Control Examples
# This script demonstrates various usage scenarios for the fleet control script

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Example 1: Business Hours Setup
business_hours_setup() {
    print_info "Example 1: Business Hours Setup"
    echo "This example shows how to set up fleet for typical business hours"
    echo ""

    print_info "Starting fleet for business hours (capacity: 3)"
    ./scripts/fleet_control.sh start 3

    print_info "Monitoring fleet for 30 seconds..."
    timeout 30s ./scripts/fleet_control.sh monitor || true

    print_warning "Remember to stop the fleet after business hours:"
    echo "  ./scripts/fleet_control.sh stop"
    echo ""
}

# Example 2: Development Team Setup
dev_team_setup() {
    print_info "Example 2: Development Team Setup"
    echo "This example shows how to set up fleet for a development team"
    echo ""

    print_info "Starting fleet for development team (capacity: 5)"
    ./scripts/fleet_control.sh start 5

    print_info "Checking fleet status..."
    ./scripts/fleet_control.sh status

    print_warning "For development teams, consider:"
    echo "  - Higher capacity during sprint planning"
    echo "  - Lower capacity during weekends"
    echo "  - Monitoring utilization to optimize costs"
    echo ""
}

# Example 3: CI/CD Pipeline Setup
cicd_pipeline_setup() {
    print_info "Example 3: CI/CD Pipeline Setup"
    echo "This example shows how to set up fleet for CI/CD pipelines"
    echo ""

    print_info "Starting fleet for CI/CD (capacity: 4)"
    ./scripts/fleet_control.sh start 4

    print_info "Monitoring fleet utilization..."
    timeout 20s ./scripts/fleet_control.sh monitor || true

    print_warning "For CI/CD pipelines, consider:"
    echo "  - 24/7 operation for critical systems"
    echo "  - Auto-scaling based on queue depth"
    echo "  - Scheduled maintenance windows"
    echo ""
}

# Example 4: Cost Optimization
cost_optimization() {
    print_info "Example 4: Cost Optimization"
    echo "This example shows cost optimization strategies"
    echo ""

    print_info "Starting with minimal capacity (1)"
    ./scripts/fleet_control.sh start 1

    print_info "Checking current status..."
    ./scripts/fleet_control.sh status

    print_info "Scaling up based on demand (3)"
    ./scripts/fleet_control.sh start 3

    print_info "Scaling down to save costs (0)"
    ./scripts/fleet_control.sh stop

    print_warning "Cost optimization tips:"
    echo "  - Start with minimal capacity"
    echo "  - Scale up only when needed"
    echo "  - Always stop fleet when not in use"
    echo "  - Monitor utilization regularly"
    echo ""
}

# Example 5: Emergency Stop
emergency_stop() {
    print_info "Example 5: Emergency Stop"
    echo "This example shows how to quickly stop the fleet"
    echo ""

    print_info "Emergency stop - setting capacity to 0"
    ./scripts/fleet_control.sh stop

    print_info "Verifying fleet is stopped..."
    ./scripts/fleet_control.sh status

    print_success "Fleet stopped successfully"
    echo ""
}

# Example 6: Monitoring and Alerts
monitoring_setup() {
    print_info "Example 6: Monitoring and Alerts"
    echo "This example shows monitoring capabilities"
    echo ""

    print_info "Starting fleet for monitoring demo"
    ./scripts/fleet_control.sh start 2

    print_info "Starting real-time monitoring (30 seconds)"
    print_warning "Press Ctrl+C to stop monitoring early"
    timeout 30s ./scripts/fleet_control.sh monitor || true

    print_info "Stopping fleet after monitoring"
    ./scripts/fleet_control.sh stop

    print_warning "Monitoring best practices:"
    echo "  - Set up CloudWatch alarms for high utilization"
    echo "  - Monitor build success rates"
    echo "  - Track cost trends over time"
    echo "  - Set up notifications for scaling events"
    echo ""
}

# Example 7: Weekend Setup
weekend_setup() {
    print_info "Example 7: Weekend Setup"
    echo "This example shows weekend cost optimization"
    echo ""

    print_info "Friday evening - reducing capacity for weekend"
    ./scripts/fleet_control.sh start 1

    print_info "Monday morning - restoring full capacity"
    ./scripts/fleet_control.sh start 3

    print_warning "Weekend optimization tips:"
    echo "  - Reduce capacity on Friday evenings"
    echo "  - Consider stopping completely on weekends"
    echo "  - Restore capacity on Monday mornings"
    echo "  - Use scheduled events for automation"
    echo ""
}

# Main menu
show_menu() {
    echo "CodeBuild Fleet Control Examples"
    echo "================================"
    echo ""
    echo "Choose an example to run:"
    echo "1. Business Hours Setup"
    echo "2. Development Team Setup"
    echo "3. CI/CD Pipeline Setup"
    echo "4. Cost Optimization"
    echo "5. Emergency Stop"
    echo "6. Monitoring and Alerts"
    echo "7. Weekend Setup"
    echo "8. Run All Examples"
    echo "9. Exit"
    echo ""
    read -p "Enter your choice (1-9): " choice
}

# Run all examples
run_all_examples() {
    print_info "Running all examples..."
    echo ""

    business_hours_setup
    dev_team_setup
    cicd_pipeline_setup
    cost_optimization
    emergency_stop
    monitoring_setup
    weekend_setup

    print_success "All examples completed!"
}

# Main function
main() {
    while true; do
        show_menu

        case $choice in
            1)
                business_hours_setup
                ;;
            2)
                dev_team_setup
                ;;
            3)
                cicd_pipeline_setup
                ;;
            4)
                cost_optimization
                ;;
            5)
                emergency_stop
                ;;
            6)
                monitoring_setup
                ;;
            7)
                weekend_setup
                ;;
            8)
                run_all_examples
                ;;
            9)
                print_info "Exiting..."
                exit 0
                ;;
            *)
                print_warning "Invalid choice. Please enter a number between 1-9."
                ;;
        esac

        echo ""
        read -p "Press Enter to continue..."
        clear
    done
}

# Check if fleet control script exists
if [ ! -f "./scripts/fleet_control.sh" ]; then
    print_warning "Fleet control script not found. Please run this from the project root directory."
    exit 1
fi

# Run main function
main
