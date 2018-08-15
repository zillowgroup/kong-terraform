# Network settings
variable "vpc_name" {
  description = "VPC Name for the AWS account and region specified"
  type        = "string"
}

variable "private_subnets" {
  description = "'Type' tag on private subnets"
  type        = "string"

  default = "private-dynamic"
}

variable "public_subnets" {
  description = "'Type' tag on public subnets for external load balancers"
  type        = "string"

  default = "public"
}

variable "default_security_group" {
  description = "Name of the default VPC security group for EC2 access"
  type        = "string"

  default = "default"
}

# Access control
variable "bastion_cidr_blocks" {
  description = "Bastion hosts allowed access to PostgreSQL and Kong Admin"
  type        = "list"

  default = [
    "127.0.0.1/32",
  ]
}

variable "external_cidr_blocks" {
  description = "External ingress access to Kong API via the load balancer"
  type        = "list"

  default = [
    "0.0.0.0/0",
  ]
}

variable "internal_cidr_blocks" {
  description = "Internal ingress access to Kong API via the load balancer"
  type        = "list"

  default = [
    "0.0.0.0/0",
  ]
}

variable "gui_cidr_blocks" {
  description = "Internal ingress access to Kong GUI (Enterprise Edition only)"
  type        = "list"

  default = [
    "0.0.0.0/0",
  ]
}

# Required tags
variable "description" {
  description = "Resource description tag"
  type        = "string"

  default = "Kong API Gateway"
}

variable "environment" {
  description = "Resource environment tag (i.e. dev, stage, prod)"
  type        = "string"
}

variable "service" {
  description = "Resource service tag"
  type        = "string"

  default = "zg-kong-2-1"
}

# Additional tags
variable "tags" {
  description = "Tags to apply to resources"
  type        = "map"

  default = {}
}

# Enterprise Edition
variable "enable_ee" {
  description = "Boolean to enable Kong Enterprise Edition settings (requires license key in SSM)"
  type        = "string"
}

# EC2 settings

# https://wiki.ubuntu.com/Minimal
variable "ec2_ami" {
  description = "Map of Ubuntu Minimal AMIs by region"
  type        = "map"

  default = {
    us-east-1 = "ami-7029320f"
    us-east-2 = "ami-0350efe0754b8e179"
    us-west-1 = "ami-657f9006"
    us-west-2 = "ami-59694f21"
  }
}

variable "ec2_instance_type" {
  description = "EC2 instance type"
  type        = "string"
}

variable "ec2_ebs_optimized" {
  description = "Boolean to use EBS optimized volumes"
  type        = "string"

  default = true
}

variable "ec2_root_volume_size" {
  description = "Size of the root volume (in Gigabytes)"
  type        = "string"

  default = 8
}

variable "ec2_key_name" {
  description = "AWS SSH Key"
  type        = "string"
}

variable "asg_max_size" {
  description = "The maximum size of the auto scale group"
  type        = "string"

  default = 4
}

variable "asg_min_size" {
  description = "The minimum size of the auto scale group"
  type        = "string"

  default = 2
}

variable "asg_desired_capacity" {
  description = "The number of instances that should be running in the group"
  type        = "string"

  default = 3
}

variable "asg_health_check_grace_period" {
  description = "Time in seconds after instance comes into service before checking health"
  type        = "string"

  # Terraform default is 300
  default = 300
}

# Kong packages
variable "ee_enabled" {
  description = "Boolean to enable Enterprise Edition"
  type       = "string"

  default = false
}

variable "ee_pkg" {
  description = "Filename of the Enterprise Edition package"
  type        = "string"

  default = "kong-enterprise-edition-0.31-1.zesty.all.deb"
}

variable "ce_pkg" {
  description = "Filename of the Community Edition package"
  type        = "string"

  default = "kong-community-edition-0.12.3.zesty.all.deb"
}

