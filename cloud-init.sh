#!/bin/sh

# Function to grab SSM parameters
aws_get_parameter() {
    aws ssm --region ${REGION} get-parameter \
        --name "${PARAMETER_PATH}/$1" \
        --with-decryption \
        --output text \
        --query Parameter.Value 2>/dev/null
}

# Enable auto updates
echo "Enabling auto updates"
echo unattended-upgrades unattended-upgrades/enable_auto_updates boolean true \
    | debconf-set-selections
dpkg-reconfigure -f noninteractive unattended-upgrades
echo "Done."

# Update awscli
echo "Upgrading AWS cli"
pip3 install --upgrade awscli

# Install kongfig
echo "Installing Kongfig"
curl -s https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add -
echo "deb https://deb.nodesource.com/node_9.x stretch main" \
    > /etc/apt/sources.list.d/nodejs.list
apt-get update
apt install -y nodejs
npm install -g kongfig
echo "Done."

# Install Kong
echo "Installing Kong"
EE_LICENSE=$(aws_get_parameter ee/license)
EE_CREDS=$(aws_get_parameter ee/bintray-auth)
if [ "$EE_LICENSE" != "placeholder" ]; then
    curl -L \
        -u $EE_CREDS \
        https://kong.bintray.com/kong-enterprise-edition-deb/dists/${EE_PKG} \
        -o ${EE_PKG} 

    if [ ! -f ${EE_PKG} ]; then
        echo "Error: Enterprise edition download failed, aborting."
        exit 1
    fi
    dpkg -i ${EE_PKG}

    cat <<EOF > /etc/kong/license.json
$EE_LICENSE
EOF
    chown root:kong /etc/kong/license.json
    chmod 640 /etc/kong/license.json
else 
    KONG_DEB_FILE=kong-community-edition-0.12.3.stretch.all.deb
    curl -sL \
        https://kong.bintray.com/kong-community-edition-deb/dists/${CE_PKG} \
        -o ${CE_PKG}
    dpkg -i ${CE_PKG}
fi
echo "Done."

# Setup database
echo "Setting up Kong database"
PGPASSWORD=$(aws_get_parameter "db/password/master")
DB_HOST=$(aws_get_parameter "db/host")
DB_NAME=$(aws_get_parameter "db/name")
DB_PASSWORD=$(aws_get_parameter "db/password")
export PGPASSWORD

RESULT=$(psql --host $DB_HOST --username root \
    --tuples-only --no-align postgres \
    <<EOF
SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}'
EOF
)

if [ $? != 0 ]; then
    echo "Error: Database connection failed, please configure manually"
    exit 1
fi

echo $RESULT | grep -q 1
if [ $? != 0 ]; then
    psql --host $DB_HOST --username root postgres <<EOF
CREATE USER ${DB_USER} WITH PASSWORD '$DB_PASSWORD';
GRANT ${DB_USER} TO root;
CREATE DATABASE $DB_NAME OWNER = ${DB_USER};
EOF
fi
unset PGPASSWORD

# Setup Configuration file
cat <<EOF > /etc/kong/kong.conf
# kong.conf, Zillow Group Kong configuration file
# Written by Dennis Kelly <dennisk@zillowgroup.com>
#
# 2018-03-13: Support for 0.12 and load balancing
# 2017-06-20: Initial release
#
# Notes:
#   - See kong.conf.default for further information

# Database settings
database = postgres 
pg_host = $DB_HOST
pg_user = ${DB_USER}
pg_password = $DB_PASSWORD
pg_database = $DB_NAME

# Load balancer headers
real_ip_header = X-Forwarded-For
trusted_ips = 0.0.0.0/0

# For /status to load balancers
admin_listen = 0.0.0.0:8001

# SSL is performed by load balancers
ssl = off
admin_ssl = off
admin_gui_ssl = off
EOF
chmod 640 /etc/kong/kong.conf
chgrp kong /etc/kong/kong.conf

if [ "$EE_LICENSE" != "placeholder" ]; then
    echo "" >> /etc/kong/kong.conf
    echo "# Enterprise Edition Settings" >> /etc/kong/kong.conf
    echo "vitals = on" >> /etc/kong/kong.conf

    for DIR in gui lib portal; do
        chown -R kong:kong /usr/local/kong/$DIR
    done
