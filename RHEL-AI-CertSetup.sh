#!/usr/bin/env bash


# CREATOR: Mike Lu (klu7@lenovo.com)
# CHANGE DATE: 3/24/2025
__version__="1.0"


# Red Hat Enterprise Linux AI Hardware Certification Test Environment Setup Script
# [Note] Must allocate more than 1.5TB space for /sysroot to download LLMs




# Fixed settings
red='\e[41m'
green='\e[32m'
yellow='\e[93m'
nc='\e[0m'
green_white='\e[42m\e[97m'


# Ensure the user is running the script as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${yellow}Please run as root to start the installation.${nc}"
    exit 1
fi

 
# Enable SSH
! systemctl status sshd | grep 'running' > /dev/null && systemctl enable sshd && systemctl start sshd


# Ensure Internet is connected
CheckInternet() {
    nslookup "google.com" > /dev/null
    if [ $? != 0 ]; then 
        echo -e "${red}No Internet connection! Please check your network${nc}" && sleep 3 && exit 1
    fi
}
CheckInternet


# Check the latest update of this script
UpdateScript() {
    release_url=https://api.github.com/repos/DreamCasterX/RHEL-AI-CertSetup/releases/latest
    new_version=$(curl -s "${release_url}" | grep '"tag_name":' | awk -F\" '{print $4}')
    release_note=$(curl -s "${release_url}" | grep '"body":' | awk -F\" '{print $4}')
    tarball_url="https://github.com/DreamCasterX/RHEL-AI-CertSetup/archive/refs/tags/${new_version}.tar.gz"
    if [[ $new_version != $__version__ ]]; then
        echo -e "⭐️ New version found!\n\nVersion: $new_version\nRelease note:\n$release_note"
        sleep 2
        echo -e "\nDownloading update..."
        pushd "$PWD" > /dev/null 2>&1
        curl --silent --insecure --fail --retry-connrefused --retry 3 --retry-delay 2 --location --output ".RHEL-AI-CertSetup.tar.gz" "${tarball_url}"
        if [[ -e ".RHEL-AI-CertSetup.tar.gz" ]]; then
            tar -xf .RHEL-AI-CertSetup.tar.gz -C "$PWD" --strip-components 1 > /dev/null 2>&1
            rm -f .RHEL-AI-CertSetup.tar.gz
            rm -f README.md
            popd > /dev/null 2>&1
            sleep 3
            sudo chmod 777 RHEL-AI-CertSetup.sh
            echo -e "Successfully updated! Please run RHEL-AI-CertSetup.sh again.\n\n" ; exit 1
        else
            echo -e "\n${red}Error occurred while downloading${nc}" ; exit 1
        fi 
    fi
}
# UpdateScript


echo "-------------------------------------------------------"
echo "    RHEL AI Certification Test Environment Setup       "
echo "-------------------------------------------------------"
echo
# Display system info
OS_VER=`cat /etc/os-release | grep ^VERSION_ID= | awk -F= '{print $2}' | cut -d '"' -f2`  # ex: 9.4
OS_build=`cat /etc/os-release | grep ^VERSION= | awk -F= '{print $2}' | cut -d '"' -f2`   # ex: 9.20250108.0.4 (Plow)
image_VER=`sudo bootc status --format json | jq .status.booted.image.image.image | awk -F ':' '{print $2}' | cut -d '"' -f1`
ilab_VER=`ilab --version | awk -F 'version ' '{print $2}'`  # ex: 
KERNEL=$(uname -r)
CPU_info=`grep "model name" /proc/cpuinfo | head -1 | cut -d ':' -f2`
MEM_info=`sudo dmidecode -t memory | grep -i size | grep -v "No Module Installed" | awk '{sum += $2} END {print sum " GB"}'`
storage_info=`sudo parted -l | grep "Disk /dev/" | grep -v "loop" | awk '{sum += $3} END {print sum " GB"}'`
product_name=`cat /sys/class/dmi/id/product_name`
echo -e "Product Name: ${yellow}"$product_name"${nc}"
echo -e "CPU:${yellow}"$CPU_info"${nc}"
echo -e "DIMM: ${yellow}"$MEM_info"${nc}"
echo -e "Storage: ${yellow}"$storage_info"${nc}"
echo -e "Kernel: ${yellow}"$KERNEL"${nc}"
echo -e "OS version: ${yellow}$OS_VER${nc}"   
echo -e "OS build: ${yellow}$OS_build${nc}"   
echo -e "Image version: ${yellow}$image_VER${nc}"     
[[ ! -z $ilab_VER ]] && echo -e "ilab version: ${yellow}$ilab_VER${nc}\n" || echo -e "ilab version: view after subscription\n"

echo "Select an option to configure"
read -p "(C)Config SUT  (R)Run rhcert  (U)Upgrade OS: " OPTION
while [[ "$OPTION" != [CcRrUu] ]]; do 
    read -p "(C)Config SUT  (R)Run rhcert  (U)Upgrade OS: " OPTION
done


if [[ "$OPTION" == [Cc] ]]; then

    # Check system registration status
    echo
    echo "----------------------"
    echo "REGISTERING  SYSTEM..."
    echo "----------------------"
    echo
    if rhc status | grep -w 'Not connected to Red Hat Subscription Management' > /dev/null; then
        # https://console.redhat.com/insights/connector/activation-keys
        read -p "Organization ID: " org_id  # 6937380 
        read -p "Activation key: " activation_key  # rhcert-ai
        ! rhc connect --organization $org_id --activation-key $activation_key && exit 1
        subscription-manager refresh
    fi
    echo -e "\n${green}Done!${nc}\n" 
    

    # Login to registey.redhat.io
    echo
    echo "--------------------"
    echo "LOGIN TO REGISTRY..."
    echo "--------------------"
    echo
    if rhc status | grep -w 'Not connected to Red Hat Insights' > /dev/null; then
        read -p "Username: " login_name
        read -p "Password: " login_PW
        skopeo login -u="$login_name" -p="$login_PW" registry.redhat.io
    fi
    [[ $? = 0 ]] && echo -e "\n${green}Done!${nc}\n" || { echo -e "${red}Failed to login to registey.redhat.io${nc}"; exit 1; }


    # Enable the Red Hat Enterprise Linux Repositories
    echo
    echo "-----------------"
    echo "ENABLING REPOS..."
    echo "-----------------"
    echo
    RELEASE=`echo $OS_VER | cut -d '.' -f1`  # 9
    cert="cert-1-for-rhel-$RELEASE-$(uname -m)-rpms"
    baseos="rhel-$RELEASE-for-$(uname -m)-baseos-rpms"
    baseos_eus="rhel-$RELEASE-for-$(uname -m)-baseos-eus-rpms"
    baseos_debug="rhel-$RELEASE-for-$(uname -m)-baseos-debug-rpms"
    appstream="rhel-$RELEASE-for-$(uname -m)-appstream-rpms"
    appstream_eus="rhel-$RELEASE-for-$(uname -m)-appstream-eus-rpms"
    appstream_debug="rhel-$RELEASE-for-$(uname -m)-appstream-debug-rpms"
    codeready="codeready-builder-for-rhel-$RELEASE-$(uname -m)-rpms"
    codeready_eus="codeready-builder-for-rhel-$RELEASE-$(uname -m)-eus-rpms"
    for repo in $cert $baseos $baseos_eus $baseos_debug $appstreamo $appstream_eus $appstream_debug $codeready $codeready_eus; do
        if ! dnf repolist | grep "$repo" > /dev/null; then
            subscription-manager repos --enable=$repo || { echo -e "${red}Enabling $repo failed${nc}"; exit 1; }
        fi
    done    
    echo -e "\n${green}Done!${nc}\n" 


    # Install the certification software
    echo
    echo "---------------------"
    echo "INSTALLING CERT SW..."
    echo "---------------------"
    echo
    if [[ ! -f /usr/bin/rhcert-cli ]]; then
        sudo rpm-ostree install redhat-certification-hardware-ai kernel-abi-stablelists || { echo -e "${red}Installing hardware test suite package failed!${nc}"; exit 1; }
    fi
    echo -e "\n${green}Done!${nc}\n" 


    echo
    echo "--------------------------------------"
    echo -e "${green_white}RHEL AI CERTIFICATION SETUP COMPLETED${nc}"
    echo "---------------------------------------"
    echo
    echo "System will automatically reboot after 5 seconds..."
    echo
    read -p "Is it okay to continue (y/n)? " ans 
    while [[ "$ans" != [YyNn] ]]; do 
        read -p "Is it okay to continue (y/n)? "ans
    done     
    [[ "$ans" == [Nn] ]] && exit 1
    for n in {5..1}s; do printf "\r$n"; sleep 1; done
    echo
    reboot now


elif [[ "$OPTION" == [Rr] ]]; then

    # Login to registey.redhat.io
    if rhc status | grep -w 'Not connected to Red Hat Insights' > /dev/null; then
        read -p "Username: " login_name
        read -p "Password: " login_PW
        skopeo login -u="$login_name" -p="$login_PW" registry.redhat.io
    fi
    [[ $? = 0 ]] && echo -e "\n${green}Done!${nc}\n" || { echo -e "${red}Failed to login to registey.redhat.io${nc}"; exit 1; }
    
    # For Sanity test only
    # sudo sed -i "s/rhelai training=\"full\"/rhelai training=\"short\"/" /etc/rhcert.xml
    echo
    rhcert-cli plan
    rhcert-cli run


elif [[ "$OPTION" == [Uu] ]]; then

    # Login to registey.redhat.io
    if rhc status | grep -w 'Not connected to Red Hat Insights' > /dev/null; then
        read -p "Username: " login_name
        read -p "Password: " login_PW
        skopeo login -u="$login_name" -p="$login_PW" registry.redhat.io
    fi
    
    # OS upgrade
    if [[ ! -f /run/containers/0/auth.json ]]; then
        echo -e "${yellow}Authentication file not found. Please login to registry.redhat.io and retry${nc}"
        exit 1
    fi
    sudo cp /run/containers/0/auth.json /etc/ostree
    sudo ls -l /etc/ostree/auth.json
    sudo bootc status
    read -p "Enter the OS version to upgrade (ex: 1.4.1): " UP_VER
    sudo bootc switch registry.redhat.io/rhelai1/bootc-nvidia-rhel9:$UP_VER
    [[ $? = 0 ]] && echo -e "\n${green}Done!${nc}\n" || { echo -e "${red}Failed to upgrade OS to "$UP_VER"${nc}"; exit 1; }
    sudo reboot -n

fi

exit