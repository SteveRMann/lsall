# About
A loosely organized collection of various commands to obtain information about a Linux computer.

My hobby is to take discarded computers and install Ubuntu on them, then donate them to underprivileged kids.
I frequently use various lsxxx commands to discover what is in the computer.

This Bash shell script will do all of these information searches in a single script.

Note- This script assumes that the computer is a member of a workgroup. Either through Samba or winbind.
This is a summary of the commands used in this script:

aplay  df  free  getent  ip

lpstat  lsb_release  lscpu  lspci

lsusb  mv  nmap  uname  wget




# Install
To download the script to your Ubuntu computer using the terminal, you can follow these steps:

1. Open the terminal on your Ubuntu computer.

2. Navigate to the directory where you want to download the script. For example, if you want to download the script to your home directory, you can use the following command:
```
cd ~
```
3. Clone the Github repository using the following command:
```
git clone https://github.com/SteveRMann/lsall.git
```
This command will create a new directory named `lsall` in your current directory and download the contents of the repository into it.

4. Navigate into the `lsall` directory using the following command:
```
cd lsall
```
5. You can now use the script.
sudo ./lsall.sh <options>
```
  Options include:
  -h, --help   How to use the script.
  -n, --net    Perform a local network scan. This is an option because the network scan takes several minutes.
               My preferred tool for a local network scan is the Advanced IP Scanner (www.advanced-ip-scanner.com)
```

Note: You will need to have Git installed on your Ubuntu computer to use the `git clone` command. If you do not have Git installed, you can install it using the following command:
```
sudo apt install git
```

# Useage
There is no installation. Just put the script anywhere you wish, make sure it is executable (chmod +x)
Some of the lsxxx commands require that they be run by a sudo user.

The script has been tested on Ubuntu and Raspberry Pi computers.  If you use this script, please provide feedback 
with your experience and suggestions for improvement.

If you download the script first to a Windows PC, run dos2pc on it after moving it to the Linux computer.