else
    # CE does not create the kong directory
    mkdir /usr/local/kong
fi

chown root:kong /usr/local/kong
chmod 2775 /usr/local/kong
echo "Done."

# Initialize Kong
echo "Initializing Kong"
sudo -u kong kong migrations up
sudo -u kong kong prepare
echo "Done."

cat <<'EOF' > /usr/local/kong/nginx.conf
worker_processes auto;
daemon off;

pid pids/nginx.pid;
error_log logs/error.log notice;

worker_rlimit_nofile 65536;

events {
    worker_connections 8192;
    multi_accept on;
}

http {
    include nginx-kong.conf;
}
EOF
chown root:kong /usr/local/kong/nginx.conf

# Log rotation
cat <<'EOF' > /etc/logrotate.d/kong
/usr/local/kong/logs/*.log {
  rotate 14
  daily
  compress
  missingok
  notifempty
  create 640 kong kong
  sharedscripts

  postrotate
    /usr/bin/sv 1 /etc/sv/kong
  endscript
}
EOF

# Start Kong under supervision
echo "Starting Kong under supervision"
mkdir -p /etc/sv/kong /etc/sv/kong/log

cat <<'EOF' > /etc/sv/kong/run
#!/bin/sh -e
exec 2>&1

ulimit -n 65536
sudo -u kong kong prepare
exec chpst -u kong /usr/local/openresty/nginx/sbin/nginx -p /usr/local/kong -c nginx.conf
EOF

cat <<'EOF' > /etc/sv/kong/log/run
#!/bin/sh -e

[ -d /var/log/kong ] || mkdir -p /var/log/kong
chown kong:kong /var/log/kong

exec chpst -u kong /usr/bin/svlogd -tt /var/log/kong
EOF
chmod 744 /etc/sv/kong/run /etc/sv/kong/log/run

cd /etc/service
ln -s /etc/sv/kong
echo "Done."

# Enable RBAC
if [ "$EE_LICENSE" != "placeholder" ]; then
    echo "Configuring enterprise edition RBAC settings"
    RUNNING=0
    for I in 1 2 3 4 5; do
        curl -s -I http://localhost:8001/status | grep -q "200 OK"
        if [ $? = 0 ]; then
            RUNNING=1
            break
        fi 
        sleep 1
    done

    if [ $RUNNING = 0 ]; then
        echo "Cannot connect to admin API, aborting"
        exit 1
    fi

    # Admin user
    curl -s -I http://localhost:8001/rbac/users/admin | grep -q "200 OK"
    if [ $? != 0 ]; then
        curl -X POST http://localhost:8001/rbac/users \
            -d name=admin -d user_token=zg-kong-2-1 > /dev/null
        curl -X POST http://localhost:8001/rbac/users/admin/roles \
            -d roles=super-admin > /dev/null
        curl -X POST http://localhost:8001/rbac/users \
            -d name=monitor -d user_token=monitor > /dev/null
    fi
    
    # Monitor permissions, role, and user for /status (ALB healthcheck)
    curl -s -I http://localhost:8001/rbac/roles/monitor | grep -q "200 OK"
    if [ $? != 0 ]; then    
        curl -s -X POST http://localhost:8001/rbac/permissions \
            -d name=monitor -d resources=status -d actions=read > /dev/null
        curl -s -X POST http://localhost:8001/rbac/roles \
            -d name=monitor -d comment='Load balancer access to /status' > /dev/null
        curl -s -X POST http://localhost:8001/rbac/roles/monitor/permissions \
            -d permissions=monitor > /dev/null         
        curl -s -X POST http://localhost:8001/rbac/users \
            -d name=monitor -d user_token=monitor
        curl -s -X POST http://localhost:8001/rbac/users/monitor/roles \
            -d roles=monitor > /dev/null
        curl -s -X POST http://localhost:8001/apis \
            -d name=status -d uris=/status -d methods=GET \
            -d upstream_url=http://localhost:8001/status > /dev/null
        curl -s -X POST http://localhost:8001/apis/status/plugins \
            -d name=request-transformer-advanced \
            -d config.add.headers=Kong-Admin-Token:monitor > /dev/null
    fi

    sv stop /etc/sv/kong 
    echo "enforce_rbac = on" >> /etc/kong/kong.conf
    sudo -u kong kong prepare
    sv start /etc/sv/kong     
fi
