# 3-tier-user-platform-project

## Project Overview

This project demonstrates the design and implementation of a production-style DevOps platform for a 3-tier web application consisting of a React frontend, Node.js backend, and MySQL database. The project covers the complete software delivery lifecycle, from developer changes and code review through automated CI/CD, security and quality gates, containerization, Kubernetes deployment, QA validation, and production promotion.

The application runs on Amazon EKS with separate QA and Production environments. GitHub Actions automates the CI/CD process, while GitLeaks, Checkov, Trivy, SonarQube, and SBOM generation provide security and code-quality checks before deployment. Docker images are built with immutable commit-SHA tags and promoted from QA to Production without rebuilding the application.

The platform also implements secure AWS authentication using GitHub OIDC and IAM roles, persistent MySQL storage using Amazon EBS, external secret management through AWS Secrets Manager and External Secrets Operator, and external application access through AWS Load Balancer Controller, Route 53, and ACM. Prometheus, Loki, Grafana Alloy, and Grafana provide monitoring, logging, and operational visibility across the deployed environment.

<img width="1182" height="1330" alt="image" src="https://github.com/user-attachments/assets/c6671ae1-f126-4cec-8204-c2afb3773394" />

### The following workflow describes how a code change moves through the complete system from development to production.

## 1. Development

A developer first receives a requirement and creates a feature branch from the `qa` branch. The developer makes the required changes to the React frontend or Node.js backend and tests the application locally with MySQL.

When the change is ready, the developer pushes the feature branch and creates a pull request into `qa`. The change goes through code review before becoming part of the QA codebase.

## 2. QA CI Pipeline

Once the change reaches the `qa` branch, GitHub Actions detects the relevant change and starts the QA CI pipeline on a runner.

The pipeline first checks the source for leaked secrets using GitLeaks. It then checks Dockerfiles, Kubernetes manifests, and infrastructure configuration using Checkov, scans application dependencies using Trivy, runs linting and tests, performs deeper code-quality analysis through SonarQube, builds the frontend, generates an SBOM, builds the Docker image, and scans the resulting image for vulnerabilities.

If any required gate fails, the pipeline stops and the developer fixes the problem. If everything passes, the Docker image is tagged with the commit SHA and pushed to the private container registry.

The pipeline then updates the Kubernetes deployment manifest with that image tag and deploys the application to the QA namespace of the EKS cluster.

## 3. QA Environment

Inside EKS, Kubernetes pulls the image from the registry and starts the application Pods. The Node.js application connects to MySQL through the Kubernetes Service.

MySQL runs as a StatefulSet because it is stateful. Its data is stored on persistent EBS storage through a PVC and StorageClass, so the data survives Pod restarts.

Database credentials are not stored directly in the application code or Git repository. AWS Secrets Manager stores the real credentials, External Secrets Operator retrieves them using the cluster's IAM identity mechanism, and creates the Kubernetes Secret consumed by the application.

For external access, the AWS Load Balancer Controller watches the Kubernetes Ingress resource and creates/configures an AWS Application Load Balancer. Route 53 handles DNS, while ACM provides the HTTPS certificate, allowing users to access the QA application through the configured domain.

## 4. QA Testing and Promotion

QA testers use the deployed application and verify that it works correctly. If they find a problem, a bugfix branch is created from QA, the fix goes through the same CI/CD process, and QA tests the application again.

Once QA signs off, the approved code is merged into `main`, which represents the production environment.

## 5. Production Deployment

The production pipeline does not rebuild the application because that could create a different artifact. Instead, it takes the exact Docker image that was already built, scanned, and tested in QA.

The image is retagged as the production image, pushed to the registry, and used to update the production Kubernetes deployment manifest. The application is then deployed to the production environment.

This provides an artifact-promotion model where the same image that passed the QA process is promoted to production rather than creating a new build.

## 6. Secure AWS Access

GitHub Actions does not use permanent AWS access keys for the deployment. GitHub generates an OIDC token, AWS validates the token against the production IAM trust policy, and the workflow receives temporary credentials for a production-specific IAM role.

EKS authorization limits that role to the production namespace. This means the QA pipeline cannot simply obtain production permissions.

Once deployed, the production application connects to the production MySQL workload. Its credentials come from the production AWS Secrets Manager secret through External Secrets Operator, while its data is stored persistently on EBS.

## 7. Production Request Flow

Users reach the production application through the custom domain. The request flows through Route 53, HTTPS/ACM, the AWS Application Load Balancer, Kubernetes Ingress, the application Service, and finally the application Pods.

The application then communicates with MySQL through the Kubernetes Service, completing the request path inside the EKS cluster.

## 8. Observability

After deployment, the observability stack continuously collects information from the running system.

Prometheus collects metrics to show what is happening inside the system. Loki collects logs to show what the application reported. Grafana Alloy collects and routes telemetry to the appropriate backend.

Grafana brings these signals together so an engineer can view system health, investigate historical problems, analyze application logs, and understand what happened in the environment.

## 9. Complete System Flow

The complete system works as a continuous delivery chain:

**Developer → Feature Branch → Pull Request → QA → GitHub Actions → Security & Quality Gates → Docker Image → Container Registry → EKS QA → QA Testing → QA Approval → `main` → Production → Users → Monitoring & Logging**

GitHub controls the source code and automation, AWS provides the infrastructure and identity, Docker provides the deployable artifact, Kubernetes runs the application workloads, and Grafana provides operational visibility into the running system.
