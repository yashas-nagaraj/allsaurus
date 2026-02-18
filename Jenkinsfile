pipeline {
    agent any
    environment {
        AWS_REGION = 'ap-south-1'
        DOCKER_CREDS = credentials('dockerhub-login')
    }
    stages {
        stage('1. Terraform Infra') {
            steps {
                dir('infra') {
                    sh 'terraform init'
                    // Create everything. This might take 20 mins the first time!
                    sh 'terraform apply -auto-approve'
                    // Capture the RDS Endpoint for later
                    script {
                        env.DB_ENDPOINT = sh(script: "terraform output -raw rds_endpoint", returnStdout: true).trim()
                        env.CLUSTER_NAME = sh(script: "terraform output -raw cluster_name", returnStdout: true).trim()
                    }
                }
            }
        }

        stage('2. K8s Config') {
            steps {
                // Update kubectl to talk to the new cluster
                sh "aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}"
                
                // Create Secret for DB Host
                sh """
                kubectl create secret generic db-secret \
                  --from-literal=host=${DB_ENDPOINT} \
                  --from-literal=password=strangerpassword \
                  --dry-run=client -o yaml | kubectl apply -f -
                """
            }
        }

        stage('3. Init Database') {
            steps {
                // Run the Job to create tables (question_text/answer_text)
                sh 'kubectl apply -f k8s/db-init-job.yaml'
            }
        }

        stage('4. Build & Push') {
            steps {
                script {
                    docker.withRegistry('', 'dockerhub-login') {
                        sh "docker build -t yashasnagaraj/stranger-backend:${BUILD_NUMBER} ./backend"
                        sh "docker push yashasnagaraj/stranger-backend:${BUILD_NUMBER}"
                        
                        sh "docker build -t yashasnagaraj/stranger-frontend:${BUILD_NUMBER} ./frontend"
                        sh "docker push yashasnagaraj/stranger-frontend:${BUILD_NUMBER}"
                    }
                }
            }
        }

        stage('5. Deploy App') {
            steps {
                // Update manifest with new image tag
                sh "sed -i 's|yashasnagaraj/stranger-backend:latest|yashasnagaraj/stranger-backend:${BUILD_NUMBER}|g' k8s/backend.yaml"
                sh "sed -i 's|yashasnagaraj/stranger-frontend:latest|yashasnagaraj/stranger-frontend:${BUILD_NUMBER}|g' k8s/frontend.yaml"
                
                sh 'kubectl apply -f k8s/backend.yaml'
                sh 'kubectl apply -f k8s/frontend.yaml'
            }
        }

        stage('6. Deploy Monitoring') {
            steps {
                // Install Prometheus & Grafana using Helm
                sh 'helm repo add prometheus-community https://prometheus-community.github.io/helm-charts'
                sh 'helm repo update'
                sh 'helm upgrade --install monitoring prometheus-community/kube-prometheus-stack'
            }
        }
    }
}
