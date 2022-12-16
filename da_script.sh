#!/bin/bash
############################################
# Tool script Directadmin
#
# Created by: ninhpq@vinahost.vn
############################################

# Reset
Nc='\e[0m' # No color

# Regular Colors
Black='\e[0;30m'  # Black
Red='\e[0;31m'    # Red
Green='\e[0;32m'  # Green
Yellow='\e[0;33m' # Yellow
Blue='\e[0;34m'   # Blue
White='\e[0;37m'  # White

function backupUser() {

	list_user=$(ls -d /usr/local/directadmin/data/users/*/ | awk -F"/" '{print $(NF-1)}' | awk 'BEGIN{ORS=" "}1')

	array_list_user=($list_user)
	a=$(echo $list_user | wc -w)
	array_list_user_domain=()
	choose_user=()
	#Lấy danh sách user hiện có
	function getUsers() {

		for ((i = 0; i < $a; i++)); do
			domain=$(find /usr/local/directadmin/data/users/${array_list_user[i]}/domains -name "*.conf" | awk -F'/' '{print $NF}' | awk -F"." '{ print substr( $0, 1, length($0)-5 ) }' | awk 'BEGIN{ORS=", "}1')

			arr[i]="User: ${array_list_user[i]} -- Domain: $domain"
			array_list_user_domain[i]=${arr[i]}

		done
	}

	#Kiểm tra user
	function checkUsers() {

		while true; do
			echo -e "Enter the User name to create backup (Max 5 user)\nExample: user1 user2 user3\n"
			read -p "Your choices: " choose1 choose2 choose3 choose4 choose5
			if [ $choose1 == "c" ]; then
				return
			fi

			choose_user=($choose1 $choose2 $choose3 $choose4 $choose5)
			i=0
			j=0

			while [ $i -lt ${#choose_user[@]} ]; do
				j=0
				while [ $j -lt ${#array_list_user[@]} ]; do
					if [[ ${choose_user[i]} == ${array_list_user[j]} ]]; then
						break
					fi
					j=$(expr $j + 1)
				done
				if [[ $j == ${#array_list_user[@]} ]]; then
					echo ""
					echo -e "User is \e[0;31minvalid\e[0m or \e[0;31mdoes not exist\e[0m, enter again! "
					break
				fi
				i=$(expr $i + 1)
			done

			if [[ $j != ${#array_list_user[@]} ]]; then
				checkQuota
				return 0
			fi

		done

	}

	#Kiểm tra dung lượng của user có vượt dung lượng cho phép không
	function checkQuota() {

		disk_system_available=$(df -k | grep -w "/" | awk '{print $4}')
		total_disk_user_used=0

		for ((i = 0; i < ${#choose_user[@]}; i++)); do
			disk_user_used=$(du -s /home/${choose_user[i]}/ | cut -d"/" -f 1)
			total_disk_user_used=$(expr $total_disk_user_used + $disk_user_used)
		done

		pass_quota=""

		echo -e "Checking disk space...\n"

		if [ ! -e '/usr/bin/bc' ]; then
			echo -e "Installing packages..."
			echo -e "Please wait..."
			yum -y install bc >/dev/null 2>&1
		fi

		echo -e "Total usage of User need to backup: $(awk 'BEGIN{printf "%.2f", '$total_disk_user_used'/1024/1024}')Gb\n"
		sleep 5

		if [[ $total_disk_user_used -gt $disk_system_available ]]; then
			echo -e "Free disk space is \e[0;31mnot available\e[0m to create backup files, need to free up space!\n"
			sleep 2
			free_up_disk_space
			disk_system_available_after_cleanup=$(df -k | grep -w "/" | awk '{print $4}')
			if [[ $total_disk_user_used -gt $disk_system_available_after_cleanup ]]; then
				echo -e "\e[0;31mNeed to free up more disk space or upgrade\e[0m\n"
				pass_quota="false"
				return 1
			else
				pass_quota="true"
				createBackup
				return 0
			fi
		else
			echo -e "Free disk space \e[0;31mavailable\e[0m to create backup files.\n"
			pass_quota="true"
			createBackup
			return 0
		fi

	}

	pass_quota=$checkQuota
	#Tạo file backup và rsyns đến VPS mới
	function createBackup() {

		while true; do
			echo -e " 1) Backup and Restore User in Remote Server\n"
			echo -e " 2) Backup in local\n"
			echo -e " 0) Cancel!\n"
			read -p "=> Option: " select
			echo ""
			case $select in
			1)
				read -p "=> Please enter IP of server: " ip
				read -p "=> Please enter Username: " username
				read -p "=> Please enter Password: " password

				echo -e "Checking login...\n"
				sleep 1
				c=0
				while [ $c -lt 3 ]; do

					if [ ! -e '/usr/bin/sshpass' ]; then
						echo -e "Installing packages..."
						echo -e "Please wait..."
						yum -y install sshpass >/dev/null 2>&1

					fi

					timeout 20s sshpass -p "$password" ssh -o "StrictHostKeyChecking=no" $username@$ip 'echo "Login Success"' >/tmp/sshpasslog.txt 2>&1

					if [ "$(grep -w "Login Success" /tmp/sshpasslog.txt)" == "Login Success" ]; then
						echo -e "Login Success\n"
						break
					else
						echo "Failed"
						tmp=$(cat /tmp/sshpasslog.txt)
						echo $tmp
						c=$(expr $c + 1)
						if [ $c -eq 3 ]; then
							return
						fi
						echo -e "\e[0;31mAgain!\e[0m"
						read -p "=> Please enter IP of server: " ip
						read -p "=> Please enter Username: " username
						read -p "=> Please enter Password: " password
					fi

				done

				sleep 5

				if [[ $pass_quota == "true" ]]; then
					echo -e "Creating a Backup for user \e[0;32m${choose_user[@]}\e[0m and Rsync to Server \e[0;31m$ip\e[0m...\n"
					sleep 10

					for x in ${choose_user[@]}; do
						echo "action=backup&append%5Fto%5Fpath=nothing&database%5Fdata%5Faware=yes&email%5Fdata%5Faware=yes&local%5Fpath=%2Fhome%2Fadmin%2Fadmin%5Fbackups%2Ffile%5Fbackup&owner=admin&select%30=$x&type=admin&value=multiple&when=now&where=local" >>/usr/local/directadmin/data/task.queue
						/usr/local/directadmin/dataskq d2000

						c=0
						while [ $c -lt 3 ]; do

							file_bakup=$(find /home/admin/admin_backups/ -cmin -30 -type f | awk -F"/" '{print $(NF) }' | awk '/$x/ {print}')

							if [ ! -e '/usr/bin/rsync' ]; then
								echo -e "Installing packages..."
								echo -e "Please wait..."
								yum -y install rsync >/dev/null 2>&1
							fi

							ionice -c 2 -n 5 rsync -pqav --progress --remove-source-files --rsh="/usr/bin/sshpass -p "$password" ssh -o StrictHostKeyChecking=no -l root" /home/admin/admin_backups/$file_bakup $username@$ip:/home/admin/admin_backups/ >/tmp/rsynlog.txt 2>&1

							if [ -s /tmp/rsynlog.txt ] && [ "$(grep -wi "failed - POSSIBLE BREAK-IN ATTEMPT" /tmp/rsynlog.txt | awk -F"-" '{print $2}')" == " POSSIBLE BREAK" ]; then
								echo -e "Success Rsync for user $x\n"
								echo -e "In progress to restore for users $x\n"
								sshpass -p "$password" ssh -o "StrictHostKeyChecking=no" $username@$ip ' yum -y install wget sshpass rsync >/dev/null '
								sshpass -p "$password" ssh -o "StrictHostKeyChecking=no" $username@$ip 'wget -P /home/admin/admin_backups/ -N "https://raw.githubusercontent.com/nintech-sudo/directadmin/main/restore.sh"'
								sshpass -p "$password" ssh -o "StrictHostKeyChecking=no" $username@$ip '. /home/admin/admin_backups/restore.sh'
								break
							elif [ -s /tmp/rsynlog.txt ]; then
								echo "Failed"
								tmp=$(cat /tmp/rsynlog.txt)
								echo $tmp
								c=$(expr $c + 1)
							else
								echo -e "Success Rsync for user $x\n"
								echo -e "In progress to restore for users $x\n"
								sshpass -p "$password" ssh -o "StrictHostKeyChecking=no" $username@$ip ' yum -y install wget sshpass rsync >/dev/null '
								sshpass -p "$password" ssh -o "StrictHostKeyChecking=no" $username@$ip 'wget -P /home/admin/admin_backups/ -N "https://raw.githubusercontent.com/nintech-sudo/directadmin/main/restore.sh"'
								sshpass -p "$password" ssh -o "StrictHostKeyChecking=no" $username@$ip '. /home/admin/admin_backups/restore.sh'
								break
							fi
							read -p "=> Please enter IP of server: " ip
							read -p "=> Please enter Username: " username
							read -p "=> Please enter Password: " password

						done

						sleep 5
					done

				else
					echo -e "Can't creating a backup file for user \e[0;31m${choose_user[@]}\e[0m ...\n"
				fi
				break
				;;

			2)
				echo -e "Creating a Backup for user \e[0;31m${choose_user[@]}\e[0m in Local...\n"
				sleep 5
				if [[ $pass_quota == "true" ]]; then

					sleep 10
					for x in ${choose_user[@]}; do
						echo "action=backup&append%5Fto%5Fpath=nothing&database%5Fdata%5Faware=yes&email%5Fdata%5Faware=yes&local%5Fpath=%2Fhome%2Fadmin%2Fadmin%5Fbackups%2Ffile%5Fbackup&owner=admin&select%30=$x&type=admin&value=multiple&when=now&where=local" >>/usr/local/directadmin/data/task.queue
						/usr/local/directadmin/dataskq d2000
					done
				else
					echo -e "Can't creating a backup file for user \e[0;31m${choose_user[@]}\e[0m ...\n"
				fi
				break
				;;

			0)
				echo -e "Bye\n"
				break
				;;

			*) echo -e "\e[0;31mIncorrect value\e[0m, Enter again! \n" ;;
			esac
		done

	}

	getUsers
	echo -e "\e[1;34m List All User and Domain \e[0m"
	next
	for ((i = 0; i < ${#array_list_user_domain[@]}; i++)); do
		printf '%-80s %-5s \n' "$i) ${array_list_user_domain[i]}" "#"
	done
	printf '%-80s %-5s \n' "c) Cancel" "#"
	next
	checkUsers

}

#Xóa file rác
function free_up_disk_space() {

	function showDiskUsed() {

		echo -e "Show Used System Capacity...\n"
		sleep 2
		echo -e "$(df -h) \n"
		sleep 2

		inode=$(df -ih | grep -w "/" | awk '{print $5}')
		echo "Checking Inodes: "
		sleep 2
		echo "Inode capacity used: "$inode
		return 0
		#find /home -type f -name "*.zip" -size +10M -exec du -h {} + | sort -rh

	}

	function cleanupDisk() {

		if rpm -q yum-utils >/dev/null; then
			echo "=>Package yum-utils already installed. Good."
		else
			echo "=>Going to install yum-utils..."
			yum -y install yum-utils
		fi

		echo "=>Removing old Linux kernels..."
		package-cleanup -y --oldkernels --count=1

		echo "=>Cleaning yum caches..."
		yum clean all
		rm -rfv /var/cache/yum
		rm -rfv /var/tmp/yum-*

		echo '=>Trimming .log files larger than 25M...'
		find /var -name "*.log" \( \( -size +25M -mtime +7 \) -o -mtime +30 \) -exec truncate {} --size 0 \;

		echo "=>Removing WP-CLI caches..."
		rm -rfv /root/.wp-cli/cache/*
		rm -rfv /home/*/.wp-cli/cache/*

		echo "=>Removing Composer caches..."
		rm -rfv /root/.composer/cache
		rm -rfv /home/*/.composer/cache

		echo "=>Removing core dumps..."
		find -regex ".*/core\.[0-9]+$" -print -delete

		echo "=>Removing Node.JS caches..."
		rm -rfv /root/.npm /home/*/.npm /root/.node-gyp /home/*/.node-gyp /tmp/npm-*

		echo '=>Removing mock caches...'
		rm -rfv /var/cache/mock/* /var/lib/mock/*

		echo '=>Removing user caches...'
		rm -rfv /home/*/.cache/* /root/.cache/*

		echo "=>Removing Directadmin error log files..."
		find /home/*/public_html/ -name error_log -print -delete

		echo "=>Removing Ticket Notification Directadmin..."
		find /usr/local/directadmin/data/tickets/ -type f -print -delete

		echo -e "\e[1;32m==>All Done! \e[0m\n"

		echo -e "Disk space after cleaned up...\n"
		sleep 2
		echo -e "$(df -h) \n"

	}

	showDiskUsed

	while true; do
		read -p "=> Do you want to Cleanup Disk? (y/n): " select
		echo ""
		case $select in
		y)
			echo " In progress cleanup disk space... "
			sleep 2
			cleanupDisk
			break
			;;

		n)
			echo -e "Bye!\n"
			return 1
			;;
		*) echo -e "\e[0;31mIncorrect value\e[0m, Enter again! \n" ;;
		esac
	done

}

