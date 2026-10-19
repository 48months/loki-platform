# Loki Logging Stack

**Purpose:** Centralized log aggregation for EKS workloads.

**Flow:**  
EKS Pods → Fluent Bit → Loki → S3  
Grafana → Loki

**Infrastructure**
- Staging: `m8g.medium`, `20 GB EBS`
- Production: `m8g.large`, `50 GB EBS`
- Log Retention: `90 Days`
- Storage: `Amazon S3`
