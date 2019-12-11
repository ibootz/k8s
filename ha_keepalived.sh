#!/bin/bash

echo "安装haproxy"
yum install -y haproxy
cat << EOF > /etc/haproxy/haproxy.cfg
global
    log         127.0.0.1 local2
    chroot      /var/lib/haproxy
    pidfile     /var/run/haproxy.pid
    maxconn     4000
    user        haproxy
    group       haproxy
    daemon

defaults
    mode                    tcp
    log                     global
    retries                 3
    timeout connect         10s
    timeout client          1m
    timeout server          1m

listen  admin_stats
    bind 0.0.0.0:9090
    mode http
    log 127.0.0.1 local0 err
    stats refresh 30s
    stats uri /status
    stats realm welcome login\ Haproxy
    stats auth admin:123456
    stats hide-version
    stats admin if TRUE

frontend kubernetes
    bind *:8443
    mode tcp
    default_backend kubernetes-master

backend kubernetes-master
    balance roundrobin
    server master1 192.168.199.211:6443 check maxconn 2000
    server master2 192.168.199.212:6443 check maxconn 2000
EOF

systemctl enable haproxy && systemctl start haproxy && systemctl status haproxy


echo "安装keepalived"

PRIORITY=$1
UNICAST_PEER=$2
MCAST_SRC_IP=$(hostname -i)

if [ -z "$PRIORITY" ];then
  echo "请指定当前节点的priorty"
  exit
fi

if [ -z "$UNICAST_PEER" ];then
  echo "请指定其他节点的ip"
  exit
fi

yum install -y keepalived
/bin/cp check_apiserver.sh /etc/keepalived/
cat <<EOF > /etc/keepalived/keepalived.conf
global_defs {
   router_id LVS_k8s
   script_user root
   enable_script_security
}

vrrp_script CheckK8sMaster {
    script "/etc/keepalived/check_apiserver.sh"
    interval 3
    timeout 9
    fall 2
    rise 2
}

vrrp_instance VI_1 {
    state BACKUP
    interface ens33
    virtual_router_id 100
    priority $PRIORITY
    advert_int 1
    mcast_src_ip $MCAST_SRC_IP
    nopreempt
    authentication {
        auth_type PASS
        auth_pass 123456
    }
    unicast_peer {
       $UNICAST_PEER
    }
    virtual_ipaddress {
        192.168.199.200/24
    }
    track_script {
        CheckK8sMaster
    }

}
EOF

systemctl restart keepalived && systemctl enable keepalived && systemctl status keepalived

