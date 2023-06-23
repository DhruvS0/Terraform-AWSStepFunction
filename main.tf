 # the below block specifies the provider and version of it for the configuration

 terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
  required_version = ">= 1.2.0"

}

# specifies the aws region we'll be deploying the app

provider "aws" {
  region = "us-east-1"
}

# to avoid overriding the existing backups in s3, we add random UUID's to name in the S3 bucket

resource "random_uuid" "random" {
}

# generates a random UUID that is used as part of the S3 bucket name

resource "aws_s3_bucket" "backup_bucket" {
  bucket = "backup-bucket-${random_uuid.random.id}"
}

# secure the s3 bucket, by blocking public access to it

resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket = aws_s3_bucket.backup_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# create an IAM policy document that allows access to the bucket

data "aws_iam_policy_document" "allow_access" {
  statement {
    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = [
      "s3:*",
    ]

    resources = [
      "${aws_s3_bucket.backup_bucket.arn}",
      "${aws_s3_bucket.backup_bucket.arn}/*",
    ]
  }
}

# policy document allows access to the S3 bucket created earlier by specifying the bucket ARN in the resources parameter and allowing all S3 actions in the actions parameter

resource "aws_s3_bucket_policy" "allow_access" {
  bucket = aws_s3_bucket.backup_bucket.id
  policy = data.aws_iam_policy_document.allow_access.json
}

/* creates an AWS Lambda function
function_name specifies the name of the Lambda function
role specifies the ARN of the IAM role that the Lambda function assumes when it executes
handler specifies the handler function that AWS Lambda calls to start execution
runtime specifies the runtime environment for the Lambda function
filename specifies the path to the deployment package within the local filesystem
timeout specifies the amount of time that AWS Lambda allows a function to run before stopping it
memory_size specifies the amount of memory that is allocated to the Lambda function
In this case, the role argument references the ARN of an IAM role resource named my_lambda_role. */

resource "aws_lambda_function" "backup_lambda_function" {
  function_name = "backup_lambda_function"
  role = aws_iam_role.my_lambda_role.arn
  handler = "backup.handler"
  runtime = "python3.8"
  filename = "backup.zip"
  timeout = 300
  memory_size = 128
# The function gets a dynamodb table name through a payload, scans the table for items and saves the items in a s3 bucket
}

/* create iam roles to access for a couple of resources.
Invoke a lambda function
Invoke a step functions state machine
Invoke EventBridge schedular */

#creates an IAM role named my_lambda_role with an assume role policy that allows the lambda.amazonaws.com service to assume the role

resource "aws_iam_role" "my_lambda_role" {
  name = "my_lambda_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

#creates an IAM role named step-function-lambda-invoker with an assume role policy that allows the states.amazonaws.com service to assume the role

resource "aws_iam_role" "step_function_lambda_invoker" {
  name = "step-function-lambda-invoker"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "states.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

}

#creates an IAM role named event-bridge-invoker with an assume role policy that allows the events.amazonaws.com service to assume the role

resource "aws_iam_role" "event_bridge_invoker" {
  name = "event-bridge-invoker"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "events.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

}

# creates an IAM policy named event-bridgw-step-function-invoke-policy that allows starting an execution of a specific Step Functions state machine

resource "aws_iam_policy" "event_bridge_step_function_invoke_policy" {
  name = "event-bridgw-step-function-invoke-policy"
  policy = jsonencode(
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "states:StartExecution",
      "Resource": "${aws_sfn_state_machine.backup_dynamodb_to_s3.arn}"
    }
  ]
})

}

# creates a CloudWatch log group for a specific Lambda function with a retention period of 7 days

resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name = "/aws/lambda/${aws_lambda_function.backup_lambda_function.function_name}"
  retention_in_days = 7
  lifecycle {
    prevent_destroy = false
  }
}

#  creates an IAM policy named lambda-cloudwatch-putmetric-policy that allows various actions on logs, S3, and DynamoDB resources

