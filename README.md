# Loki Logging Setup on EKS Cluster

## Overview
Provides centralized log collection, storage, and visualization for Amazon EKS workloads.

## Components

- Grafana Alloy (Ships K8's container logs & metrics to Loki)
- Grafana Loki (Log Storage & aggregation)
- Grafana UI (Log exploration and visualization)
- Amazon S3 (Log retention and archival)

## Architecture

EKS → Grafana Alloy → Grafana Loki → S3 bucket 
Grafana UI → Grafana Loki

## Benefits

- Single agent for logs, metrics, and traces
- Native Grafana ecosystem integration
- Simpler future observability expansion
