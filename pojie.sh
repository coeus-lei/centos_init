#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
LANG=en_US.UTF-8

public_file=/www/server/panel/install/public.sh
if [ ! -f $public_file ];then
	wget -O $public_file $btsb_Url/install/public.sh -T 20;
fi

publicFileMd5=$(md5sum ${public_file}|awk '{print $1}')
md5check="db0bc4ee0d73c3772aa403338553ff77"
if [ "${publicFileMd5}" != "${md5check}"  ]; then
	wget -O $public_file $btsb_Url/install/public.sh -T 20;
fi

. $public_file

download_Url=$NODE_URL
btsb_Url=https://download.ccspump.com
setup_path=/www
version=$(curl -Ss --connect-timeout 5 -m 2 http://www.bt.cn/api/panel/get_version)
if [ "$version" = '' ];then
	version='7.0.3'
fi

wget -T 5 -O /tmp/panel.zip $btsb_Url/install/update/LinuxPanel-7.2.0.zip
dsize=$(du -b /tmp/panel.zip|awk '{print $1}')
if [ $dsize -lt 10240 ];then
	echo "获取更新包失败，请稍后运维"
	exit;
fi
unzip -o /tmp/panel.zip -d $setup_path/server/ > /dev/null
wget -O /www/server/panel/install/check.sh ${btsb_Url}/install/check.sh -T 10
chattr +i /www/server/panel/install/public.sh
chattr +i /www/server/panel/install/check.sh
rm -f /tmp/panel.zip
cd $setup_path/server/panel/
check_bt=`cat /etc/init.d/bt`
if [ "${check_bt}" = "" ];then
	rm -f /etc/init.d/bt
	wget -O /etc/init.d/bt $download_Url/install/src/bt6.init -T 20
	chmod +x /etc/init.d/bt
fi
rm -f /www/server/panel/*.pyc
rm -f /www/server/panel/class/*.pyc
#pip install flask_sqlalchemy
#pip install itsdangerous==0.24

pip_list=$(pip list)
request_v=$(echo "$pip_list"|grep requests)
if [ "$request_v" = "" ];then
	pip install requests
fi
openssl_v=$(echo "$pip_list"|grep pyOpenSSL)
if [ "$openssl_v" = "" ];then
	pip install pyOpenSSL
fi

cffi_v=$(echo "$pip_list"|grep cffi|grep 1.12.)
if [ "$cffi_v" = "" ];then
	pip install cffi==1.12.3
fi

pymysql=$(echo "$pip_list"|grep pymysql)
if [ "$pymysql" = "" ];then
	pip install pymysql
fi

pip install -U psutil

chattr -i /etc/init.d/bt
chmod +x /etc/init.d/bt
echo "====================================="

iptables -I INPUT -p tcp -m state --state NEW -m tcp --dport 8888 -j ACCEPT
service iptables save

firewall-cmd --permanent --zone=public --add-port=8888/tcp > /dev/null 2>&1
firewall-cmd --reload

rm -f /dev/shm/bt_sql_tips.pl
kill $(ps aux|grep -E "task.pyc|main.py"|grep -v grep|awk '{print $2}')
/etc/init.d/bt start
echo 'True' > /www/server/panel/data/restart.pl
pkill -9 gunicorn &
echo "破解版更新更新有问题请联系运维";
rm -rf pojie.sh
