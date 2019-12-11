#!/bin/bash

echo "复制证书文件到/etc/kubernetes/ssl"
/bin/cp ./cert/server*.pem ./cert/ca*.pem /etc/kubernetes/ssl/

echo "创建加密配置文件"
#encryption-config.yaml中的secret字段，还有csv中的token字段都可以使用$(head -c 32 /dev/urandom | base64)函数生成
cat > encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: Gqmk6tFxZnyW3YbLE4t05mGf4SobW+NzoBxyZ4zWWFQ=
      - identity: {}
EOF

echo "创建kube-apiserver使用的客户端令牌文件, token可以使用'head -c 32 /dev/urandom | base64'命令来生成"
cat <<EOF > bootstrap-token.csv
9NbTXmnjbZuJdMAMqF+8q5t0lCtUgDtSMP9/Dn5FbZU=,kubelet-bootstrap,10001,"system:kubelet-bootstrap" 
EOF

echo "将加密文件拷贝到其他master节点"
yum install -y sshpass > /dev/null
/bin/cp encryption-config.yaml bootstrap-token.csv /etc/kubernetes/cfg
# sshpass -p 1990912 scp encryption-config.yaml bootstrap-token.csv root@192.168.199.212:/etc/kubernetes/cfg
rm -rf encryption-config.yaml bootstrap-token.csv


echo "创建kube-apiserver.service文件"
cat > /etc/systemd/system/kube-apiserver.service << EOF
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=network.target

[Service]
ExecStart=/usr/local/bin/kube-apiserver \
  --enable-admission-plugins=NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \
  --anonymous-auth=false \
  --encryption-provider-config=/etc/kubernetes/cfg/encryption-config.yaml \
  --advertise-address=0.0.0.0 \
  --bind-address=0.0.0.0 \
  --secure-port=6443 \
  --insecure-port=0 \
  --authorization-mode=Node,RBAC \
  --runtime-config=api/all \
  --enable-bootstrap-token-auth \
  --service-cluster-ip-range=10.254.0.0/16 \
  --service-node-port-range=30000-32700 \
  --tls-cert-file=/etc/kubernetes/ssl/server.pem \
  --tls-private-key-file=/etc/kubernetes/ssl/server-key.pem \
  --client-ca-file=/etc/kubernetes/ssl/ca.pem \
  --kubelet-client-certificate=/etc/kubernetes/ssl/server.pem \
  --kubelet-client-key=/etc/kubernetes/ssl/server-key.pem \
  --service-account-key-file=/etc/kubernetes/ssl/ca-key.pem \
  --etcd-cafile=/etc/kubernetes/ssl/ca.pem \
  --etcd-certfile=/etc/kubernetes/ssl/server.pem \
  --etcd-keyfile=/etc/kubernetes/ssl/server-key.pem \
  --etcd-servers=https://192.168.199.211:2379,https://192.168.199.212:2379,https://192.168.199.213:2379 \
  --allow-privileged=true \
  --apiserver-count=2 \
  --audit-log-maxage=30 \
  --audit-log-maxbackup=3 \
  --audit-log-maxsize=100 \
  --audit-log-path=/var/log/kubernetes/kube-apiserver-audit.log \
  --event-ttl=1h \
  --alsologtostderr=true \
  --logtostderr=false \
  --log-dir=/var/log/kubernetes \
  --v=2
Restart=on-failure
RestartSec=5
Type=notify
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

mkdir -p /var/log/kubernetes

systemctl daemon-reload && systemctl enable kube-apiserver && systemctl start kube-apiserver && systemctl status kube-apiserver

echo "授予kubernetes证书访问kubelet api权限"
#在执行kubectl exec、run、logs 等命令时，apiserver会转发到kubelet。这里定义 RBAC规则，授权apiserver调用kubelet API"
kubectl create clusterrolebinding kube-apiserver:kubelet-apis --clusterrole=system:kubelet-api-admin --user kubernetes

#预定义的ClusterRole system:kubelet-api-admin授予访问kubelet所有 API 的权限：
kubectl describe clusterrole system:kubelet-api-admin


echo -e "\n检查api-server和集群状态"
echo "netstat -ptln | grep kube-apiserve  ==>"
netstat -ptln | grep kube-apiserve

echo -e "\nkubectl cluster-info  ==>"
kubectl cluster-info

echo -e "\nkubectl get all --all-namespaces  ==>"
kubectl get all --all-namespaces

echo -e "\nkubectl get componentstatuses  ==>"
kubectl get componentstatuses

