output "public_ip" {
  value = aws_instance.zomato-prod-frontend[*].public_ip
}

output "instance_id" {
  value = aws_instance.zomato-prod-frontend[*].id
}