#!/usr/bin/env bash

: ${BUILD_NUMBER:=1}
: ${PROFILE:=default}
: ${SG_VALUE:=sg-00cb6fd66209c6f64}
: ${AMIID:=ami-0bdf93799014acdc4}
: ${INSTANCETYPE=t2.micro}
: ${KP:=gusikp}
: ${SUBNETS:=subnet-49633d04,subnet-4e92d933,subnet-ad001cc6}
: ${MINSIZE:=1}
: ${DESIREDCAPACITY:=2}
: ${MAXSIZE:=3}
: ${AWSCERTIFICATE:=AWSCertificate}
: ${DNSRECORD:=www.candidate.gustau.perez}
: ${CLOUD_INIT_PATH:=files/cloud_init/cloud_init.sh}

yell() { tput setaf 1; echo "$0: $*" >&2; tput init; }
simple_yell() { tput setaf 1; echo "$*" >&2; tput init; }
die() { yell "$*"; exit 111; }
try() { "$@" || die "cannot $*"; }

function usage(){
     cat <<FI_CAT
 This script will deploy or update a glovo-app stack. Usage:

         ./glovo-app-cf.sh {-t create-stack | update-stack }

 You can use the following environment variables to control the behaviour of the script:

    BUILD_NUMBER:       To set the version of the ASG and the instances (defaults to 1)
    PROFILE:            AWS profile to use (defaults to the defalult profile)
    SG_VALUE:           Comma delimited list of security groups to use
    AMIID:              AMI ID to use (defaults to Amazon's stock Ubuntu 18.04LTS)
    INSTANCETYPE:       Instance type (defaults to t2.micro)
    KP:                 Keypair to use (defaults to none)
    SUBNETS:            Comma delimited list of subnets to put the load balancer and the instances (defaults to none)
    MINSIZE:            Min size of the autoscaling group (defaults 1)
    DESIREDCAPACITY:    Desired  size of the autoscaling group (Defaults 2)
    MAXSIZE:            Max size of the autoscaling group (Defaults 3)
    AWSCERTIFICATE:     AWS Certificate ID to use in the HTTPS balancer (defaults to a non-existing certificate)
    CLOUD_INIT_PATH:    Path of the cloud-init script to use (defaults to files/cloud_init/cloud_init.sh)

FI_CAT
}

function banner(){
     cat <<FI_CAT
       _                                                     __
  __ _| | _____   _____         __ _ _ __  _ __         ___ / _|
 / _  | |/ _ \ \ / / _ \ _____ / _  | '_ \| '_ \ _____ / __| |_
| (_| | | (_) \ V / (_) |_____| (_| | |_) | |_) |_____| (__|  _|
 \__, |_|\___/ \_/ \___/       \__,_| .__/| .__/       \___|_|
 |___/                              |_|   |_|
FI_CAT
}

function process_stack(){
    aws cloudformation $1 \
        --stack-name autoscaling-glovo-app \
        --template-body file://cloudformation/autoscaling.yml \
        --profile ${PROFILE} \
        --parameters ParameterKey=KeyName,ParameterValue=${KP} \
            ParameterKey=AMIId,ParameterValue=${AMIID} \
            ParameterKey=InstanceTypeParameter,ParameterValue=${INSTANCETYPE} \
            ParameterKey=VersionId,ParameterValue=${BUILD_NUMBER} \
            ParameterKey=SecurityGroup,ParameterValue=\"${SG_VALUE}\" \
            ParameterKey=Subnets,ParameterValue=\"${SUBNETS}\" \
            ParameterKey=MinSize,ParameterValue=\"${MINSIZE}\" \
            ParameterKey=DesiredCapacity,ParameterValue=\"${DESIREDCAPACITY}\" \
            ParameterKey=MaxSize,ParameterValue=\"${MAXSIZE}\" \
            ParameterKey=AWSCertificate,ParameterValue=${AWSCERTIFICATE} \
            ParameterKey=DNSRecord,ParameterValue=${DNSRECORD} \
            ParameterKey=UserData,ParameterValue=$(base64 ${CLOUD_INIT_PATH})
    [[ $? != 0 ]] && die "Something bad happened..."
    exit
}

banner

# To keep things clean, when the loop finishes MEDIA_TO_PROCESS must contain the mediagroup
while getopts ":t:h" opt; do
    case ${opt} in
        t) [[ ${OPTARG} == "update-stack" || ${OPTARG} == "create-stack" ]] && process_stack ${OPTARG}
           exit
           ;;
        h) usage
           exit
           ;;
    esac
done

usage
