#!/bin/bash

# Update packages
sudo yum update -y

# Install PostgreSQL (Amazon Linux 2)
sudo amazon-linux-extras install -y postgresql14
sudo yum install -y postgresql-server postgresql-contrib

# Initialize database (path may vary)
sudo postgresql-setup --initdb

# Enable and start PostgreSQL
sudo systemctl enable postgresql
sudo systemctl start postgresql

# Allow all private subnets inside the VPC
echo "host    all     all     10.0.0.0/16     md5" | sudo tee -a /var/lib/pgsql/data/pg_hba.conf

# Listen on all interfaces
sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" /var/lib/pgsql/data/postgresql.conf

# Restart PostgreSQL
sudo systemctl restart postgresql

# Create database and user
sudo -u postgres psql <<EOF
CREATE USER webapp WITH PASSWORD 'TechCorpPass123';
CREATE DATABASE techcorpdb OWNER webapp;
GRANT ALL PRIVILEGES ON DATABASE techcorpdb TO webapp;
EOF