#!/bin/bash

if [ -z "$1" ];then
  echo "请指定etcd_name"
  exit
fi

read -p "请确认是否将相关证书添加到/etc/kubernetes/ssl目录中?" rs
if [ $rs != 'y' -a $rs != 'Y' -a $rs != 'YES' -a $rs != 'yes' ];then
  echo "程序终止执行"
  exit
fi

ETCD_NAME=$1
# 第一个节点启动时，传new；后续其他节点传existing
ETCD_INITIAL_CLUSTER_STATE=$2
ETCD_HOST=$(hostname -i)
ETCD_CFG=/etc/kubernetes/cfg
ETCD_SSL=/etc/kubernetes/ssl

echo "生成配置文件"
if [ ! -d "$ETCD_CFG" ];then
  mkdir -p $ETCD_CFG
fi
rm -rf $ETCD_CFG/etcd.conf
cat > $ETCD_CFG/etcd.conf <<EOF
#[Member]
ETCD_NAME=$ETCD_NAME
ETCD_DATA_DIR="/var/lib/etcd"
ETCD_LISTEN_PEER_URLS="https://$ETCD_HOST:2380"
ETCD_LISTEN_CLIENT_URLS="https://$ETCD_HOST:2379"

#[Clustering]
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://$ETCD_HOST:2380"
ETCD_ADVERTISE_CLIENT_URLS="https://$ETCD_HOST:2379"
ETCD_INITIAL_CLUSTER="etcd1=https://192.168.199.211:2380,etcd2=https://192.168.199.212:2380,etcd3=https://192.168.199.213:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"
ETCD_INITIAL_CLUSTER_STATE="$ETCD_INITIAL_CLUSTER_STATE"
ETCD_ENABLE_V2="true"
EOF

echo "复制证书文件到指定目录"
if [ ! -d "$ETCD_SSL" ];then
  mkdir -p $ETCD_SSL
fi
/bin/cp -rf ./cert/server*.pem $ETCD_SSL
/bin/cp -rf ./cert/ca.pem $ETCD_SSL

echo "生成启动文件"
systemctl stop etcd.service &> /dev/null
systemctl disable etcd.service &> /dev/null
rm -rf /etc/systemd/system/etcd.service 
rm -rf /var/lib/etcd
mkdir -p /var/lib/etcd

# 1. ETCD3.4 版本 ETCDCTL_API=3 etcdctl 和 etcd --enable-v2=false 成为了默认配置，如要使用 v2 版本，执行 etcdctl 时候需要设置 ETCDCTL_API 环境变量，例如：ETCDCTL_API=2 etcdctl
# 2. ETCD3.4 版本会自动读取环境变量的参数，所以 EnvironmentFile 文件中有的参数，不需要再次在 ExecStart 启动参数中添加l, 
# 如同时配置，会触发以下类似报错 “etcd: conflicting environment variable "ETCD_NAME" is shadowed by corresponding command-line flag (either unset environment variable or disable flag)”
# 3. flannel 操作 etcd 使用的是 v2 的 API，而 kubernetes 操作 etcd 使用的 v3 的 API
cat > /etc/systemd/system/etcd.service <<EOF
[Unit]
Description=Etcd Server
After=network.target
After=network-online.target
Wants=network-online.target
Documentation=https://github.com/coreos

[Service]
Type=notify
EnvironmentFile=-$ETCD_CFG/etcd.conf
WorkingDirectory=/var/lib/etcd/
ExecStart=/usr/local/bin/etcd \
  --cert-file=$ETCD_SSL/server.pem \
  --key-file=$ETCD_SSL/server-key.pem \
  --trusted-ca-file=$ETCD_SSL/ca.pem \
  --peer-cert-file=$ETCD_SSL/server.pem \
  --peer-key-file=$ETCD_SSL/server-key.pem \
  --peer-trusted-ca-file=$ETCD_SSL/ca.pem
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload && systemctl enable etcd.service && systemctl start etcd.service && systemctl status etcd
