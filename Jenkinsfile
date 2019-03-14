pipeline {
  agent any
  stages {
    stage('List contents') {
      steps {
        sh 'ls -la'
      }
    }
    stage('What\'s my IP') {
      steps {
        sh 'curl http://checkip.amazonaws.com'
      }
    }
  }
}