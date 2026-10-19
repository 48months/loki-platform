pipeline {
  agent any

  parameters {
    choice(name: 'TARGET_ENV', choices: ['staging', 'prod'], description: 'Target environment')
    booleanParam(name: 'APPLY_TERRAFORM', defaultValue: false, description: 'Apply the Terraform plan')
    booleanParam(name: 'DEPLOY_ALLOY', defaultValue: false, description: 'Deploy or upgrade Alloy on the cluster')
  }

  options {
    timestamps()
    disableConcurrentBuilds()
    timeout(time: 60, unit: 'MINUTES')
  }

  environment {
    AWS_DEFAULT_REGION = 'eu-west-1'
    TF_IN_AUTOMATION   = 'true'
  }

  stages {
    stage('Terraform plan') {
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: (params.TARGET_ENV == 'prod' ? 'aws-prod' : 'aws_non_prod')]]) {
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

    stage('Approve prod apply') {
      when {
        allOf {
          expression { params.APPLY_TERRAFORM }
          expression { params.TARGET_ENV == 'prod' }
        }
      }
      steps {
        input message: 'Apply the Terraform plan to PRODUCTION? Check plan.txt in the build artifacts first.', ok: 'Apply'
      }
    }

    stage('Terraform apply') {
      when { expression { params.APPLY_TERRAFORM } }
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: (params.TARGET_ENV == 'prod' ? 'aws-prod' : 'aws_non_prod')]]) {
          dir('terraform') {
            sh 'terraform apply -input=false tfplan'
            sh 'echo "Loki push URL: $(terraform output -raw loki_push_url)"'
          }
        }
      }
    }

    stage('Deploy Alloy') {
      when { expression { params.DEPLOY_ALLOY } }
      environment {
        TARGET = "${params.TARGET_ENV}"
      }
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: (params.TARGET_ENV == 'prod' ? 'aws-prod' : 'aws_non_prod')]]) {
          sh '''
            . helm/alloy/versions.env
            if [ "$TARGET" = "prod" ]; then CLUSTER="$EKS_CLUSTER_PROD"; else CLUSTER="$EKS_CLUSTER_STAGING"; fi
            aws eks update-kubeconfig --region eu-west-1 --name "$CLUSTER"
            helm repo add grafana https://grafana.github.io/helm-charts --force-update
            helm repo update
            helm upgrade --install alloy grafana/alloy --version "$ALLOY_CHART_VERSION" \
              -n "$ALLOY_NAMESPACE" --create-namespace \
              -f helm/alloy/values-$TARGET.yaml \
              --set-file alloy.configMap.content=helm/alloy/config.alloy \
              --wait --timeout 5m
            kubectl -n "$ALLOY_NAMESPACE" rollout status ds/alloy --timeout=5m
          '''
        }
      }
    }
  }
}
