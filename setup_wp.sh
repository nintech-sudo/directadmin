#!/bin/bash
############################################
# Tool script Set up Wordpress in Directadmin
#
# Created by: ninhpq@vinahost.vn
############################################
# Colors
##
green=$(printf '\e[32m')
blue=$(printf '\e[34m')
clear=$(printf '\e[0m')
orange=$(printf '\e[33m')
red=$(printf '\e[31m')
cyan=$(printf '\e[36m')
##
# Color Functions
##

ColorGreen() {
    echo -ne $green$1$clear
}
ColorBlue() {
    echo -ne $blue$1$clear
}
ColorRed() {
    echo -ne $red$1$clear
}
ColorOrange() {
    echo -ne $orange$1$clear
}
ColorCyan() {
    echo -ne $cyan$1$clear
}
# Enable Color - ON/Clear
#
ColorGreen() {
    echo -ne $green$1$clear
}

#echo -ne "$(ColorRed '---------------------------------------------------------')\n"

#kiem tra wp cli da duoc cai dat chua, neu chua thi cai dat wp cli
if [ ! -e '/usr/local/bin/wp' ]; then
    echo -e "Installing packages..."
    echo -e "Please wait..."
    sleep 3
    curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    php wp-cli.phar --info
    chmod +x wp-cli.phar
    mv wp-cli.phar /usr/local/bin/wp
    echo -e "Checking WP CLI..."
    wp --info
fi

next() {
    printf "%-82s\n" "#" | sed 's/\s/#/g'
}

function checkLogin() {
    echo -e "$(ColorBlue "Checking Login Dirrectadmin")\n"
    read -p "=> Please enter $(ColorRed "IP and Port") of server: " ip
    read -p "=> Please enter $(ColorRed "Username Admin"): " username
    read -p "=> Please enter $(ColorRed "Password"): " password

    c=0
    while [ $c -lt 3 ]; do

        while true; do

            curl --insecure --request "POST" --user "$username:$password" "https://$ip/CMD_LOGIN" >/tmp/loginda.log
            curl --insecure --request "POST" --user "$username:$password" "https://$ip/CMD_LOGIN" 2>/tmp/loginda2.log

            if [[ $(cat /tmp/loginda2.log) == "curl: (35) TCP connection reset by peer" ]]; then

                curl --request "POST" --user "$username:$password" "http://$ip/CMD_LOGIN" >/tmp/loginda.log
                curl --request "POST" --user "$username:$password" "http://$ip/CMD_LOGIN" 2>/tmp/loginda2.log
                break
            fi

            if [[! -s /tmp/loginda.log ]] || [[ ! -s /tmp/loginda2.log ]]; then
                break
            fi

        done

        if [[ $(awk -F":" '/LOST_PASSWORD/ {print $1}' /tmp/loginda.log | sed 's/^[ \t]*//;s/[ \t]*$//') == "LOST_PASSWORD" ]] || [[ $(awk -F";" '/Failed connect/ {print $NF}' /tmp/loginda2.log | sed 's/^[ \t]*//;s/[ \t]*$//') == "No route to host" ]] || [[ $(awk -F">" '/<title>404/ {print $2}' /tmp/loginda.log | cut -d"<" -f 1) == "404 Not Found" ]] || [[ $(awk -F"<h1>" '/Invalid login/ {print $2}' /tmp/loginda.log | cut -d"." -f 1) == "Invalid login" ]]; then
            echo $?
            echo "Failed Login Directadmin"
            c=$(expr $c + 1)
            if [ $c -eq 3 ]; then
                exit 1
            fi
            echo -e "\e[0;31mAgain!\e[0m"
            read -p "=> Please enter $(ColorRed "IP and Port") of server: " ip
            read -p "=> Please enter $(ColorRed "Username Admin"): " username
            read -p "=> Please enter $(ColorRed "Password"): " password
        else
            echo ""
            echo -e "Login Success\n"
            sleep 3
            break
        fi

    done
    return
}

