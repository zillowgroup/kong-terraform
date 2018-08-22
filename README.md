# ZG Kong Cluster Terraform Module

[Kong API Gateway] (https://konghq.com/) is an API gateway microservices
management layer. This is the terraform module used to provision Kong
Clusters at Zillow Group and is available under the Apache License 2.0 
license. Both Kong Community and Enterprise Edition are supported.

By default, the following resources will be provisioned:

- Auora PostgreSQL cluster for Kong configuration
- An Auto Scaling Group (ASG) and EC2 instances running Kong (Kong nodes)
- An external load balancer (HTTPS only)
  - HTTPS:443 - Kong Proxy
- An internal load balancer (HTTP and HTTPS)
  - HTTP:80 - Kong Proxy
  - HTTPS:443 - Kong Proxy
  - HTTPS:8444 - Kong Admin API (Enterprise Edition only)
  - HTTPS:8445 - Kong Admin GUI (Enterprise Edition only)
- Security groups granting least privilege access to resources
- An IAM instance profile for access to Kong specific SSM Parameter Store 
  metadata and secrets

Optionally, a redis cluster can be provisioned for rate-limiting counters 
and caching, and most default resources can be disabled.  See variables.tf
for a complete list of tunables. 

The Kong nodes are based on [Minimal Ubuntu] (https://wiki.ubuntu.com/Minimal).
Using cloud-init, the following is provisioned on top of the AMI:

- A kong service user
- Minimal set of dependancies and debugging tools
- Kongfig for Kong configuration management
- Kong, running under runit process supervision
- Splunk plugin for Kong
- Log rotation of Kong log files

Prerequisites:

- An AWS VPC
- Private and public subnets labeled using the "Type" tag
- An SSH Key
- An SSL managed certificate to associate with HTTPS load balancers

Required variables:

    vpc_name               VPC Name for the AWS account and region specified
    environment            Resource environment tag (i.e. dev, stage, prod)
    ec2_instance_type      EC2 instance type
    ec2_key_name           AWS SSH Key
    ssl_cert_external      SSL certificate domain name for the external API HTTPS listener
    ssl_cert_internal      SSL certificate domain name for the internal API HTTPS listener
    ssl_cert_internal_gui  SSL certificate domain name for the GUI HTTPS listener

Example main.tf:

    provider "aws" {
      region  = "us-west-2"
      profile = "dev"
    }

    module "kong" {
      source = "github.com/zillowgroup/kong-terraform"

      vpc_name              = "my-vpc"
      environment           = "dev"
      ec2_instance_type     = "t2.small"
      ec2_ebs_optimized     = false
      ec2_key_name          = "my-key"
      ssl_cert_external     = "*.domain.name"
      ssl_cert_internal     = "*.domain.name"
      ssl_cert_internal_gui = "*.domain.name"

      enable_internal_lb = true

      db_instance_count = 3

      tags = {
         Owner = "devops@domain.name"
         Team = "DevOps"
      }
    }

Create the resources in AWS:

    terraform init
    terraform plan -out kong.plan
    terraform apply kong.plan

While resources are being provisioned, login to the AWS console and navigate
to:

    EC2 -> Systems Manager Shared Resources -> Parameter Store

Update the Kong database password parameter with one of your choosing:

    /[service]/[environment]/db/password

Note: You can generate a random, secure password using:

    pwgen -s 16

This step is manual to avoid checking in secrets into a repository. 
Additionally, if installing Enterprise Edition:

Update the license key by editing the parameter (default value is "placeholder"):
 
    /[service]/[environment]/ee/license

Update the Bintray authentication paramater (default value is "placeholder", format is 
"username:apikey")" for Enterprise Edition downloads:

    /[service]/[environment]/ee/bintray-auth

To login to the EC2 instance(s):

    ssh -i [/path/to/key/specified/in/ec2_key_name] ubuntu@[ec2-instance]

After you login to an EC2 instance, it is **highly** recommended to update 
the master PostgreSQL password using psql from the command line:

    PG_HOST=$(grep ^pg_host /etc/kong/kong.conf | cut -d= -f2 | awk '{print $1}')
    PGPASSWORD=KongChangeMeNow#1 psql -h $PG_HOST template1
    > ALTER USER root WITH PASSWORD '[new password]';

Then update the key in the Parameter Store to the same value:

    /[service]/[environment]/db/password/master

You are now ready to manage APIs!
