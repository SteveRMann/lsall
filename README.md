# lsall
A loosely organized collection of various commands to obtain information about a Linux computer.

My hobby is to take discarded computers and install Ubuntu on them, then donate them to underprivileged kids.
I frequently use various lsxxx commands to discover what is in the computer.

This Bash shell script will do all of these information searches in a single script.

# Useage
There is no installation. Just put the script anywhere you wish, make sure it is executable (chmod +x)
Some of the lsxxx commands require that they be run by a sudo user.

sudo ./lsall.sh <options>

  Options include:
  -h, --help   How to use the script.
  -n, --net    Perform a local network scan. This is an option because the network scan takes several minutes.
               My preferred tool for a local network scan is the Advanced IP Scanner (www.advanced-ip-scanner.com)

The script has been tested on Ubuntu and Raspberry Pi computers.  If you use this script, please provide feedback 
with your experience and suggestions for improvement.

If you download the script first to a Windows PC, run dos2pc on it after moving it to the Linux computer.