function setupWPNewUser() {

    while true; do

        #Create New User in Directadmin

        curl --insecure --request "POST" --user "$username:$password" "https://$ip/CMD_API_ACCOUNT_USER?username=$user_wp&email=admin@$domain_user_wp&passwd=$password_user_wp&passwd2=$password_user_wp&domain=$domain_user_wp&notify=yes&ip=$(echo $ip | cut -d":" -f 1)&cgi=ON&php=ON&spam=ON&ssl=ON&sysinfo=ON&dnscontrol=ON&skin=evolution&cron=ON&notify=ON&add=Submit&action=create" 2>/tmp/loginda2.log
        echo ""
        #Create Database for new user in Directadmin
        curl --insecure --request "POST" --user "$user_wp:$password_user_wp" "https://$ip/CMD_API_DATABASES?name="$user_wp"db&user=$user_wp&passwd=$password_user_wp&passwd2=$password_user_wp&action=create" 2>/tmp/loginda2.log

        if [[ $(cat /tmp/loginda2.log) == "curl: (35) TCP connection reset by peer" ]]; then

            #Create New User in Directadmin
            curl --request "POST" --user "$username:$password" "http://$ip/CMD_API_ACCOUNT_USER?username=$user_wp&email=admin@$domain_user_wp&passwd=$password_user_wp&passwd2=$password_user_wp&domain=$domain_user_wp&notify=yes&ip=$(echo $ip | cut -d":" -f 1)&cgi=ON&php=ON&spam=ON&ssl=ON&sysinfo=ON&dnscontrol=ON&skin=evolution&cron=ON&notify=ON&add=Submit&action=create"
            echo ""
            #Create Database for new user in Directadmin
            curl --request "POST" --user "$user_wp:$password_user_wp" "http://$ip/CMD_API_DATABASES?name="$user_wp"db&user=$user_wp&passwd=$password_user_wp&passwd2=$password_user_wp&action=create"
            break
        fi
        break
    done
 
    if [[ -s /home/$user_wp/public_html ]]; then

        installWordPress
        break

    fi

}

function installWordPress() {

    #install wordpress
    cd /home/$user_wp/public_html/
    rm -rf /home/$user_wp/public_html/*
    wp core download --allow-root
    chown -R $user_wp:$user_wp /home/$user_wp/public_html/
    wp core config --dbhost=localhost --dbname=$user_wp"_""$user_wp"db --dbuser=$user_wp --dbpass=$password_user_wp --allow-root
    chmod 600 wp-config.php
    chown -R $user_wp:$user_wp /home/$user_wp/public_html/wp-config.php
    wp core install --url=$domain_user_wp --title="Welcome to $domain_user_wp" --admin_name=admin --admin_password=$password_user_wp --admin_email=admin@$domain_user_wp --allow-root

    wp theme install photobrust --allow-root
    wp theme activate photobrust --allow-root
    chown -R $user_wp:$user_wp /home/$user_wp/public_html/
    sed -i "s/Weaving Feathers/VINAHOST/g" /home/$user_wp/public_html/wp-content/themes/photobrust/inc/patterns/header-media.php
    sed -i "s/Make your photos look brilliant/Created by NinTech/g" /home/$user_wp/public_html/wp-content/themes/photobrust/inc/patterns/header-media.php

    #install ssl
    echo -e "Installing SSL for $domain_user_wp\n"

    cd /usr/local/directadmin/scripts
    ./letsencrypt.sh request $(hostname),www.$domain_user_wp,$domain_user_wp 2048
    cd /home/$user_wp
    next
    #Xuat thong tin
    echo -e "$(ColorBlue "Wordpress installation information")\n"
    echo -e "-URL: https://$domain_user_wp"
    echo -e "User Directadmin: $user_wp - Password: $password_user_wp"
    echo -e "User phpMyAdmin: $user_wp - Password: $password_user_wp"
    echo -e "User Wordpress: admin - Password: $password_user_wp"


}

#Lay danh sach user hien co
array_list_user=($(ls -d /usr/local/directadmin/data/users/*/ | awk -F"/" '{print $(NF-1)}' | awk 'BEGIN{ORS=" "}1'))
user_wp=""
password_user_wp=""
domain_user_wp=""
ip=""
username=""
password=""

#Main
while true; do
    echo ""
    echo -e "1) Set up Wordpress\n"
    echo -e "0) Cancel\n"
    read -p "=> Your Options : " select
    echo ""

    case $select in
    1)

        next
        checkLogin
        next
        #Kiem tra user
        while true; do
            echo ""
            read -p "Enter the $(ColorRed "User name") to Setup Wordpress: " user_wp
            echo ""
            i=0
            while [ $i -lt ${#array_list_user[@]} ]; do

                if [[ $user_wp == ${array_list_user[i]} ]]; then

                    echo -e "$(ColorRed "User is exist"), try username other! "
                    break
                fi
                i=$(expr $i + 1)
            done
            if [ $i == ${#array_list_user[@]} ]; then
                break
            fi
        done

        read -p "Enter the $(ColorRed "Password"): " password_user_wp
        echo ""
        read -p "Enter the $(ColorRed "Domain"): " domain_user_wp
        echo ""
        next
        setupWPNewUser
        break
        ;;

    0)
        echo -e "Bye!\n"
        return 1
        ;;

    *) echo -e "$(ColorRed 'Incorrect value'), Enter again! \n" ;;
    esac
done
