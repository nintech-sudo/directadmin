#!/bin/bash
############################################
# Tool script Directadmin
#
# Created by: ninhpq@vinahost.vn
############################################

if [ ! -e '/usr/sbin/dmidecode' ]; then
    echo -e "Installing packages..."
    echo -e "Please wait..."
    yum -y install bc >/dev/null 2>&1
fi

ram_physical=$(dmidecode -t 17 | awk -F":" '/Size/ {print $2}' | sed 's/^[ \t]*//' | awk '{print $1}')

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
    case $select in
    1024)
        echo "Creating Swap 1GB"
        _create_swap;
        break
        ;;

    2048)
        echo -e "Creating Swap 2GB"
        _create_swap;
        break
        ;;
    3072)
        echo -e "Creating Swap 3GB"
        _create_swap;
        break
        ;;
    4096)
        echo -e "Creating Swap 4GB"
        _create_swap;
        break
        ;;
    0)
        echo -e "Exit"
        return
        ;;
    *) echo -e "\e[0;31mIncorrect value\e[0m, Enter again! \n" ;;
    esac
done

function _create_swap() {

    #Xoa swap neu da ton tai
    if [ ! ${#list_swapon[@]} -eq 0 ]; then
        echo -e "Removing installed Swap "
        for ((i = 0; i < ${#list_swapon[@]}; i++)); do

            swapoff -v ${list_swapon[i]}
            sed -i '/swap/d' /etc/fstab
            rm -rf ${list_swapon[i]}
        done
    fi
    dd if=/dev/zero of=/swapfile bs=1024 count=$(expr $select \* 1024)
    chown root:root /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo "/swapfile   none    swap    sw    0   0" | sudo tee -a /etc/fstab
    sed -i '/vm.swappiness/d' /etc/sysctl.conf
    sysctl vm.swappiness=10
    echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf
    sed 's/vm.swappiness =.*/vm.swappiness = 10/g' /usr/lib/tuned/virtual-guest/tuned.conf
    echo -e "Show Ram Infomation...\n"
    sleep 2
    free -h
    echo ""
 
}