function system_info() {
	# install wget, fio and virt-what
	if [ ! -e '/usr/bin/wget' ] || [ ! -e '/usr/bin/fio' ] || [ ! -e '/usr/sbin/virt-what' ]; then
		echo -e "Installing packages..."
		echo -e "Please wait..."
		yum clean all >/dev/null 2>&1 && yum install -y epel-release >/dev/null 2>&1 && yum install -y wget fio virt-what >/dev/null 2>&1
		apt-get update >/dev/null 2>&1 && apt-get install -y wget fio virt-what >/dev/null 2>&1
	fi

	# check if /scripts exists
	if [ ! -d "/scripts" ]; then
		mkdir /scripts
	fi

	get_opsy() {
		[ -f /etc/redhat-release ] && awk '{print ($1,$3~/^[0-9]/?$3:$4)}' /etc/redhat-release && return
		[ -f /etc/os-release ] && awk -F'[= "]' '/PRETTY_NAME/{print $3,$4,$5}' /etc/os-release && return
		[ -f /etc/lsb-release ] && awk -F'[="]+' '/DESCRIPTION/{print $2}' /etc/lsb-release && return
	}

	calc_disk() {
		local total_size=0
		local array=$@
		for size in ${array[@]}; do
			[ "${size}" == "0" ] && size_t=0 || size_t=$(echo ${size:0:${#size}-1})
			[ "$(echo ${size:(-1)})" == "M" ] && size=$(awk 'BEGIN{printf "%.1f", '$size_t' / 1024}')
			[ "$(echo ${size:(-1)})" == "T" ] && size=$(awk 'BEGIN{printf "%.1f", '$size_t' * 1024}')
			[ "$(echo ${size:(-1)})" == "G" ] && size=${size_t}
			total_size=$(awk 'BEGIN{printf "%.1f", '$total_size' + '$size'}')
		done
		echo ${total_size}
	}

	function info() {
		clear
		print_logo
		virtua=$(virt-what)
		if [[ ${virtua} ]]; then
			virt="$virtua"
		else
			virt="No Virt"
		fi
		HOSTNAME=$(hostname)
		IP=$(curl -s https://ip.vinahost.vn)
		cname=$(awk -F: '/model name/ {name=$2} END {print name}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//')
		cores=$(awk -F: '/model name/ {core++} END {print core}' /proc/cpuinfo)
		freq=$(awk -F: '/cpu MHz/ {freq=$2} END {print freq}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//')
		tram=$(free -m | awk '/Mem/ {print $2}')
		uram=$(free -m | awk '/Mem/ {print $3}')
		swap=$(free -m | awk '/Swap/ {print $2}')
		uswap=$(free -m | awk '/Swap/ {print $3}')
		up=$(awk '{a=$1/86400;b=($1%86400)/3600;c=($1%3600)/60} {printf("%d days, %d hour %d min\n",a,b,c)}' /proc/uptime)
		load=$(w | head -1 | awk -F'load average:' '{print $2}' | sed 's/^[ \t]*//;s/[ \t]*$//')
		opsy=$(get_opsy)
		arch=$(uname -m)
		lbit=$(getconf LONG_BIT)
		kern=$(uname -r)
		date=$(date)
		disk_size1=($(LANG=C df -hPl | grep -wvE '\-|none|tmpfs|devtmpfs|by-uuid|chroot|Filesystem' | awk '{print $2}'))
		disk_size2=($(LANG=C df -hPl | grep -wvE '\-|none|tmpfs|devtmpfs|by-uuid|chroot|Filesystem' | awk '{print $3}'))
		disk_total_size=$(calc_disk ${disk_size1[@]})
		disk_used_size=$(calc_disk ${disk_size2[@]})
		echo "System Info"
		next
		echo "Hostname             : $HOSTNAME"
		echo "Primary IP           : $IP"
		echo "CPU model            : $cname"
		echo "Number of cores      : $cores"
		echo "CPU frequency        : $freq MHz"
		echo "Total size of Disk   : $disk_total_size GB ($disk_used_size GB Used)"
		echo "Total amount of Mem  : $tram MB ($uram MB Used)"
		echo "Total amount of Swap : $swap MB ($uswap MB Used)"
		echo "System uptime        : $up"
		echo "Load average         : $load"
		echo "OS                   : $opsy"
		echo "Arch                 : $arch ($lbit Bit)"
		echo "Kernel               : $kern"
		echo "Virt                 : $virt"
		echo "Date                 : $date"

		return 0
	}
	info
}

function createSwap() {

	#ram_physical=$(dmidecode -t 17 | awk -F":" '/Size/ {print $2}' | sed 's/^[ \t]*//' | awk '{print $1}')

	list_swapon=($(swapon -s | awk '{print $(NR=1)}' | grep -v "Filename" | awk 'BEGIN{ORS=" "}1'))
	echo -e "Show Ram Infomation...\n"
	sleep 2
	free -h
	echo ""
	sleep 2

	while true; do
		echo -e "1024=1GB; 2048=2GB; 3072=3GB; 4096=4GB\n"
		read -p "How much Swaps do you need to create? : " select
		echo ""
		if [ $select -eq 1024 ] || [ $select -eq 2048 ] || [ $select -eq 3072 ] || [ $select -eq 4096 ]; then

			#Xoa swap neu da ton tai
			if [ ! ${#list_swapon[@]} -eq 0 ]; then
				echo -e "Removing installed Swap\n"
				for ((i = 0; i < ${#list_swapon[@]}; i++)); do

					swapoff -v ${list_swapon[i]}
					sed -i '/swap/d' /etc/fstab
					rm -rf ${list_swapon[i]}
				done
			fi
			echo ""
			echo -e "Creating Swap...\n"
			sleep 2
			dd if=/dev/zero of=/swapfile bs=1024 count=$(expr $select \* 1024)
			chown root:root /swapfile
			chmod 600 /swapfile
			mkswap -f /swapfile 
			swapon /swapfile 
			echo "/swapfile   none    swap    sw    0   0" | sudo tee -a /etc/fstab >/dev/null
			sed -i '/vm.swappiness/d' /etc/sysctl.conf >/dev/null
			sysctl vm.swappiness=10 >/dev/null
			echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf >/dev/null
			sed 's/vm.swappiness =.*/vm.swappiness = 10/g' /usr/lib/tuned/virtual-guest/tuned.conf >/dev/null
			echo ""
			echo -e "Show Ram Infomation...\n"
			sleep 2
			free -h
			echo ""
			return
		fi

	done
}

function speed_test() {
	local speedtest=$(wget -4O /dev/null -T300 $1 2>&1 | awk '/\/dev\/null/ {speed=$3 $4} END {gsub(/\(|\)/,"",speed); print speed}')
	local ipaddress=$(ping -c1 -4 -n $(awk -F'/' '{print $3}' <<<$1) | awk -F '[()]' '{print $2;exit}')
	local nodeName=$2
	printf "\e[0;33m%-40s\e[0;32m%-16s\e[0;31m%-14s\e[0m\n" "${nodeName}" "${ipaddress}" "${speedtest}"
}

function network_test() {
	clear
	print_logo
	echo "Network speed test"
	next
	case $1 in
	1)
		speed_test 'http://speedtest1.vtn.com.vn/speedtest/random4000x4000.jpg' 'VNPT, Ha Noi, VN'
		speed_test 'http://speedtest3.vtn.com.vn/speedtest/random4000x4000.jpg' 'VNPT, Ho Chi Minh, VN'
		speed_test 'http://speedtestkv1a.viettel.vn/speedtest/random4000x4000.jpg' 'Viettel Network, Ha Noi, VN'
		speed_test 'http://speedtestkv3a.viettel.vn/speedtest/random4000x4000.jpg' 'Viettel Network, Ho Chi Minh, VN'
		speed_test 'https://proof.ovh.net/files/10Mb.dat' 'FPT Telecom, Ha Noi, VN'
		speed_test 'http://speedtest.ftp.otenet.gr/files/test10Mb.db' 'FPT Telecom, Ho Chi Minh, VN'
		speed_test 'https://lax-ca-us-ping.vultr.com/vultr.com.100MB.bin' 'USA'
		speed_test 'http://speedtest.singapore.linode.com/100MB-singapore.bin' 'Singapore'
		speed_test 'http://speedtest.c1.hkg1.dediserve.com/100MB.test' 'Hongkong'
		speed_test 'http://speedtest.tokyo2.linode.com/100MB-tokyo.bin' 'Japan'
		;;
	2)
		speed_test 'http://speedtest1.vtn.com.vn/speedtest/random4000x4000.jpg' 'VNPT, Ha Noi, VN'
		;;
	3)
		speed_test 'http://speedtest3.vtn.com.vn/speedtest/random4000x4000.jpg' 'VNPT, Ho Chi Minh, VN'
		;;
	4)
		speed_test 'http://speedtestkv1a.viettel.vn/speedtest/random4000x4000.jpg' 'Viettel Network, Ha Noi, VN'
		;;
	5)
		speed_test 'http://speedtestkv3a.viettel.vn/speedtest/random4000x4000.jpg' 'Viettel Network, Ho Chi Minh, VN'
		;;
	6)
		speed_test 'http://speedtest.ftp.otenet.gr/files/test10Mb.db' 'FPT Telecom, Ha Noi, VN'
		;;
	7)
		speed_test 'https://proof.ovh.net/files/10Mb.dat' 'FPT Telecom, Ho Chi Minh, VN'
		;;
	8)
		speed_test 'https://lax-ca-us-ping.vultr.com/vultr.com.100MB.bin' 'USA'
		;;
	9)
		speed_test 'http://speedtest.singapore.linode.com/100MB-singapore.bin' 'Singapore'
		;;
	10)
		speed_test 'http://speedtest.c1.hkg1.dediserve.com/100MB.test' 'Hongkong'
		;;
	11)
		speed_test 'http://speedtest.tokyo2.linode.com/100MB-tokyo.bin' 'Japan'
		;;
	esac

	return 0
}

