package config

// Config represents the structure of the configuration.
type Config struct {
    SQSURL              string `mapstructure:"sqs_url"`
    S3DropZoneBucket    string `mapstructure:"s3_drop_zone_bucket"`
    S3SnowflakeBucket   string `mapstructure:"s3_snowflake_bucket"`
}