import boto3
import os
import debugpy


def read_queue():
    
    # Set up the AWS S3 and SQS clients #need to wrap in error handling
    s3_client = boto3.client('s3')
    sqs_client = boto3.client('sqs', region_name='us-east-1')

    queue_url = os.environ.get("SQS_QUEUE_URL")
    s3_drop_zone_bucket = os.environ.get("S3_DZ")
    s3_snowflake_bucket = os.environ.get("S3_SNOWFLAKE")

    count = 1

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
        count = count + 1

def main():
    debugpy.listen(('0.0.0.0', 5678))
    debugpy.wait_for_client()
    debugpy.breakpoint()

    read_queue()


if __name__=="__main__": 
    main() 