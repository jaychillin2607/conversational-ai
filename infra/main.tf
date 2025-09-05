# Data source for the latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Default VPC (using existing VPC to keep it simple)
data "aws_vpc" "default" {
  default = true
}

# Default subnet
data "aws_subnet" "default" {
  vpc_id            = data.aws_vpc.default.id
  availability_zone = data.aws_availability_zones.available.names[0]
  default_for_az    = true
}

# Security Group for the EC2 instance
resource "aws_security_group" "voice_agent_sg" {
  name_prefix = "voice-agent-sg"
  description = "Security group for AI Voice Agent EC2 instance"
  vpc_id      = data.aws_vpc.default.id

  # SSH access
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP for frontend (nginx)
  ingress {
    description = "HTTP Frontend"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Backend API
  ingress {
    description = "Backend API"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS (optional, for future SSL)
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "voice-agent-security-group"
    Project     = "ai-voice-agent"
    Environment = var.environment
  }
}

# Key Pair for SSH access
resource "aws_key_pair" "voice_agent_key" {
  key_name   = "voice-agent-key"
  public_key = var.ssh_public_key

  tags = {
    Name        = "Voice Agent Key Pair"
    Project     = "ai-voice-agent"
    Environment = var.environment
  }
}

# EC2 Instance
resource "aws_instance" "voice_agent" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.voice_agent_key.key_name
  vpc_security_group_ids = [aws_security_group.voice_agent_sg.id]
  subnet_id              = data.aws_subnet.default.id

  # IAM instance profile for AWS Bedrock access
  iam_instance_profile = aws_iam_instance_profile.ec2_voice_agent_profile.name

  # User data script for initial setup
  user_data = file("${path.module}/user-data.sh")

  # Enable detailed monitoring
  monitoring = true

  # Root volume configuration
  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    delete_on_termination = true
    encrypted             = true

    tags = {
      Name        = "voice-agent-root-volume"
      Project     = "ai-voice-agent"
      Environment = var.environment
    }
  }

  tags = {
    Name        = "ai-voice-agent"
    Project     = "ai-voice-agent"
    Environment = var.environment
    Type        = "voice-agent-server"
  }

  # Ensure instance is recreated if user data changes
  user_data_replace_on_change = true

  lifecycle {
    create_before_destroy = true
  }
}

# Associate the instance with the security group
resource "aws_network_interface_sg_attachment" "voice_agent_sg_attachment" {
  security_group_id    = aws_security_group.voice_agent_sg.id
  network_interface_id = aws_instance.voice_agent.primary_network_interface_id
}
