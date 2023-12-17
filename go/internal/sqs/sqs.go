package sqs

import (
	"fmt"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/sqs"
)

// GetSQSMessage retrieves a message from the specified SQS queue.
func GetSQSMessage(awsSession *session.Session, queueURL *string) (string, string, error) {

	// Create an SQS service client
	svc := sqs.New(awsSession)

	// Receive a message from the queue
	result, err := svc.ReceiveMessage(&sqs.ReceiveMessageInput{
		QueueUrl:            queueURL,
		MaxNumberOfMessages: aws.Int64(1),
		VisibilityTimeout:   aws.Int64(0),
		WaitTimeSeconds:     aws.Int64(20),
	})
	if err != nil {
		return "", "", fmt.Errorf("failed to receive SQS message: %v", err)
	}

	// Check if a message is received
	if len(result.Messages) == 0 {
		return "", "", fmt.Errorf("no messages received from SQS queue")
	}

	// Extract the message body
	messageBody := *result.Messages[0].Body
	handle := *result.Messages[0].ReceiptHandle
	return messageBody, handle, nil
}

// DeleteMessage deletes a message from an Amazon SQS queue
// Inputs:
//
//	sess is the current session, which provides configuration for the SDK's service clients
//	queueURL is the URL of the queue
//	messageID is the ID of the message
//
// Output:
//
//	If success, nil
//	Otherwise, an error from the call to DeleteMessage
func DeleteMessage(sess *session.Session, queueURL *string, messageHandle *string) error {

	svc := sqs.New(sess)

	_, err := svc.DeleteMessage(&sqs.DeleteMessageInput{
		QueueUrl:      queueURL,
		ReceiptHandle: messageHandle,
	})

	if err != nil {
		return err
	}

	return nil
}