# Load Balancer settings
variable "enable_external_lb" {
  description = "Boolean to enable/create the external load balancer, exposing Kong to the Internet"
  type        = "string"

  default = true
}

variable "enable_internal_lb" {
  description = "Boolean to enable/create the internal load balancer for the forward proxy"
  type        = "string"

  default = true
}

variable "deregistration_delay" {
  description = "Seconds to wait before changing the state of a deregistering target from draining to unused"
  type        = "string"

  # Terraform default is 300
  default = 300
}

variable "enable_deletion_protection" {
  description = "Boolean to enable delete protection on the ALB"
  type        = "string"

  # Terraform default is false
  default = true
}

variable "health_check_healthy_threshold" {
  description = "Number of consecutives checks before a unhealthy target is considered healthy"
  type        = "string"

  # Terraform default is 5
  default = 5
}

variable "health_check_interval" {
  description = "Seconds between health checks"
  type        = "string"

  # Terraform default is 30
  default = 5
}

variable "health_check_matcher" {
  description = "HTTP Code(s) that result in a successful response from a target (comma delimited)"
  type        = "string"

  default = 200
}

variable "health_check_timeout" {
  description = "Seconds waited before a health check fails"
  type        = "string"

  # Terraform default is 5
  default = 3
}

variable "health_check_unhealthy_threshold" {
  description = "Number of consecutive checks before considering a target unhealthy"
  type        = "string"

  # Terraform default is 2
  default = 2
}

variable "idle_timeout" {
  description = "Seconds a connection can idle before being disconnected"
  type        = "string"

  # Terraform default is 60
  default = 60
}

variable "ssl_cert_external" {
  description = "SSL certificate domain name for the external API HTTPS listener"
  type        = "string"
}

variable "ssl_cert_internal" {
  description = "SSL certificate domain name for the internal API HTTPS listener"
  type        = "string"
}

variable "ssl_cert_internal_gui" {
  description = "SSL certificate domain name for the GUI HTTPS listener"
  type        = "string"
}

variable "ssl_policy" {
  description = "SSL Policy for HTTPS Listeners"
  type        = "string"

  default = "ELBSecurityPolicy-TLS-1-2-2017-01"
}

# Cloudwatch alarms
variable "cloudwatch_actions" {
  description = "List of cloudwatch actions for Alert/Ok"
  type        = "list"

  default = []
}

variable "http_4xx_count" {
  description = "HTTP Code 4xx count threshhold"
  type        = "string"

  default = 50
}

variable "http_5xx_count" {
  description = "HTTP Code 5xx count threshhold"
  type        = "string"

  default = 50
}
# Datastore settings
variable "db_instance_class" {
  description = "Database instance class"
  type        = "string"

  default = "db.r4.large"
}

variable "db_instance_count" {
  description = "Number of database instances (0 to leverage an existing db)"
  type        = "string"
}

variable "db_host" {
  description = "Database host name/endpoint if using an existing Aurora cluster"
  type        = "string"

  default = "placeholder"
}

variable "db_username" {
  description = "Database master username"
  type        = "string"

  default = "root"
}

variable "db_password" {
  description = "Initial database master password"
  type        = "string"

  default = "zg-kong-2-1"
}

variable "db_subnet_group" {
  description = "Database instance subnet group name"
  type        = "string"

  default = "db_subnets"
}

variable "db_backup_retention_period" {
  description = "The number of days to retain backups"
  type        = "string"

  default = 7
}

# Redis settings (for rate_limiting only)
variable "enable_redis" {
  description = "Boolean to enable redis AWS resource"
  type        = "string"

  default = false
}

variable "redis_instance_type" {
  description = "Redis node instance type"
  type        = "string"

  default = "cache.t2.small"
}

variable "redis_instance_count" {
  description = "Number of redis nodes"
  type        = "string"

  default = 2
}

variable "redis_subnet_group" {
  description = "Redis cluster subnet group name"
  type        = "string"

  default = "cache-subnets"
}
