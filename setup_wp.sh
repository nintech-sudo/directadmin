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


ip=$(curl -s http://ip.vinahost.vn)
port=$(netstat -ntulp | grep directadmin | awk -F":::" '{print $2}' | sed 's/^[ \t]*//;s/[ \t]*$//')

function checkLogin() {

    echo -e "$(ColorBlue "Checking Login Dirrectadmin")\n"
    echo -e "Server: $ip:$port \n"
    read -p "=> Please enter $(ColorRed "Username Admin"): " username
    read -p "=> Please enter $(ColorRed "Password"): " password

    c=0
    while [ $c -lt 3 ]; do

        while true; do

            curl --insecure --request "POST" --user "$username:$password" "https://$ip:$port/CMD_LOGIN" >/tmp/loginda.log
            curl --insecure --request "POST" --user "$username:$password" "https://$ip:$port/CMD_LOGIN" 2>/tmp/loginda2.log

            if [[ $(cat /tmp/loginda2.log) == "curl: (35) TCP connection reset by peer" ]]; then

                curl --request "POST" --user "$username:$password" "http://$ip:$port/CMD_LOGIN" >/tmp/loginda.log
                curl --request "POST" --user "$username:$password" "http://$ip:$port/CMD_LOGIN" 2>/tmp/loginda2.log
                break
            fi

            if [[ ! -s /tmp/loginda.log ]] || [[ ! -s /tmp/loginda2.log ]]; then
                break
            fi

        done

        if [[ $(awk -F":" '/LOST_PASSWORD/ {print $1}' /tmp/loginda.log | sed 's/^[ \t]*//;s/[ \t]*$//') == "LOST_PASSWORD" ]] ||
            [[ $(awk -F";" '/Failed connect/ {print $NF}' /tmp/loginda2.log | sed 's/^[ \t]*//;s/[ \t]*$//') == "No route to host" ]] ||
            [[ $(awk -F">" '/<title>404/ {print $2}' /tmp/loginda.log | cut -d"<" -f 1) == "404 Not Found" ]] ||
            [[ $(awk -F"<h1>" '/Invalid login/ {print $2}' /tmp/loginda.log | cut -d"." -f 1) == "Invalid login" ]] || [[ -s /tmp/loginda2.log ]]; then

            echo "Failed Login Directadmin"
            c=$(expr $c + 1)
            if [ $c -eq 3 ]; then
                exit 1
            fi
            echo -e "\e[0;31mAgain!\e[0m"
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

    sed -i 's/max_username_length=.*/max_username_length=30/g' /usr/local/directadmin/conf/directadmin.conf
    service directadmin restart

    while true; do

        #Create New User in Directadmin

        curl --insecure --request "POST" --user "$username:$password" "https://$ip:$port/CMD_API_ACCOUNT_USER?username=$user_wp&email=admin@$domain_user_wp&passwd=$password_user_wp&passwd2=$password_user_wp&domain=$domain_user_wp&notify=yes&ip=$(echo $ip | cut -d":" -f 1)&cgi=ON&php=ON&spam=ON&ssl=ON&sysinfo=ON&dnscontrol=ON&skin=evolution&cron=ON&notify=ON&add=Submit&action=create" 2>/tmp/loginda2.log
        echo ""
        #Create Database for new user in Directadmin
        curl --insecure --request "POST" --user "$user_wp:$password_user_wp" "https://$ip:$port/CMD_API_DATABASES?name="$user_wp"db&user=$user_wp&passwd=$password_user_wp&passwd2=$password_user_wp&action=create" 2>/tmp/loginda2.log

        if [[ $(cat /tmp/loginda2.log) == "curl: (35) TCP connection reset by peer" ]]; then

            #Create New User in Directadmin
            curl --request "POST" --user "$username:$password" "http://$ip:$port/CMD_API_ACCOUNT_USER?username=$user_wp&email=admin@$domain_user_wp&passwd=$password_user_wp&passwd2=$password_user_wp&domain=$domain_user_wp&notify=yes&ip=$(echo $ip | cut -d":" -f 1)&cgi=ON&php=ON&spam=ON&ssl=ON&sysinfo=ON&dnscontrol=ON&skin=evolution&cron=ON&notify=ON&add=Submit&action=create"
            echo ""
            #Create Database for new user in Directadmin
            curl --request "POST" --user "$user_wp:$password_user_wp" "http://$ip:$port/CMD_API_DATABASES?name="$user_wp"db&user=$user_wp&passwd=$password_user_wp&passwd2=$password_user_wp&action=create"
            break
        fi
        break
    done

    if [[ -s /home/$user_wp/public_html ]]; then
        echo -e "Installing Wordpress... \n"
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

#    #install ssl
#    echo -e "Installing SSL for $domain_user_wp\n"
#    if [[ ! -s /usr/local/directadmin/scripts/letsencrypt.sh ]]; then
#
#        cd /usr/local/directadmin/custombuild
#        ./build update
#        sed -i 's/doDAVersionCheck$/doDAVersionCheck:/' build
#        ./build letsencrypt
#        break
#    fi
#    sed -i 's/dns_ttl=.*/dns_ttl=1/g' /usr/local/directadmin/conf/directadmin.conf
#    sed -i 's/letsencrypt=.*/letsencrypt=1/g' /usr/local/directadmin/conf/directadmin.conf

#    cd /usr/local/directadmin/scripts
#    ./letsencrypt.sh request $(cat /usr/local/directadmin/conf/directadmin.conf | awk -F"=" '/servername/ {print $2}'),$domain_user_wp,www.$domain_user_wp 4096

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
username=""
password=""

#Main
while true; do
    next
    echo ""
    read -p "=> Do you want to Setup Wordpress (y/n) : " select
    echo ""

    case $select in
    y | yes)

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

    n | no)
        echo -e "Bye!\n"
        break
        ;;

    *) echo -e "$(ColorRed 'Incorrect value'), Enter again! \n" ;;
    esac
done
