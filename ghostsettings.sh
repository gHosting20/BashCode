#!/bin/bash
clear
echo "gHost configuration started.."
sleep 3s
comm=""
if [ -n "$(command -v apt-get)" ]; then
        echo "apt-get"
        comm="apt-get"
fi
if [ -n "$(command -v apt)" ]; then
        echo "apt"
        comm="apt"
fi
if [ -n "$(command -v yum)" ]; then
        echo "yum"
        comm="yum"
	echo "non è ancora stata eleborata l'integrazione di distro yum based"
	exit 1
fi

if [[ $comm == "" ]]; then
    echo "no apt, apt-get or yum found"
    exit 1
fi
clear
echo "update and upgrade starting..."
sudo apt update && sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y
sudo apt install figlet -y
sudo apt install dos2unix -y
sudo apt install git -y
clear
echo "checking firewall..."
checkufw='ufw'
if ! dpkg -s $checkufw >/dev/null 2>&1; then
    echo "installing ufw firewall"
    sudo apt install ufw -y
else
    echo "ufw firewall found"
fi

#php check and install
checkphp='php'
webserver=''
clear
echo "check what type of web server is running"
sleep 3s
#check webserver
if [[ `ps -acx|grep apache|wc -l` > 0 ]]; then
    echo "Found Apache"
    webserver='Apache'
fi
if [[ `ps -acx|grep nginx|wc -l` > 0 ]]; then
    echo "Found Nginx"
    webserver='Nginx'
fi

if [ "$webserver" == "" ]; then
    echo "no type of web server found"
    echo "Non è stata registrata la presenza di alcun web server...."
    echo "Per continuare è necessario installare o Apache o Nginx..."
    echo -n "Vuoi installare Apache o Nginx? "
    read choice < /dev/tty
    if [ "$choice" == "Apache" ]; then
        echo "Apache installing..."
        sudo apt install apache2 -y
        sudo systemctl start apache2
        echo "Apache installed and running"
        webserver='Apache'
    elif [ "$choice" == "Nginx" ]; then
        echo "Nginx installing..."
        sudo apt install nginx -y
        sudo systemctl start nginx
        echo "Nginx installed and running"
        webserver='Nginx'
    else
        echo "Se non vuoi installare nessun tipo di web server gHost non puo essere configurato"
        exit 1
    fi
fi

#check bug user per debian
sudo apt-get remove --purge unscd -y
sudo rm -f /etc/localtime
sudo ln -sf /usr/share/zoneinfo/Europe/Rome /etc/localtime
cd /var/www && sudo mkdir ghost
cd /var/www && sudo mkdir ghost_file_manager

#certbot
clear
echo "Certbot installing..."
sleep 3s
if [ "$webserver" == "Apache" ]; then
    sudo add-apt-repository ppa:certbot/certbot
    sudo apt install python-certbot-apache -y
else
    sudo add-apt-repository ppa:certbot/certbot
    sudo apt install python-certbot-nginx -y
fi
#check php


if [ "$webserver" == "Apache" ]; then
clear
echo "writing Apache conf"
sleep 3s
LINESTART=$(grep -nr "DocumentRoot" /etc/apache2/sites-available/000-default.conf | cut -d : -f1 )
TEXT='Alias /ghostAPI /var/www/ghost'
TEXT1='<Directory /var/www/ghost>'
TEXT2='Require all granted'
TEXT3='AllowOverride all'
TEXT4='</Directory>'

sed -i $((LINESTART+1))"i\\$TEXT" /etc/apache2/sites-available/000-default.conf
sed -i $((LINESTART+2))"i\\$TEXT1" /etc/apache2/sites-available/000-default.conf
sed -i $((LINESTART+3))"i\\$TEXT2" /etc/apache2/sites-available/000-default.conf
sed -i $((LINESTART+4))"i\\$TEXT3" /etc/apache2/sites-available/000-default.conf
sed -i $((LINESTART+5))"i\\$TEXT4" /etc/apache2/sites-available/000-default.conf
if ! dpkg -s $checkphp >/dev/null 2>&1; then
	clear
        echo "no found"
        echo "php installing...."
	sleep 3s
        sudo apt-get install -y php7.2 libapache2-mod-php php-mysql
        sudo apt-get install php7.2 -y
        sudo apt-get install php7.2-{bcmath,dev,bz2,intl,gd,mbstring,mysql,zip,fpm} -y
        if [[ `php -v` < 40 ]]; then
            sudo apt-get install -y php libapache2-mod-php php-mysql
            sudo apt-get install php -y
            sudo apt-get install php-{bcmath,dev,bz2,intl,gd,mbstring,mysql,zip,fpm} -y
        fi


