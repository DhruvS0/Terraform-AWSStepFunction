
import boto3
import json

def handler(event, context):
    
    print("Event : ", event['Payload'])
    print("Context : ", context)
    payload = event['Payload']
    #payload = payload['detail']['custom_detail_type']
    print("payload : ",  payload)
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table(payload['tableName'])
    s3 = boto3.client('s3')
    response = table.scan()
    data = response['Items']
    while 'LastEvaluatedKey' in response:
        response = table.scan(ExclusiveStartKey=response['LastEvaluatedKey'])
        data.extend(response['Items'])
    s3.put_object(Body=json.dumps(data), Bucket=payload['s3BucketName'], Key='file_name.json')
    
    return {
                    "statusCode": 200,
                    "headers": {    
                        "Access-Control-Allow-Headers" : "Content-Type",
                        "Access-Control-Allow-Origin": "*", 
                        "Access-Control-Allow-Methods": "GET" 
                    },         
                    "body": json.dumps({"message": "success"}),
                }

