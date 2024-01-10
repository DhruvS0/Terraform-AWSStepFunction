# Terraform-AWSStepFunction: Automating Data Backups from DynamoDB to S3

## Overview

This repository demonstrates how to automate daily backups of DynamoDB data to S3 using a serverless architecture involving EventBridge, Step Functions, and Lambda.

## Architecture

![Blank board](https://github.com/DhruvS0/Terraform-AWSStepFunction/assets/113872537/83f0cf6b-f7cf-4442-b78e-5bd8011e2f4b)

## Key Components

- DynamoDB: Source database for backup data.
- S3: Destination for storing backup files.
- Lambda: Function responsible for fetching data from DynamoDB and storing it in S3 as JSON.
- EventBridge: Schedules daily events at 12:00 PM to trigger the Step Function.
- Step Functions: Orchestrates the backup workflow by invoking the Lambda function.
- Terraform: Infrastructure as Code (IaC) tool for managing deployment and configuration.
## Prerequisites

- An AWS account with programmatic access
- AWS CLI installed and configured
- Required IAM roles and policies (details provided in the setup guide)
## Setup Guide

1. Clone this repository:
```
git clone https://github.com/<your-username>/Terraform-AWSStepFunction.git
```
2. Install Terraform:
Follow the official Terraform installation instructions for your operating system:
```
https://learn.hashicorp.com/tutorials/terraform/install-cli
```
3. Configure AWS credentials:
Set up your AWS credentials using the AWS CLI:
```
https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html
```
4. Create IAM roles and policies:
Detailed instructions are provided in the docs/iam-setup.md file.
## Deployment

1. Initialize Terraform:
```sh
cd Terraform-AWSStepFunction
terraform init
```
2. Plan the infrastructure changes:
```sh
terraform plan
```
3. Apply the changes:
```sh
terraform apply
```
## Troubleshooting

### Common errors and solutions:

1. Permissions issues:

**Error message:** "AccessDeniedException: User: arn:aws:iam::... is not authorized to perform: states:StartExecution on resource: ..."

**Solution:** Ensure that the IAM role or user executing the Step Function has the necessary permissions to start executions, invoke Lambda functions, and access DynamoDB and S3 resources.

2. Lambda function errors:

**Error message:** "Execution failed due to a Lambda function failure: ..."

**Solution:** Check the Lambda function logs for specific error messages and troubleshoot accordingly.
Common causes include:Incorrect code logic, Missing dependencies, Timeouts due to insufficient resources

3. EventBridge rule misconfiguration:

**Error message:** "EventBridge rule did not trigger the Step Function as expected."

**Solution:** Verify that the EventBridge rule is configured correctly with the right target, schedule, and pattern matching.

4. Terraform configuration errors:

**Error message:** "Error: Error applying plan: ..."

**Solution:** Carefully review the Terraform plan output for errors, and double-check the configuration for any typos or inconsistencies.

### Logging and monitoring:

1. Accessing logs:

- Lambda function logs: View logs in the AWS Management Console, CloudWatch Logs, or use the AWS CLI.
- Step Function logs: View execution history and logs in the Step Functions console or use the AWS CLI.
- EventBridge logs: View logs in CloudTrail.
2. Monitoring the workflow:

- Step Functions console: Visually monitor the state machine's execution progress and identify any failed states.
- CloudWatch metrics: Set up alarms for key metrics like execution duration, error rates, and resource usage.
- X-Ray tracing: Enable X-Ray for detailed tracing of the workflow, identifying bottlenecks and performance issues.
## Further Enhancements

- Customizable backup schedule: Allow users to specify backup times and frequencies.
- Error handling and retries: Implement robust error handling and retry mechanisms.
- Data validation and compression: Validate backup data integrity and optionally compress files for storage optimization.
## Contributing

We welcome contributions! Please follow our guidelines: (link to contributing guidelines)
