#!/bin/bash
whoami=$(whoami)
dir=$(pwd | rev | cut -d "/" -f1 | rev)
a=1
ip=$(ifconfig eth0 | grep 'inet addr' | cut -d":" -f2 | cut -d" " -f1 | awk '{ print $1 }')
if [ $1 && $1 == "-nonpi" ]; then
    arch=1
else
    arch=$(uname -m | grep arm | wc -c)
fi

if [ $whoami != "root" ]; then ## check runnning as root
        echo "Please run as root"
	exit 1
fi
if [ $dir != "scripts" ]; then ## confirm correct folder
    echo "Cannot find required files"
    echo "Are you in the 'scripts' folder?"
    exit 1
fi
if [ $arch != 0 ]; then
    echo "This device does not appear to be a Pi"
    echo "Only Raspberry Pis are currently supported"
    echo "If you wish to continue please run with '-nonpi'"
    exit 1
cd ..
where=$(pwd)

## Main function ##
if [ -e ./.progress ]; then
    cont=$(cat .progress)
    $cont
else
    setpassword
fi
##

funtion setpassword{ ## Get password for heating control user ##
    while [[ $a == "1" ]]; do
        echo -n "Please enter a password for the heating control user: "
        read -s firstpw
        echo
        echo -n "Re-enter the password: "
        read -s secondpw
        if [ $firstpw == $secondpw ]; then
            a=2
        fi
    done
    sed -i "s/PASSWORDGOESHERE/$firstpw/g" pp*.php
    copyingstuff
}

function copyingstuff {
    echo "Do you require hot water control?"
    echo "(If you are unsure select no)"
    echo -n "Yes/No (N)"
    read answer
    if [ $answer = "" || $answer =~ "n|N|No|no|NO" ]; then
        rm www/index1w.php
        mv www/index1h.php www/index1.php
    else
        rm www/index1h.php
        mv www/index1w.php www/index1.php
    fi
    echo -e "\nCopying files..."
    ( cp -r scripts/ /scripts/ && cp -r www/ /var/ && cp *.php /var/ ) || { echo "Copying failed" && echo $FUNCNAME > ./.progress && exit 1; }
    echo "done"
    addusertopi
}

function addusertopi {
    echo "Adding user 'heatingpi'..."
    useradd heatingpi -m -s /bin/bash || { echo "Failed to add user" && echo $FUNCNAME > ./.progress && exit 1; }
    setuserpw
}

function setuserpw {
    echo "heatingpi:$firstpw" > pass.txt
    chpasswd < pass.txt || { echo "Failed to set password" && echo $FUNCNAME > ./.progress && exit 1; }
    rm pass.txt
    echo "done"
    aptprep
}

function aptprep {
    echo "Preparing apt for package installs..."
    echo "## Webmin apt repo##" >> /etc/apt/sources.list
    wget -q http://www.webmin.com/jcameron-key.asc
    echo "deb http://download.webmin.com/download/repository sarge contrib" >> /etc/apt/sources.list
    apt-key add jcameron-key.asc
    apt-get -qqq update || { echo "Apt preparation failed" && echo $FUNCNAME > ./.progress && exit 1; }
    echo "done"
    installpacks
}

function installpacks {
    echo "Installing packages..."
    apt-get -qqq -y install $(< Package.list)  || { echo "Package install failed" && echo $FUNCNAME > ./.progress && exit 1; }
    echo "done"
    croninstall
}

function croninstall {
    echo "Installing crons..."
    crontab crons/root.cron || { echo "Root cron install failed" && echo $FUNCNAME > ./.progress && exit 1; }
    runuser -l heatingpi -c "crontab $where/crons/heatingpi.cron" || { echo "HeatingPi cron install failed" && echo $FUNCNAME > ./.progress && exit 1; }
    echo "done"
    ipset
}

function ipset {
    echo "Setting HeatingPi IP..."
    if [[ $ip =~ "0\." ]]; then
        cp ipzero.txt /etc/network/interfaces
        $ip = "192.168.0.100"
    elif [[ $ip =~ "1\." ]]; then
        cp ipone.txt /et/network/interfaces
        $ip = "192.168.1.100"
    else
        echo "Unable to detect IP address scheme"
        echo "Setting IP to DHCP"
    fi
}

echo "


