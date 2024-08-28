#!/bin/bash

set -e

kind_image='kindest/node:v1.28.13'
docker pull "${kind_image}"

reg_name='kind-registry'
reg_port='5001'
reg_host='localhost:5001'
containerdConfigPatches=$(cat <<EOF
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:${reg_port}"]
    endpoint = ["http://${reg_name}:5000"]
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."kind-registry:5000"]
    endpoint = ["http://${reg_name}:5000"]
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."kind-reg.actions-runner-system.svc"]
    endpoint = ["http://${reg_name}:5000"]
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."asia-southeast1-docker.pkg.dev"]
    endpoint = ["http://${reg_name}:5000"]
EOF
)

function setup_local_registry() {
  if [ "$(docker inspect -f '{{.State.Running}}' "${reg_name}" 2>/dev/null || true)" != 'true' ]; then
    docker run \
      -d --restart=always -p "127.0.0.1:${reg_port}:5000" --name "${reg_name}" \
      registry:2
  fi
}

function setup_kind_cluster() {
  cat <<EOF | kind create cluster \
    --image ${kind_image} \
    --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
    kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  - |
    kind: ClusterConfiguration
    etcd:
    local:
        dataDir: /tmp/etcd
        extraArgs:
        unsafe-no-fsync: "true"
  - |
    kind: KubeletConfiguration
    maxPods: 510
  extraPortMappings:
  - containerPort: 9999
    hostPort: 9999
    protocol: TCP
${containerdConfigPatches}
EOF
}

function remove_kind_cluster() {
  kind delete cluster
}

function connect_registry_to_cluster() {
  if [ "$(docker inspect -f='{{json .NetworkSettings.Networks.kind}}' "${reg_name}")" = 'null' ]; then
    echo "Connecting registry to the cluster network"
    docker network connect "kind" "${reg_name}"
  fi
}

function setup_local_registry_hosting() {
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "${reg_host}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF
}

# Steps to setup the registry and kind cluster on local
setup_local_registry
remove_kind_cluster
setup_kind_cluster
connect_registry_to_cluster
setup_local_registry_hosting



