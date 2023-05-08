#!/bin/bash

ticker=0
function tick() {
  #printf "%s" "$ticker"
  printf "%s" "."
  ((ticker++))
}
# Define a function called dbg that takes an argument and prints it
function dbg() {
    echo "DEBUG: $1"
}

#Text colors
RED='\033[0;31m'
GREEN='\033[0;32m'
LtCYAN='\033[1;36m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

#Is the user root?
if [ "$(id -u)" != "0" ]; then
  printf "${RED}This script must run by a sudo user.${NC}\n"
  exit 1
fi


##### DEPENDENCIES #####
if which smartctl >/dev/null; then
  SMARTCTL_OK=true
else
  echo "smartctl is not installed. It can be installed using"
  printf "${LtCYAN}sudo apt install smartmontools${NC}\n\n"
  SMARTCTL_OK=false
fi

if which duf >/dev/null; then
  DUF_OK=true
else
  echo "Duf is not installed. It can be installed using"
  printf "${LtCYAN}sudo apt install duf${NC}\n\n"
  DUF_OK=false
fi

if which sed >/dev/null; then
  SED_OK=true
else
  SED_OK=false
fi

#Utilities to test?
if which gcc >/dev/null; then
  GCC_OK=true
else
  GCC_OK=false
fi


########## Command Line ##########
# Default values
SCAN_ENABLED=false

# Parse command-line options
# -n or --net mens to perform a network scan.
while [[ $# -gt 0 ]]; do
  case $1 in
    -n|--net)
      SCAN_ENABLED=true
      shift
      ;;

    -h|--help)
      echo "Help:"
	  echo
	  echo "----- OPTIONS -----"
	  echo "-n or --net"
	  echo "The -n option scans the private network IPv4 range from 192.168.1.1 to .254 using the nmap command."
	  echo "-Pn option in nmap instructs it to skip the host discovery stage and treat all specified hosts as alive."
	  echo "Because it treats all IP addresses as alive, -Pn can result in false positives or missed hosts."
	  echo "And, the network scan is painfully slow, so it is default off."
	  echo
	  echo "----- NOTES -----"
      echo "USERS section:"
      echo "The list of users who have login credentials uses the 'getent' command. This makes"
      echo "a list of all usernames that have a valid login shell and can log in to the system."
	  echo
	  echo "USB NOTES:"
      echo "You can find the product name associated with the idProduct value"
      echo "by looking it up in the USB ID Repository, which is a public repository"
      echo "that maintains a database of USB Vendor and Product ID assignments."
      echo "You can access the USB ID Repository website at"
      echo "http://www.linux-usb.org/usb-ids.html. The website provides a downloadable"
      echo "copy of the database in plain text format, which is updated daily,"
      echo "as well as a searchable online database."
      echo
      echo
	  shift
	  exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;	  
  esac
done

echo "Getting data."
tick

#IP range to scan
FIRSTIP=50
LASTIP=70

DATETIME=$(date +"%Y-%m-%d %H:%M:%S")
KERNEL_NAME=$(uname --kernel-name)
HOST_NAME=$(uname --nodename)
KERNEL_RELEASE=$(uname --kernel-release)
KERNEL_VERSION=$(uname --kernel-version)
MACHINE_NAME=$(uname --machine)
PROCESSOR_TYPE=$(uname --processor)
HARDWARE_PLATFORM=$(uname --hardware-platform)
OPERATING_SYSTEM=$(uname --operating-system)
WORKGROUP=$(grep 'workgroup\s*=' /etc/samba/smb.conf | sed 's/.*=\s*//; s/\r//')

CORE_UTILITIES_VERSION=$(mv --version | awk '/GNU coreutils/ {print $NF}')

lsb_release_output=$(lsb_release -a 2>/dev/null)
OS_DISTRIBUTOR_ID=$(echo "$lsb_release_output" | awk '/Distributor ID:/ {print $3}')

tick

if [ "$OS_DISTRIBUTOR_ID" = "Raspbian" ]; then
  PIFLAG="true"
  OS_VERSION=$(lsb_release -sr)
