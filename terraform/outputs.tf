output "loki_instance_id" {
  value = aws_instance.loki.id
}

output "loki_private_ip" {
  value = aws_instance.loki.private_ip
}

output "loki_push_url" {
  description = "Alloy pushes to this URL."
  value       = "http://${aws_instance.loki.private_ip}:3100/loki/api/v1/push"
}

output "loki_ready_url" {
  description = "Readiness endpoint, used by the Jenkins smoke test."
  value       = "http://${aws_instance.loki.private_ip}:3100/ready"
}

output "loki_bucket" {
  value = aws_s3_bucket.loki.id
}
