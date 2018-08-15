# ZG Kong Cluster Terraform Module

Required variables:

    vpc_name               VPC Name for the AWS account and region specified
    environment            Resource environment tag (i.e. dev, stage, prod)
    ec2_instance_type      EC2 instance type
    ec2_key_name           AWS SSH Key
    ssl_cert_external      SSL certificate domain name for the external API HTTPS listener
    ssl_cert_internal      SSL certificate domain name for the internal API HTTPS listener
    ssl_cert_internal_gui  SSL certificate domain name for the GUI HTTPS listener
    db_instance_count      Number of database instances (0 to leverage an existing db)

Create the resources in AWS:

    terraform init
    terraform plan -out kong.plan
    terraform apply kong.plan

If installing enterprise edition, open the AWS console and navigate to:

    EC2 -> Systems Manager Shared Resources -> Parameter Store

Update the license key by editing the parameter (default value is "placeholder"):
 
    /[service]/[environment]/ee/license

Update the Bintray authentication paramater (default value is "placeholder", format is 
"username:apikey")" for Enterprise Edition downloads:

    /[service]/[environment]/ee/bintray-auth

Skip the above step for the community edition.

For all editions, In the AWS console update the Parameter Store name with your Kong database password:

    /[service]/[environment]/db/password

Note: You can generate a random, secure password using:

    pwgen -s 16

To login to the EC2 instance(s):

    ssh -i [/path/to/key/specified/in/variables.tf] admin@[ec2-instance]

After you login to an EC2 instance, it is highly recommended to update 
the master PostgreSQL password using psql from the command line:

    PG_HOST=$(grep ^pg_host /etc/kong/kong.conf | cut -d= -f2 | awk '{print $1}')
    PGPASSWORD=KongChangeMeNow#1 psql -h $PG_HOST template1
    > ALTER USER root WITH PASSWORD '[new password]';

Then update the key in the Parameter Store to the same value:

    /[service]/[environment]/db/password/master

You are now ready to use Kongfig to manage APIs!
