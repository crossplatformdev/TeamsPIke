# TeamsPIke
TeamSpeak Server on Raspberry Pi

This tutorial provides a step-by-step guide to install and run a TeamSpeak 3 server on a Raspberry Pi using QEMU emulation.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Quick Start (Automated Installation)](#quick-start-automated-installation)
- [Manual Installation](#manual-installation)
- [Running as a System Service](#running-as-a-system-service)
- [Making it Persistent on Reboot](#making-it-persistent-on-reboot)
- [Troubleshooting](#troubleshooting)

## Prerequisites

**Hardware Requirements:**
- Raspberry Pi 2, 3, or 4 (tested on Pi 4)
- Any ARMv8 CPU running Ubuntu
- Minimum 2GB RAM recommended
- At least 2GB free disk space

**Software Requirements:**
- Ubuntu (or Debian-based Linux distribution)
- Root or sudo access
- Internet connection for downloading packages and TeamSpeak server

**Knowledge Requirements:**
- Basic Linux command line skills
- Understanding of user permissions and systemd services

## Quick Start (Automated Installation)

For a fully automated installation, use the provided script:

```bash
sudo bash raspberry_pi_teamspeak.sh focal
```

**Note:** Replace `focal` with your Ubuntu codename:
- Ubuntu 20.04 LTS: `focal`
- Ubuntu 18.04 LTS: `bionic`
- Ubuntu 19.10: `eoan`
- Check your version with: `lsb_release -c`

The script will:
1. Install all dependencies
2. Set up the chroot environment
3. Download and configure TeamSpeak server
4. Create a systemd service
5. Display your admin token at the end

After the script completes, skip to the [Running as a System Service](#running-as-a-system-service) section.

---

## Manual Installation

Follow these steps if you prefer to understand and execute each step manually.

### Step 1: Install Dependencies

**Run on:** Host machine

```bash
sudo apt install qemu-user-static binfmt-support
```

**What this does:**
- `qemu-user-static`: Enables running x86_64 binaries on ARM through emulation
- `binfmt-support`: Allows the kernel to recognize and execute foreign binary formats

### Step 2: Create TeamSpeak User

**Run on:** Host machine

```bash
sudo adduser teamspeak --disabled-login --uid 1111
sudo setcap cap_sys_chroot+ep /usr/sbin/chroot
```

**What this does:**
- Creates a dedicated `teamspeak` user with UID 1111 (must match UID inside chroot)
- `setcap` grants the chroot command special capabilities to run without full root privileges
- This allows TeamSpeak to run more securely as a non-root user

### Step 3: Add Multiarch Support for AMD64

**Run on:** Host machine

TeamSpeak server is only available for x86_64/AMD64 architecture, so we need to enable multiarch support.

#### Edit APT Sources

Add the AMD64 repository to your sources:

```bash
echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ focal main multiverse restricted universe" | sudo tee /etc/apt/sources.list.d/ubuntu_amd64.list
```

**Important:** Replace `focal` with your Ubuntu version codename:
- Ubuntu 20.04 LTS → `focal`
- Ubuntu 18.04 LTS → `bionic`  
- Ubuntu 19.10 → `eoan`
- Check your version: `lsb_release -c`

#### Enable AMD64 Architecture

```bash
sudo dpkg --add-architecture amd64
sudo apt update
```

**Validation:** Run `dpkg --print-foreign-architectures` - you should see `amd64` listed.

### Step 4: Create QEMU Chroot Environment

**Run on:** Host machine

Create the base AMD64 filesystem using qemu-debootstrap:

```bash
sudo qemu-debootstrap --arch amd64 focal /home/teamspeak/ts3vm
```

**Note:** Replace `focal` with your Ubuntu codename (same as in Step 3).

**What this does:**
- Creates a minimal Ubuntu AMD64 filesystem at `/home/teamspeak/ts3vm`
- Automatically performs first and second-stage bootstrap
- Copies `qemu-x86_64-static` to enable x86_64 emulation
- **This will take approximately 20 minutes** - be patient!

**Validation:** After completion, check that `/home/teamspeak/ts3vm` contains directories like `bin`, `usr`, `etc`, etc.

### Step 5: Mount Shared Memory

**Run on:** Host machine

TeamSpeak requires access to `/dev/shm` (shared memory) to function properly.

```bash
sudo mount --bind /dev/shm /home/teamspeak/ts3vm/dev/shm
```

**⚠️ Critical:** TeamSpeak will fail to start without this mount!

**Validation:** Verify the mount with: `mount | grep ts3vm/dev/shm`

### Step 6: Download TeamSpeak Server

**Run on:** Host machine

Download the latest TeamSpeak server (adjust version as needed):

```bash
wget https://files.teamspeak-services.com/releases/server/3.11.0/teamspeak3-server_linux_amd64-3.11.0.tar.bz2
tar -xvjf teamspeak3-server_linux_amd64-3.11.0.tar.bz2
```

Copy it to the chroot environment:

```bash
sudo cp -r teamspeak3-server_linux_amd64 /home/teamspeak/ts3vm/root/
```

**Note:** Check [TeamSpeak downloads](https://www.teamspeak.com/en/downloads/#server) for the latest version.

### Step 7: Enter the Chroot Environment

**Run on:** Host machine

Enter the chroot environment to configure TeamSpeak:

```bash
sudo chroot /home/teamspeak/ts3vm
```

You will see output like this (warnings are normal):

```
qemu-x86_64-static: warning: TCG doesn't support requested feature: CPUID.01H:ECX.vmx [bit 5]
bash: warning: setlocale: LC_ALL: cannot change locale (xx_XX.UTF-8)
root@ubuntu:/#
```

**Note:** The QEMU warnings about VMX features are expected and can be safely ignored.

### Step 8: Configure TeamSpeak Inside Chroot

**Run on:** Inside chroot environment (after Step 7)

All commands in this step are executed **inside the chroot environment**.

#### Create TeamSpeak User

```bash
adduser teamspeak --disabled-login --uid 1111
```

**Important:** UID 1111 must match the host user for proper permissions.

#### Move and Configure TeamSpeak

```bash
mv /root/teamspeak3-server_linux_amd64 /home/teamspeak/
cd /home/teamspeak/teamspeak3-server_linux_amd64
touch .ts3server_license_accepted
```

#### Start TeamSpeak for Initial Setup

```bash
./ts3server_minimal_runscript.sh
```

**⚠️ Important:** The server will display critical information:
- **Server Admin password** - Save this!
- **Server Admin privilege key (token)** - Save this!

You can retrieve the token later with:

```bash
cat /home/teamspeak/teamspeak3-server_linux_amd64/logs/* | grep token
```

Or from the host:

```bash
cat /home/teamspeak/ts3vm/home/teamspeak/teamspeak3-server_linux_amd64/logs/* | grep token
```

#### Exit Chroot

Press `Ctrl+C` to stop the server, then type `exit` to leave the chroot environment.

**Validation:** You should be back at your host machine prompt.

### Step 9: Manual Server Control (Optional)

**Run on:** Host machine

You can manually control the TeamSpeak server with these commands:

**Start the server:**
```bash
sudo chroot /home/teamspeak/ts3vm /bin/bash -c "cd /home/teamspeak/teamspeak3-server_linux_amd64 && ./ts3server_startscript.sh start"
```

**Stop the server:**
```bash
sudo chroot /home/teamspeak/ts3vm /bin/bash -c "cd /home/teamspeak/teamspeak3-server_linux_amd64 && ./ts3server_startscript.sh stop"
```

**Check status:**
```bash
sudo chroot /home/teamspeak/ts3vm /bin/bash -c "cd /home/teamspeak/teamspeak3-server_linux_amd64 && ./ts3server_startscript.sh status"
```

For automatic management, proceed to the next section.

---

## Running as a System Service

**Run on:** Host machine

To run TeamSpeak automatically as a system service:

### Create the Systemd Service File

```bash
sudo nano /lib/systemd/system/teamspeak.service
```

Paste the following configuration:

```ini
[Unit]
Description=TeamSpeak 3 Server in chroot environment
After=network.target

[Service]
WorkingDirectory=/home/teamspeak/
User=teamspeak
Group=teamspeak
Type=forking
ExecStart=/usr/sbin/chroot /home/teamspeak/ts3vm /bin/bash -c "cd /home/teamspeak/teamspeak3-server_linux_amd64 && ./ts3server_startscript.sh start"
ExecStop=/usr/sbin/chroot /home/teamspeak/ts3vm /bin/bash -c "cd /home/teamspeak/teamspeak3-server_linux_amd64 && ./ts3server_startscript.sh stop"
PIDFile=/home/teamspeak/ts3vm/home/teamspeak/teamspeak3-server_linux_amd64/ts3server.pid
RestartSec=15
Restart=always

[Install]
WantedBy=multi-user.target
```

**What this does:**
- Runs TeamSpeak as the `teamspeak` user (not root)
- Automatically restarts if it crashes
- Starts after network is available

### Enable and Start the Service

```bash
sudo systemctl daemon-reload
sudo systemctl start teamspeak
```

**Check status:**
```bash
sudo systemctl status teamspeak
```

You should see "active (running)" in green.

### Enable Auto-Start on Boot

```bash
sudo systemctl enable teamspeak
```

### Connect to Your Server

1. Open TeamSpeak client on another computer
2. Connect to your Raspberry Pi's IP address (default port: 9987)
3. When prompted, enter the **Server Admin privilege key (token)** you saved earlier
4. You now have full admin access!

**Find your Pi's IP address:**
```bash
hostname -I
```

---

## Making it Persistent on Reboot

**Run on:** Host machine

The `/dev/shm` mount is temporary and will be lost on reboot. To make it permanent:

### Edit /etc/fstab

```bash
sudo nano /etc/fstab
```

Add this line at the end:

```
/dev/shm    /home/teamspeak/ts3vm/dev/shm    none    defaults,bind    0    0
```

Save and exit (Ctrl+X, Y, Enter in nano).

**Validation:** Test the fstab entry without rebooting:

```bash
sudo umount /home/teamspeak/ts3vm/dev/shm
sudo mount -a
mount | grep ts3vm/dev/shm
```

You should see the mount is active again.

**Congratulations! 🎉** Your TeamSpeak server is now fully configured and will survive reboots.

---

## Troubleshooting

### Server Won't Start

**Problem:** TeamSpeak fails to start with "Failed to open database" or similar errors.

**Solution:** Ensure `/dev/shm` is mounted:
```bash
mount | grep ts3vm/dev/shm
```

If not mounted:
```bash
sudo mount --bind /dev/shm /home/teamspeak/ts3vm/dev/shm
```

### Permission Errors

**Problem:** "Permission denied" errors when starting service.

**Solution:** Verify the teamspeak user owns the files:
```bash
sudo chown -R teamspeak:teamspeak /home/teamspeak/ts3vm/home/teamspeak
```

Also check that setcap was applied:
```bash
getcap /usr/sbin/chroot
```
Should show: `/usr/sbin/chroot = cap_sys_chroot+ep`

### Can't Connect from Client

**Problem:** Connection times out or refuses.

**Solutions:**
1. Check if server is running: `sudo systemctl status teamspeak`
2. Verify server is listening: `sudo chroot /home/teamspeak/ts3vm netstat -tuln | grep 9987`
3. Check firewall settings:
   ```bash
   sudo ufw allow 9987/udp
   sudo ufw allow 10011/tcp
   sudo ufw allow 30033/tcp
   ```
4. Verify your Pi's IP address: `hostname -I`

### QEMU Warnings

**Problem:** Seeing many QEMU warnings about VMX features.

**Solution:** These warnings are normal and can be safely ignored. They indicate CPU features that can't be emulated but aren't needed for TeamSpeak.

### Server Crashes Frequently

**Problem:** Service restarts repeatedly.

**Solutions:**
1. Check logs: `sudo journalctl -u teamspeak -n 50`
2. Check TeamSpeak logs: `sudo cat /home/teamspeak/ts3vm/home/teamspeak/teamspeak3-server_linux_amd64/logs/*`
3. Verify you have enough free memory: `free -h`
4. Ensure adequate disk space: `df -h /home/teamspeak`

### Forgot Admin Token

**Problem:** Lost or forgot the server admin token.

**Solution:** Retrieve it from logs:
```bash
sudo cat /home/teamspeak/ts3vm/home/teamspeak/teamspeak3-server_linux_amd64/logs/* | grep token
```

Look for the line with `token=` - the last one shown is your current admin token.

### Need to Update TeamSpeak Version

1. Download the new version to the host
2. Extract it
3. Stop the service: `sudo systemctl stop teamspeak`
4. Backup current installation:
   ```bash
   sudo cp -r /home/teamspeak/ts3vm/home/teamspeak/teamspeak3-server_linux_amd64 /home/teamspeak/ts3vm/home/teamspeak/teamspeak3-server_backup
   ```
5. Copy new files over the old ones (preserving database and config)
6. Start service: `sudo systemctl start teamspeak`

---

## Additional Resources

- [TeamSpeak Official Website](https://www.teamspeak.com/)
- [TeamSpeak Server Downloads](https://www.teamspeak.com/en/downloads/#server)
- [TeamSpeak Server Documentation](https://support.teamspeak.com/hc/en-us/categories/360001340557-Server)

---

**Enjoy your TeamSpeak server! 🎮🎙️**

