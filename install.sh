#!/bin/sh

# Check for required dependencies
if [ -f "/usr/bin/apt-get" ]; then
    install_type='2';
    install_command="apt-get"
elif [ -f "/usr/bin/yum" ]; then
    install_type='3';
    install_command="yum"
elif [ -f "/usr/sbin/pkg" ]; then
    install_type='4';
    install_command="pkg"
else
    install_type='0'
fi

packages='nslookup netstat ss ifconfig tcpkill timeout awk sed grep grepcidr'

if  [ "$install_type" = '4' ]; then
    packages="$packages ipfw"
else
    packages="$packages iptables"
fi

if [ $install_type -eq 3 ];then
    echo "installing epel-release..."
    yum install epel-release -y >/dev/null 2>&1
fi
for dependency in $packages; do
    which $dependency >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        if [ "$install_type" = '0' ]; then
            echo "can not find out package install tool, exiting..."
            exit 1
        fi
        echo "error: Required dependency '$dependency' is missing."
        eval "$install_command install -y $(grep $dependency config/dependencies.list | awk '{print $'$install_type'}')"
    fi
done

which grepcidr >/dev/null 2>&1
if [[ $? -ne 0 ]];then
    echo 'grepcidr is not installed correctly, installing from source...'
    yum install gcc -y >/dev/null 2>&1
    wget -q http://www.pc-tools.net/files/unix/grepcidr-2.0.tar.gz
    tar -xf grepcidr-2.0.tar.gz
    cd  grepcidr-2.0
    make && make PREFIX=/usr install
    cd - >/dev/null 2>&1
fi

# which apf >/dev/null 2>&1
# if [[ $? -ne 0 ]];then
    # echo 'apf is not installed correctly, installing from source...'
    # wget -q -O apf-current.tar.gz http://www.rfxnetworks.com/downloads/apf-current.tar.gz
    # tar xf apf-current.tar.gz
    # cd apf-*
    # bash install.sh >/dev/null 2>&1 || echo 'apf installation failed.'
    # cd - >/dev/null 2>&1
# fi

cd $(cd "$(dirname "$0")" && pwd)

if [ -d "$DESTDIR/usr/local/ddos" ]; then
    echo "Please un-install the previous version first"
    exit 0
else
    mkdir -p "$DESTDIR/usr/local/ddos"
fi

clear

if [ ! -d "$DESTDIR/etc/ddos" ]; then
    mkdir -p "$DESTDIR/etc/ddos"
fi

if [ ! -d "$DESTDIR/var/lib/ddos" ]; then
    mkdir -p "$DESTDIR/var/lib/ddos"
fi

echo; echo 'Installing DOS-Deflate 0.9'; echo

if [ ! -e "$DESTDIR/etc/ddos/ddos.conf" ]; then
    echo -n 'Adding: /etc/ddos/ddos.conf...'
    cp config/ddos.conf "$DESTDIR/etc/ddos/ddos.conf" > /dev/null 2>&1
    echo " (done)"
fi

if [ ! -e "$DESTDIR/etc/ddos/ignore.ip.list" ]; then
    echo -n 'Adding: /etc/ddos/ignore.ip.list...'
    cp config/ignore.ip.list "$DESTDIR/etc/ddos/ignore.ip.list" > /dev/null 2>&1
    netstat -tanpe | grep sshd: | awk '{print $5}' | awk -F: '{print $1}' | sort | uniq >> "$DESTDIR/etc/ddos/ignore.ip.list"
    echo " (done)"
fi

if [ ! -e "$DESTDIR/etc/ddos/ignore.host.list" ]; then
    echo -n 'Adding: /etc/ddos/ignore.host.list...'
    cp config/ignore.host.list "$DESTDIR/etc/ddos/ignore.host.list" > /dev/null 2>&1
    echo " (done)"
fi

echo -n 'Adding: /usr/local/ddos/LICENSE...'
cp LICENSE "$DESTDIR/usr/local/ddos/LICENSE" > /dev/null 2>&1
echo " (done)"

echo -n 'Adding: /usr/local/ddos/ddos.sh...'
cp src/ddos.sh "$DESTDIR/usr/local/ddos/ddos.sh" > /dev/null 2>&1
chmod 0755 /usr/local/ddos/ddos.sh > /dev/null 2>&1
echo " (done)"

