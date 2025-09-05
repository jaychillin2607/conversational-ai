# AWS Configuration
aws_region = "us-east-1"

# Environment (dev, staging, prod)
environment = "dev"

# EC2 Configuration
instance_type = "t2.medium"

# SSH Public Key (required)
# Generate with: ssh-keygen -t rsa -b 4096 -f ~/.ssh/voice-agent-key
# Then copy the content of ~/.ssh/voice-agent-key.pub
ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC/8Js/cNECmdvsjVnAAJfF0Os51Q/fPwdR20czTyoOnN2puw92SPlZcrRFwEp73LWt9Hn0/TtU4f1X4uq6lOtB/QkyZl+2D+k0iNThILyR8garWCzk2XWN+i+KYABNQAgX+qnkGWSZvxUeD6VjKLvbMhZa0IHGtLV60vDkhCogUyZBsp2NH61Ml4weKgGlkXNByCD33gz415p4TwdxcbNLpvcQjpcVAvRZDcdUflToGeCJBBi7ls3MW31u9EWFE6CmTzL7J1C3WbVcIW755KDZJnTrRlxSi4MqZYjinKNKrRMDlxOj9+GqbRfLee7gwPmIjeVXe9zJrHMiyi3gYonF2djecCDsnkPbEKDzRVuN0LC0k5on1FUf68xwOFMssLG1UIerFGAARhpmNRCG77dlVDlIvRIQId60MpVkyQmm1EofxCye6XETXa60HEyOb2dxxWAAbjgafkPd776qCChh5on/Q+BxobayNFnQFh3qMKSbUypK8Xxi7GfkWW4VVc/C9Nnqr40TqygNU+kzu7CV7ppr4mKZ2nYU5YAigd5E/MQJI8uSJpgl0tcdlD05Xn/GxdE2ooS8KMhggqfiF/onifPG8pViJNvT7rGhcwhT74uE5v4v5BVKYkeDRD82QERIPc+OdIa1wwm/xyLGkEzYPBPFOCDA5iRK12pKTeZOJQ== jay@Jay.local"

# Root volume size in GB
root_volume_size = 20

# Example values for different environments:
# 
# Development:
# instance_type = "t3.small"
# root_volume_size = 20
#
# Production:
# instance_type = "t3.large"  
# root_volume_size = 30
#
# Available regions with Bedrock Nova Sonic:
# - us-east-1 (N. Virginia)
# - us-west-2 (Oregon)
# - eu-west-1 (Ireland)
# - ap-southeast-1 (Singapore)
#
# Choose the region closest to your users for lowest latency