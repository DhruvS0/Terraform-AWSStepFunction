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

provider "aws" {
  region = "us-east-1"
}

resource "random_uuid" "random" {
}

resource "aws_s3_bucket" "backup_bucket" {
  bucket = "backup-bucket-${random_uuid.random.id}"
}

resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket = aws_s3_bucket.backup_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

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

resource "aws_s3_bucket_policy" "allow_access" {
  bucket = aws_s3_bucket.backup_bucket.id
  policy = data.aws_iam_policy_document.allow_access.json
}

resource "aws_lambda_function" "backup_lambda_function" {
  function_name = "backup_lambda_function"
  role = aws_iam_role.my_lambda_role.arn
  handler = "backup.handler"
  runtime = "python3.8"
  filename = "backup.zip"
  timeout = 300
  memory_size = 128

}

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

resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name = "/aws/lambda/${aws_lambda_function.backup_lambda_function.function_name}"
  retention_in_days = 7
  lifecycle {
    prevent_destroy = false
  }
}

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

resource "aws_iam_role_policy_attachment" "step_function_lambda_invoke_policy_attachment" {
  role = aws_iam_role.step_function_lambda_invoker.name
  policy_arn = aws_iam_policy.step_function_lambda_invoke_policy.arn
}

resource "aws_iam_role_policy_attachment" "event_bridge_step_function_invoke_policy_attachment" {
  role = aws_iam_role.event_bridge_invoker.name
  policy_arn = aws_iam_policy.event_bridge_step_function_invoke_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_cloudwatch_invoke_policy_attachment" {
  role = aws_iam_role.my_lambda_role.name
  policy_arn = aws_iam_policy.lambda_cloudwatch_putmetric_policy.arn
}

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

resource "aws_cloudwatch_event_rule" "backup_dynamodb_to_s3" {
  name = "backup_dynamodb_to_s3"
  schedule_expression = "cron(0 * 12 * ? *)"
}

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

