#!/bin/bash

#内核层面禁用ipv6
disable_ipv6() {
    if [[ -n "$(ip a|awk '/inet6/')" ]]; then
        if [[ "7" == "$(awk -F"[ |(.)?]" '{print $4}' /etc/centos-release)" ]]; then
            if ! awk '/GRUB_CMDLINE_LINUX/' /etc/default/grub|grep 'ipv6.disable=1'; then
                sed -ri 's/^(GRUB_CMDLINE_LINUX.*)(")$/\1 ipv6.disable=1\2/' /etc/default/grub
            fi
            grub2-mkconfig -o /boot/grub2/grub.cfg
        fi
    fi
}

#ssh_iptables() {
#    sed -ri 's/^#?(Port)\s{1,}.*/\1 22992/' /etc/ssh/sshd_config
#    curl -Lks4 https://raw.githubusercontent.com/kongbinquan/init/master/friewall2iptables.sh|bash
#    curl -Lks4 https://raw.githubusercontent.com/kongbinquan/init/master/iptables_init_rules > /etc/sysconfig/iptables
#    if [ $1 == "publicnet" ]; then
#        sed -i '10s/$/\n-A INPUT                                  -p tcp -m tcp -m state --state NEW -m multiport --dports 22,22992 -m comment --comment "SSH_PORT" -j ACCEPT/' /etc/sysconfig/iptables
#        sed -ri '/(172.(30|25)|47.90|119.28.51.253|119.9.95.122|MOA)/d' /etc/sysconfig/iptables
#    fi    
#    systemctl restart sshd.service iptables.service
#    [[ "$(awk '/^UseDNS/{print $2}' /etc/ssh/sshd_config)" =~ ^[nN][oO]$ ]] || { echo 'UseDNS no' >> /etc/ssh/sshd_config && service sshd restart; }
#}
#加速ssh连接，并更改端口访问安全
ssh_config(){
    sed -ri 's@(#?)(UseDNS yes)@\2@g' /etc/ssh/sshd_config
    sed -ri 's/^#?(Port)\s{1,}.*/\1 22992/' /etc/ssh/sshd_config
    systemctl restart sshd.service
}


#安装zabbix客户端，按照生产环境更改server段ip
install_zabbix() {
    curl -Lk4 https://raw.githubusercontent.com/kongbinquan/init/master/zabbix_install_scripts.sh|bash -x -s net 172.25.100.10 
    iptables -I INPUT 4 -s 172.25.100.10/32 -p tcp -m tcp -m state --state NEW -m multiport --dports 10050:10053 -m comment --comment "Zabbix_server" -j ACCEPT
}


#安装docker-ce，以及最新版的docker-compose
install_docker() {
    yum install -y epel-release && yum install -y tmux
    #if ! rpm -ql epel-release >/dev/null 2>&1;then yum install -y tmux epel-release; fi
    curl -Lks4 https://raw.githubusercontent.com/kongbinquan/init/master/docker-install.sh|bash        
}


#禁用selinux
setSELinux() {
    [ -f /etc/sysconfig/selinux ] && { sed -i 's/^SELINUX=.*/#&/;s/^SELINUXTYPE=.*/#&/;/SELINUX=.*/a SELINUX=disabled' /etc/sysconfig/selinux; /usr/sbin/setenforce 0; }
    [ -f /etc/selinux/config ] && { sed -i 's/^SELINUX=.*/#&/;s/^SELINUXTYPE=.*/#&/;/SELINUX=.*/a SELINUX=disabled' /etc/selinux/config; /usr/sbin/setenforce 0; }
}

sync_time() {

    [ -x /usr/sbin/ntpdate ] || yum install ntpdate -y
    if grep -q ntpdate /var/spool/cron/root 2>/dev/null; then sed -i '/ntpdate/d' /var/spool/cron/root; fi
    echo -e "\n*/5 * * * * /usr/sbin/ntpdate -u pool.ntp.org >/dev/null 2>&1" >> /var/spool/cron/root
    /usr/sbin/ntpdate -u pool.ntp.org
    echo -e "\n=======\n" && cat /var/spool/cron/root
}

add_yum_pulgins() {
    yum install epel-release -y
    if ! which axel 2>/dev/null; then yum install axel -y;fi
    curl -4Lk https://raw.githubusercontent.com/kongbinquan/init/master/yum_plugins/axelget.conf > /etc/yum/pluginconf.d/axelget.conf
    curl -4Lk https://github.com/kongbinquan/init/blob/master/yum_plugins/axelget.py >/usr/lib/yum-plugins/axelget.py
}

setPS1() {
	curl -Lks 'https://raw.githubusercontent.com/kongbinquan/init/master/PS1' >> /etc/profile

	for i in `find /home/ -name '.bashrc'` /etc/skel/.bashrc ~/.bashrc ;do
		cat >> $i <<-EOF
			xterm_set_tabs() {
				TERM=linux
				export \$TERM
				setterm -regtabs 4
				TERM=xterm
				export \$TERM
			}
			linux_set_tabs() {
				TERM=linux;
				export \$TERM
				setterm -regtabs 8
				LESS="-x4"
				export LESS
			}
			#[ \$(echo \$TERM) == "xterm" ] && xterm_set_tabs
			linux_set_tabs
			listipv4() {
				if [ "\$1" != "lo" ]; then
					which ifconfig >/dev/null 2>&1 && ifconfig | sed -rn '/^[^ \\t]/{N;s/(^[^ ]*).*addr:([^ ]*).*/\\1=\\2/p}' | \\
						awk -F= '\$2!~/^192\\.168|^172\\.(1[6-9]|2[0-9]|3[0-1])|^10\\.|^127|^0|^\$/{print}' \\
						|| ip addr | awk '\$1=="inet" && \$NF!="lo"{print \$NF"="\$2}'
				else
					which ifconfig >/dev/null 2>&1 && ifconfig | sed -rn '/^[^ \\t]/{N;s/(^[^ ]*).*addr:([^ ]*).*/\\1=\\2/p}' \\
					|| ip addr | awk '\$1=="inet" && \$NF!="lo"{print \$NF"="\$2}'
				fi
			}
			tmux_init() {
				tmux new-session -s "LookBack" -d -n "local"    # 开启一个会话
				tmux new-window -n "other"          # 开启一个窗口
				tmux split-window -h                # 开启一个竖屏
				tmux split-window -v "htop"          # 开启一个横屏,并执行top命令
				tmux -2 attach-session -d           # tmux -2强制启用256color，连接已开启的tmux
			}
			# 判断是否已有开启的tmux会话，没有则开启
			#if which tmux 2>&1 >/dev/null; then test -z "\$TMUX" && { tmux attach || tmux_init; };fi
		EOF
	done
}

updateYUM() {
	yum clean all && yum makecache
	#sed -i '/[main]/a exclude=kernel*' /etc/yum.conf
	yum -y install lshw vim tree bash-completion git xorg-x11-xauth xterm \
		gettext axel tmux vnstat man vixie-cron screen vixie-cron crontabs \
		wget curl iproute tar gdisk iotop iftop htop
#	. /etc/bash_completion
	[ "$release" = "6" ] && yum -y groupinstall "Development tools" "Server Platform Development"
	[ "$release" = "7" ] && yum -y groups install "Development Tools" "Server Platform Development"
}

disable_ipv6
add_yum_pulgins
sync_time
ssh_config
#install_zabbix
setSELinux
install_docker
setPS1
updateYUM
ss -tnl