next() {
	printf "%-82s\n" "#" | sed 's/\s/#/g'
}

function print_logo() {
	echo -e "\e[34;3;20m  
██████╗░██╗██████╗░███████╗░█████╗░████████╗░█████╗░██████╗░███╗░░░███╗██╗███╗░░██╗
██╔══██╗██║██╔══██╗██╔════╝██╔══██╗╚══██╔══╝██╔══██╗██╔══██╗████╗░████║██║████╗░██║
██║░░██║██║██████╔╝█████╗░░██║░░╚═╝░░░██║░░░███████║██║░░██║██╔████╔██║██║██╔██╗██║
██║░░██║██║██╔══██╗██╔══╝░░██║░░██╗░░░██║░░░██╔══██║██║░░██║██║╚██╔╝██║██║██║╚████║
██████╔╝██║██║░░██║███████╗╚█████╔╝░░░██║░░░██║░░██║██████╔╝██║░╚═╝░██║██║██║░╚███║
╚═════╝░╚═╝╚═╝░░╚═╝╚══════╝░╚════╝░░░░╚═╝░░░╚═╝░░╚═╝╚═════╝░╚═╝░░░░░╚═╝╚═╝╚═╝░░╚══╝
  \e[0m"
	next
}

print_menu() {
	print_logo
	printf '%-80s %-5s \n' "1) System Infomation" "#"
	printf '%-80s %-5s \n' "2) Backup and Restore User" "#"
	printf '%-80s %-5s \n' "3) Restore User" "#"
	printf '%-80s %-5s \n' "4) Clean up Disk space" "#"
	printf '%-80s %-5s \n' "5) Create Swap" "#"
	printf '%-80s %-5s \n' "6) Network speed test" "#"
	printf '%-80s %-5s \n' "7) Setup Wordpress in Directadmin" "#"
	echo -e "0) Exit \t\t\t\t\t\t\t    \e[34;5;1mCode by Nin\e[0m  #"
	next
}

print_speedtest_menu() {
	clear
	print_logo
	printf '%-80s %-5s \n' "1) All" "#"
	printf '%-80s %-5s \n' "2) VNPT, Ha Noi, VN" "#"
	printf '%-80s %-5s \n' "3) VNPT, Ho Chi Minh, VN" "#"
	printf '%-80s %-5s \n' "4) Viettel Network, Ha Noi, VN" "#"
	printf '%-80s %-5s \n' "5) Viettel Network, Ho Chi Minh, VN" "#"
	printf '%-80s %-5s \n' "6) FPT Telecom, Ha Noi, VN" "#"
	printf '%-80s %-5s \n' "7) FPT Telecom, Ho Chi Minh, VN" "#"
	printf '%-80s %-5s \n' "8) USA" "#"
	printf '%-80s %-5s \n' "9) Singapore" "#"
	printf '%-80s %-5s \n' "10) HongKong" "#"
	printf '%-80s %-5s \n' "11) Japan" "#"
	echo -e "0) Exit \t\t\t\t\t\t\t    \e[34;5;1mCode by Nin\e[0m  #"
	next
}

get_option() {
	opt=69
	while [ $opt -gt $1 ]; do
		printf "Option: "
		read -r opt
		case $opt in
		'' | *[!0-9]*)
			echo "invalid option"
			opt=69
			;;
		*) ;;

		esac
	done
	return $opt
}

