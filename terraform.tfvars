region = "us-east-1"

vpc_cidr = "10.0.0.0/16"

public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnets = ["10.0.3.0/24", "10.0.4.0/24"]

azs = [] # leave empty to auto-select two available AZs

# Your provided values
keypair               = "teraform"

# instance types (optional overrides)
bastion_instance_type = "t3.micro"
web_instance_type     = "t3.micro"
db_instance_type      = "t3.small"