else
PIFLAG="false"
  OS_VERSION=$(echo "$lsb_release_output" | awk '/LSB Version:/ {print $3}')
fi

OS_DESCRIPTION=$(echo "$lsb_release_output" | awk '/Description:/ {print $2, $3, $4}')
OS_RELEASE=$(echo "$lsb_release_output" | awk '/Release:/ {print $2}')
OS_CODENAME=$(echo "$lsb_release_output" | awk '/Codename:/ {print $2}')

CPU_MODEL=$(lscpu | awk -F: '/Model name/ {sub(/^[ \t]+/, "", $2); print $2}')
CPU_CORES=$(lscpu | grep 'CPU(s):' | awk '{print $2}')

MEMORY_TOTAL=$(free -h --si | awk '/Mem:/ {print $2}')
MEMORY_USED=$(free -h --si | awk '/Mem:/ {print $3}')
MEMORY_FREE=$(free -h --si | awk '/Mem:/ {print $4}')
MEMORY_SHARED=$(free -h --si | awk '/Mem:/ {print $5}')
MEMORY_CACHE=$(free -h --si | awk '/Mem:/ {print $6}')
MEMORY_AVAILABLE=$(free -h --si | awk '/Mem:/ {print $7}')

DRIVE_SPACE=$(df -h)
MOUNTED=$(df | grep '^/dev')

tick

LOCAL_IP=$(sudo ip addr show | grep inet | grep -v inet6 | grep -v 127.0.0.1 | awk '{print $2}' | cut -d '/' -f 1)
# extract the first three octets of the IP address
NETWORK_PREFIX=$(echo "$LOCAL_IP" | cut -d '.' -f 1-3)


# Some system items removed because the output is duplicated somewhere else

#NUC only:
if [ "$PIFLAG" = "false" ]; then
  BIOSDATE=$(cat /sys/class/dmi/id/bios_date)
  BIOSRELEASE=$(sudo cat /sys/class/dmi/id/bios_release)
  BIOSVENDOR=$(sudo cat /sys/class/dmi/id/bios_vendor)
  BIOSVERSION=$(sudo cat /sys/class/dmi/id/bios_version)
  read -r -d '' BIOSNOTE << EOM
(Data from '/sys/class/dmi/id/')
EOM
  
  BOARDASSETTAG=$(sudo cat /sys/class/dmi/id/board_asset_tag)
  BOARDNAME=$(sudo cat /sys/class/dmi/id/board_name)
  BOARDSERIAL=$(sudo cat /sys/class/dmi/id/board_serial)
  BOARDVENDOR=$(sudo cat /sys/class/dmi/id/board_vendor)
  BOARDVERSION=$(sudo cat /sys/class/dmi/id/board_version)
  
  CHASSISASSETTAG=$(sudo cat /sys/class/dmi/id/chassis_asset_tag)
  CHASSISSERIAL=$(sudo cat /sys/class/dmi/id/chassis_serial)
  CHASSISTYPE=$(sudo cat /sys/class/dmi/id/chassis_type)
  
  CHASSISVENDOR=$(sudo cat /sys/class/dmi/id/chassis_vendor)
  CHASSISVERSION=$(sudo cat /sys/class/dmi/id/chassis_version)

  
  #MODALIAS=$(sudo cat /sys/class/dmi/id/modalias)
  PRODUCTFAMILY=$(sudo cat /sys/class/dmi/id/product_family)
  PRODUCTNAME=$(sudo cat /sys/class/dmi/id/product_name)
  COMPUTERSERIAL=$(sudo cat /sys/class/dmi/id/product_serial)
  PRODUCTSKU=$(sudo cat /sys/class/dmi/id/product_sku)
  PRODUCTUUID=$(sudo cat /sys/class/dmi/id/product_uuid)
  PRODUCTVERSION=$(sudo cat /sys/class/dmi/id/product_version)
  SYSVENDOR=$(sudo cat /sys/class/dmi/id/sys_vendor)
  #UEVENT=$(sudo cat /sys/class/dmi/id/uevent)
  
  POWERASYNC=$(sudo cat /sys/class/dmi/id/power/async)
  #POWERAUTOSUSPENDDELAYMS=$(sudo cat /sys/class/dmi/id/power/autosuspend_delay_ms)
  POWERCONTROL=$(sudo cat /sys/class/dmi/id/power/control)
  POWERRUNTIMEACTIVEKIDS=$(sudo cat /sys/class/dmi/id/power/runtime_active_kids)
  POWERRUNTIMEACTIVETIME=$(sudo cat /sys/class/dmi/id/power/runtime_active_time)
  POWERRUNTIMEENABLED=$(sudo cat /sys/class/dmi/id/power/runtime_enabled)
  POWERRUNTIMESTATUS=$(sudo cat /sys/class/dmi/id/power/runtime_status)
  POWERRUNTIMESUSPENDEDTIME=$(sudo cat /sys/class/dmi/id/power/runtime_suspended_time)
  POWERRUNTIMEUSAGE=$(sudo cat /sys/class/dmi/id/power/runtime_usage)
  
  DISPLAY=$(lspci | grep -i vga | cut -d ":" -f 3)
