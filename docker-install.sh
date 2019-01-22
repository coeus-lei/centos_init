#!/bin/bash
change_kernel() {
	yum clean all
	yum -y remove kernel-headers kernel-tools kernel-tools-libs
	if [ $1 == "aufs" ]; then
		[ -d "/usr/src/kernels/`uname -r`/fs/aufs" ] && return
		cat >/etc/yum.repos.d/kernel-ml-aufs.repo <<-EOF
			[kernel-ml-aufs]
			name=RHEL AUFS Kernel - Mainline
			baseurl=http://mirrors.dtops.cc/kernel_ml_aufs/\$releasever/\$basearch/
			http://mirrors.ds.com/kernel_ml_aufs/\$releasever/\$basearch/
			enabled=1
			gpgcheck=0
		EOF
		#curl -Lk http://mirrors.dwhd.org/kernel-ml-aufs/kernel-ml-auf.repo >/etc/yum.repos.d/kernel-ml-aufs.repo
		yum makecache
		yum -y install kernel-ml-aufs kernel-ml-aufs-headers kernel-ml-aufs-devel kernel-ml-aufs-tools-libs-devel perf python-perf
	else
		yum install -y http://elrepo.org/linux/kernel/el7/x86_64/RPMS/elrepo-release-7.0-3.el7.elrepo.noarch.rpm
		yum makecache
		yum --enablerepo=elrepo-kernel install -y kernel-ml kernel-ml-devel kernel-ml-doc kernel-ml-headers kernel-ml-tools kernel-ml-tools-libs kernel-ml-tools-libs-devel perf python-perf
	fi

	if [ "$(awk '{print int(($3~/^[0-9]/?$3:$4))}' /etc/centos-release)" == "7" ]; then
		grub2-set-default 0
	elif [ "$(awk '{print int(($3~/^[0-9]/?$3:$4))}' /etc/centos-release)" == "6" ]; then
		if grep aliyun /etc/yum.repos.d/CentOS-Base.repo >/dev/null 2>&1; then
			echo -e "\033[44;37;1mThis is a Aliyun CentOS OS, you can't use this kernel\033[39;49;0m"
		else
			sed -ri 's/^(default).*/\1=0/' /boot/grub/grub.conf
		fi
	fi
	sed -i '/\[main\]/a exclude=kernel*' /etc/yum.conf
	echo installd > /tmp/kernel
}

#不更改内核，使用overlay2的Storage Driver
#if ! grep -q installd /tmp/kernel; then change_kernel $1; fi

#不加此参数在docker info命令下会有警告提示
if ! grep -q net.bridge.bridge-nf-call-iptables /etc/sysctl.conf; then
	cat >> /etc/sysctl.conf <<-EOF
		net.bridge.bridge-nf-call-ip6tables = 1
		net.bridge.bridge-nf-call-iptables = 1
		net.bridge.bridge-nf-call-arptables = 1
	EOF
	sysctl -p 2>/dev/null| grep bridge
fi

if ! which docker >/dev/null 2>&1; then curl -Lk get.docker.com|bash; fi
if ! which docker-compose >/dev/null 2>&1; then curl -Lk https://raw.githubusercontent.com/kongbinquan/init/master/docker-compose|bash; fi

[ "$(awk -F'[ |.]' '{print $4 }' /etc/centos-release)" == "7" ] && \
	{ systemctl enable docker && systemctl start docker; } || \
	{ chkconfig docker on && service docker start; }

# clear && echo -e "\033[45;37;1mSystem will be reboot\033[39;49;0m" && sleep 5 && reboot
clear && echo -e "\033[45;37;1mthe docker sets up now\033[39;49;0m"
