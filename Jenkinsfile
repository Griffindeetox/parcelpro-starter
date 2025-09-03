pipeline {
  agent any
  environment {
    APP = "parcelpro"
    // Set these in Global properties:
    // AWS_REGION, AWS_ACCOUNT_ID, ECR_REPO
    ECR = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}"
    GIT_SHA = "${env.GIT_COMMIT?.take(7)}"
  }
  options { timestamps() }
  stages {
    stage('Sanity Env') {
      steps {
        sh '''
          [ -n "$AWS_REGION" ] && [ -n "$AWS_ACCOUNT_ID" ] && [ -n "$ECR" ] && [ -n "$ECR_REPO" ] || { echo "Missing AWS envs"; exit 1; }
          docker version || true
        '''
      }
    }
    stage('Checkout') { steps { checkout scm } }

    stage('Install & Test (lenient for demo)') {
      steps {
        sh '''
          if [ -d src ]; then
            cd src
            composer install --prefer-dist --no-interaction || true
            php artisan test || true
            npm ci || true
            npm run build || true
          else
            echo "No ./src folder yet (ok for demo)"
          fi
        '''
      }
    }

    stage('Build Image') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'aws-creds',
                          usernameVariable: 'AWS_ACCESS_KEY_ID',
                          passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
          sh '''
            aws ecr get-login-password --region "$AWS_REGION" \
              | docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

            docker build -t "$APP:$GIT_SHA" .
            docker tag "$APP:$GIT_SHA" "$ECR:$GIT_SHA"
            docker tag "$APP:$GIT_SHA" "$ECR:latest"
          '''
        }
      }
    }

    stage('Push Image') {
      steps {
        sh '''
          docker push "$ECR:$GIT_SHA"
          docker push "$ECR:latest"
          echo "Pushed image: $ECR:$GIT_SHA"
        '''
      }
    }

    stage('Migrate (placeholder)') {
      steps { echo 'TODO: aws ecs run-task ... one-off migrate' }
    }

    stage('Deploy to ECS (placeholder)') {
      steps { echo 'TODO: aws ecs update-service ... --force-new-deployment' }
    }

    stage('Smoke Test (placeholder)') {
      steps { sh 'bash scripts/healthcheck.sh || true' }
    }
  }
  post {
    success { echo "Build OK. Image => $ECR:$GIT_SHA" }
    failure { echo "Build failed — check logs." }
  }
}