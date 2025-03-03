pipeline {
  environment {
    // 项目信息
    PROJECT_NAME = 'bene-website'
    REPOSITORY_URL = "https://github.com/holla-world/${PROJECT_NAME}.git"
    // Git commit id
    COMMIT_ID = "${sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()}"
    FULL_COMMIT_ID = "${sh(script: 'git rev-parse HEAD', returnStdout: true).trim()}"
    // 镜像仓库
    REGISTRY_USER = 'AWS'
    REGISTRY_URL = "751415081683.dkr.ecr.ap-southeast-1.amazonaws.com"
    IMAGE_NAME = "${REGISTRY_URL}/typing/${PROJECT_NAME}:${BRANCH_NAME}-${COMMIT_ID}"
    // Kubernetes 配置
    KUBECONFIG_PRODUCTION_CREDENTIAL_ID = 'bene-production-kubeconfig'
    KUBECONFIG_DEVELOPMENT_CREDENTIAL_ID = 'bene-development-kubeconfig'
  }

  stages {
    stage('代码克隆') {
      steps {
        git(url: env.REPOSITORY_URL, credentialsId: 'github', branch: env.BRANCH_NAME, changelog: true, poll: false)
      }
    }

    stage('服务依赖处理') {
      steps {
        container('nodejs') {
          // 打印当前目录和文件列表（调试用）
          sh '''
            echo "Current directory:"
            pwd
            echo "Files in current directory:"
            ls -lh
          '''

          // 非 stable 分支使用 build:test
          // 将 dockerfile 中的 build 替换为 build:test
          sh """
              if [ "${BRANCH_NAME}" != "stable" ]
              then
                sed -i 's/build/build:test/g' Dockerfile
              fi
          """
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
      when {
        branch 'dev'
      }
      steps {
        deployKubernetes(env.KUBECONFIG_DEVELOPMENT_CREDENTIAL_ID, 'deploy/development/')
      }
    }

    stage('部署至灰度环境') {
      when {
        branch 'staging'
      }
      steps {
        deployKubernetes(env.KUBECONFIG_PRODUCTION_CREDENTIAL_ID, 'deploy/staging/')
      }
    }

    stage('部署至生产环境') {
      when {
        branch 'stable'
      }
      steps {
        deployKubernetes(env.KUBECONFIG_PRODUCTION_CREDENTIAL_ID, 'deploy/production/')
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
      inheritFrom 'typing-ci-nodejs'
      yaml '''
apiVersion: v1
kind: Pod
metadata:
  name: typing-ci-build-nodejs
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
  - name: nodejs
    image: docker.io/node:20.12
    command:
    - cat
    tty: true
    securityContext:
        privileged: true
  - name: kubectl
    image: 751415081683.dkr.ecr.ap-southeast-1.amazonaws.com/typing/other:kubectl-arm64-1.30.8
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

// 部署 Kubernetes
def deployKubernetes(String credentialsId, String manifestDir) {
  container('kubectl') {
    withCredentials(
      [kubeconfigFile(credentialsId: credentialsId, variable: 'KUBECONFIG')]
    ) {
      sh """
        cd ${manifestDir}
        kubectl kustomize ./ > output.yaml
        sed -ie s,ARTEFACT_IMAGE,${IMAGE_NAME}, output.yaml
        kubectl apply -f output.yaml
      """
    }
  }
}

// 通知构建结果
def notifyBuildResult(boolean buildSuccessed) {
  container('kubectl') {
    sh """
        curl -X POST https://devops-bot.voya-tool.world/v1/ks/jenkins/build-result \
          -H "Content-Type: application/json" \
          -d '{"build_successed": ${buildSuccessed}, "full_commit_id": "${FULL_COMMIT_ID}", "branch_name": "${BRANCH_NAME}", "build_number": ${BUILD_NUMBER}, "duration": ${currentBuild.duration}, "job_name": "${JOB_NAME}"}'
    """
    echo "Pipeline ${buildSuccessed ? 'succeeded' : 'failed'}!"
    echo "${currentBuild.duration}"
  }
}
