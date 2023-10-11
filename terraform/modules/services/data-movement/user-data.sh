#!/bin/bash
sudo yum update -y
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker
echo 'Docker installed and started'

# Pull and run your Docker container
docker run -d --name my_container -p 80:80 your-docker-image:tag