#Main ==================================================================================
main() {
	opt=69
	while [ ! $opt -eq 0 ]; do
		clear
		print_menu
		get_option 10
		opt=$?
		case $opt in
		1)
			system_info
			;;
		2)
			backupUser
			;;
		3)	
			wget -P /home/admin/admin_backups/ -N "https://raw.githubusercontent.com/nintech-sudo/directadmin/main/restore.sh"
			. /home/admin/admin_backups/restore.sh	
			rm -rf /home/admin/admin_backups/restore.sh
			;;
		4)
			free_up_disk_space
			;;
		5)
			createSwap
			;;
		6)
			again="y"
			while [ $again == "y" ]; do
				print_speedtest_menu
				get_option 10
				net_opt=$?
				if [ $net_opt -ne 0 ]; then
					network_test $net_opt
					printf "Try again with another host? (y for YES): "
					read -r again
					re='[a-zA-Z]'
					if [[ "$again" =~ $re ]]; then
						case $again in
						y) ;;

						Y)
							again="y"
							;;
						*)
							again="n"
							;;
						esac
					else
						again="n"
					fi
				else
					again="n"
				fi
			done
			opt=69
			;;
		7)      
			wget -P /home/admin/admin_backups/ -N "https://raw.githubusercontent.com/nintech-sudo/directadmin/main/setup_wp.sh"
			. /home/admin/admin_backups/setup_wp.sh
			rm -rf /home/admin/admin_backups/setup_wp.sh
			;;

		0)
			echo "Exit"
			return 0
			;;
		esac
		next
		printf "Press [Enter] to back to Main menu..."
		read
	done
}

clear
main
