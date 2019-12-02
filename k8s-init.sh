#!/bin/bash
#该脚本用于在安装k8s集群之前做一些必要的系统优化和设置

echo "清空防火墙规则，并关闭防火墙"
iptables -F
systemctl stop firewalld > /dev/null
systemctl disable firewalld > /dev/null

echo "关闭selinux"
setenforce 0
sed -i 's/enforcing/disabled/' /etc/selinux/config

echo "关闭swap"
swapoff -a
sed -i 's/.*swap.*/#&/' /etc/fstab
echo "vm.swappiness = 0">> /etc/sysctl.conf
sysctl -p > /dev/null

echo "同步系统时间"
yum -y install ntpdate &> /dev/null
ntpdate time.windows.com > /dev/null

echo "优化内核参数"
cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_nonlocal_bind = 1
net.ipv4.ip_forward = 1
vm.swappiness=0
EOF
sysctl --system > /dev/null
echo 'vm.min_free_kbytes=102400' >> /etc/sysctl.conf
sysctl -p

echo "修改文件句柄数"
cat <<EOF >>/etc/security/limits.conf
soft nofile 65536
hard nofile 65536
soft nproc 65536
hard nproc 65536
soft memlock unlimited
hard memlock unlimited
EOF

echo "安装ipvs"
yum install ipvsadm ipset sysstat conntrack libseccomp -y > /dev/null
#开机加载内核模块，并设置开机自动加载
cat > /etc/sysconfig/modules/ipvs.modules <<EOF
#!/bin/bash
modprobe -- ip_vs
modprobe -- ip_vs_rr
modprobe -- ip_vs_wrr
modprobe -- ip_vs_sh
modprobe -- nf_conntrack
EOF
chmod 755 /etc/sysconfig/modules/ipvs.modules && bash /etc/sysconfig/modules/ipvs.modules > /dev/null
lsmod | grep -e ip_vs -e nf_conntrack

echo "添加hosts"
cat >> /etc/hosts <<EOF
192.168.199.211 master1 etcd1
192.168.199.212 master2 etcd2
192.168.199.213 node1 etcd3
192.168.199.214 node2
EOF

echo "配置k8s国内源"
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

echo "修改docker全局配置"
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