#End of NUC only.

else
  #Raspberry Pi only:
  BOARDVENDOR=$(cat /proc/device-tree/model | tr -d '\0' | cut -d ' ' -f 1)
  BOARDNAME=$(cat /proc/device-tree/model | tr -d '\0' | cut -d ' ' -f 2-)
  BOARDSERIAL=$(cat /proc/device-tree/serial-number | tr -d '\0')
  BOARDVERSION=$(grep "Revision" /proc/cpuinfo | uniq | awk -F ":" '{print $2}' | tr -d ' ')
  #Pick one...
  COMPUTERSERIAL=$(sudo cat /proc/cpuinfo | grep Serial | cut -d ' ' -f 2)
  #COMPUTERSERIAL=$(sudo cat /proc/cpuinfo | awk '/Serial/ {print $3}')
  
  output=$(vcgencmd version)
  BIOSDATE=$(echo "$output" | grep -oP '^\w+\s+\d+\s+\d{4}\s+\d{2}:\d{2}:\d{2}')
  BIOSVENDOR=$(echo "$output" | awk '/Copyright/ {print $4}')
  BIOSVERSION=$(echo "$output" | awk '/version/ {print $2, $3, $4}')
  read -r -d '' BIOSNOTE << EOM
The Raspberry Pi doesn't have a conventional BIOS. Instead, it uses a firmware 
called the Unified Extensible Firmware Interface (UEFI) firmware, which is stored
on a separate partition on the SD card.
The UEFI firmware on the Raspberry Pi doesn't expose information about the firmware
date, release, vendor or version in the same way that a traditional BIOS does. However,
this script does extract some information about the firmware using the vcgencmd command.
EOM

#/proc/cpuinfo has Hardware (BCM2835), Revision (a22082), Serial, Processor Model Name
#Split cat /proc/device-tree/model into Vendor and Boardname

fi


#End of Raspberry Pi only:

