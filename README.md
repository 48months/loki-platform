# Loki logging platform

Infrastructure and deployment code for Loki (monolithic mode, m5 hosts only) and Grafana Alloy
(the only log collector). Source is in GitHub. Pipelines run in Jenkins.

## Layout

| Path | Purpose |
|---|---|
| `terraform/` | S3 bucket (90-day retention via compactor, backstop lifecycle), IAM role, security group, Loki EC2 host |
| `terraform/templates/` | Loki config and user data rendered into the host at boot |
| `terraform/envs/` | Per-environment variables and S3 backend settings |
| `helm/alloy/` | Alloy pipeline (`config.alloy`) and per-environment values |
| `jenkins/Jenkinsfile` | Validate, plan, approve (prod), apply, deploy Alloy, smoke test |

## Flow

1. Push to GitHub; the Multibranch Pipeline runs Validate and Terraform plan.
2. Review `plan.txt` in the build artifacts.
3. Re-run with `APPLY_TERRAFORM` for staging, or approve the prod gate.
4. Deploy Alloy to the EKS cluster for that environment.
5. Smoke test checks Loki `/ready`.

## Migration waves

Alloy only ships namespaces matched by `LOG_NAMESPACE_REGEX` in the values file. Each wave widens
the regex, then the CloudWatch output is removed for those namespaces. This is what makes each
namespace move to exactly one destination.

## Before the first run (placeholders to replace)

- `terraform/envs/*.tfvars`: VPC, subnet and security group IDs, bucket names, `loki_sha256`.
- `terraform/envs/*.backend.hcl`: state bucket.
- `jenkins/Jenkinsfile`: `ALLOY_CHART_VERSION` and the staging EKS cluster name.
- `helm/alloy/values-*.yaml`: `LOKI_PUSH_URL` (from the Terraform output `loki_push_url`) and `LOG_NAMESPACE_REGEX`.
- Jenkins credentials `aws-staging` and `aws-prod`, and an agent labelled `terraform-helm` with terraform, helm, kubectl, aws CLI and curl.

## Open items to verify

- Loki 3.4.2 is the default version. Confirm it, and set `loki_sha256` from the release checksums.
- Confirm the Loki config keys against the pinned release in staging (the `tsdb_shipper` and compactor keys).
- Alloy `loki.write` WAL: the document caps the WAL at 3 GB per node. Confirm which setting enforces the cap in the Alloy release in use. `max_segment_age` is a placeholder until then.
- The Loki host needs egress to download the release: a NAT gateway or an approved proxy.
- Terraform 1.10 or later is required for `use_lockfile` (S3 locking).