echo -n 'Creating ddos script: /usr/local/sbin/ddos...'
mkdir -p "$DESTDIR/usr/local/sbin/"
echo "#!/bin/bash
/usr/local/ddos/ddos.sh \$@" > "$DESTDIR/usr/local/sbin/ddos"
chmod 0755 "$DESTDIR/usr/local/sbin/ddos"
echo " (done)"

echo -n 'Adding man page...'
mkdir -p "$DESTDIR/usr/share/man/man1/"
cp man/ddos.1 "$DESTDIR/usr/share/man/man1/ddos.1" > /dev/null 2>&1
chmod 0644 "$DESTDIR/usr/share/man/man1/ddos.1" > /dev/null 2>&1
echo " (done)"

if [ -d /etc/logrotate.d ]; then
    echo -n 'Adding logrotate configuration...'
    mkdir -p "$DESTDIR/etc/logrotate.d/"
    cp src/ddos.logrotate "$DESTDIR/etc/logrotate.d/ddos" > /dev/null 2>&1
    chmod 0644 "$DESTDIR/etc/logrotate.d/ddos"
    echo " (done)"
fi

echo;

if [ -d /etc/newsyslog.conf.d ]; then
    echo -n 'Adding newsyslog configuration...'
    mkdir -p "$DESTDIR/etc/newsyslog.conf.d"
    cp src/ddos.newsyslog "$DESTDIR/etc/newsyslog.conf.d/ddos" > /dev/null 2>&1
    chmod 0644 "$DESTDIR/etc/newsyslog.conf.d/ddos"
    echo " (done)"
fi

echo;

if [ -d /usr/lib/systemd/system ]; then
    echo -n 'Setting up systemd service...'
    mkdir -p "$DESTDIR/usr/lib/systemd/system/"
    cp src/ddos.service "$DESTDIR/usr/lib/systemd/system/" > /dev/null 2>&1
    chmod 0755 "$DESTDIR/usr/lib/systemd/system/ddos.service" > /dev/null 2>&1
    echo " (done)"

    # Check if systemctl is installed and activate service
    SYSTEMCTL_PATH=`whereis systemctl`
    if [ "$SYSTEMCTL_PATH" != "systemctl:" ] && [ "$DESTDIR" = "" ]; then
        echo -n "Activating ddos service..."
        systemctl enable ddos > /dev/null 2>&1
        systemctl start ddos > /dev/null 2>&1
        echo " (done)"
    else
        echo "ddos service needs to be manually started... (warning)"
    fi
elif [ -d /etc/init.d ]; then
    echo -n 'Setting up init script...'
    mkdir -p "$DESTDIR/etc/init.d/"
    cp src/ddos.initd "$DESTDIR/etc/init.d/ddos" > /dev/null 2>&1
    chmod 0755 "$DESTDIR/etc/init.d/ddos" > /dev/null 2>&1
    echo " (done)"

    # Check if update-rc is installed and activate service
    UPDATERC_PATH=`whereis update-rc.d`
    if [ "$UPDATERC_PATH" != "update-rc.d:" ] && [ "$DESTDIR" = "" ]; then
        echo -n "Activating ddos service..."
        update-rc.d ddos defaults > /dev/null 2>&1
        service ddos start > /dev/null 2>&1
        echo " (done)"
    else
        echo "ddos service needs to be manually started... (warning)"
    fi
elif [ -d /etc/rc.d ]; then
    echo -n 'Setting up rc script...'
    mkdir -p "$DESTDIR/etc/rc.d/"
    cp src/ddos.rcd "$DESTDIR/etc/rc.d/ddos" > /dev/null 2>&1
    chmod 0755 "$DESTDIR/etc/rc.d/ddos" > /dev/null 2>&1
    echo " (done)"

    # Activate the service
    echo -n "Activating ddos service..."
    echo 'ddos_enable="YES"' >> /etc/rc.conf
    service ddos start > /dev/null 2>&1
    echo " (done)"
elif [ -d /etc/cron.d ] || [ -f /etc/crontab ]; then
    echo -n 'Creating cron to run script every minute...'
    /usr/local/ddos/ddos.sh --cron > /dev/null 2>&1
    echo " (done)"
fi

echo; echo 'Installation has completed!'
echo 'Config files are located at /etc/ddos/'
echo
echo 'Please send in your comments and/or suggestions to:'
echo 'https://github.com/jgmdev/ddos-deflate/issues'
echo

exit 0
