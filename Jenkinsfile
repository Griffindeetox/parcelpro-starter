pipeline {
  agent any
  parameters {
    booleanParam(name: 'SKIP_DEPLOY', defaultValue: false, description: 'Tick to build/push only, skip ECS deploy')
  }
  environment {
    APP      = "parcelpro"
    // From Manage Jenkins → System → Global env vars
    // AWS_REGION, AWS_ACCOUNT_ID, ECR_REPO
    ECR      = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}"
    GIT_SHA  = "${env.GIT_COMMIT?.take(7)}"
    // ECS
    ECS_CLUSTER = "parcelpro"
    ECS_SERVICE = "parcelpro-web"
  }
  options { timestamps() }

  stages {
    stage('Sanity Env') {
      steps {
        sh '''
          set -e
          : "${AWS_REGION:?missing}"; : "${AWS_ACCOUNT_ID:?missing}"; : "${ECR_REPO:?missing}"
          echo "ECR=${ECR}"
          aws --version || true
          docker version || true
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
            set -e
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
          set -e
          docker push "$ECR:$GIT_SHA"
          docker push "$ECR:latest"
          echo "Pushed: $ECR:$GIT_SHA and :latest"
        '''
      }
    }

    stage('Deploy to ECS') {
      when { expression { return !params.SKIP_DEPLOY } }
      steps {
        withCredentials([usernamePassword(credentialsId: 'aws-creds',
                          usernameVariable: 'AWS_ACCESS_KEY_ID',
                          passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
          sh '''
            set -e
            echo "Triggering ECS rolling deploy on $ECS_CLUSTER / $ECS_SERVICE ..."
            aws ecs update-service \
              --cluster "$ECS_CLUSTER" \
              --service "$ECS_SERVICE" \
              --force-new-deployment \
              --region "$AWS_REGION"

            echo "Waiting for service to stabilize..."
            aws ecs wait services-stable \
              --cluster "$ECS_CLUSTER" \
              --services "$ECS_SERVICE" \
              --region "$AWS_REGION"

            echo "Deploy complete."
          '''
        }
      }
    }
  }

  post {
    success {
      echo "Build OK → ${ECR}:${GIT_SHA}"
      echo "Tip: Re-run with SKIP_DEPLOY=true to skip ECS step."
    }
    failure { echo "Build failed — check the stage logs above." }
  }
}