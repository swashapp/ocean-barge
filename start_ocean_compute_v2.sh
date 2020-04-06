#!/usr/bin/env bash 
# Copyright (c) 2019 Ocean Protocol contributors
# SPDX-License-Identifier: Apache-2.0
# Linux or Mac OS X
#

# colors
COLOR_R="\033[0;31m"    # red
COLOR_G="\033[0;32m"    # green
COLOR_Y="\033[0;33m"    # yellow
COLOR_B="\033[0;34m"    # blue
COLOR_M="\033[0;35m"    # magenta
COLOR_C="\033[0;36m"    # cyan

# reset
COLOR_RESET="\033[00m"

# check platform type 
OSX="Darwin"
LINUX="Linux"

PLATFORM=$(uname)
OS_NAME=$(cat /etc/os-release | awk -F '=' '/^NAME/{print $2}' | awk '{print $1}' | tr -d '"')

if [[ $PLATFORM == $LINUX ]]; then
  if [[ $OS_NAME =~ (Ubuntu|Debian) ]]; then
    DIST_TYPE="Ubuntu"
  elif [[ $OS_NAME =~ (CentOS|Fedora|Red Hat) ]]; then
    DIST_TYPE="CentOS"
  fi
fi

MINIKUBE_HOME="/usr/local/bin"
MINIKUBE_CMD="$MINIKUBE_HOME/minikube start"
K="sudo kubectl"


main() {
  set_minikube_parameters
  if cleanup_and_deploy_minikube; then
    sleep 10 # 
    deploy_ocean_compute_v2
  fi
}


install_kubectl_minikube_others() {
# Installing kubectl if needed
  if ! [ -x "$(command -v kubectl)" ]; then
    echo -e "${COLOR_Y}Installing kubectl...${COLOR_RESET}"
    if [[ $PLATFORM == $OSX ]]; then
      brew install kubectl
    elif [[ $PLATFORM == $LINUX ]]; then
      if [[ $DIST_TYPE == "Ubuntu" ]]; then
        sudo apt-get update && sudo apt-get install -y apt-transport-https
        curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
        echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
        sudo apt-get update
        sudo apt-get install -y kubectl socat conntrack
        sudo bash -c "echo 1 > /proc/sys/net/bridge/bridge-nf-call-iptables"

      elif [[ $DIST_TYPE == "CentOS" ]]; then

      	cat <<EOF > /etc/yum.repos.d/kubernetes.repo
        [kubernetes]
        name=Kubernetes
        baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
        enabled=1
        gpgcheck=1
        repo_gpgcheck=1
        gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

        sudo yum install -y kubectl socat conntrack
        sudo bash -c "echo 1 > /proc/sys/net/bridge/bridge-nf-call-iptables"
      fi
    fi
    echo -e "${COLOR_G}[OK]${COLOR_RESET}"
  fi


# Installing minikube if needed
  if ! [ -x "$(command -v minikube)" ] ; then
    echo -e "${COLOR_Y}Installing minikube...${COLOR_RESET}"
    if [[ $PLATFORM == $OSX ]]; then
      curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-darwin-amd64 && chmod +x minikube && sudo mv minikube $MINIKUBE_HOME
    elif [[ $PLATFORM == $LINUX ]]; then
      curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 && chmod +x minikube && sudo mv minikube $MINIKUBE_HOME 
    fi
    sudo $MINIKUBE_HOME/minikube config set ShowBootstrapperDeprecationNotification false &&
    sudo $MINIKUBE_HOME/minikube config set WantUpdateNotification false &&
    sudo $MINIKUBE_HOME/minikube config set WantReportErrorPrompt false &&
    sudo $MINIKUBE_HOME/minikube config set WantKubectlDownloadMsg false 
    echo -e "${COLOR_G}"Notice: minikube was successfully installed"${COLOR_RESET}"
  fi
}


cleanup_and_deploy_minikube() {
  
  # Stop and delete previous minikube instance running
  if [ -x "$(command -v minikube)" ] ; then
  minikube_status=$(sudo $MINIKUBE_HOME/minikube status | grep 'host:' | awk '{print $2}')
   if [[ $minikube_status == "Running" ]]; then
  	echo -e "${COLOR_C}First, we need to stop existing minikube...${COLOR_RESET}"
   sudo $MINIKUBE_HOME/minikube stop
   fi
  echo -e "${COLOR_C}Delete existing k8s cluster...${COLOR_RESET}"
    sudo $MINIKUBE_HOME/minikube delete
  fi

  install_kubectl_minikube_others

  # start minikube with desired settings
  echo -e "${COLOR_M}"minikube will now try to start the local k8s cluster"${COLOR_RESET}"
  sudo $MINIKUBE_CMD
  if [ ! sudo $MINIKUBE_HOME/minikube status >/dev/null 2>&1 ] ; then
    echo -e "${COLOR_R}Unable to start minikube. Please see errors above${COLOR_RESET}"
    return 1
  fi

}

# set minikube startup parameters 
set_minikube_parameters() {
     
  # Assuming driver none by default
    MINIKUBE_CMD=$MINIKUBE_CMD" --vm-driver=none"

}


deploy_ocean_compute_v2() {

echo -e "${COLOR_G}Starting Ocean Compute V2 deployment...${COLOR_RESET}"
$K create ns ocean-operator
$K create ns ocean-compute


$K -n ocean-operator create -f ocean/operator-service/deploy_on_k8s/postgres-configmap.yaml
$K -n ocean-operator create -f ocean/operator-service/deploy_on_k8s/postgres-storage.yaml
$K -n ocean-operator create -f ocean/operator-service/deploy_on_k8s/postgres-deployment.yaml
$K -n ocean-operator create -f ocean/operator-service/deploy_on_k8s/postgresql-service.yaml
$K -n ocean-operator apply -f ocean/operator-service/deploy_on_k8s/deployment.yaml
$K -n ocean-operator apply -f ocean/operator-service/deploy_on_k8s/role_binding.yaml
$K -n ocean-operator apply -f ocean/operator-service/deploy_on_k8s/service_account.yaml

$K -n ocean-operator expose deployment operator-api --port=8050

$K -n ocean-compute apply -f ocean/operator-engine/k8s_install/sa.yml
$K -n ocean-compute apply -f ocean/operator-engine/k8s_install/binding.yml
$K -n ocean-compute apply -f ocean/operator-engine/k8s_install/operator.yml
$K -n ocean-compute apply -f ocean/operator-engine/k8s_install/computejob-crd.yaml
$K -n ocean-compute apply -f ocean/operator-engine/k8s_install/workflow-crd.yaml
$K -n ocean-compute create -f ocean/operator-service/deploy_on_k8s/postgres-configmap.yaml

$K -n ocean-operator wait --timeout=60s --for=condition=Available  deployment/postgres
$K -n ocean-operator wait --timeout=60s --for=condition=Available  deployment/operator-api

echo -e "${COLOR_G}Forwarding connection to localhost port 8050${COLOR_RESET}"
$K -n ocean-operator port-forward svc/operator-api 8050 &

sleep 10 #to allow the pod initialize and accept connections
echo -e "${COLOR_G}Initialize the database...${COLOR_RESET}"
curl -X POST "http://0.0.0.0:8050/api/v1/operator/pgsqlinit" -H  "accept: application/json"

echo -e "${COLOR_G}Point your browser at: http://localhost:8050/api/v1/docs/${COLOR_RESET}\n"

}

main "$@"
