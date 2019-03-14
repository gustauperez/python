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
    stage('Artifact') {
      parallel {
        stage('Artifact') {
          steps {
            archiveArtifacts 'README.md'
          }
        }
        stage('Artifact 2') {
          steps {
            archiveArtifacts 'README.md'
          }
        }
      }
    }
  }
}