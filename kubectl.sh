#!/bin/bash

if [ ! -f /usr/local/bin/kubectl ];then
  echo "请确认/usr/local/bin文件夹中是否存在kube-apiserver,kubeadm,kube-controller-manager,kubectl,kube-scheduler等文件"
  exit
fi

echo "复制证书到/etc/kubernetes/ssl"
/bin/cp ./cert/admin*.pem ./cert/ca.pem /etc/kubernetes/ssl

echo "创建~/.kube/config文件"
kubectl config set-cluster kubernetes \
  --certificate-authority=/etc/kubernetes/ssl/ca.pem \
  --embed-certs=true \
  --server=https://192.168.199.200:8443 \
  --kubeconfig=kubectl.kubeconfig

echo "设置客户端认证参数"
kubectl config set-credentials admin \
  --client-certificate=/etc/kubernetes/ssl/admin.pem \
  --client-key=/etc/kubernetes/ssl/admin-key.pem \
  --embed-certs=true \
  --kubeconfig=kubectl.kubeconfig

echo "设置上下文参数"
kubectl config set-context kubernetes \
  --cluster=kubernetes \
  --user=admin \
  --kubeconfig=kubectl.kubeconfig

echo "设置默认上下文"
kubectl config use-context kubernetes --kubeconfig=kubectl.kubeconfig

echo "拷贝kubectl.kubeconfig文件到~/.kube/config"
/bin/cp kubectl.kubeconfig ~/.kube/config

rm -rf kubectl.kubeconfig

