#!/bin/bash

set -e

# Logging
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "Starting user-data script at $(date)"

# Update and install Docker
yum update -y
yum install -y docker git
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

echo "User-data script completed at $(date)"