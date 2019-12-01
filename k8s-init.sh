#!/bin/bash

#该脚本用于在安装k8s集群之前做一些必要的系统优化和设置

read -p "请确认是否已经修改待部署机器的主机名（192.168.199.211：master1\n192.168.199.212 master2\n192.168.199.213 node1\n192.168.199.214 node2）:" rs
if [ $rs != 'yes' -a $rs != 'y' -a $rs != 'YES' -a $rs != 'Y' ];then
  echo "脚本退出执行"
  exit
fi

read -p "请确认系统是否已经安装最新版Docker：" rs1
if [ $rs1 != 'yes' -a $rs1 != 'y' -a $rs1 != 'YES' -a $rs1 != 'Y' ];then
  echo "脚本退出执行"
  exit
fi

echo "1. 清空防火墙规则"
iptables -F

echo "2. 关闭selinux"
sed -i 's/enforcing/disabled/' /etc/selinux/config
setenforce 0

echo "3. 关闭swap"
swapoff -a
sed -i 's/.*swap.*/#&/' /etc/fstab
echo "vm.swappiness = 0">> /etc/sysctl.conf
sysctl -p > /dev/null

echo "4. 同步系统时间"
yum -y install ntpdate &> /dev/null
ntpdate time.windows.com > /dev/null

echo "5. 优化内核参数"
cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system > /dev/null

echo "6. 添加hosts"
cat >> /etc/hosts <<EOF
192.168.199.211 master1
192.168.199.212 master2
192.168.199.213 node1
192.168.199.214 node2
EOF

echo "7. 配置k8s国内源"
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=0
repo_gpgcheck=0
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
yum clean all &> /dev/null
yum makecache fast &> /dev/null
yum -y update &> /dev/null

echo "8. 修改docker全局配置"
cat > /etc/docker/daemon.json <<EOF
{
  "registry-mirrors": ["https://52emalvj.mirror.aliyuncs.com"],
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ]
}
EOF
systemctl daemon-reload
systemctl restart docker

echo "9. 生成证书（手动）"

echo "10. 安装etcd集群（手动）"

echo "11. 安装k8s各组件（手动）"
