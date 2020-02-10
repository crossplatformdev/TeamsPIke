# TeamsPIke
TeamSpeak on Raspberry Pi

The following tutorial is intended to serve as a guide to mount
a TeamSpeak server on a Raspberry Pi.

During this task, a Pi 4 model was used, but it would work on
Raspberry 2, 3 and 4 models (and any ARMv8 cpu running Ubuntu).

# First Step
Install the following dependencies:

```sudo apt install qemu-user-static binfmt```

# Second Step

```
sudo adduser teamspeak --disabled-login
sudo setcap cap_sys_chroot+ep /usr/sbin/chroot 
```
The second command is ONLY needed to run teamspeak as a server without root privileges.

# Adding multiarch support for ARMV8

Edit apt sources.

Add this repository to your sources.list:

```deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ focal main multiverse restricted universe```

<b>Note 'focal' should be replaced by 'eoan' if you're not on Ubuntu's testing branch</b>

Perform an APT update and then enable multiarch support for amd64:

```
sudo dpkg --add-architecture amd64
sudo apt update
```

# Creating VM image with qemu-debootstrap

Create the base filesystem inside the directory of your preference.

```qemu-debootstrap --arch amd64 xenial ts3vm```

This will perform all the neccesary steps as --first and --second-stage, and will
copy qemu-x86_64-static to the VM meanwhile the process is taking time (and it will be around 20 minutes).

It is neccesary to mount /dev/shm in the VM for this to work:

```mount --bind /dev/shm /[PATH_TO]/ts3vm/dev/shm```

Download it to your Raspberry, and copy it to the vm /root folder with: 

```
wget https://files.teamspeak-services.com/releases/server/3.11.0/teamspeak3-server_linux_amd64-3.11.0.tar.bz2
tar -xvjf teamspeak3-server_linux_amd64-3.11.0.tar.bz2
cp -r teamspeak3-server_linux_amd64 ts3vm/root/
chroot ts3vm
```

# Installing TeamSpeak Server on Raspberry Pi

Once you had chroot'ed into ts3vm , you should see something as the following on the terminal:

```
root@ubuntu:/home/teamspeak# chroot tsvm/
qemu-x86_64-static: warning: TCG doesn't support requested feature: CPUID.01H:ECX.vmx [bit 5]
bash: warning: setlocale: LC_ALL: cannot change locale (xx_XX.UTF-8)
qemu-x86_64-static: warning: TCG doesn't support requested feature: CPUID.01H:ECX.vmx [bit 5]
qemu-x86_64-static: warning: TCG doesn't support requested feature: CPUID.01H:ECX.vmx [bit 5]
qemu-x86_64-static: warning: TCG doesn't support requested feature: CPUID.01H:ECX.vmx [bit 5]
qemu-x86_64-static: warning: TCG doesn't support requested feature: CPUID.01H:ECX.vmx [bit 5]
qemu-x86_64-static: warning: TCG doesn't support requested feature: CPUID.01H:ECX.vmx [bit 5]
root@ubuntu:/#
```

Execute then the following commands_

```
adduser teamspeak --disabled-login
cd /root/teamspeak3-server_linux_amd64/
touch .ts3server_license_accepted
./ts3server_minimal_runscript.sh
```

Keep the track of the password and the token given in the output , you will need them later.
You have to make sure that user GUIDs of teamspeak user of both environments is the same to make it run 
as non-root user.

<b>Note that Teamspeak will fail to boot it you did not mounted /dev/shm</b>

Then connect with TeamSpeak Client to your Raspberry Pi IP.
You will be prompted to enter the token you noted down before.

You can control now the server with these commands:

```
chroot ts3vm /bin/bash -c "cd /home/teamspeak/ && ./teamspeak3-server_linux_amd64/ts3server_startscript.sh start"
```
```
chroot ts3vm /bin/bash -c "cd /home/teamspeak/ && ./teamspeak3-server_linux_amd64/ts3server_startscript.sh stop"
```

# Advanced: Running as a system service

Execute ```sudo nano /lib/systemd/system/teamspeak.service``` in the host machine and paste the following:

```
[Unit]
Description=TeamSpeak 3 Server in chroot environment
After=network.target

[Service]
WorkingDirectory=/home/teamspeak/
User=teamspeak
Group=teamspeak
Type=forking
ExecStart=chroot ts3vm /bin/bash -c "cd /home/teamspeak/ && ./teamspeak3-server_linux_amd64/ts3server_startscript.sh restart"
ExecStop=chroot ts3vm /bin/bash -c "cd /home/teamspeak/ && ./teamspeak3-server_linux_amd64/ts3server_startscript.sh stop"
PIDFile=/home/teamspeak/ts3vm/home/teamspeak/teamspeak3-server_linux_amd64/ts3server.pid
RestartSec=500
Restart=always

[Install]
WantedBy=multi-user.target
```

Then try the service with:

```
sudo systemctl daemon-reload
systemctl start teamspeak
```

If it works, congratulations!!! you made it!

You can add it now to boot up services with:

```
systemctl enable teamspeak
```

# One last thing...

In order to make it work on next reboot, /dev/shm must be mounted.

So, you can edit /etc/fstab and add the following:

```
/dev/shm        /home/teamspeak/ts3vm/dev/shm    none defaults,bind      0       0
```

Enjoy! ;)

