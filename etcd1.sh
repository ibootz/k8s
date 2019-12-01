#!/bin/bash

# 生成配置文件
cat > /etc/kubernetes/cfg/etcd <<EOF
#[Member]
ETCD_NAME="etcd1"
ETCD_DATA_DIR="/var/lib/etcd"
ETCD_LISTEN_PEER_URLS="https://192.168.199.211:2380"
ETCD_LISTEN_CLIENT_URLS="https://192.168.199.211:2379"

#[Clustering]
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://192.168.199.211:2380"
ETCD_ADVERTISE_CLIENT_URLS="https://192.168.199.211:2379"
ETCD_INITIAL_CLUSTER="etcd1=https://192.168.199.211:2380,etcd2=https://192.168.199.212:2380,etcd3=https://192.168.199.213:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"
ETCD_INITIAL_CLUSTER_STATE="new"
EOF

#生成启动文件
cat > /etc/systemd/system/etcd.service <<EOF
[Unit]
Description=Etcd Server
After=network.target
After=network-online.target
Wants=network-online.target
Documentation=https://github.com/coreos

[Service]
Type=notify
EnvironmentFile=-/etc/kubernetes/cfg/etcd
WorkingDirectory=/var/lib/etcd/
ExecStart=/usr/local/bin/etcd \
  --name=${ETCD_NAME} \
  --data-dir=${ETCD_DATA_DIR} \
  --listen-peer-urls=${ETCD_LISTEN_PEER_URLS} \
  --listen-client-urls=${ETCD_LISTEN_CLIENT_URLS},http://127.0.0.1:2379 \
  --advertise-client-urls=${ETCD_ADVERTISE_CLIENT_URLS} \
  --initial-advertise-peer-urls=${ETCD_INITIAL_ADVERTISE_PEER_URLS} \
  --initial-cluster=${ETCD_INITIAL_CLUSTER} \
  --initial-cluster-token=${ETCD_INITIAL_CLUSTER} \
  --cert-file=/etc/kubernetes/ssl/server.pem \
  --key-file=/etc/kubernetes/ssl/server-key.pem \
  --trusted-ca-file=/etc/kubernetes/ssl/ca.pem \
  --peer-cert-file=/etc/kubernetes/ssl/server.pem \
  --peer-key-file=/etc/kubernetes/ssl/server-key.pem \
  --peer-trusted-ca-file=/etc/kubernetes/ssl/ca.pem
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload && systemctl enable etcd.service && systemctl start etcd.service && systemctl status etcd
