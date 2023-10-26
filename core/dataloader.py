import boto3
import os
import debugpy
import json
from json import JSONDecodeError
import logging


def decode_json_recursively(source):
    try:
        if isinstance(source, list):
            data = [decode_json_recursively(list_item) for list_item in source]
        elif isinstance(source, dict):
            data = source
        else:
            data = json.loads(source)

        if isinstance(data, dict):
            for k, v in data.items():
                data[k] = decode_json_recursively(v)
    except (JSONDecodeError, TypeError, AttributeError):
        return source
    return data


def read_queue():

    try:
        # Set up the AWS S3 and SQS clients #need to wrap in error handling
        s3 = boto3.resource('s3')
        sqs_client = boto3.client('sqs', region_name='us-east-1')

        queue_url = os.environ.get("SQS_QUEUE_URL")
        s3_drop_zone_bucket = os.environ.get("S3_DZ")
        s3_snowflake_bucket = os.environ.get("S3_SNOWFLAKE")
    except Exception as e:
        print(f"An error occurred: {str(e)}")
        logging.error(f"An error occurred: {str(e)}")

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
                logging.info("Messages Read")
                for message in response['Messages']:
                    # Extract S3 notification details from the message
                    s3_event = message['Body']

                    s3_event_dict = decode_json_recursively(s3_event)
                    # Extract the object key
                    object_key = s3_event_dict["Message"]["detail"]["object"]["key"]

                    src_bucket = s3.Bucket(s3_drop_zone_bucket)
                    src_obj = src_bucket.Object(object_key)

                    drop_zone_file = {
                        'Bucket': src_bucket.name,
                        'Key': src_obj.key
                    }

                    s3.meta.client.copy(drop_zone_file, s3_snowflake_bucket, object_key)

                    

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
            logging.error(f"An error occurred: {str(e)}")


def main():
    #debugpy.listen(('0.0.0.0', 5678))
    #debugpy.wait_for_client()
    #debugpy.breakpoint()
    logging.getLogger().setLevel(logging.INFO)

    if logging.getLogger().hasHandlers():
        # The Lambda environment pre-configures a handler logging to stderr. If a handler is already configured,
        # `.basicConfig` does not execute. Thus we set the level directly.
        logging.getLogger().setLevel(logging.INFO)
    else:
        logging.basicConfig(level=logging.INFO)

    read_queue()


if __name__=="__main__": 
    main() 