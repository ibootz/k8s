#!/bin/bash
# keepalive健康检查脚本

err=0
for k in $(seq 1 5)
do
  check_code=$(pgrep kube-apiserver)
  if [[ $check_code == "" ]]; then
    err=$(expr $err + 1)
    sleep 5
    continue
  else
    err=0
    break
  fi
done

if [[ $err != "0" ]]; then
  echo "systemctl stop keepalived"
  /usr/bin/systemctl stop keepalived
  exit 1
else
  exit 0
fi

