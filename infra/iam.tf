# IAM Role for EC2 instance
resource "aws_iam_role" "ec2_voice_agent_role" {
  name = "ec2-voice-agent-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "EC2 Voice Agent Role"
    Project     = "ai-voice-agent"
    Environment = var.environment
  }
}

# IAM Policy for Bedrock Nova Sonic access
resource "aws_iam_policy" "bedrock_nova_sonic_policy" {
  name        = "bedrock-nova-sonic-policy"
  description = "Policy for accessing AWS Bedrock Nova Sonic model"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream",
          "bedrock:GetFoundationModel",
          "bedrock:ListFoundationModels"
        ]
        Resource = [
          "arn:aws:bedrock:${var.aws_region}::foundation-model/amazon.nova-sonic-v1:0",
          "arn:aws:bedrock:${var.aws_region}::foundation-model/amazon.nova-sonic-*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:ListFoundationModels",
          "bedrock:GetFoundationModel"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "Bedrock Nova Sonic Policy"
    Project     = "ai-voice-agent"
    Environment = var.environment
  }
}

# IAM Policy for CloudWatch Logs (optional but recommended)
resource "aws_iam_policy" "cloudwatch_logs_policy" {
  name        = "ec2-cloudwatch-logs-policy"
  description = "Policy for EC2 to write to CloudWatch Logs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:*:*"
      }
    ]
  })

  tags = {
    Name        = "CloudWatch Logs Policy"
    Project     = "ai-voice-agent"
    Environment = var.environment
  }
}

# Attach Bedrock policy to role
resource "aws_iam_role_policy_attachment" "attach_bedrock_policy" {
  role       = aws_iam_role.ec2_voice_agent_role.name
  policy_arn = aws_iam_policy.bedrock_nova_sonic_policy.arn
}

# Attach CloudWatch Logs policy to role
resource "aws_iam_role_policy_attachment" "attach_cloudwatch_policy" {
  role       = aws_iam_role.ec2_voice_agent_role.name
  policy_arn = aws_iam_policy.cloudwatch_logs_policy.arn
}

# Instance Profile for EC2 
resource "aws_iam_instance_profile" "ec2_voice_agent_profile" {
  name = "ec2-voice-agent-profile"
  role = aws_iam_role.ec2_voice_agent_role.name

  tags = {
    Name        = "EC2 Voice Agent Instance Profile"
    Project     = "ai-voice-agent"
    Environment = var.environment
  }
}
