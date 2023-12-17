package config

import (
    "fmt"
    "github.com/spf13/viper"
)

// ReadConfig reads the configuration from the specified file.
func ReadConfig(filePath string) (*Config, error) {
    // Initialize Viper
    viper.SetConfigFile(filePath)
    viper.SetConfigType("yaml")

    // Read the config file
    if err := viper.ReadInConfig(); err != nil {
        return nil, fmt.Errorf("failed to read config file: %v", err)
    }

    // Unmarshal the config into the Config struct
    var cfg Config
    if err := viper.Unmarshal(&cfg); err != nil {
        return nil, fmt.Errorf("failed to unmarshal config: %v", err)
    }

    return &cfg, nil
}