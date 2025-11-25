output "vpc_id" {
  value = aws_vpc.main.id
}

output "bastion_public_ip" {
  value       = aws_eip.bastion_eip.public_ip
  description = "Public IP to SSH into bastion"
}

output "alb_dns_name" {
  value       = aws_lb.alb.dns_name
  description = "Application Load Balancer DNS name"
}

output "web_private_ips" {
  value = [for i in aws_instance.web : i.private_ip]
}

output "db_private_ip" {
  value = aws_instance.db.private_ip
}
