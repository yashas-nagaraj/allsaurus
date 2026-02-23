# 🦖 Project Allsaurus: Stranger Things 3-Tier Cloud App

## 📖 Overview
Project Allsaurus is a production-grade, 3-tier cloud-native application deployed entirely on AWS. Themed around "Stranger Things," it allows users to browse season information and submit community questions. 

This project demonstrates modern DevOps practices, including Infrastructure as Code (IaC), containerization, zero-touch Kubernetes orchestration, and automated CI/CD pipelines.



## 🏗️ Architecture Design
1. **Frontend Tier (Presentation):** An HTML/JS/CSS web application hosted on Nginx. Deployed as a Kubernetes Deployment and exposed to the internet via an AWS Classic Load Balancer.
2. **Backend Tier (Application Logic):** A Python Flask API that handles CORS, routing, and database connections. Deployed as a K8s Deployment.
3. **Database Tier (Data Layer):** An AWS RDS MySQL 8.0 instance securely placed in private subnets. It only accepts traffic on port 3306 from the EKS Node Security Group.
4. **CI/CD Pipeline:** A dedicated EC2 instance running Jenkins automates the entire lifecycle: provisioning infrastructure (Terraform), building images (Docker), and deploying workloads (Kubectl/Helm).
5. **Observability:** Prometheus and Grafana deployed via Helm to track cluster CPU, memory, and pod health in real-time.

---

## 🛠️ Tech Stack
* **Cloud Provider:** AWS (EKS, EC2, RDS, VPC, ELB)
* **Infrastructure as Code:** Terraform (HCL)
* **CI/CD:** Jenkins (Declarative Groovy Pipelines)
* **Containerization:** Docker & DockerHub
* **Orchestration:** Kubernetes (Deployments, Services, Secrets, Jobs)
* **Observability:** Helm, Prometheus, Grafana
* **Languages:** Python (Flask), Bash, HTML/JS/CSS

---

## 📂 Repository Structure
```text
allsaurus/
├── backend/
│   ├── app.py              # Python Flask API logic
│   ├── requirements.txt    # Python dependencies
│   └── Dockerfile          # Backend container build instructions
├── frontend/
│   ├── index.html          # UI (Contains dynamic BACKEND_URL_PLACEHOLDER)
│   ├── default.conf        # Nginx configuration (Port 80)
│   └── Dockerfile          # Frontend container build instructions
├── infra/
│   └── main.tf             # Terraform code (VPC, EKS via t3.small nodes, RDS)
├── k8s/
│   ├── backend.yaml        # K8s Deployment & Service for Backend
│   ├── frontend.yaml       # K8s Deployment & Service for Frontend
│   └── db-init-job.yaml    # K8s Job to create MySQL tables on startup
└── Jenkinsfile             # Declarative multi-stage CI/CD Pipeline