else
	clear
    echo "php found"
    sleep 3s
    dpkg-query -W -f='${Status} ${Version}\n' php
fi
fi

if [ "$webserver" == "Nginx" ]; then
  FILE=/etc/nginx/sites-enabled/default
if [ -f "$FILE" ]; then
    FILE=/etc/nginx/sites-available/default
else
    echo "$FILE non trovato"
    echo -n "Perfavore digitare il nome del file di configurazione che gHost dovrà scrivere per completare la configurazione: "
    read path < /dev/tty
    FILE=/etc/nginx/sites-available/$path
    if [ -f "$FILE" ]; then
     clear
    echo "$FILE found"
else
    echo "$FILE non trovato"
    exit 1
fi
fi
phpinst=false

if [[ `php -v` > 40 ]]; then
     clear
    echo "php found"
     sleep 3s
     phpinst=true

else
    clear
    echo "php installing..."
   sleep 3s
    sudo apt install php7.2 php7.2-fpm php7.2-dev php7.2-mysql  -y
    sudo systemctl restart nginx
fi

if [[ `php -v` < 40 ]]; then
    echo "try to get a better version of php..."
    sudo apt-get update
    sudo apt-get install php-fpm php-dev php-mysql -y
    sudo systemctl restart nginx
fi

if [[ `php -v` < 40 ]]; then
    echo "retry php installing..."
    echo "php installing..."
    sudo apt install -y apt-transport-https lsb-release ca-certificates
    wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
    echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list
    sudo apt update
    sudo apt install php7.2 php7.2-fpm php7.2-dev php7.2-mysql -y
    sudo systemctl restart nginx
fi
clear
echo "writing nginx conf"
sleep 3s

word=`php -v | awk '/^PHP/{print $2}'`
version=`printf '%-.3s' "$word"`
if ! $phpinst ; then
sed -i 's/index index.html index.htm index.nginx-debian.html;/index index.php index.html index.htm index.nginx-debian.html;/' $FILE
LINESTART=$(grep -nr ".php$ {" $FILE | cut -d : -f1 )
LINEEND=$((LINESTART+2))
sed -i "${LINESTART},${LINEEND} s/# *//" $FILE
LINESTART1=$(grep -nr "fastcgi_pass unix" $FILE | cut -d : -f1 )
LINEEND1=$((LINESTART1+0))
sed -i "${LINESTART1},${LINEEND1} s/# *//" $FILE
LINEPHP=`sed -n ${LINESTART1}p $FILE`
rgtline=$(echo $LINEPHP | sed 's/\//\\\//g')
sed -i 's/'"${rgtline}"'/fastcgi_pass unix:\/var\/run\/php\/php'"$version"'-fpm.sock;}/' $FILE
fi
TEXT='location /ghostAPI/ {'
TEXT1='alias /var/www/ghost/;'
TEXT2='index index.php;'
TEXT3='location ~ \.php$ {'
TEXT4='include snippets/fastcgi-php.conf;'
TEXT5='fastcgi_param SCRIPT_FILENAME $request_filename;'
TEXT6='fastcgi_pass unix:/var/run/php/php'"$version"'-fpm.sock;'
TEXT7='}'
sed -i '/^server {/,/^}/!b;/^}/i\'"$TEXT"'' $FILE
sed -i '/^server {/,/^}/!b;/^}/i\'"$TEXT1"'' $FILE
sed -i '/^server {/,/^}/!b;/^}/i\'"$TEXT2"'' $FILE
sed -i '/^server {/,/^}/!b;/^}/i\'"$TEXT3"'' $FILE
sed -i '/^server {/,/^}/!b;/^}/i\'"$TEXT4"'' $FILE
sed -i '/^server {/,/^}/!b;/^}/i\'"$TEXT5"'' $FILE
sed -i '/^server {/,/^}/!b;/^}/i\'"$TEXT6"'' $FILE
sed -i '/^server {/,/^}/!b;/^}/i\'"$TEXT7"'' $FILE
sed -i '/^server {/,/^}/!b;/^}/i\'"$TEXT7"'' $FILE
fi

#install ruby and gems per scout-realtime
clear
echo "installing ruby and scout realtime gem"
sleep 3s
sudo apt -y install ruby-full
sudo apt-get -y install rubygems
sudo gem install scout_realtime

#check vsftpd
clear
echo "checking vsftpd package"
sleep 3s
checkvsftpd='vsftpd'

