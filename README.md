
# Terraform — Web + Database Server Deployment

This project deploys a **web server** and a **database server** using:
- AWS EC2
- Terraform
- User data scripts for automation

---

## 📌 Project Structure

project-root/
├── main.tf
├── variables.tf
├── outputs.tf
├── terraform.tfvars.example
├── user_data/
│   ├── web_server_setup.sh
│   └── db_server_setup.sh
└── README.md



---

## 🚀 Web Server Setup (`web_server_setup.sh`)

This script:

- Updates OS
- Installs Apache
- Starts/Enables Apache service
- Creates an index page showing:
  - **EC2 Instance ID**

---

## 🗄 Database Server Setup (`db_server_setup.sh`)

This script:

- Installs PostgreSQL 14
- Initializes PostgreSQL
- Enables + starts the service
- Updates config to:
  - Listen on all network interfaces
  - Allow connections from private subnets (10.0.0.0/16)
- Creates:
  - User: **webapp**
  - Database: **techcorpdb**
  - Grants privileges

---

## 🛠 How It Works

Terraform provisions:

1. **VPC + subnets**
2. **Security groups**
3. **EC2 Web Server**
4. **EC2 DB Server**
5. Applies `user_data` scripts automatically during boot

---

## 🔍 Testing the Web Server

Visit:

http://<web-server-public-ip>

You should see a page showing the EC2 **instance ID**.

---

## 🔍 Testing DB Connection

From the web server:

```bash
psql -h <db-private-ip> -U webapp -d techcorpdb

✔ Requirements

1. Terraform

2. AWS Account

3. AWS CLI configured

4. Key pair for SSH

📌 Notes

You can modify CIDRs/passwords as needed.
These scripts work for Amazon Linux 2 only.


