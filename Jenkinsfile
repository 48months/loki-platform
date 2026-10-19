pipeline {
  agent any

  parameters {
    choice(name: 'TARGET_ENV', choices: ['staging', 'prod'], description: 'Environment to act on')
    choice(name: 'ACTION', choices: [
      'loki-plan',     // show Terraform changes for the Loki host (no changes made)
      'loki-apply',    // create or update the Loki host
      'loki-destroy',  // destroy the Loki EC2 instance only (keeps bucket, IAM, security group)
      'alloy-plan',    // show what Helm would install or change for Alloy (no changes made)
      'alloy-deploy',  // install or upgrade Alloy and show its status
      'alloy-remove'   // uninstall Alloy and show its status
    ], description: 'What to do')
    string(name: 'CONFIRM', defaultValue: '', description: 'Type DESTROY to run loki-destroy or alloy-remove. Leave blank otherwise.')
  }

  options { timestamps(); disableConcurrentBuilds(); timeout(time: 60, unit: 'MINUTES') }

  environment {
    AWS_DEFAULT_REGION = 'eu-west-1'
    TF_IN_AUTOMATION   = 'true'
    TARGET             = "${params.TARGET_ENV}"
    AWS_CREDS_ID       = "${params.TARGET_ENV == 'prod' ? 'aws-prod' : 'aws_non_prod'}"
  }

  stages {

    stage('Validate') {
      steps {
        script {
          if (params.ACTION in ['loki-destroy', 'alloy-remove'] && params.CONFIRM != 'DESTROY') {
            error("ACTION ${params.ACTION} needs CONFIRM set to DESTROY")
          }
          echo "Running ${params.ACTION} on ${params.TARGET_ENV}"
        }
      }
    }

    // ---------------- Loki host (Terraform) ----------------

    stage('Loki plan') {
      when { expression { params.ACTION in ['loki-plan', 'loki-apply'] } }
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: env.AWS_CREDS_ID]]) {
          dir('terraform') {
            sh "terraform init -input=false -reconfigure -backend-config=envs/${params.TARGET_ENV}.backend.hcl"
            script {
              def inState = sh(script: "terraform state list | grep -q '^aws_s3_bucket.loki\$'", returnStatus: true) == 0
              if (!inState) {
                def bucket = sh(script: "grep '^bucket_name' envs/${params.TARGET_ENV}.tfvars | cut -d'\"' -f2", returnStdout: true).trim()
                sh "terraform import -input=false -var-file=envs/${params.TARGET_ENV}.tfvars aws_s3_bucket.loki '${bucket}'"
              }
            }
            sh "terraform plan -input=false -var-file=envs/${params.TARGET_ENV}.tfvars -out=tfplan"
            sh 'terraform show -no-color tfplan > plan.txt'
            archiveArtifacts artifacts: 'plan.txt', fingerprint: true
          }
        }
      }
    }

    stage('Loki apply') {
      when { expression { params.ACTION == 'loki-apply' } }
      steps {
        script {
          if (params.TARGET_ENV == 'prod') {
            input message: 'Approve Loki apply on PROD?', ok: 'Apply'
          }
        }
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: env.AWS_CREDS_ID]]) {
          dir('terraform') {
            sh 'terraform apply -input=false tfplan'
            sh 'echo "Loki push URL: $(terraform output -raw loki_push_url)"'
            sh 'echo "Loki private IP: $(terraform output -raw loki_private_ip)"'
          }
        }
      }
    }

    stage('Loki destroy') {
      when { expression { params.ACTION == 'loki-destroy' } }
      steps {
        script {
          if (params.TARGET_ENV == 'prod') {
            input message: 'Approve Loki INSTANCE destroy on PROD?', ok: 'Destroy'
          }
        }
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: env.AWS_CREDS_ID]]) {
          dir('terraform') {
            sh "terraform init -input=false -reconfigure -backend-config=envs/${params.TARGET_ENV}.backend.hcl"
            sh "terraform destroy -input=false -auto-approve -target=aws_instance.loki -var-file=envs/${params.TARGET_ENV}.tfvars"
            sh 'echo "Loki instance destroyed. Bucket, IAM role and security group were kept."'
          }
        }
      }
    }

    // ---------------- Alloy (Helm) ----------------

    stage('Alloy plan') {
      when { expression { params.ACTION in ['alloy-plan', 'alloy-deploy'] } }
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: env.AWS_CREDS_ID]]) {
          sh '''
            set -eu
            . helm/alloy/versions.env
            if [ "$TARGET" = "prod" ]; then CLUSTER="$EKS_CLUSTER_PROD"; else CLUSTER="$EKS_CLUSTER_STAGING"; fi
            aws eks update-kubeconfig --region eu-west-1 --name "$CLUSTER"
            helm repo add grafana https://grafana.github.io/helm-charts --force-update
            helm repo update
            helm upgrade --install alloy grafana/alloy --version "$ALLOY_CHART_VERSION" -n "$ALLOY_NAMESPACE" --create-namespace -f helm/alloy/values-$TARGET.yaml --set-file alloy.configMap.content=helm/alloy/config.alloy --dry-run > alloy-plan.txt
            echo "Alloy plan written to alloy-plan.txt"
            helm list -n "$ALLOY_NAMESPACE"
          '''
          archiveArtifacts artifacts: 'alloy-plan.txt', fingerprint: true
        }
      }
    }

    stage('Alloy deploy') {
      when { expression { params.ACTION == 'alloy-deploy' } }
      steps {
        script {
          if (params.TARGET_ENV == 'prod') {
            input message: 'Approve Alloy deploy on PROD?', ok: 'Deploy'
          }
        }
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: env.AWS_CREDS_ID]]) {
          sh '''
            set -eu
            . helm/alloy/versions.env
            if [ "$TARGET" = "prod" ]; then CLUSTER="$EKS_CLUSTER_PROD"; else CLUSTER="$EKS_CLUSTER_STAGING"; fi
            aws eks update-kubeconfig --region eu-west-1 --name "$CLUSTER"
            helm repo add grafana https://grafana.github.io/helm-charts --force-update
            helm repo update
            helm upgrade --install alloy grafana/alloy --version "$ALLOY_CHART_VERSION" -n "$ALLOY_NAMESPACE" --create-namespace -f helm/alloy/values-$TARGET.yaml --set-file alloy.configMap.content=helm/alloy/config.alloy --wait --timeout 5m
            echo "--- Helm status ---"
            helm status alloy -n "$ALLOY_NAMESPACE"
            echo "--- DaemonSet status ---"
            kubectl -n "$ALLOY_NAMESPACE" get ds alloy
            kubectl -n "$ALLOY_NAMESPACE" rollout status ds/alloy --timeout=5m
          '''
        }
      }
    }

    stage('Alloy remove') {
      when { expression { params.ACTION == 'alloy-remove' } }
      steps {
        script {
          if (params.TARGET_ENV == 'prod') {
            input message: 'Approve Alloy REMOVAL on PROD?', ok: 'Remove'
          }
        }
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: env.AWS_CREDS_ID]]) {
          sh '''
            set -eu
            . helm/alloy/versions.env
            if [ "$TARGET" = "prod" ]; then CLUSTER="$EKS_CLUSTER_PROD"; else CLUSTER="$EKS_CLUSTER_STAGING"; fi
            aws eks update-kubeconfig --region eu-west-1 --name "$CLUSTER"
            helm uninstall alloy -n "$ALLOY_NAMESPACE" || echo "Alloy release was not installed"
            echo "--- Remaining releases ---"
            helm list -n "$ALLOY_NAMESPACE"
            echo "--- DaemonSet check (should say NotFound) ---"
            kubectl -n "$ALLOY_NAMESPACE" get ds alloy || true
          '''
        }
      }
    }
  }
}
