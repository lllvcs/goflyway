#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

sh_ver="1.0.4"
Folder="/usr/local/goflyway"
File="/usr/local/goflyway/goflyway"
CONF="/usr/local/goflyway/goflyway.conf"
Now_ver_File="/usr/local/goflyway/ver.txt"
Log_File="/usr/local/goflyway/goflyway.log"

Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[信息]${Font_color_suffix}"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"
Tip="${Green_font_prefix}[注意]${Font_color_suffix}"

#检查系统
check_sys(){
	if [[ -f /etc/redhat-release ]]; then
		release="centos"
	elif cat /etc/issue | grep -q -E -i "debian"; then
		release="debian"
	elif cat /etc/issue | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
	elif cat /proc/version | grep -q -E -i "debian"; then
		release="debian"
	elif cat /proc/version | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
    fi
	bit=`uname -m`
}
check_installed_status(){
	[[ ! -e ${File} ]] && echo -e "${Error} GoFlyway 没有安装，请检查 !" && exit 1
}
check_pid(){
	PID=$(ps -ef| grep "goflyway"| grep -v grep| grep -v ".sh"| grep -v "init.d"| grep -v "service"| awk '{print $2}')
}
check_new_ver(){
	new_ver=$(wget -qO- "https://github.com/coyove/goflyway/tags"|grep "/goflyway/releases/tag/"|grep -v '\-apk'|head -n 1|awk -F "/tag/" '{print $2}'|sed 's/\">//')
	if [[ -z ${new_ver} ]]; then
		echo -e "${Error} GoFlyway 最新版本获取失败，请手动获取最新版本号[ https://github.com/coyove/goflyway/releases ]"
		stty erase '^H' && read -p "请输入版本号 [ 格式如 v1.1.0a ] :" new_ver
		[[ -z "${new_ver}" ]] && echo "取消..." && exit 1
	else
		echo -e "${Info} 检测到 GoFlyway 最新版本为 [ ${new_ver} ]"
	fi
}
check_ver_comparison(){
	now_ver=$(cat ${Now_ver_File})
	[[ -z ${now_ver} ]] && echo "${new_ver}" > ${Now_ver_File}
	if [[ ${now_ver} != ${new_ver} ]]; then
		echo -e "${Info} 发现 GoFlyway 已有新版本 [ ${new_ver} ]"
		stty erase '^H' && read -p "是否更新 ? [Y/n] :" yn
		[[ -z "${yn}" ]] && yn="y"
		if [[ $yn == [Yy] ]]; then
			check_pid
			[[ ! -z $PID ]] && kill -9 ${PID}
			rm -rf ${Folder}
			mkdir ${Folder}
			Download_goflyway
			Start_goflyway
		fi
	else
		echo -e "${Info} 当前 GoFlyway 已是最新版本 [ ${new_ver} ]" && exit 1
	fi
}
Download_goflyway(){
	cd ${Folder}
	if [[ ${bit} == "x86_64" ]]; then
		wget --no-check-certificate -N "https://github.com/coyove/goflyway/releases/download/${new_ver}/goflyway_linux_amd64.tar.gz"
		mv goflyway_linux_amd64.tar.gz goflyway_linux.tar.gz
	else
		wget --no-check-certificate -N "https://github.com/coyove/goflyway/releases/download/${new_ver}/goflyway_linux_386.tar.gz"
		mv goflyway_linux_386.tar.gz goflyway_linux.tar.gz
	fi
	[[ ! -e "goflyway_linux.tar.gz" ]] && echo -e "${Error} GoFlyway 下载失败 !" && exit 1
	tar -xzf goflyway_linux.tar.gz
	[[ ! -e "goflyway" ]] && echo -e "${Error} GoFlyway 解压失败 !" && exit 1
	chmod +x goflyway
	echo "${new_ver}" > ${Now_ver_File}
}
Service_goflyway(){
	if [[ ${release} = "centos" ]]; then
		if ! wget --no-check-certificate https://raw.githubusercontent.com/lllvcs/goflyway/master/goflyway_centos -O /etc/init.d/goflyway; then
			echo -e "${Error} GoFlyway 服务管理脚本下载失败 !" && exit 1
		fi
		chmod +x /etc/init.d/goflyway
		chkconfig --add goflyway
		chkconfig goflyway on
	else
		if ! wget --no-check-certificate https://raw.githubusercontent.com/lllvcs/goflyway/master/goflyway_debian -O /etc/init.d/goflyway; then
			echo -e "${Error} GoFlyway 服务管理脚本下载失败 !" && exit 1
		fi
		chmod +x /etc/init.d/goflyway
		update-rc.d -f goflyway defaults
	fi
	echo -e "${Info} GoFlyway 服务管理脚本下载完成 !"
}
Installation_dependency(){
	mkdir ${Folder}
}
Write_config(){
	cat > ${CONF}<<-EOF
port=${new_port}
passwd=${new_passwd}
proxy_pass=${new_proxy_pass}
EOF
}
Read_config(){
	[[ ! -e ${CONF} ]] && echo -e "${Error} GoFlyway 配置文件不存在 !" && exit 1
	port=`cat ${CONF}|grep "port"|awk -F "=" '{print $NF}'`
	passwd=`cat ${CONF}|grep "passwd"|awk -F "=" '{print $NF}'`
	proxy_pass=`cat ${CONF}|grep "proxy_pass"|awk -F "=" '{print $NF}'`
}
Set_port(){
	while true
		do
		echo -e "请输入 GoFlyway 监听端口 [1-65535]（如果要伪装或者套CDN，那么只能使用端口：80 8080 8880 2052 2082 2086 2095）"
		stty erase '^H' && read -p "(默认: 80):" new_port
		[[ -z "${new_port}" ]] && new_port="80"
		expr ${new_port} + 0 &>/dev/null
		if [[ $? -eq 0 ]]; then
			if [[ ${new_port} -ge 1 ]] && [[ ${new_port} -le 65535 ]]; then
				echo && echo "========================"
				echo -e "	端口 : ${Red_background_prefix} ${new_port} ${Font_color_suffix}"
				echo "========================" && echo
				break
			else
				echo "输入错误, 请输入正确的端口。"
			fi
		else
			echo "输入错误, 请输入正确的端口。"
		fi
		done
}
Set_passwd(){
	echo "请输入 GoFlyway 密码"
	stty erase '^H' && read -p "(默认: 12345678):" new_passwd
	[[ -z "${new_passwd}" ]] && new_passwd="12345678"
	echo && echo "========================"
	echo -e "	密码 : ${Red_background_prefix} ${new_passwd} ${Font_color_suffix}"
	echo "========================" && echo
}
Set_proxy_pass(){
	echo "请输入 GoFlyway 要伪装(反向代理，只支持 HTTP:// 网站)"
	stty erase '^H' && read -p "(默认不伪装):" new_proxy_pass
	if [[ ! -z ${new_proxy_pass} ]]; then
		echo && echo "========================"
		echo -e "	伪装 : ${Red_background_prefix} ${new_proxy_pass} ${Font_color_suffix}"
		echo "========================" && echo
	fi
}
Set_conf(){
	Set_port
	Set_passwd
	Set_proxy_pass
}
Set_goflyway(){
	check_installed_status
	check_pid
	Set_conf
	Read_config
	Del_iptables
	Write_config
	Add_iptables
	Save_iptables
	Restart_goflyway
}
Install_goflyway(){
	[[ -e ${File} ]] && echo -e "${Error} 检测到 GoFlyway 已安装 !" && exit 1
	echo -e "${Info} 开始设置 用户配置..."
	Set_conf
	echo -e "${Info} 开始安装/配置 依赖..."
	Installation_dependency
	echo -e "${Info} 开始检测最新版本..."
	check_new_ver
	echo -e "${Info} 开始下载/安装..."
	Download_goflyway
	echo -e "${Info} 开始下载/安装 服务脚本(init)..."
	Service_goflyway
	echo -e "${Info} 开始写入 配置文件..."
	Write_config
	echo -e "${Info} 开始设置 iptables防火墙..."
	Set_iptables
	echo -e "${Info} 开始添加 iptables防火墙规则..."
	Add_iptables
	echo -e "${Info} 开始保存 iptables防火墙规则..."
	Save_iptables
	echo -e "${Info} 所有步骤 安装完毕，开始启动..."
	Start_goflyway
}
Start_goflyway(){
	check_installed_status
	check_pid
	[[ ! -z ${PID} ]] && echo -e "${Error} GoFlyway 正在运行，请检查 !" && exit 1
	/etc/init.d/goflyway start
	sleep 1s
	check_pid
	[[ ! -z ${PID} ]] && View_goflyway
}
Stop_goflyway(){
	check_installed_status
	check_pid
	[[ -z ${PID} ]] && echo -e "${Error} GoFlyway 没有运行，请检查 !" && exit 1
	/etc/init.d/goflyway stop
}
Restart_goflyway(){
	check_installed_status
	check_pid
	[[ ! -z ${PID} ]] && /etc/init.d/goflyway stop
	/etc/init.d/goflyway start
	sleep 1s
	check_pid
	[[ ! -z ${PID} ]] && View_goflyway
}
Update_goflyway(){
	check_installed_status
	check_new_ver
	check_ver_comparison
}
Uninstall_goflyway(){
	check_installed_status
	echo "确定要卸载 GoFlyway ? (y/N)"
	echo
	stty erase '^H' && read -p "(默认: n):" unyn
	[[ -z ${unyn} ]] && unyn="n"
	if [[ ${unyn} == [Yy] ]]; then
		check_pid
		[[ ! -z $PID ]] && kill -9 ${PID}
		Read_config
		Del_iptables
		rm -rf ${Folder}
		if [[ ${release} = "centos" ]]; then
			chkconfig --del goflyway
		else
			update-rc.d -f goflyway remove
		fi
		rm -rf /etc/init.d/goflyway
		echo && echo "GoFlyway 卸载完成 !" && echo
	else
		echo && echo "卸载已取消..." && echo
	fi
}
View_goflyway(){
	check_installed_status
	Read_config
	ip=$(wget -qO- -t1 -T2 ipinfo.io/ip)
	if [[ -z "${ip}" ]]; then
		ip=$(wget -qO- -t1 -T2 api.ip.sb/ip)
		if [[ -z "${ip}" ]]; then
			ip=$(wget -qO- -t1 -T2 members.3322.org/dyndns/getip)
			if [[ -z "${ip}" ]]; then
				ip="VPS_IP"
			fi
		fi
	fi
	[[ -z ${proxy_pass} ]] && proxy_pass="无"
	link_qr
	clear && echo "————————————————" && echo
	echo -e " GoFlyway 信息 :" && echo
	echo -e " 地址\t: ${Green_font_prefix}${ip}${Font_color_suffix}"
	echo -e " 端口\t: ${Green_font_prefix}${port}${Font_color_suffix}"
	echo -e " 密码\t: ${Green_font_prefix}${passwd}${Font_color_suffix}"
	echo -e " 伪装\t: ${Green_font_prefix}${proxy_pass}${Font_color_suffix}"
	echo -e "${link}"
	echo -e "${Tip} 链接仅适用于Windows系统的 Goflyway Tools 客户端（https://doub.io/dbrj-11/）。"
	echo && echo "————————————————"
}
urlsafe_base64(){
	date=$(echo -n "$1"|base64|sed ':a;N;s/\n//g;ta'|sed 's/=//g;s/+/-/g;s/\//_/g')
	echo -e "${date}"
}
link_qr(){
	PWDbase64=$(urlsafe_base64 "${passwd}")
	base64=$(urlsafe_base64 "${ip}:${port}:${PWDbase64}")
	url="goflyway://${base64}"
	QRcode="http://doub.pw/qr/qr.php?text=${url}"
	link=" 链接\t: ${Red_font_prefix}${url}${Font_color_suffix} \n 二维码 : ${Red_font_prefix}${QRcode}${Font_color_suffix} \n "
}
View_Log(){
	check_installed_status
	[[ ! -e ${Log_File} ]] && echo -e "${Error} GoFlyway 日志文件不存在 !" && exit 1
	echo && echo -e "${Tip} 按 ${Red_font_prefix}Ctrl+C${Font_color_suffix} 终止查看日志" && echo
	tail -f ${Log_File}
}
Add_iptables(){
	iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport ${new_port} -j ACCEPT
	iptables -I INPUT -m state --state NEW -m udp -p udp --dport ${new_port} -j ACCEPT
}
Del_iptables(){
	iptables -D INPUT -m state --state NEW -m tcp -p tcp --dport ${port} -j ACCEPT
	iptables -D INPUT -m state --state NEW -m udp -p udp --dport ${port} -j ACCEPT
}
Save_iptables(){
	if [[ ${release} == "centos" ]]; then
		service iptables save
	else
		iptables-save > /etc/iptables.up.rules
	fi
}
Set_iptables(){
	if [[ ${release} == "centos" ]]; then
		service iptables save
		chkconfig --level 2345 iptables on
	else
		iptables-save > /etc/iptables.up.rules
		echo -e '#!/bin/bash\n/sbin/iptables-restore < /etc/iptables.up.rules' > /etc/network/if-pre-up.d/iptables
		chmod +x /etc/network/if-pre-up.d/iptables
	fi
}
Update_Shell(){
	echo -e "当前版本为 [ ${sh_ver} ]，开始检测最新版本..."
	sh_new_ver=$(wget --no-check-certificate -qO- "https://softs.fun/Bash/goflyway.sh"|grep 'sh_ver="'|awk -F "=" '{print $NF}'|sed 's/\"//g'|head -1) && sh_new_type="softs"
	[[ -z ${sh_new_ver} ]] && sh_new_ver=$(wget --no-check-certificate -qO- "https://raw.githubusercontent.com/lllvcs/goflyway/master/goflyway.sh"|grep 'sh_ver="'|awk -F "=" '{print $NF}'|sed 's/\"//g'|head -1) && sh_new_type="github"
	[[ -z ${sh_new_ver} ]] && echo -e "${Error} 检测最新版本失败 !" && exit 0
	if [[ ${sh_new_ver} != ${sh_ver} ]]; then
		echo -e "发现新版本[ ${sh_new_ver} ]，是否更新？[Y/n]"
		stty erase '^H' && read -p "(默认: y):" yn
		[[ -z "${yn}" ]] && yn="y"
		if [[ ${yn} == [Yy] ]]; then
			if [[ $sh_new_type == "softs" ]]; then
				
				wget -N --no-check-certificate https://raw.githubusercontent.com/lllvcs/goflyway/master/goflyway.sh && chmod +x goflyway.sh
			fi
			echo -e "脚本已更新为最新版本[ ${sh_new_ver} ] !"
		else
			echo && echo "	已取消..." && echo
		fi
	else
		echo -e "当前已是最新版本[ ${sh_new_ver} ] !"
	fi
}
check_sys
echo && echo -e "  GoFlyway 一键管理脚本 ${Red_font_prefix}[v${sh_ver}]${Font_color_suffix}
  
 ${Green_font_prefix}0.${Font_color_suffix} 升级脚本
