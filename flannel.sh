#!/bin/bash

echo "向etcd写入集群Pod网段信息"
ETCDCTL_API=2 etcdctl \
    --endpoints="https://192.168.199.211:2379,https://192.168.199.212:2379,https://192.168.199.213:2379" \
    --ca-file="/etc/kubernetes/ssl/ca.pem" \
    --key-file="/etc/kubernetes/ssl/server-key.pem" \
    --cert-file="/etc/kubernetes/ssl/server.pem" \
    set /kubernetes/network/config '{"Network":"172.30.0.0/16", "SubnetLen": 24, "Backend": {"Type": "vxlan"}}'

echo "复制证书到指定目录"
K8S_SSL=/etc/kubernetes/ssl
if [ ! -d "$K8S_SSL" ];then
  mkdir -p $K8S_SSL
fi
/bin/cp ./cert/ca.pem ./cert/admin*.pem $K8S_SSL

echo "创建flannel.service文件"
cat > /etc/systemd/system/flannel.service << EOF
[Unit]
Description=Flanneld overlay address etcd agent
After=network.target
After=network-online.target
Wants=network-online.target
After=etcd.service
Before=docker.service

[Service]
Type=notify
ExecStart=/usr/local/bin/flanneld \
  -etcd-cafile=/etc/kubernetes/ssl/ca.pem \
  -etcd-certfile=/etc/kubernetes/ssl/admin.pem \
  -etcd-keyfile=/etc/kubernetes/ssl/admin-key.pem \
  -etcd-endpoints=https://192.168.199.211:2379,https://192.168.199.212:2379,https://192.168.199.213:2379 \
  -etcd-prefix=/kubernetes/network
ExecStartPost=/usr/local/bin/mk-docker-opts.sh -k DOCKER_NETWORK_OPTIONS -d /run/flannel/docker
Restart=on-failure

[Install]
WantedBy=multi-user.target
RequiredBy=docker.service
EOF
#mk-docker-opts.sh 脚本将分配给flanneld的Pod子网网段信息写入到/run/flannel/docker文件中，后续docker启动时使用这个文件中参数值设置docker0网桥。
#flanneld 使用系统缺省路由所在的接口和其它节点通信，对于有多个网络接口的机器（如，内网和公网），可以用 -iface=enpxx 选项值指定通信接口。

echo "启动flannel"
systemctl daemon-reload && systemctl enable flannel && systemctl start flannel && systemctl status flannel

echo "验证flannel"
echo "cat /run/flannel/docker(flannel分配给docker的子网信息) ==>"
cat /run/flannel/docker
echo "cat /run/flannel/subnet.env(flannel整个大网段以及在此节点上的子网段) ==>"
cat /run/flannel/subnet.env
echo "ip add | grep flannel ==>"
ip add | grep flannel

echo "配置docker支持flannel"
sed -i '/^EnvironmentFile.*/d;s/ $DOCKER_NETWORK_OPTIONS//;s/ExecStart.*/& $DOCKER_NETWORK_OPTIONS/;/ExecStart/i\EnvironmentFile=/run/flannel/docker' /etc/systemd/system/multi-user.target.wants/docker.service
systemctl daemon-reload && systemctl restart docker && systemctl status docker
echo "ip add | grep docker ==>"
ip add | grep docker

echo "设置CNI插件支持flannel"
if [ ! -f /usr/local/bin/ptp ];then
  echo "请解压缩cni-plugins-xxx文件到/usr/local/bin目录"
  exit
fi

mkdir -p /etc/cni/net.d
cat > /etc/cni/net.d/10-default.conf <<EOF
{
    "name": "flannel",
    "type": "flannel",
    "delegate": {
        "bridge": "docker0",
        "isDefaultGateway": true,
        "mtu": 1400
    }
}
EOF
