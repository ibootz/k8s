#!/bin/bash

# 生成CA证书和私钥
cat > cert/ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "87600h"
    },
    "profiles": {
      "kubernetes": {
         "expiry": "87600h",
         "usages": [
            "signing",
            "key encipherment",
            "server auth",
            "client auth"
        ]
      }
    }
  }
}
EOF

cat > cert/ca-csr.json <<EOF
{
    "CN": "kubernetes",
    "hosts": [],
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "L": "Beijing",
            "ST": "Beijing",
      	    "O": "k8s",
            "OU": "System"
        }
    ]
}
EOF

cfssl gencert -initca cert/ca-csr.json | cfssljson -bare cert/ca

#------------------------------------------------------------------

# 生成server证书和私钥,供etcd,kube-apiserver使用
cat > cert/server-csr.json <<EOF
{
    "CN": "kubernetes",
    "hosts": [
      "127.0.0.1",
      "192.168.199.211",
      "192.168.199.212",
      "192.168.199.213",
      "10.10.10.1",
      "kubernetes",
      "kubernetes.default",
      "kubernetes.default.svc",
      "kubernetes.default.svc.cluster",
      "kubernetes.default.svc.cluster.local"
    ],
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "L": "BeiJing",
            "ST": "BeiJing",
            "O": "k8s",
            "OU": "System"
        }
    ]
}
EOF

# CN(Common Name):后续kube-apiserver组件将从证书中提取该字段作为请求的用户名；
# hosts:localhost地址 + master部署节点的ip地址 + etcd节点的部署地址 + 负载均衡指定的虚拟ip地址(10.10.10.1) + k8s默认带的一些地址
# O(Organtzation):后续kube-apiserver组件将从证书中提取该字段作为请求的用户所属的用户组；

cfssl gencert -ca=cert/ca.pem -ca-key=cert/ca-key.pem -config=cert/ca-config.json -profile=kubernetes cert/server-csr.json | cfssljson -bare cert/server

#------------------------------------------------------------------

# 生成admin证书和私钥,供kubectl, flannel使用
cat > cert/admin-csr.json <<EOF
{
  "CN": "admin",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "L": "BeiJing",
      "ST": "BeiJing",
      "O": "system:masters",
      "OU": "System"
    }
  ]
}
EOF

cfssl gencert -ca=cert/ca.pem -ca-key=cert/ca-key.pem -config=cert/ca-config.json -profile=kubernetes cert/admin-csr.json | cfssljson -bare cert/admin

#------------------------------------------------------------------

# 生成kube-proxy证书和私钥,供kube-proxy使用
cat > cert/kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "L": "BeiJing",
      "ST": "BeiJing",
      "O": "k8s",
      "OU": "System"
    }
  ]
}
EOF

cfssl gencert -ca=cert/ca.pem -ca-key=cert/ca-key.pem -config=cert/ca-config.json -profile=kubernetes cert/kube-proxy-csr.json | cfssljson -bare cert/kube-proxy
