// this is a go file
package main

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/mikesturm2001/AWS_S3_Data_Movement/go/internal/config"
	"github.com/mikesturm2001/AWS_S3_Data_Movement/go/internal/director"
)

func main() {

	// Get the current working directory
	wd, err := os.Getwd()
	if err != nil {
		fmt.Printf("Error getting working directory: %v\n", err)
		os.Exit(1)
	}

	// Path to the config file relative to the working directory
	root := filepath.Join(wd, "../..")

	// Root folder of this project
	configFile := filepath.Join(root, "configs", "configs.yaml")

	// Read the configuration
	cfg, err := config.ReadConfig(configFile)
	if err != nil {
		fmt.Printf("Error reading config: %v\n", err)
		return
	}

	// Print the configuration
	fmt.Printf("SQS URL: %s\n", cfg.SQSURL)
	fmt.Printf("S3 Drop Zone Bucket: %s\n", cfg.S3DropZoneBucket)
	fmt.Printf("S3 Snowflake Bucket: %s\n", cfg.S3SnowflakeBucket)

	// Initialize and run your SQS and S3 processing logic
	if err := director.ProcessSQSMessage(cfg); err != nil {
		fmt.Printf("Error processing SQS message: %v\n", err)
		return
	}
}
