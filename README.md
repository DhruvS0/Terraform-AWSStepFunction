# Terraform-AWSStepFunction
Create a system that uses an EventBridge scheduling tool and a step functions workflow to programmatically schedule data backups from a DynamoDB table to an AWS S3 bucket.
Following deployment, the EventBridge scheduler calls the Step Function each day at 12:00 p.m. and passes the bucket and table name.
The Step Function then calls a Lambda function, which retrieves information from a DynamoDB table and deposits it as a JSON file in an S3 bucket.
The equipment and AWS Serverless Services that we will use to complete this assignment are listed below:
DynamoDB: The database used as the source for the data that will be backed up.
S3: The location where the backed-up data will be stored.
Lambda: The procedure that transfers data from DynamoDB to S3.

You can schedule events that will trigger AWS Lambda functions or other targets at predetermined periods using the EventBridge scheduler.
Terraform: The project's infrastructure-as-code tool for deployment and management.
You must have an AWS account and the AWS CLI installed on your local computer before continuing.
You must also set up the required IAM roles and policies in addition to configuring your AWS login information.

![image](https://github.com/DhruvS0/Terraform-AWSStepFunction/assets/113872537/e157d857-c269-4a26-b908-ef00d4b831ad)


