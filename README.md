# ParcelPro (DevOps Starter)

A GitHub-ready starter to rehearse a JD-aligned DevOps workflow (Jenkins + Docker + AWS ECS/RDS/S3 + SQS/SNS + Lambda; optional DigitalOcean).  
**You bring the Laravel app; this repo brings CI/CD, infra stubs, and runbooks.**

---

## What you get
- **Jenkinsfile**: Build → test → scan → push to ECR → migrate → deploy to ECS → smoke test
- **Dockerfile**: Multi-stage (composer/node → php-fpm) for Laravel
- **docker-compose.yml**: Local dev (php-fpm, nginx, mysql)
- **app-snippets/**: Drop-in Laravel examples (Job, Controller, routes, blade)
- **infra/** (Terraform stubs): ECR, ECS, IAM, VPC, RDS, S3, SQS/SNS, Lambda (thumbnail)
- **docs/**: Architecture, Release checklist, Runbooks

---

## Quickstart
1. Add a Laravel app under `src/`
2. Copy snippets from `app-snippets/`
3. Run locally with Docker Compose
4. Deploy via Jenkins → AWS ECS/ECR