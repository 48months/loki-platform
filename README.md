# Loki Logging Setup on EKS Cluster

## Overview
This document describes the centralized logging solution implemented using Grafana Loki for log aggregation and Grafana for log visualization.

## Components

- Grafana Alloy (Ship K8's container logs & metrics to Loki)
- Grafana Loki (Log Storage & Query Engine)
- Grafana UI (Log Visualization & Dashboards)
- Amazon S3 (Long-term Log Storage)

## Architecture

EKS → Grafana Alloy → Grafana Loki → S3  
Grafana UI → Grafana Loki

## Benefits

- Single agent for logs, metrics, and traces
- Native Grafana ecosystem integration
- Simpler future observability expansion
