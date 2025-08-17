# CodeBuild Fleet Control GitHub Action

This GitHub Action provides easy access to AWS CodeBuild fleet control functionality directly from GitHub workflows.

## Usage

### Basic Usage

```yaml
- name: 'Check fleet status'
  uses: ./.github/actions/fleet-control
  with:
    action: 'status'
```

### Start Fleet

```yaml
- name: 'Start fleet with capacity 3'
  uses: ./.github/actions/fleet-control
  with:
    action: 'start'
    target_capacity: '3'
```

### Stop Fleet

```yaml
- name: 'Stop fleet'
  uses: ./.github/actions/fleet-control
  with:
    action: 'stop'
```

### Switch Projects

```yaml
- name: 'Switch specific projects to fleet'
  uses: ./.github/actions/fleet-control
  with:
    action: 'switch_to_fleet'
    project_names: 'runner-project1,runner-project2'
```

### Scheduled Control

```yaml
- name: 'Run scheduled control'
  uses: ./.github/actions/fleet-control
  with:
    action: 'scheduled_control'
    schedule_type: 'business_hours'
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `action` | Fleet control action to perform | Yes | `status` |
| `target_capacity` | Target capacity for start action | No | `2` |
| `project_names` | Comma-separated list of CodeBuild project names | No | `''` |
| `schedule_type` | Schedule type for scheduled_control | No | `business_hours` |
| `aws_region` | AWS region for the fleet | No | `us-east-1` |
| `fleet_name` | Name of the CodeBuild fleet | No | `codebuild-runners-fleet` |
| `lambda_function_name` | Name of the Lambda function | No | `codebuild-runners-fleet-controller` |

## Actions

- `status` - Check fleet and project status
- `start` - Start fleet with specified capacity
- `stop` - Stop fleet (disables scheduler)
- `monitor` - Monitor fleet for 30 seconds
- `init` - Initialize fleet configuration
- `switch_to_fleet` - Switch projects to use fleet
- `switch_to_ondemand` - Switch projects to on-demand
- `scheduled_control` - Run timezone-aware scheduled control
- `enable_scheduler` - Enable EventBridge scheduler
- `disable_scheduler` - Disable EventBridge scheduler

## Schedule Types

- `business_hours` - Monday-Friday, 8 AM - 6 PM Eastern
- `weekend` - Fleet off on weekends
- `custom` - Monday-Friday, 9 AM - 5 PM Eastern
- `smart` - Monday-Friday, 7 AM - 7 PM Eastern

## Environment Variables

The action requires these environment variables to be set:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

## Example Workflows

See the workflow files in `.github/workflows/` for complete examples:

- `fleet-control.yml` - Manual fleet control workflow (automated control handled by EventBridge + Lambda)