#if [[ $checkvsftpd == *"no packages found"* ]]; then
if ! dpkg -s $checkvsftpd >/dev/null 2>&1; then
        echo "no found"
        echo "vsftpd installing...."
        sudo apt-get install -y vsftpd
        sudo systemctl start vsftpd
        sudo systemctl enable vsftpd
        echo "settings vsftpd.conf"
        echo "making bakup of original file..."
        sudo cp /etc/vsftpd.conf /etc/vsftpd.conf.back
        sed -i 's/#write_enable=YES/write_enable=YES/' /etc/vsftpd.conf
        sed -i 's/#local_umask=022/local_umask=022/' /etc/vsftpd.conf
        sed -i 's/#chroot_local_user=YES/chroot_local_user=YES/' /etc/vsftpd.conf
        sed -i 's/user_sub_token=$USER/#user_sub_token=$USER/' /etc/vsftpd.conf
        sed -i 's/local_root=/home/$USER/ftp/#local_root=/home/$USER/ftp/' /etc/vsftpd.conf
        echo "writing vsftpd.conf"
        echo "userlist_enable=YES" >> /etc/vsftpd.conf
        echo "userlist_file=/etc/vsftpd.userlist" >> /etc/vsftpd.conf
        echo "userlist_deny=NO" >> /etc/vsftpd.conf
        echo "force_dot_files=YES" >> /etc/vsftpd.conf
        echo "pasv_min_port=40000" >> /etc/vsftpd.conf
        echo "pasv_max_port=50000" >> /etc/vsftpd.conf
        echo "Restarting vsftpd..."
        sudo systemctl restart vsftpd
        echo "Restarted."

else
    echo "vsftpd found"
    dpkg-query -W -f='${Status} ${Version}\n' vsftpd
fi

sudo apt install wget -y

#mysql check
checkmysql=$(mysql --version 2>&1)
if [[ ( $checkmysql == *"not found"* ) || ( $checkmysql == *"No such file"* ) ]] 
    then
    clear
    echo "mysql not found"
    sleep 3s
    echo "Installing..."
    checklinux=$(lsb_release -a | grep 'Distributor ID:')
    if [[ $checklinux == *"Ubuntu"* ]]; then
        sudo apt update
        sudo apt install mysql-server -y
        sudo systemctl start mysql
        sudo systemctl enable mysql
        echo -n "Inserisci la password root per MySQL: "
        read answer < /dev/tty
        com="alter user 'root'@'localhost' identified with mysql_native_password by '$answer'"
        sudo mysql -uroot -p -e "$com"
    elif [[ $checklinux == *"Debian"* ]]; then
        sudo apt update
        wget http://repo.mysql.com/mysql-apt-config_0.8.13-1_all.deb
        sudo dpkg -i mysql-apt-config_0.8.13-1_all.deb
        sudo apt update
        sudo apt install mysql-server -y
        sudo systemctl start mysql
        sudo systemctl enable mysql
    else
        clear
        echo "mysql non disponibile per questa distro"
        sleep 5s
    fi
    
else
    clear
    echo "mysql found"
    sleep 3s
fi

