#!/bin/bash

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#    http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit
set -o nounset

WORKER_JOIN_COMMAND="$1"
WORKER_NAME="$2"
WORKER_PUBLIC_IP="$3"
WORKER_CLUSTER_VPC_ID="$4"

echo $WORKER_JOIN_COMMAND
echo $WORKER_NAME
echo $WORKER_PUBLIC_IP
echo $WORKER_CLUSTER_VPC_ID

function loop() {
  local count=0
  CMD=$1
  while true ; do
    echo $CMD
    ${CMD}
    (( count = ${count} + 1 ))
    if [ $? -eq 0 ] ; then
      echo $CMD success! count = ${count}
      break;
    else
      echo $CMD error! count = ${count}
      if [ ${count} -eq 3] ; then
        break;
      fi
      sleep 1
    fi
  done
}

sudo modprobe br_netfilter
echo '1' | sudo tee /proc/sys/net/ipv4/ip_forward
echo -e 'net.bridge.bridge-nf-call-ip6tables = 1\nnet.bridge.bridge-nf-call-iptables = 1\nnet.ipv4.ip_forward = 1' | sudo tee /etc/sysctl.d/00-system.conf

loop 'sudo apt-get update'
loop 'sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common'
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
loop 'sudo apt-get update'
sudo apt-cache madison docker-ce
loop 'sudo apt-get install -y docker-ce=5:19.03.14~3-0~ubuntu-xenial docker-ce-cli=5:19.03.14~3-0~ubuntu-xenial containerd.io'
echo -e '{\n  "exec-opts": ["native.cgroupdriver=systemd"]\n}' | sudo tee /etc/docker/daemon.json
sudo systemctl daemon-reload
sudo systemctl restart docker
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
sudo add-apt-repository "deb https://apt.kubernetes.io/ kubernetes-$(lsb_release -cs) main"
loop 'sudo apt-get update'
sudo apt-cache madison kubelet
loop 'sudo apt-get install -y kubectl=1.20.0-00 kubeadm=1.18.6-00 kubelet=1.18.6-00'
sudo apt-mark hold kubectl kubelet kubeadm
sudo ${WORKER_JOIN_COMMAND} --node-name ${WORKER_NAME}
sudo kubectl annotate nodes ${WORKER_NAME} flannel.alpha.coreos.com/public-ip-overwrite=${WORKER_PUBLIC_IP} --overwrite --kubeconfig=/etc/kubernetes/kubelet.conf
sudo kubectl annotate nodes ${WORKER_NAME} vpc.id=${WORKER_CLUSTER_VPC_ID} --kubeconfig=/etc/kubernetes/kubelet.conf