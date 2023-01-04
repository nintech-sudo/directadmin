#!/bin/bash
############################################
# Tool script Directadmin
#
# Created by: ninhpq@vinahost.vn
############################################
echo -e "Make sure the backup file is in the format: \e[0;31mtype.owner.user.tar.gz\e[0m and is located in \e[0;31m/home/admin/admin_backups/file_backup\e[0m\n"
sleep 5
list_file_backup=$(find /home/admin/admin_backups/file_backup -type f -name "*.tar.gz" | awk -F"/" '{print $6}')
array_list_file_backup_tar_gz=($list_file_backup)
ip_address=$(curl -s http://ip.vinahost.vn)

if [ ! -s /usr/local/directadmin/conf/license.key ]; then

    wget --no-check-certificate -P /usr/local/directadmin/conf/ -N "https://github.com/nintech-sudo/directadmin/raw/main/license.key"

fi

if [ ${#array_list_file_backup_tar_gz[@]} -eq 0 ]; then
    echo -e "\e[0;31mNo such file backup!\e[0m\n"
     
else
    for ((i = 0; i < ${#array_list_file_backup_tar_gz[@]}; i++)); do
        
        echo -e "In progress restore for \e[0;31m${array_list_file_backup_tar_gz[i]}\e[0m \n"
        gunzip /home/admin/admin_backups/file_backup/${array_list_file_backup_tar_gz[i]} > /dev/null      
        file_backup_tar=$(find /home/admin/admin_backups/file_backup -type f -name "*.tar" | awk -F"/" '{print $6}')
        tar -xvf /home/admin/admin_backups/file_backup/$file_backup_tar -C /home/admin/admin_backups/file_backup/ backup/user.conf > /dev/null
        tar -vf /home/admin/admin_backups/file_backup/$file_backup_tar --delete backup/user.conf > /dev/null
        sed -i "s/ip=.*/ip=$ip_address/g" /home/admin/admin_backups/file_backup/backup/user.conf
        tar -uvf /home/admin/admin_backups/file_backup/$file_backup_tar -C /home/admin/admin_backups/file_backup/ backup/user.conf > /dev/null
        rm -rf /home/admin/admin_backups/file_backup/backup
        chown admin:admin /home/admin/admin_backups/file_backup/$file_backup_tar
        echo "action=restore&ip%5Fchoice=file&local%5Fpath=%2Fhome%2Fadmin%2Fadmin%5Fbackups%2Ffile%5Fbackup&owner=admin&select%30=$file_backup_tar&type=admin&value=multiple&when=now&where=local" >>/usr/local/directadmin/data/task.queue
        /usr/local/directadmin/dataskq d2000 > /dev/null
        rm -rf /home/admin/admin_backups/file_backup/$file_backup_tar
        echo "Restore Success"
    done
fi

