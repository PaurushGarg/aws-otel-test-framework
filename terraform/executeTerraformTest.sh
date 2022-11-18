#!/bin/bash
##########################################
# This script is used to execute a terraform test case. It is primarily for use 
# with the Batch Test Generator. The script expects two to three arguments
# depending on the aws_service type. The script also expects certain enviornment 
# variables to be set. Expected inputs and env variables are listed below.
#
# Expected env variables:
# TF_VAR_aoc_version
# DDB_TABLE_NAME
# TTL_DATE time insert for TTL item in cache
# on mac TTL_DATE=$(date -v +7d +%s)
# for local use. command line vars will override this env var
# TF_VAR_cortex_instance_endpoint
#
# Inputs
# $1: aws_service
# $2: testcase 
# $3: ECS/EC2 only - ami/ecs launch type 
# $3: For all EKS tests we expect region|clustername
##########################################

set -x

echo "Test Case Args: $@"


opts=""
if [[ -f ./testcases/$2/parameters.tfvars ]] ; then 
    opts="-var-file=../testcases/$2/parameters.tfvars" ; 
fi

APPLY_EXIT=0
TEST_FOLDER=""
service="$1"
export AWS_REGION=us-west-2
case "$service" in
    EC2) TEST_FOLDER="./ec2/";
        opts+=" -var=testing_ami=$3";
    ;;
    EKS*) TEST_FOLDER="./eks/"
        region=$(echo $3 | cut -d \| -f 1);
        clustername=$(echo $3 | cut -d \| -f 2);
        export AWS_REGION=${region};
        opts+=" -var=region=${region}";
        opts+=" -var=eks_cluster_name=${clustername}";
    ;;
    ECS) TEST_FOLDER="./ecs/";
        opts+=" -var=ecs_launch_type=$3";
    ;;
    *)
    echo "service ${service} is not valid";
    exit 1;
    ;;
esac

case ${AWS_REGION} in
    "us-east-2") export TF_VAR_cortex_instance_endpoint="https://aps-workspaces.us-east-2.amazonaws.com/workspaces/ws-1de68e95-0680-42bb-8e55-67e7fd5d0861";
    ;;
    "us-west-2") export TF_VAR_cortex_instance_endpoint="https://aps-workspaces.us-west-2.amazonaws.com/workspaces/ws-e0c3c74f-7fdf-4e90-87d2-a61f52df40cd";
    ;;
esac

test_framework_shortsha=$(git rev-parse --short HEAD)
checkCache(){
    CACHE_HIT=$(aws dynamodb get-item --region=us-west-2 --table-name ${DDB_TABLE_NAME} --key {\"TestId\":{\"S\":\"$1$2$3\"}\,\"aoc_version\":{\"S\":\"${TF_VAR_aoc_version}$test_framework_shortsha\"}})
}

checkCache $1 $2 $3
# Used as a retry mechanic.
ATTEMPTS_LEFT=2
cd ${TEST_FOLDER};
while [ $ATTEMPTS_LEFT -gt 0 ] && [ -z "${CACHE_HIT}" ]; do
    terraform init;
    if timeout -k 5m --signal=SIGINT -v 45m terraform apply -auto-approve -lock=false $opts  -var="testcase=../testcases/$2" ; then
        APPLY_EXIT=$?
        echo "Exit code: $?" 
        aws dynamodb put-item --region=us-west-2 --table-name ${DDB_TABLE_NAME} --item {\"TestId\":{\"S\":\"$1$2$3\"}\,\"aoc_version\":{\"S\":\"${TF_VAR_aoc_version}$test_framework_shortsha\"}\,\"TimeToExist\":{\"N\":\"${TTL_DATE}\"}} --return-consumed-capacity TOTAL
    else
        APPLY_EXIT=$?
        echo "Terraform apply failed"
        echo "Exit code: $?"
        echo "AWS_service: $1"
        echo "Testcase: $2" 
    fi

    case "$service" in
        EKS*) terraform destroy --auto-approve $opts;
        ;;
    *)
        terraform destroy --auto-approve;
    ;;
    esac

    checkCache $1 $2 $3 
    let ATTEMPTS_LEFT=ATTEMPTS_LEFT-1
done


exit $APPLY_EXIT
