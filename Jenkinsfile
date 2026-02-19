pipeline {
    agent any
    environment {
        AWS_REGION = 'ap-south-1'
        // This must match the ID of the credential you create in Jenkins exactly
        DOCKER_CREDS = credentials('dockerhub-login') 
    }
    stages {
        stage('1. Terraform Infra') {
            steps {
                dir('infra') {
                    sh 'terraform init'
                    // Create everything. This might take 20 mins the first time!
                    sh 'terraform apply -auto-approve'
                    // Capture the RDS Endpoint and Cluster Name for later
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
                // Delete the old job if it exists so the pipeline doesn't fail on re-runs
                sh 'kubectl delete -f k8s/db-init-job.yaml --ignore-not-found=true'
                // Run the Job to create tables (question_text/answer_text)
                sh 'kubectl apply -f k8s/db-init-job.yaml'
            }
        }

        stage('4. Build & Deploy Backend') {
            steps {
                script {
                    docker.withRegistry('', 'dockerhub-login') {
                        sh "docker build -t yashasnagaraj/stranger-backend:${BUILD_NUMBER} ./backend"
                        sh "docker push yashasnagaraj/stranger-backend:${BUILD_NUMBER}"
                    }
                }
                // Deploy Backend immediately so AWS starts building the Load Balancer
                sh "sed -i 's|yashasnagaraj/stranger-backend:latest|yashasnagaraj/stranger-backend:${BUILD_NUMBER}|g' k8s/backend.yaml"
                sh 'kubectl apply -f k8s/backend.yaml'
            }
        }

        stage('5. Inject URL & Deploy Frontend') {
            steps {
                // 1. Wait for AWS to give us the Load Balancer URL
                sh """
                echo "Waiting for Backend LoadBalancer to provision (can take 2-3 mins)..."
                
                # Loop until the hostname is not empty
                BACKEND_ELB=\$(kubectl get svc backend-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
                while [ -z "\$BACKEND_ELB" ]; do
                    echo "Still waiting..."
                    sleep 15
                    BACKEND_ELB=\$(kubectl get svc backend-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
                done
                
                echo "Success! Backend API is at: http://\$BACKEND_ELB:5000/api"
                
                # 2. Inject this exact URL into your index.html
                sed -i "s|const API = .*|const API = \\"http://\$BACKEND_ELB:5000/api\\";|g" frontend/index.html
                """

                // 3. NOW build the frontend (with the correct URL baked inside)
                script {
                    docker.withRegistry('', 'dockerhub-login') {
                        sh "docker build -t yashasnagaraj/stranger-frontend:${BUILD_NUMBER} ./frontend"
                        sh "docker push yashasnagaraj/stranger-frontend:${BUILD_NUMBER}"
                    }
                }
                
                // 4. Deploy Frontend
                sh "sed -i 's|yashasnagaraj/stranger-frontend:latest|yashasnagaraj/stranger-frontend:${BUILD_NUMBER}|g' k8s/frontend.yaml"
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
