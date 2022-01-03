#!/bin/bash

# do we have usb audio plugged in?

USBA=$(aplay -l |  grep -q 'USB Audio' ; echo $?)
if [ $USBA -ne 0 ] ; then
  echo "no USB Audio device detected, bailing out..."
  exit 1
fi

# archlinux
# Increasing the highest requested RTC interrupt frequency (default is 64 Hz)
echo 2048 > /sys/class/rtc/rtc0/max_user_freq
echo 2048 > /proc/sys/dev/hpet/max-user-freq


# set cpu governor
for CPU in 0 1 2 3 ; do
  echo "performance" > /sys/devices/system/cpu/cpu${CPU}/cpufreq/scaling_governor
done

# stop all not needed
#systemctl stop exim4 netdata bluetooth cron openvpn-client@rpi4bkp1195 openvpn-client@rpi4bkp wpa_supplicant rsync "triggerhappy*" smartd hciuart systemd-timesyncd dbus.socket dbus rng-tools "systemd-journald*" systemd-journald systemd-journald.socket systemd-journald-audit.socket systemd-journald-dev-log.socket rsyslog syslog.socket systemd-tmpfiles-clean.timer systemd-tmpfiles-clean man-db.timer logrotate.timer apt-daily.timer apt-daily-upgrade.timer systemd-journald.socket systemd-journald alsa-state getty@tty1.service mpd
./stop_services.sh

swapoff -a

# let journald running
#systemctl stop exim4 netdata bluetooth cron openvpn-client@rpi4bkp1195 openvpn-client@rpi4bkp wpa_supplicant rsync "triggerhappy*" smartd hciuart systemd-timesyncd dbus.socket dbus rng-tools systemd-tmpfiles-clean.timer systemd-tmpfiles-clean man-db.timer logrotate.timer apt-daily.timer apt-daily-upgrade.timer systemd-journald.socket systemd-journald alsa-state getty@tty1.service

mkdir -p /dev/shm/RAATServer/Logs
mkdir -p /dev/shm/RoonBridge/Logs

mv /var/roon/RoonBridge/Logs /var/roon/RoonBridge/Logs.old
mv /var/roon/RAATServer/Logs /var/roon/RAATServer/Logs.old

ln -s /dev/shm/RAATServer/Logs /var/roon/RAATServer/Logs
ln -s /dev/shm/RoonBridge/Logs /var/roon/RoonBridge/Logs

patch_raatserver(){
  echo "Patching /opt/RoonBridge/Bridge/RAATServer"
  #pushd .
  #patch --dry-run /opt/RoonBridge/Bridge/RAATServer << EOF
  patch --dry-run --verbose /opt/RoonBridge/Bridge/RAATServer << EOF
--- RAATServer.orig	2021-12-02 17:50:11.058437357 +0100
+++ RAATServer	2021-12-02 17:51:17.651100558 +0100
@@ -46,7 +46,7 @@
 # fire up the app
 cd "$ROOTPATH/Bridge"
 if [ -x /bin/bash ]; then
-    exec /bin/bash -c "exec -a RAATServer \"$MONO_DIR/bin/mono-sgen\" --debug --gc=sgen --server RAATServer.exe $@"
+    exec /usr/bin/taskset -c 2 /bin/bash -c "exec -a RAATServer \"$MONO_DIR/bin/mono-sgen\" --debug --gc=sgen --server RAATServer.exe $@"
 else
     exec "$MONO_DIR/bin/mono-sgen" --debug --gc=sgen --server RAATServer.exe "$@"
 fi
EOF
  #popd
}

grep -q taskset /opt/RoonBridge/Bridge/RAATServer || patch_raatserver

##systemctl start upmpdcli networkaudiod roonbridge
#systemctl start networkaudiod roonbridge

iptables -P INPUT ACCEPT ; iptables -F INPUT

#sudo mount -o remount,size=32M /dev/shm
# skusime mpd z RAMky
sudo mount -o remount,size=64M /dev/shm
# toto je almost minimum pre beh z ramky
#sudo mount -o remount,size=42M /dev/shm
# skusime cachovat do ramdisku..
#sudo mount -o remount,size=512M /dev/shm

# give dhcpcd chance to setup eth0 during boot time
UPTIME=$(awk -F '.' '{print $1}' /proc/uptime)
if [ $UPTIME -lt 120 ] ; then
  #sleep 20	# ok for RPi4 at fullspeed
  sleep 10	# ok for RPI4 at 400MHz
fi

for X in {1..10} ; do
  NAS=$(ping -q -c 3 -W 10 192.168.0.42 >/dev/null 2>&1 ; echo $? | egrep -v '^$')
  if [ "$NAS" -eq 0 ] ; then
    mount /storage-nfs
    break
  fi
  echo "Try $X failed.."
done

/usr/sbin/ntpdate sk.pool.ntp.org &

# zkopiruj z nfs mpd db
if [[ -d "/storage-nfs/LIVE/mpd" ]] ; then
  rsync -av /storage-nfs/LIVE/mpd /dev/shm/
  chown -R mpd /dev/shm/mpd
  # 512MB of nfs read ahead
  ./nfs_read-ahead.sh set /storage-nfs 524288
fi


systemctl stop rpcbind.socket rpcbind system-getty.slice systemd-resolved user.slice
echo "nameserver 192.168.0.1" > /etc/resolv.conf


systemctl start mpd mpd.socket roonbridge
#systemctl start roonbridge
sleep 5

./tweaks.sh



#
# one-time setup stuff....
#
# borrowed from RuneOS
cat > /etc/sysctl.d/10-upboard.conf << EOF
vm.min_free_kbytes=32768
vm.vfs_cache_pressure = 300
net.core.rmem_max=12582912
net.core.wmem_max=12582912
net.ipv4.tcp_rmem= 10240 87380 12582912
net.ipv4.tcp_wmem= 10240 87380 12582912
net.ipv4.tcp_timestamps = 0
#net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_sack = 0
#net.ipv4.tcp_sack = 1
net.ipv4.tcp_no_metrics_save = 1
net.core.netdev_max_backlog = 5000
vm.overcommit_memory = 2
vm.overcommit_ratio = 100
fs.inotify.max_user_watches = 52428
EOF

#echo "kernel.printk = 3 3 3 3" > /etc/sysctl.d/20-quiet-printk.conf

