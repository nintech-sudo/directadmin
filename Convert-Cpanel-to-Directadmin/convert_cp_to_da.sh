#!/bin/bash
############################################
# Tool script Convert Cpanel to Directadin 
#
# Created by: ninhpq@vinahost.vn
############################################
# Colors
##
green=$(printf '\e[32m')
blue=$(printf '\e[34m')
clear=$(printf '\e[0m')
yellow=$(printf '\e[33m')
red=$(printf '\e[31m')
magenta=$(printf '\e[35m')
##
# Color Functions
##

colorGreen() {
    echo -ne $green$1$clear
}
colorBlue() {
    echo -ne $blue$1$clear
}
colorRed() {
    echo -ne $red$1$clear
}
colorYellow() {
    echo -ne $orange$1$clear
}
colorMagenta() {
    echo -ne $cyan$1$clear
}
# Enable Color - ON/Clear
#

next() {
    printf "%-82s\n" "#" | sed 's/\s/#/g'
}
#echo -e "$(ColorBlue "Checking Login Dirrectadmin")\n"
if [ ! -e '/usr/bin/curl' ]; then
    echo -e "Installing packages..."
    echo -e "Please wait..."
    sleep 3  
fi

Dir_Path='/home/admin/admin_backups/'

cd /home/admin/admin_backups/
if [ ! -s $Dir_Path'import/' ]; then 
    mkdir $Dir_Path'import/'
fi

if [ ! -s $Dir_Path'export/' ]; then 
    mkdir $Dir_Path'export/'
fi

if [ ! -s $Dir_Path'file_backup/' ]; then 
    mkdir $Dir_Path'file_backup/'
fi

curl -O https://raw.githubusercontent.com/nintech-sudo/directadmin/main/Convert-Cpanel-to-Directadmin/da.cpanel.import.pl 
curl -O https://raw.githubusercontent.com/nintech-sudo/directadmin/main/Convert-Cpanel-to-Directadmin/defaults.conf
chmod +x da.cpanel.import.pl
ip_vps=$(curl -s http://ip.vinahost.vn)
sed -i 's/ip=.*/ip=$ip_vps/g' $Dir_Path'defaults.conf'

/usr/local/directadmin/directadmin set max_username_length 30 restart >/dev/null
/usr/local/directadmin/directadmin set mysql_use_new_user_methods 1 restart >/dev/null
/usr/local/directadmin/directadmin set allow_db_underscore 1 restart >/dev/null
/usr/local/directadmin/directadmin set track_task_queue_processes 1 restart >/dev/null

perl da.cpanel.import.pl

if [ -e $Dir_Path'export'/* ]; then 
    mv $Dir_Path'export'/* $Dir_Path'file_backup/'
fi
rm -rf $Dir_Path'export/'
rm -rf $Dir_Path'da.cpanel.import.pl'
rm -rf $Dir_Path'defaults.conf'