resource "aws_iam_policy" "lambda_cloudwatch_putmetric_policy" {
  name = "lambda-cloudwatch-putmetric-policy"
  policy = jsonencode(
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "logs:*",
      "Resource": "arn:aws:logs:*:*:*"
    },
    {
      "Effect": "Allow",
      "Action": "s3:*",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "dynamodb:*",
      "Resource": "*"
    }
  ]
})

}

# creates an IAM policy named step-function-lambda-invoke-policy that allows invoking a specific Lambda function by a step functions state machine

resource "aws_iam_policy" "step_function_lambda_invoke_policy" {
  name = "step-function-lambda-invoke-policy"
  policy = jsonencode(
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "lambda:InvokeFunction",
      "Resource": "${aws_lambda_function.backup_lambda_function.arn}"
    }
  ]
})

}

# creates an IAM role policy attachment that attaches an IAM policy named step_function_lambda_invoke_policy to an IAM role named step_function_lambda_invoker

resource "aws_iam_role_policy_attachment" "step_function_lambda_invoke_policy_attachment" {
  role = aws_iam_role.step_function_lambda_invoker.name
  policy_arn = aws_iam_policy.step_function_lambda_invoke_policy.arn
}

# creates an IAM role policy attachment that attaches an IAM policy named event_bridge_step_function_invoke_policy to an IAM role named event_bridge_invoker

resource "aws_iam_role_policy_attachment" "event_bridge_step_function_invoke_policy_attachment" {
  role = aws_iam_role.event_bridge_invoker.name
  policy_arn = aws_iam_policy.event_bridge_step_function_invoke_policy.arn
}

# creates an IAM role policy attachment that attaches an IAM policy named lambda_cloudwatch_putmetric_policy to an IAM role named my_lambda_role

resource "aws_iam_role_policy_attachment" "lambda_cloudwatch_invoke_policy_attachment" {
  role = aws_iam_role.my_lambda_role.name
  policy_arn = aws_iam_policy.lambda_cloudwatch_putmetric_policy.arn
}

# creates an AWS Step Functions state machine named backup_dynamodb_to_s3

resource "aws_sfn_state_machine" "backup_dynamodb_to_s3" {

  role_arn = aws_iam_role.step_function_lambda_invoker.arn
  name = "backup_dynamodb_to_s3"
  definition = <<EOF
{
  "Comment": "A description of my state machine",
  "StartAt": "Backup",
  "States": {
    "Backup": {
      "Type": "Task",
      "Resource": "${aws_lambda_function.backup_lambda_function.arn}",
      "OutputPath": "$.Payload",
      "Parameters": {
        "Payload.$": "$",
        "FunctionName": "${aws_lambda_function.backup_lambda_function.arn}"
      },
      "Catch": [
        {
          "ErrorEquals": ["States.TaskFailed"],
          "Next": "Fail"
        }
      ],
      "End": true
    },
    "Fail": {
      "Type": "Fail"
    }
  }
}
  EOF
}

# creates a CloudWatch Events rule named backup_dynamodb_to_s3 with a specified schedule expression

resource "aws_cloudwatch_event_rule" "backup_dynamodb_to_s3" {
  name = "backup_dynamodb_to_s3"
  schedule_expression = "cron(0 * 12 * ? *)"
}

#  creates a CloudWatch Events target that specifies the target for the previously created rule

resource "aws_cloudwatch_event_target" "yada" {
  target_id = "event_target"
  rule      = aws_cloudwatch_event_rule.backup_dynamodb_to_s3.name
  arn       = aws_sfn_state_machine.backup_dynamodb_to_s3.arn
  role_arn = aws_iam_role.event_bridge_invoker.arn
  input = jsonencode(
{
  "s3BucketName":  "${aws_s3_bucket.backup_bucket.id}",
  "tableName": "Product"

})
}