tick
USERS=$(getent passwd | grep "/bin/bash" | cut -d: -f1)
PRINTERS=$(lpstat -p | awk '{print $2}')
PUBLIC_IP=$(wget -qO- http://ipecho.net/plain)

# Get audio device information
readarray -t AUDIODEVICES < <(aplay -l | grep "^card")


# Get a list of network devices
NETDEVICES=$(ip link show | grep "^[0-9]" | awk '{print $2}' | cut -d ":" -f 1)
# Remove the first device (Loopback) from the list
NETDEVICES=$(echo "$NETDEVICES" | sed '1d')



tick
# Map the chassis type numeric value to a string
case $CHASSISTYPE in
    1) ENCLOSURESTRING="Other" ;;
    2) ENCLOSURESTRING="Unknown" ;;
    3) ENCLOSURESTRING="Desktop" ;;
    4) ENCLOSURESTRING="Low Profile Desktop" ;;
    5) ENCLOSURESTRING="Pizza Box" ;;
    6) ENCLOSURESTRING="Mini Tower" ;;
    7) ENCLOSURESTRING="Tower" ;;
    8) ENCLOSURESTRING="Portable" ;;
    9) ENCLOSURESTRING="Laptop" ;;
    10) ENCLOSURESTRING="Notebook" ;;
    11) ENCLOSURESTRING="Handheld" ;;
    12) ENCLOSURESTRING="Docking Station" ;;
    13) ENCLOSURESTRING="All-in-One" ;;
    14) ENCLOSURESTRING="Sub-Notebook" ;;
    15) ENCLOSURESTRING="Space-Saving" ;;
    16) ENCLOSURESTRING="Lunch Box" ;;
    17) ENCLOSURESTRING="Main Server Chassis" ;;
    18) ENCLOSURESTRING="Expansion Chassis" ;;
    19) ENCLOSURESTRING="Sub-Chassis" ;;
    20) ENCLOSURESTRING="Bus Expansion Chassis" ;;
    21) ENCLOSURESTRING="Peripheral Chassis" ;;
    22) ENCLOSURESTRING="RAID Chassis" ;;
    23) ENCLOSURESTRING="Rack Mount Chassis" ;;
    24) ENCLOSURESTRING="Sealed-case PC" ;;
    25) ENCLOSURESTRING="Multi-system chassis" ;;
	25) ENCLOSURESTRING="Multi-system chassis" ;;
    26) ENCLOSURESTRING="Compact PCI" ;;
    27) ENCLOSURESTRING="Advanced TCA" ;;
    28) ENCLOSURESTRING="Blade" ;;
    29) ENCLOSURESTRING="Blade Enclosure" ;;
    30) ENCLOSURESTRING="Tablet" ;;
    31) ENCLOSURESTRING="Convertible" ;;
    32) ENCLOSURESTRING="Detachable" ;;
    33) ENCLOSURESTRING="IoT Gateway" ;;
    34) ENCLOSURESTRING="Embedded PC" ;;
    35) ENCLOSURESTRING="Mini PC" ;;
    36) ENCLOSURESTRING="Stick PC" ;;
    37) ENCLOSURESTRING="1U Rack Mount" ;;
    38) ENCLOSURESTRING="2U Rack Mount" ;;
    39) ENCLOSURESTRING="3U Rack Mount" ;;
    40) ENCLOSURESTRING="4U Rack Mount" ;;
    41) ENCLOSURESTRING="5U Rack Mount" ;;
    42) ENCLOSURESTRING="Rack Mount Module" ;;
    43) ENCLOSURESTRING="Blade Server" ;;
    44) ENCLOSURESTRING="Conversion Box" ;;
    45) ENCLOSURESTRING="Smart Display" ;;
    46) ENCLOSURESTRING="IoT Device" ;;
    *) ENCLOSURESTRING="Unknown chassis type: $CHASSISTYPE" ;;
esac


#------------------- USB Devices -------------------
#dbg "USB Devices"
# Get the output of lsusb -v
output=$(lsusb -v 2>/dev/null)

# Count the number of lines in the output
num_lines=$(echo "$output" | wc -l)

#dbg "$num_lines lines in the output"
# Iterate through each line in the output
for (( i=1; i<=$num_lines; i++ )); do
    if (( i % 30 == 0 )); then
        tick
    fi
    line=$(echo "$output" | sed "${i}q;d")
	# Uncomment to show every line.
    #echo "Line $i: $line"
done
# Excellent. Every line from the lsusb -v command is on a separate line.

tick
#dbg "USB Devices- Initialize the arrays"
# Initialize the arrays
declare -a IDPRODUCT
declare -a IDVENDOR
declare -a IMANUFACTURER
declare -a IPRODUCT
declare -a ISERIAL
declare -a BDEVICECLASS
declare -a BDEVICESUBCLASS
declare -a BDEVICEPROTOCOL



