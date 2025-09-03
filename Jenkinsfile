pipeline {
  agent any
  environment {
    APP = "parcelpro"
    ECR = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}"
    GIT_SHA = "${env.GIT_COMMIT?.take(7)}"
  }
  options { timestamps() }
  stages {
    stage('Sanity Env') {
      steps {
        sh '''
          [ -n "$AWS_REGION" ] && [ -n "$AWS_ACCOUNT_ID" ] && [ -n "$ECR_REPO" ] || { echo "Missing AWS envs"; exit 1; }
          echo "ECR: $ECR"
        '''
      }
    }
    stage('Checkout') { steps { checkout scm } }

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

    stage('Migrate (placeholder)') { steps { echo 'TODO: ecs run-task migrate' } }
    stage('Deploy (placeholder)')  { steps { echo 'TODO: ecs update-service' } }
  }
  post {
    success { echo "Build OK → $ECR:$GIT_SHA" }
    failure { echo "Build failed — check logs." }
  }
}