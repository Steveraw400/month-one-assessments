#!/bin/bash

sudo yum update -y
sudo yum install -y httpd

sudo systemctl enable httpd
sudo systemctl start httpd

INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

sudo cat <<EOF > /var/www/html/index.html
<html>
<h1>Web Server is Running</h1>
<p>Instance ID: $INSTANCE_ID</p>

</html>
EOF