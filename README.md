# Loki logging (staging)

Loki runs on one EC2 instance (m5.medium) in monolithic mode. Logs are stored in S3 for 90 days. Grafana Alloy runs on the EKS nodes and sends logs to Loki.
