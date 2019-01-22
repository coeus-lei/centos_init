#!/bin/bash
systemctl mask firewalld
systemctl stop firewalld
yum -y install iptables-devel iptables-services iptables
systemctl enable iptables
systemctl start iptables
