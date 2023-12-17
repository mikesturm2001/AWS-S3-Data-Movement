package director

import (
	"encoding/json"
	"fmt"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/credentials"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/mikesturm2001/AWS_S3_Data_Movement/go/internal/config"
	"github.com/mikesturm2001/AWS_S3_Data_Movement/go/internal/s3"
	"github.com/mikesturm2001/AWS_S3_Data_Movement/go/internal/sqs"
)

// Message encapsulates all the information to publish in a message
type S3Message struct {
	Type      string `json:"Type"`
	MessageId string `json:"MessageId"`
	TopicArn  string `json:"TopicArn"`
	Message   string `json:"Message"`
	Timestamp string `json:"Timestamp"`
}

type Message struct {
	Version    string        `json:"version"`
	ID         string        `json:"id"`
	DetailType string        `json:"detail-type"`
	Source     string        `json:"source"`
	Account    string        `json:"account"`
	Time       string        `json:"time"`
	Region     string        `json:"region"`
	Resources  []string      `json:"resources"`
	Detail     DetailContent `json:"detail"`
}

type DetailContent struct {
	Version   string `json:"version"`
	Bucket    Bucket `json:"bucket"`
	Object    Object `json:"object"`
	RequestID string `json:"request-id"`
	Requester string `json:"requester"`
	SourceIP  string `json:"source-ip-address"`
	Reason    string `json:"reason"`
}

type Bucket struct {
	Name string `json:"name"`
}

type Object struct {
	Key       string `json:"key"`
	Size      int    `json:"size"`
	Etag      string `json:"etag"`
	VersionID string `json:"version-id"`
	Sequencer string `json:"sequencer"`
}

// ProcessSQSMessage processes the SQS message, extracting file information and performing directory operations.
func ProcessSQSMessage(cfg *config.Config) error {

	awsConfig := &aws.Config{
		Region: aws.String("us-east-1"),
	}

	awsConfig.Credentials = credentials.NewSharedCredentials("", "github-actions-iam-user")

	// Create an AWS session
	awsSession, err := session.NewSession(awsConfig)
	if err != nil {
		return fmt.Errorf("failed to create AWS session: %v", err)
	}

	// Get SQS message
	sqsMessage, messageHandle, err := sqs.GetSQSMessage(awsSession, &cfg.SQSURL)
	if err != nil {
		return fmt.Errorf("failed to get SQS message: %v", err)
	}

	// Parse SQS message
	var s3Message S3Message
	err = json.Unmarshal([]byte(sqsMessage), &s3Message)
	if err != nil {
		return fmt.Errorf("Error unmarshaling SQS message:", err)
	}

	// S3 Message was not unmarshalling automatically so we will manually unmarshall the rest of the object here
	var message Message
	err = json.Unmarshal([]byte(s3Message.Message), &message)
	if err != nil {
		return fmt.Errorf("Error unmarshaling Detail field:", err)
	}

	fileName := message.Detail.Object.Key

	// Perform directory operations (e.g., copy file from source to destination)
	// You can implement your specific logic here

	fmt.Printf("Processing file: %s\n", fileName)
	// Add your logic to handle the file, e.g., copy it from source to destination

	// Perform directory operations (e.g., copy file from source to destination)
	if err := s3.CopyFileBetweenBuckets(awsSession, cfg, fileName); err != nil {
		return fmt.Errorf("error copying file between buckets: %v", err)
	}

	// Delete SQS message (assuming successful processing)
	err = sqs.DeleteMessage(awsSession, &cfg.SQSURL, &messageHandle)
	if err != nil {
		fmt.Println("Got an error deleting the message:")
		fmt.Println(err)
		return fmt.Errorf("error deleting SQS message: %v", err)
	}

	fmt.Println("Deleted message from queue with URL " + cfg.SQSURL)

	return nil
}
