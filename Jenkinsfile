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
                    sh 'terraform apply -auto-approve'
                    script {
                        env.DB_ENDPOINT = sh(script: "terraform output -raw rds_endpoint", returnStdout: true).trim()
                        env.CLUSTER_NAME = sh(script: "terraform output -raw cluster_name", returnStdout: true).trim()
                    }
                }
            }
        }

        stage('2. K8s Config') {
            steps {
                sh "aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}"
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
                sh 'kubectl delete -f k8s/db-init-job.yaml --ignore-not-found=true'
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
                sh "sed -i 's|image: yashasnagaraj/stranger-backend:.*|image: yashasnagaraj/stranger-backend:${BUILD_NUMBER}|g' k8s/backend.yaml"
                sh 'kubectl apply -f k8s/backend.yaml'
            }
        }

        stage('5. Inject URL & Deploy Frontend') {
            steps {
                sh """
                echo "Waiting for Backend LoadBalancer..."
                BACKEND_ELB=\$(kubectl get svc backend-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
                while [ -z "\$BACKEND_ELB" ]; do
                    sleep 10
                    BACKEND_ELB=\$(kubectl get svc backend-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
                done
                
                # THE BULLETPROOF FIX: No spaces to confuse the shell!
                sed -i "s|BACKEND_URL_PLACEHOLDER|\$BACKEND_ELB|g" frontend/index.html
                """

                script {
                    docker.withRegistry('', 'dockerhub-login') {
                        sh "docker build -t yashasnagaraj/stranger-frontend:${BUILD_NUMBER} ./frontend"
                        sh "docker push yashasnagaraj/stranger-frontend:${BUILD_NUMBER}"
                    }
                }
                
                sh "sed -i 's|image: yashasnagaraj/stranger-frontend:.*|image: yashasnagaraj/stranger-frontend:${BUILD_NUMBER}|g' k8s/frontend.yaml"
                sh 'kubectl apply -f k8s/frontend.yaml'
            }
        }
        
        // Stage 6 removed to save EKS memory and ensure pipeline success!
    }
}
