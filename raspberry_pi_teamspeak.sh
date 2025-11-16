#!/bin/bash
echo "                                                                      ./::::/:  "
echo "                                                                     ./      ./ "
echo "                                                                    .o .      :+"
echo "                                                                 \`  ./\`ss:\`:+:-/"
echo " \`.                                                             \`.      \`\` \`\`./ "
echo "\`\`.\`\`  \`\`\`\`\`   \`\`\`\`\`  \`\`\`\`\`\`\`\`\`\`  \`\`\`\`\`  \`\`\`\`\`   \`\`\`\`\`    \`\`\`\`  \`.  \`\`   \`.-::\` "
echo " \`.\`  \`.\` \`.\` \`\`\` ..  ..  ..\` .. \`.\` \`\`  .\`  ..  .\` \`.\`  \`\` \`.\` \`. \`.           "
echo " \`.   \`.\`\`..\`   \`\`..  .\`  ..  \`.  \`.\`\`   .\`  \`. \`..\`\`.\`   \`\`\`.\` \`...\`           "
echo " \`.   \`.   \`  \`.\` \`.  .\`  ..  \`.    \`\`.\` .\`  \`. \`.\`  \`\` \`.\` \`.\` \`.\`\`.\`          "
echo " \`.\`\` \`.\`\`\`.  \`.\`\`..  .\`  ..  \`.  .\`\`\`.\` ..\`\`.\`  .\`\`\`.\` \`.\`\`\`.\` \`.  \`.          "
echo "   \`\`   \`\`\`    \`\`                  \`\`\`   .\` \`\`    \`\`\`     \`                     "
echo "                                         .\`                                     "

echo "--+ Installing depencencies..."
sudo apt install qemu-user-static binfmt-support -y
sudo useradd teamspeak --uid 1111
sudo setcap cap_sys_chroot+ep /usr/sbin/chroot 

# Add required repo for multiarch
echo "--+ Adding multiarch support"
sudo echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ focal main multiverse restricted universe" > /etc/apt/sources.list.d/ubuntu_amd64.list
sudo dpkg --add-architecture amd64
sudo apt update &>/dev/null

echo "--+ Creating base filesistem . It may take a while, please be patient. Output is enabled."
qemu-debootstrap --arch amd64 xenial /home/teamspeak/ts3vm

echo "--+ Mounting /dev/shm into chroot environment... (remember to edit fstab)"
umount /home/teamspeak/ts3vm/dev/shm &>/dev/null
mount --bind /dev/shm /home/teamspeak/ts3vm/dev/shm

echo "--+ Downloading Teamspeak Server 3.11.0 AMD64"
wget https://files.teamspeak-services.com/releases/server/3.11.0/teamspeak3-server_linux_amd64-3.11.0.tar.bz2 &>/dev/null

echo "--+ Uncompressing file..."
tar -xvjf teamspeak3-server_linux_amd64-3.11.0.tar.bz2 &>/dev/null

echo "--+ Preparing chroot environment..."
sudo setcap cap_sys_chroot+ep /usr/sbin/chroot 
chroot /home/teamspeak/ts3vm /bin/bash -c "apt install ca-certificates -y" &>/dev/null
chroot /home/teamspeak/ts3vm /bin/bash -c "useradd teamspeak --uid 1111" &>/dev/null
mkdir /home/teamspeak/ts3vm/home/teamspeak/teamspeak3-server_linux_amd64/ -p
mv teamspeak3-server_linux_amd64/** /home/teamspeak/ts3vm/home/teamspeak/teamspeak3-server_linux_amd64/
chroot /home/teamspeak/ts3vm /bin/bash -c "touch /home/teamspeak/teamspeak3-server_linux_amd64/.ts3server_license_accepted" &>/dev/null
chown teamspeak:teamspeak /home/teamspeak/ts3vm/home/teamspeak -R

echo "--+ Writing systemctl service file..."
rm /lib/systemd/system/teamspeak.service &>/dev/null
export TEMP_FILE=$(cat <<EOF

[Unit]
Description=TeamSpeak 3 Server in chroot environment
After=network.target

[Service]
WorkingDirectory=/home/teamspeak/
User=teamspeak
Group=teamspeak
Type=forking
ExecStart=chroot ts3vm /bin/bash -c "cd /home/teamspeak/teamspeak3-server_linux_amd64/ && ./ts3server_startscript.sh start"
ExecStop=chroot ts3vm /bin/bash -c "cd /home/teamspeak/teamspeak3-server_linux_amd64/ && ./ts3server_startscript.sh stop"
PIDFile=/home/teamspeak/ts3vm/home/teamspeak/teamspeak3-server_linux_amd64/ts3server.pid
Restart=always

[Install]
WantedBy=multi-user.target

EOF
)

sudo echo "$TEMP_FILE" >> /lib/systemd/system/teamspeak.service
sudo systemctl daemon-reload

echo "--+ Starting server for the first time will take 10 minutes. Please be patient."
kill -9 `pidof "/usr/bin/qemu-x86_64-static ./ts3server"`
chroot /home/teamspeak/ts3vm /bin/bash -c "./home/teamspeak/teamspeak3-server_linux_amd64/ts3server_minimal_runscript.sh" 2>/dev/null &
sleep 600
kill -9 `pidof "/usr/bin/qemu-x86_64-static ./ts3server"`
rm /home/teamspeak/ts3vm/home/teamspeak/teamspeak3-server_linux_amd64/ts3server.pid
echo "##############################################################################################"
echo "##############################################################################################"
echo "##############################################################################################"
echo "--+ YOUR TOKEN IS (always last one): "
cat /home/teamspeak/ts3vm/home/teamspeak/teamspeak3-server_linux_amd64/logs/** | grep token
echo "##############################################################################################"
echo "--+ Next steps: "
echo "- systemctl start teamspeak"
echo "- Connect to server and introduce token"
echo "- systemctl enable teamspeak to enable at boot up"
echo "- edit /etc/fstab, add '/dev/shm /home/teamspeak/ts3vm/dev/shm none defaults,bind 0 0"
echo
echo "--+ ENJOY!"
echo "##############################################################################################"
echo "##############################################################################################"
echo "##############################################################################################"

exit 0;