————————————
 ${Green_font_prefix}1.${Font_color_suffix} 安装 GoFlyway
 ${Green_font_prefix}2.${Font_color_suffix} 升级 GoFlyway
 ${Green_font_prefix}3.${Font_color_suffix} 卸载 GoFlyway
————————————
 ${Green_font_prefix}4.${Font_color_suffix} 启动 GoFlyway
 ${Green_font_prefix}5.${Font_color_suffix} 停止 GoFlyway
 ${Green_font_prefix}6.${Font_color_suffix} 重启 GoFlyway
————————————
 ${Green_font_prefix}7.${Font_color_suffix} 设置 GoFlyway 账号
 ${Green_font_prefix}8.${Font_color_suffix} 查看 GoFlyway 账号
 ${Green_font_prefix}9.${Font_color_suffix} 查看 GoFlyway 日志
————————————" && echo
if [[ -e ${File} ]]; then
	check_pid
	if [[ ! -z "${PID}" ]]; then
		echo -e " 当前状态: ${Green_font_prefix}已安装${Font_color_suffix} 并 ${Green_font_prefix}已启动${Font_color_suffix}"
	else
		echo -e " 当前状态: ${Green_font_prefix}已安装${Font_color_suffix} 但 ${Red_font_prefix}未启动${Font_color_suffix}"
	fi
else
	echo -e " 当前状态: ${Red_font_prefix}未安装${Font_color_suffix}"
fi
echo
stty erase '^H' && read -p " 请输入数字 [0-9]:" num
case "$num" in
	0)
	Update_Shell
	;;
	1)
	Install_goflyway
	;;
	2)
	Update_goflyway
	;;
	3)
	Uninstall_goflyway
	;;
	4)
	Start_goflyway
	;;
	5)
	Stop_goflyway
	;;
	6)
	Restart_goflyway
	;;
	7)
	Set_goflyway
	;;
	8)
	View_goflyway
	;;
	9)
	View_Log
	;;
	*)
	echo "请输入正确数字 [0-9]"
	;;
esac