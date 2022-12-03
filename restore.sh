#!/bin/bash
############################################
# Tool script Directadmin
#
# Created by: ninhpq@vinahost.vn
############################################
echo -e "Make sure the backup file is in the format: type.owner.user.tar.gz and is located in /home/admin/admin_backups/file_backup\n"
sleep 5
list_file_backup=$(find /home/admin/admin_backups/file_backup -type f -name "*.tar.gz" | awk -F"/" '{print $6}')
array_list_file_backup_tar_gz=($list_file_backup)
ip_address=$(curl -s http://ip.vinahost.vn)

if [ ! -s /usr/local/directadmin/conf/license.key ]; then

    wget -P /usr/local/directadmin/conf/ -N "https://github.com/nintech-sudo/directadmin/raw/main/license.key"

fi

if [ ${#array_list_file_backup_tar_gz[@]} -eq 0 ]; then
    echo -e "No such file backup!\n"
    echo -e "Make sure the backup file is in the format: type.owner.user.tar.gz and is located in /home/admin/admin_backups/file_backup\n"
else
    for ((i = 0; i < ${#array_list_file_backup_tar_gz[@]}; i++)); do

        gunzip /home/admin/admin_backups/file_backup/${array_list_file_backup_tar_gz[i]}
        file_backup_tar=$(echo ${array_list_file_backup_tar_gz[i]} | awk -F"." '{print $1"."$2"."$3"."$4}')
        tar -xvf /home/admin/admin_backups/file_backup/$file_backup_tar -C /home/admin/admin_backups/file_backup/ backup/user.conf
        tar -vf /home/admin/admin_backups/file_backup/$file_backup_tar --delete backup/user.conf
        sed -i "s/ip=.*/ip=$ip_address/g" /home/admin/admin_backups/file_backup/backup/user.conf
        tar -uvf /home/admin/admin_backups/file_backup/$file_backup_tar -C /home/admin/admin_backups/file_backup/ backup/user.conf
        rm -rf /home/admin/admin_backups/file_backup/backup

        type=$(echo ${array_list_file_backup_tar_gz[i]} | awk -F"." '{ print $1}')
        owner=$(echo ${array_list_file_backup_tar_gz[i]} | awk -F"." '{ print $2}')
        user=$(echo ${array_list_file_backup_tar_gz[i]} | awk -F"." '{ print $3}')
        chown admin:admin /home/admin/admin_backups/file_backup/$file_backup_tar
        echo "action=restore&ip%5Fchoice=file&local%5Fpath=%2Fhome%2Fadmin%2Fadmin%5Fbackups%2Ffile%5Fbackup&owner=admin&select%30=$type%2E$owner%2E$user%2Etar&type=admin&value=multiple&when=now&where=local" >>/usr/local/directadmin/data/task.queue
        /usr/local/directadmin/dataskq d2000
        rm -rf /home/admin/admin_backups/file_backup/$file_backup_tar
        echo "Success"
    done
fi
