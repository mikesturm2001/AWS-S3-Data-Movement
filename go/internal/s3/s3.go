package s3

import (
	"fmt"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/s3"
	"github.com/mikesturm2001/AWS_S3_Data_Movement/go/internal/config"
)

// CopyFileBetweenBuckets copies a file from the source S3 bucket to the destination S3 bucket.
func CopyFileBetweenBuckets(awsSession *session.Session, cfg *config.Config, fileName string) error {
	// Create an S3 service client
	svc := s3.New(awsSession)

	// Replace 'source-bucket' and 'destination-bucket' with your actual bucket names
	sourceBucket := cfg.S3DropZoneBucket
	destinationBucket := cfg.S3SnowflakeBucket

	// Declare the err variable
	var err error

	// Copy the file from the source bucket to the destination bucket
	_, err = svc.CopyObject(&s3.CopyObjectInput{
		Bucket:     &destinationBucket,
		CopySource: aws.String(sourceBucket + "/" + fileName),
		Key:        aws.String(fileName),
	})
	if err != nil {
		return fmt.Errorf("failed to copy file between S3 buckets: %v", err)
	}

	fmt.Printf("File %s copied from %s to %s\n", fileName, sourceBucket, destinationBucket)
	return nil
}