#mariadb check (not supported from gHost)
comaria=$(dpkg -l | grep -e mariadb-server)
length=${#comaria}
if [[ $length > 0 ]]; then
    clear
    echo "la versione di MySQL presente sul tuo hosting ha delle dipendenze verso mariadb-server, gHost non supporta questa versione di MySQL"
    sleep 5s
fi

#mongodb check
checkmongo=$(mongo --version 2>&1)
if [[ ( $checkmongo == *"not found"* ) || ( $checkmongo == *"No such file"* ) ]] 
    then
    clear
    echo "mongo not found"
    sleep 3s
    key=$(wget -qO - https://www.mongodb.org/static/pgp/server-4.2.asc | sudo apt-key add -)
    if [[ $key == *"OK"* ]]; then
        echo "key imported successfully"
    else
        sudo apt-get install gnupg -y
        wget -qO - https://www.mongodb.org/static/pgp/server-4.2.asc | sudo apt-key add -
    fi
    checkdistro=$(lsb_release -a | grep 'Distributor ID:')
    if [[ $checkdistro == *"Ubuntu"* ]]; then
        echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu bionic/mongodb-org/4.2 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.2.list
        sudo apt update
        sudo apt-get install -y mongodb-org
        sudo systemctl start mongod
        sudo systemctl enable mongod
    elif [[ $checkdistro == *"Debian"* ]]; then
        checkdebian=$(lsb_release -a | grep 'Description')
        if [[ $checkdebian == *"stretch"* ]]; then
            echo "deb http://repo.mongodb.com/apt/debian stretch/mongodb-enterprise/4.2 main" | sudo tee /etc/apt/sources.list.d/mongodb-enterprise.list
            sudo apt-get update
            sudo apt-get install -y mongodb-enterprise
            sudo systemctl start mongod
            sudo systemctl enable mongod
        elif [[ $checkdebian == *"buster"* ]]; then
            echo "deb http://repo.mongodb.com/apt/debian buster/mongodb-enterprise/4.2 main" | sudo tee /etc/apt/sources.list.d/mongodb-enterprise.list
            sudo apt-get update
            sudo apt-get install -y mongodb-enterprise
            sudo systemctl start mongod
            sudo systemctl enable mongod
        else
            clear
            echo "mongoDB non disponibile per questa distro"
            sleep 3s
        fi
    else
        clear
        echo "mongoDB non disponibile per questa distro"
        sleep 3s
    fi
    
else
    clear
    echo "mongo found"
    sleep 3s
fi

clear
echo "install php driver for mongo"
sleep 3s
sudo apt install php-pear php-mongodb -y
sudo pecl install mongodb
vers=`php -i | grep /.+/php.ini -oE`
offvers="$vers"
sudo echo ";extension=mongodb.so" >> "$offvers"
if [ "$webserver" == "Nginx" ]; then
    sudo systemctl restart nginx
else
    sudo systemctl restart apache2
fi
sudo systemctl restart mongod


#ghost user creation
clear
echo "ghost user creation and configuration as root"
sleep 3s
sudo adduser ghost --gecos "First Last,RoomNumber,WorkPhone,HomePhone" --disabled-password
echo -n "Inserisci la password per ghost: "
read answerpass < /dev/tty
echo "ghost:$answerpass" | sudo chpasswd
echo "ghost root permission settings..."
sudo usermod -aG sudo,adm ghost
echo "ghost ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
echo "ghost is root"

#ghost ftp settings
echo "ghost ftp settings..."
sudo usermod -d /var/www ghost
echo "ghost properties on destination folder..."
sudo chown ghost:ghost /var/www/ghost
sudo chown ghost:ghost /var/www/ghost_file_manager
echo "ghost" | sudo tee -a /etc/vsftpd.userlist
clear
echo "ufw settings...."
sleep 3s
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 20/tcp
sudo ufw allow 21/tcp
sudo ufw allow 990/tcp
sudo ufw allow 40000:50000/tcp
sudo ufw allow in from 127.0.0.1 to any port 5555 proto tcp
echo "y" | sudo ufw enable

if [ "$webserver" == "Nginx" ]; then
    echo "Make adjustament for Nginx web server"
    word=`php -v | awk '/^PHP/{print $2}'`
    version=`printf '%-.3s' "$word"`
    versionphp="$version"
    ngingroup=$(grep "group = " -m1 /etc/php/$version/fpm/pool.d/www.conf)
    ngingroupuser=$(grep ".group = " /etc/php/$version/fpm/pool.d/www.conf)
    nginuser=`ps aux | egrep '([n|N]ginx|[h|H]ttpd)' | awk '{ print $1}' | uniq | tail -1`
    sed -i 's/user '"$nginuser"';/user ghost;/' /etc/nginx/nginx.conf
    sed -i 's/user = '"$nginuser"'/user = ghost/' /etc/php/$version/fpm/pool.d/www.conf
    sed -i 's/'"$ngingroup"'/group = ghost/' /etc/php/$version/fpm/pool.d/www.conf
    sed -i 's/listen.owner = '"$nginuser"'/listen.owner = ghost/' /etc/php/$version/fpm/pool.d/www.conf
    sed -i 's/'"$ngingroupuser"'/listen.group = ghost/' /etc/php/$version/fpm/pool.d/www.conf
    echo "file written."
    echo "Restarting services...."
    echo "Restarting Nginx...."
    sudo systemctl restart nginx
    echo "Restarting php...."
    sudo systemctl restart php"$versionphp"-fpm
    echo "Done."
    figlet gHost
    echo "Developed by Simone Ghisu and Marcello Pajntar"
elif [ "$webserver" == "Apache" ]; then
    sudo chown root:adm /var/log/apache2
    echo "Make adjustament for Apache web server"
    checkgroup=$(grep "export APACHE_RUN_GROUP=" /etc/apache2/envvars)
    checkuser=$(grep "export APACHE_RUN_USER=" /etc/apache2/envvars)
    sed -i 's/'"$checkuser"'/export APACHE_RUN_USER=ghost/' /etc/apache2/envvars
    sed -i 's/'"$checkgroup"'/export APACHE_RUN_GROUP=root/' /etc/apache2/envvars
    echo "Restarting Apache...."
    sudo systemctl restart apache2
    echo "Done."
    figlet gHost
    echo "Developed by Simone Ghisu and Marcello Pajntar"
fi
