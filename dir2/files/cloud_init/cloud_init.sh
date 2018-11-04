#!/usr/bin/env bash

: ${GLOVO_APP_DIRECTORY:=/var/www/glovo-app}
: ${GLOVO_APP_JAR:=systems-engineer-interview-1.0-SNAPSHOT.jar}
: ${GLOVO_APP_URL:=https://s3-eu-west-1.amazonaws.com/glovo-public/}
: ${S3_BUCKET:=cloudformation.gustau.perez}

function enable_swap(){
         if [ ! -e /swapfile ]; then
                 fallocate -l 1G /swapfile
                 chmod 0600 /swapfile
                 mkswap /swapfile
                 swapon /swapfile
                 echo "/swapfile   none    swap    sw    0   0" >> /etc/fstab
         fi
}

function install_dependencies(){
      add-apt-repository -y ppa:webupd8team/java && \
          apt-get update && apt-get install -y nginx openjdk-8-jdk awscli
}

function copy_s3_resources(){
       aws s3 cp s3://${S3_BUCKET}/files/nginx/default /etc/nginx/sites-enabled/
       aws s3 cp s3://${S3_BUCKET}/files/systemd/glovo-app.service /etc/systemd/system/
}

function provision_app_directory(){
        [ ! -e ${GLOVO_APP_DIRECTORY} ] && mkdir -p ${GLOVO_APP_DIRECTORY}
}

function copy_http_resources(){
        pushd ${GLOVO_APP_DIRECTORY} && curl -O ${GLOVO_APP_URL}${GLOVO_APP_JAR} && \
                ln -s ${GLOVO_APP_JAR} systems-engineer-interview.jar && \
                popd
}

function create_glovo-app_user(){
        id glovo-app > /dev/null 2>&1
        [ $? -eq 1 ] && useradd glovo-app
}

function start_servers(){
      systemctl stop nginx
      systemctl start nginx
      systemctl enable glovo-app
      systemctl start glovo-app
}

install_dependencies
enable_swap
provision_app_directory
copy_http_resources
copy_s3_resources
create_glovo-app_user
start_servers
