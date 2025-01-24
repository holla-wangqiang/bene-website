pipeline {
  environment {
    // 项目信息
    PROJECT_NAME = ''
    REPOSITORY_URL = "https://github.com/holla-world/${PROJECT_NAME}.git"
    // Kubernetes 配置
    KUBECONFIG_PRODUCTION_CREDENTIAL_ID = 'bene-production-kubeconfig'
    KUBECONFIG_DEVELOPMENT_CREDENTIAL_ID = 'bene-development-kubeconfig'
    // Git commit id
    COMMIT_ID = "${sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()}"
    FULL_COMMIT_ID = "${sh(script: 'git rev-parse HEAD', returnStdout: true).trim()}"
    // 镜像仓库
    REGISTRY_USER = 'AWS'
    REGISTRY_URL = "751415081683.dkr.ecr.ap-southeast-1.amazonaws.com"
    IMAGE_NAME = "${REGISTRY_URL}/typing/${PROJECT_NAME}:${BRANCH_NAME}-${COMMIT_ID}"
  }

  stages {
    stage('代码克隆') {
      steps {
        git(url: env.REPOSITORY_URL, credentialsId: 'github', branch: "$BRANCH_NAME", changelog: true, poll: false)
      }
    }

    stage('处理依赖并执行构建') {
      steps {
        container('builder') {
          // 打印当前目录和文件列表（调试用）
          sh '''
            echo "Current directory:"
            pwd
            echo "Files in current directory:"
            ls -lh
          '''

          // 依赖下载
          withCredentials([usernamePassword(credentialsId: 'github', passwordVariable: 'PASSWD', usernameVariable: 'USER')]) {
            sh '''
              apk add git
              git config --global url."https://${USER}:${PASSWD}@github.com".insteadOf "https://github.com"
              go mod download
            '''
          }

          // 执行构建
          sh 'go build -ldflags="-s -w" -o main ./main.go'
        }
      }
    }

    stage('获取镜像仓库令牌') {
      steps {
        container('podman') {
          sh '''
            aws ecr get-login-password | \
            podman login --username $REGISTRY_USER --password-stdin $REGISTRY_URL
          '''
        }
      }
    }

    stage('构建并推送镜像') {
      steps {
        container('podman') {
          sh """
            podman build --format docker -t $IMAGE_NAME -f Dockerfile .
            podman push $IMAGE_NAME
          """
          echo env.IMAGE_NAME
        }
      }
    }

    stage('部署至测试环境') {
      when{
        branch 'dev'
      }
      steps {
        container('kubectl') {
          withCredentials(
            [kubeconfigFile(credentialsId: env.KUBECONFIG_DEVELOPMENT_CREDENTIAL_ID, variable: 'KUBECONFIG')]
          ) {
            sh """
              cd deploy/development/
              kubectl kustomize ./ > output.yaml
              envsubst < output.yaml | kubectl apply -f -
            """
          }
        }
      }
    }

    stage('部署至灰度环境') {
      when{
        branch 'staging'
      }
      steps {
        container('kubectl') {
          withCredentials(
            [kubeconfigFile(credentialsId: env.KUBECONFIG_PRODUCTION_CREDENTIAL_ID, variable: 'KUBECONFIG')]
          ) {
            sh """
              cd deploy/staging/
              kubectl kustomize ./ > output.yaml
              envsubst < output.yaml | kubectl apply -f -
            """
          }
        }
      }
    }

    stage('部署至生产环境') {
      when{
        branch 'stable'
      }
      steps {
        container('kubectl') {
          withCredentials(
            [kubeconfigFile(credentialsId: env.KUBECONFIG_PRODUCTION_CREDENTIAL_ID, variable: 'KUBECONFIG')]
          ) {
            sh """
              cd deploy/production/
              kubectl kustomize ./ > output.yaml
              envsubst < output.yaml | kubectl apply -f -
            """
          }
        }
      }
    }
  }

  post {
    success {
      notifyBuildResult(true)
    }

    failure {
      notifyBuildResult(false)
    }
  }

  // 运行环境
  agent {
    kubernetes {
      label 'typing-ci-go'
      yaml '''
apiVersion: v1
kind: Pod
metadata:
  name: typing-ci-build
spec:
  containers:
  - name: podman
    image: 751415081683.dkr.ecr.ap-southeast-1.amazonaws.com/typing/other:podman-20250115
    imagePullPolicy: IfNotPresent
    command:
    - cat
    tty: true
    securityContext:
        privileged: true
    volumeMounts:
    - name: storage
      mountPath: /var/lib/containers
    - name: aws-ecr-credential
      mountPath: /root/.aws/credentials
      subPath: credentials
    - name: aws-ecr-credential
      mountPath: /root/.aws/config
      subPath: config
  - name: builder
    image: golang:1.22.4-alpine
    command:
    - cat
    tty: true
    securityContext:
        privileged: true
  - name: kubectl
    image: 751415081683.dkr.ecr.ap-southeast-1.amazonaws.com/typing/other:kubectl-arm64-1.30.8
    imagePullPolicy: Always
    command:
    - cat
    tty: true
    securityContext:
        privileged: true
  volumes:
  - name: storage
    hostPath:
      path: /var/lib/containers
  - name: aws-ecr-credential
    configMap:
      name: aws-ecr-credential
'''
    }
  }
}

// 通知构建结果
def notifyBuildResult(boolean buildSuccessed) {
  container('kubectl') {
    sh """
        curl -X POST https://devops-bot.voya-tool.world/v1/ks/jenkins/build-result \
          -H "Content-Type: application/json" \
          -d '{"build_successed": ${buildSuccessed}, "full_commit_id": "${FULL_COMMIT_ID}", "branch_name": "${BRANCH_NAME}", "build_number": ${BUILD_NUMBER}, "duration": ${currentBuild.duration}}'
    """
    echo "Pipeline ${buildSuccessed ? 'succeeded' : 'failed'}!"
    echo "${currentBuild.duration}"
  }
}