#dbg "USB Devices- Iterate through each line"
# Iterate through each line in the output
for (( i=1; i<=$num_lines; i++ )); do
  if (( i % 30 == 0 )); then
    tick
  fi
  line=$(echo "$output" | sed "${i}q;d")
  if [[ $line == *"idProduct"* ]]; then
    IDPRODUCT+=("$line")
  fi
  if [[ $line == *"idVendor"* ]]; then
    IDVENDOR+=("$line")
  fi
    if [[ $line == *"iManufacturer"* ]]; then
    IMANUFACTURER+=("$line")
  fi
    if [[ $line == *"iProduct"* ]]; then
    IPRODUCT+=("$line")
  fi
    if [[ $line == *"iSerial"* ]]; then
    ISERIAL+=("$line")
  fi
    if [[ $line == *"bDeviceClass"* ]]; then
    BDEVICECLASS+=("$line")
  fi
    if [[ $line == *"bDeviceSubClass"* ]]; then
    BDEVICESUBCLASS+=("$line")
  fi
    if [[ $line == *"bDeviceProtocol"* ]]; then
    BDEVICEPROTOCOL+=("$line")
  fi

done


# Remove the unwanted prefixes from the array element
#dbg "USB Devices- Remove the unwanted prefixes"
num_items=${#IDPRODUCT[@]}

for (( i=0; i<$num_items; i++ )); do
    if (( i % 30 == 0 )); then
        tick
    fi
	IDPRODUCT[$i]=$(echo "${IDPRODUCT[$i]}" | sed -E 's/^.*idProduct\s+[x0-9a-f]+\s+(.*)$/\1/')
	IDVENDOR[$i]=$(echo "${IDVENDOR[$i]}" | sed -E 's/^.*idVendor\s+[x0-9a-f]+\s+(.*)$/\1/')
	IMANUFACTURER[$i]=$(echo "${IMANUFACTURER[$i]}" | sed -E 's/^.*iManufacturer\s+[x0-9a-f]+\s+(.*)$/\1/')
	IPRODUCT[$i]=$(echo "${IPRODUCT[$i]}" | sed -E 's/^.*iProduct\s+[x0-9a-f]+\s+(.*)$/\1/')
	ISERIAL[$i]=$(echo "${ISERIAL[$i]}" | sed -E 's/^.*iSerial\s+[x0-9a-f]+\s+(.*)$/\1/')
	BDEVICECLASS[$i]=$(echo "${BDEVICECLASS[$i]}" | sed -E 's/^.*bDeviceClass\s+[x0-9a-f]+\s+(.*)$/\1/')
	BDEVICESUBCLASS[$i]=$(echo "${BDEVICESUBCLASS[$i]}" | sed -E 's/^.*bDeviceSubClass\s+[x0-9a-f]+\s+(.*)$/\1/')
	BDEVICEPROTOCOL[$i]=$(echo "${BDEVICEPROTOCOL[$i]}" | sed -E 's/^.*bDeviceProtocol\s+[x0-9a-f]+\s+(.*)$/\1/')

done

# Print the final array
#echo "There are $num_items items in the array"
#for ((i=0; i<$num_items; i++)); do
#    echo "IDPRODUCT[$((i+1))]: ${IDPRODUCT[i]#*: }"
#    echo "IDVENDOR[$((i+1))]: ${IDVENDOR[i]}"
#    echo "IMANUFACTURER[$((i+1))]: ${IMANUFACTURER[i]}"
#    echo "IPRODUCT[$((i+1))]: ${IPRODUCT[i]}"
#    echo "ISERIAL[$((i+1))]: ${ISERIAL[i]}"
#    echo "BDEVICECLASS[$((i+1))]: ${BDEVICECLASS[i]}"
#    echo "BDEVICESUBCLASS[$((i+1))]: ${BDEVICESUBCLASS[i]}"
#    echo "BDEVICEPROTOCOL[$((i+1))]: ${BDEVICEPROTOCOL[i]}"
#	echo
#done
#------------------- END of USB Devices -------------------


#----------- Output the results -----------
echo
printf "${CYAN}====================================${NC}\n"
echo "             advisor.sh"
echo "       Computer Profile Summary"
echo "       ------------------------"
echo "Profile Date:           $DATETIME"
echo "Computer Name:          $HOSTNAME"
echo "Login name:             $USER"
printf "${CYAN}====================================${NC}\n"
echo
printf "${CYAN}------------- COMPUTER --------------${NC}\n"
echo "(Data from 'uname')"
echo "Machine name:           $MACHINE_NAME"
echo "Host name:              $HOST_NAME"
echo "Product Family:         $PRODUCTFAMILY"
echo "Product Name:           $PRODUCTNAME"
echo "Serial Number:          $COMPUTERSERIAL"
echo "System Vendor:          $SYSVENDOR"
echo "UUID: $PRODUCTUUID"
echo
printf "${CYAN}--------------- CPU -----------------${NC}\n"
echo "(Data from 'lscpu')"
echo "CPU Model:              $CPU_MODEL"
echo "CPU Cores:              $CPU_CORES"
echo "Processor Type:         $PROCESSOR_TYPE"
echo "Hardware platform:      $HARDWARE_PLATFORM"
echo
printf "${CYAN}--------------- BIOS ----------------${NC}\n"
echo "$BIOSNOTE"
echo "Date:                   $BIOSDATE"
echo "Release:                $BIOSRELEASE"
echo "Vendor:                 $BIOSVENDOR"
echo "Version:                $BIOSVERSION"
echo
printf "${CYAN}--------------- BOARD ---------------${NC}\n"
echo "(Data from '/sys/class/dmi/id/')"
echo "Name:                   $BOARDNAME"
echo "Serial Number:          $BOARDSERIAL"
echo "Vendor:                 $BOARDVENDOR"
echo "Version:                $BOARDVERSION"
echo "Enclosure:              $ENCLOSURESTRING"
echo
printf "${CYAN}---------------- OS -----------------${NC}\n"
echo "(Data from 'lsb_release_output')"
echo "Operating System:       $OPERATING_SYSTEM"
echo "Core Utilities Version: $CORE_UTILITIES_VERSION"
echo "OS Version:             $OS_VERSION"
echo "OS Release:             $OS_RELEASE"
echo "OS Codename:            $OS_CODENAME"
echo "OS Distributor ID:      $OS_DISTRIBUTOR_ID"
echo "OS Description:         $OS_DESCRIPTION"
echo 
printf "${CYAN}-------------- USERS ---------------${NC}\n"
echo "(Data from 'getent passwd')"
echo "$USERS"
echo
printf "${CYAN}-------------- KERNEL ---------------${NC}\n"
echo "(Data from 'uname')"
echo "Kernel name:            $KERNEL_NAME"
echo "Kernel release:         $KERNEL_RELEASE"
echo "Kernel version:         $KERNEL_VERSION"
echo
printf "${CYAN}--------------- MEMORY --------------${NC}\n"
echo "(Data from 'free -h --si')"
echo "Total Memory:           $MEMORY_TOTAL"
echo "Used Memory:            $MEMORY_USED"
echo "Free Memory:            $MEMORY_FREE"
echo "Shared Memory:          $MEMORY_SHARED"
echo "Cache Memory:           $MEMORY_CACHE"
echo "Available Memory:       $MEMORY_AVAILABLE"
echo "More information may be obtained from the command 'free -h --si', or 'meminfo'"
echo
printf "${CYAN}--------------- DISKS ---------------${NC}\n"
echo "(Data from 'df -h')"
echo -n "Drive space:\n"
echo "$DRIVE_SPACE"
echo -n "Mounted file systems::\n"
echo "$MOUNTED"
echo
if [ "$DUF_OK" = true ]; then
  printf "${CYAN}---------------- DUF ----------------${NC}\n"
  echo "(Output of the 'duf' program)"
  duf -width 132
  echo
fi
printf "${CYAN}-------------- PRINTERS ---------------${NC}\n"
echo "(Data from 'lpstat -p')"
echo $PRINTERS
echo
printf "${CYAN}-------- PCI DISPLAY ADAPTERS ---------${NC}\n"
echo "(Data from 'lspci')"
echo $DISPLAY
echo
printf "${CYAN}------------ AUDIO DEVICES ------------${NC}\n"
echo "(Data from 'aplay -l')"
# Iterate through each line in the output
num_items=${#AUDIODEVICES[@]}
for (( i=1; i<=$num_items; i++ )); do
    echo "${AUDIODEVICES[$((i-1))]}"
done
echo
printf "${CYAN}-------------- UTILITIES --------------${NC}\n"
if [ "$GCC_OK" = true ]; then
  GCC_COMPILER_VERSION=$(gcc --version | awk '/gcc/ {print $4}')
  echo "GCC Compiler version: $GCC_COMPILER_VERSION"
fi
if [ "$SED_OK" = true ]; then
  SED_VERSION=$(sed --version | awk '/GNU sed/ && !done {print $NF; done=1}')
  echo "Sed Version:          $SED_VERSION"
fi
echo
printf "${CYAN}------------- USB DEVICES -------------${NC}\n"
echo "(Data from 'lsusb')"
num_items=${#IDPRODUCT[@]}
for ((i=0; i<$num_items; i++)); do
  echo "Product:              ${IPRODUCT[i]}"
  echo "Vendor:               ${IDVENDOR[i]}"
  echo "Manufacturer:         ${IMANUFACTURER[i]}"
  echo
done
echo
printf "${CYAN}--------------- NETWORK ---------------${NC}\n"
echo "(Data from 'ip link show')"
echo -e "Available network devices:\n$NETDEVICES"
echo
echo "(Data from 'sudo ip addr show')"
echo "Local IP address:     $LOCAL_IP"
echo "Public IP address:    $PUBLIC_IP"
echo
echo "Workgroup name:       $WORKGROUP"
echo
echo "For a complete network scan, use the -n (or --net) option."
echo "Warning, using the -n option will take several minutes to complete."
echo

########## Local Network Scan ##########
if [ "$SCAN_ENABLED" = true ]; then
  declare -a MAC
  declare -a MANUFACTURER
  declare -a HOST

  printf "${CYAN}---------- Local NEtwork scan ----------${NC}\n"
  echo "Scanning $NETWORK_PREFIX.$FIRSTIP to $LASTIP"
  printf "%-15s %-30s %-18s %s\n" "IP" "HOST" "MAC" "Manufacturer"
  for ((i=$FIRSTIP; i<=$LASTIP; i++))
  do
    #echo -n "."
    output=$(sudo nmap -Pn $NETWORK_PREFIX.$i)
    MAC[$i]=$(echo "$output" | awk '/MAC Address/ {print $3}')
    MANUFACTURER[$i]=$(echo "$output" | awk -F'[()]' '/MAC Address/ {print $2}')
    HOST[$i]=$(echo "$output" | awk '/Nmap scan report for/{print $5}')
    if [ -n "${MAC[$i]}" ]; then
      printf "%-15s %-30s %-18s %s\n" "192.168.1.$i" "${HOST[$i]}" "${MAC[$i]}" "${MANUFACTURER[$i]}"
    fi
  done
fi

# The -a option is used to declare an array, and MAC is the name of the array.
# In the loop, we are using ${MAC[$i]} to access the i-th element of the MAC array.
#
# The -Pn option skips the host discovery stage to speed up the scanning process.
# However, using -Pn can result in false positives or missed hosts, so it should
# be used with caution.
#
# In this example, the printf command is used to format the output with four columns.
# The %15s, %25s, %18s, and %s are format specifiers for the columns, and the - flag
# is used to left-align the text. The values "IP", "HOST", "MAC", and "Manufacturer"
# are passed as arguments to printf to specify the column headers.
#
#In this example, the if statement checks if the ${MAC[$i]} variable is non-empty using
#the -n flag with the [ command. If the variable is non-empty, the echo statement is executed,
#printing the MAC address for the corresponding IP address.
#############################
