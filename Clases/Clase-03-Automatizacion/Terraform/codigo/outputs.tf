output "ip_publica" {
  value = aws_instance.servidor.public_ip
}

output "zona" {
  value = aws_instance.servidor.availability_zone
}
