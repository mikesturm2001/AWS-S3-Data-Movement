import boto3
import os

# Set up the AWS S3 and SQS clients
s3_client = boto3.client('s3')
sqs_client = boto3.client('sqs')

def read_queue():
    
    queue_url = os.environ.get("SQS_QUEUE_URL")
    s3_drop_zone_bucket = os.environ.get("S3_DZ")
    s3_snowflake_bucket = os.environ.get("S3_SNOWFLAKE")

    src = s3.Bucket(s3_drop_zone_bucket)
    dst = s3.Bucket(s3_snowflake_bucket)

    # Todo: refactor this to run while there are objects in the SQS queue vs "while true" infinite loop
    while True:
        try:
            # Receive messages from the SQS queue
            response = sqs_client.receive_message(
                QueueUrl=queue_url,
                AttributeNames=['All'],
                MessageAttributeNames=['All'],
                MaxNumberOfMessages=1,
                WaitTimeSeconds=20  # Adjust this as needed
            )

            if 'Messages' in response:
                for message in response['Messages']:
                    # Extract S3 notification details from the message
                    s3_event = message['Body']
                    print("Received S3 Notification:")
                    print(s3_event)

                    # Process the S3 event as needed
                    # Todo: We want to use boto3 copy the object here https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/s3/client/copy_object.html


                    # todo: we then need to generate a control file based on the metadata of the object


                    # Todo: Publish a message to the destination Queue telling it to process the file

                    
                    # Delete the message from the SQS queue
                    receipt_handle = message['ReceiptHandle']
                    sqs_client.delete_message(
                        QueueUrl=queue_url,
                        ReceiptHandle=receipt_handle
                    )
            else:
                print("No messages received from the queue.")

        except Exception as e:
            print(f"An error occurred: {str(e)}")

def main():

    read_queue()
