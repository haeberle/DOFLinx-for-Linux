#!/bin/bash
#
# Changes applied for Batocera:
# - If Batocera is detected, PLUGIN_PATH is forced to:
#   /userdata/system/configs/mame/plugins
# - This avoids installing into the read-only overlay filesystem.
#

# Run this script with this command
# wget https://raw.githubusercontent.com/DOFLinx/DOFLinx-for-Linux/refs/heads/main/setup-doflinx.sh && chmod +x setup-doflinx.sh && ./setup-doflinx.sh  TODO delete these lines later
# wget https://raw.githubusercontent.com/alinke/DOFLinx-for-Linux/refs/heads/main/setup-doflinx.sh && chmod +x setup-doflinx.sh && ./setup-doflinx.sh
version=2
install_successful=true
batocera_40_plus_version=40
RETROPIE_AUTOSTART_FILE="/opt/retropie/configs/all/autostart.sh"
RETROPIE_LINE_TO_ADD="cd ~/doflinx && ./DOFLinx -PATH_INI=~/doflinx/config/DOFLinx.ini"

NEWLINE=$'\n'
cyan='\033[0;36m'
red='\033[0;31m'
yellow='\033[0;33m'
green='\033[0;32m'
nc='\033[0m'

function pause(){
 read -s -n 1 -p "Press any key to continue . . ."
 echo ""
}

echo -e ""
echo -e "       ${cyan}DOFLinx for Linux : Installer Version $version${nc}    "
echo -e ""
echo -e "This script will install the DOFLinx software in $HOME/doflinx"
echo -e "Plese ensure you have at least 1 GB of free disk space in $HOME"
echo -e ""
pause

# TODO
# set DOFLinx to run?

INSTALLPATH="${HOME}/"

commandLineArg=$1

# If this is an existing installation then DOFLinx could already be running
if test -f ${INSTALLPATH}doflinx/DOFLinx; then
   echo "[INFO] Existing DOFLinx installation found"
   if pgrep -x "DOFLinx" > /dev/null; then
     echo -e "${green}[INFO]${nc} Stopping DOFLinx"
     ${INSTALLPATH}doflinx/DOFLinxMsg QUIT
  fi
fi

if ! test -f ${INSTALLPATH}pixelcade/pixelweb; then
   echo -e "${green}[INFO]${nc} No Pixelcade installation can be seen at ${INSTALLPATH}pixelcade"
fi

# The possible platforms are:
# linux_arm64
# linux_386
# linux_amd64
# linux_arm_v6
# linux_arm_v7

if uname -m | grep -q 'armv6'; then
   echo -e "${yellow}arm_v6 Detected...${nc}"
   machine_arch=arm_v6
fi

if uname -m | grep -q 'armv7'; then
   echo -e "${yellow}arm_v7 Detected...${nc}"
   machine_arch=arm_v7
fi

if uname -m | grep -q 'aarch32'; then
   echo -e "${yellow}aarch32 Detected...${nc}"
   aarch32=arm_v7
fi

if uname -m | grep -q 'aarch64'; then
   echo -e "${green}[INFO]${nc} aarch64 Detected..."
   machine_arch=arm64
fi

if uname -m | grep -q 'x86'; then
   if uname -m | grep -q 'x86_64'; then
      echo -e "${green}[INFO]${nc}x86 64-bit Detected..."
      machine_arch=x64
   else
      echo -e "${red}[ERROR]${nc}x86 32-bit Detected...not supported"
      machine_arch=386
   fi
fi

if uname -m | grep -q 'amd64'; then
   echo -e "${green}[INFO]${nc}x86 64-bit Detected..."
   machine_arch=x64
fi

if test -f /proc/device-tree/model; then
   if cat /proc/device-tree/model | grep -q 'Raspberry Pi 3'; then
      echo -e "${yellow}Raspberry Pi 3 detected...${nc}"
      pi3=true
   fi
   if cat /proc/device-tree/model | grep -q 'Pi 4'; then
      echo -e "${yellow}Raspberry Pi 4 detected...${nc}"
      pi4=true
   fi
   if cat /proc/device-tree/model | grep -q 'Pi Zero W'; then
      echo -e "${yellow}Raspberry Pi Zero detected...${nc}"
      pizero=true
   fi
   if cat /proc/device-tree/model | grep -q 'ODROID-N2'; then
      echo -e "${yellow}ODroid N2 or N2+ detected...${nc}"
      odroidn2=true
   fi
fi

if [[ $machine_arch == "default" ]]; then
  echo -e "${red}[ERROR] Your device platform WAS NOT Detected"
  echo -e "${yellow}[WARNING] Guessing that you are on x64 but be aware DOFLinx may not work${nc}"
  machine_arch=x64
fi

if [[ ! -d "${INSTALLPATH}doflinx" ]]; then
   mkdir ${INSTALLPATH}doflinx
fi
if [[ ! -d "${INSTALLPATH}doflinx/temp" ]]; then
   mkdir ${INSTALLPATH}doflinx/temp
fi

echo -e "${cyan}[INFO]Installing DOFLinx Software...${nc}"

cd ${INSTALLPATH}doflinx/temp

doflinx_url=https://github.com/DOFLinx/DOFLinx-for-Linux/releases/download/doflinx/doflinx.zip
wget -O "${INSTALLPATH}doflinx/temp/doflinx.zip" "$doflinx_url"
if [ $? -ne 0 ]; then
   echo -e "${red}[ERROR]${nc} Failed to download DOFLinx"
   install_successful=false
else
   unzip -o doflinx.zip -d ${INSTALLPATH}doflinx
   if [ $? -ne 0 ]; then
      echo -e "${red}[ERROR]${nc} Failed to unzip DOFlinx"
      install_successful=false
   else
      cp -f ${INSTALLPATH}doflinx/${machine_arch}/* ${INSTALLPATH}doflinx/
      if [ $? -ne 0 ]; then
         echo -e "${red}[ERROR]${nc} Failed to copy DOFLinx files"
         install_successful=false
      fi

      PLUGIN_PATH=$(find / -name init.lua 2>/dev/null | grep hiscore| xargs dirname | xargs dirname | head -n 1)

      if batocera-info | grep -q 'System'; then
         PLUGIN_PATH="/userdata/system/configs/mame/plugins"
      fi

      cp -f -r "${INSTALLPATH}doflinx/DOFLinx Mame Integration/doflinx" ${PLUGIN_PATH}/
      if [ $? -ne 0 ]; then
         echo -e "${yellow}[WARNING]${nc} Failed to copy DOFLinx plugin, will attempt via sudo"
         sudo cp -f -r "${INSTALLPATH}doflinx/DOFLinx Mame Integration/doflinx" ${PLUGIN_PATH}/
         if [ $? -ne 0 ]; then
             echo -e "${red}[ERROR]${nc} Failed to copy DOFLinx plugin"
             install_successful=false
         fi
      fi
      cp -f ${INSTALLPATH}doflinx/DLSocket/${machine_arch}/DLSocket ${PLUGIN_PATH}/doflinx/
      if [ $? -ne 0 ]; then
          echo -e "${yellow}[WARNING]${nc} Failed to copy DLSocket to DOFLinx plugin directory, will attempt via sudo"
          sudo cp -f ${INSTALLPATH}doflinx/DLSocket/${machine_arch}/DLSocket ${PLUGIN_PATH}/doflinx/
          if [ $? -ne 0 ]; then
              echo -e "${red}[ERROR]${nc} Failed to copy DLSocket to DOFLinx plugin directory"
              install_successful=false
          fi
      fi
   fi
fi

chmod a+x ${INSTALLPATH}doflinx/DOFLinx
chmod a+x ${INSTALLPATH}doflinx/DOFLinxMsg

sed -i -e "s|/home/arcade/|${INSTALLPATH}|g" ${INSTALLPATH}/doflinx/config/DOFLinx.ini
if [ $? -ne 0 ]; then
   echo -e "${red}[ERROR] Failed to edit DOFLinx.ini"
   install_successful=false
fi

# Checking for Batocera installation
if batocera-info | grep -q 'System'; then
   echo -e "${green}[INFO]${nc}Batocera Detected"
   batocera_version="$(batocera-es-swissknife --version | cut -c1-2)" #get the version of Batocera as only Batocera V40 and above support services
   if [[ $batocera_version -ge $batocera_40_plus_version ]]; then
      if [[ ! -d ${INSTALLPATH}services ]]; then
         mkdir ${INSTALLPATH}services
      fi
      wget -O ${INSTALLPATH}services/doflinx https://raw.githubusercontent.com/DOFLinx/DOFLinx-for-Linux/main/batocera/doflinx
      chmod +x ${INSTALLPATH}services/doflinx
      sleep 1
      batocera-services enable doflinx 
      echo -e "${green}[INFO]${nc} DOFLinx added to Batocera services for Batocera V40 and up"
   fi
else
  echo -e "${yellow}[ERROR]${nc} Not on Batocera, skipping Batocera setup..."
fi

# Checking for Retropie installation
if [[ -f "$RETROPIE_AUTOSTART_FILE" ]]; then
  echo "${green}[INFO]${nc}RetroPie Detected..."
  if grep -q "DOFLinx" "$RETROPIE_AUTOSTART_FILE"; then
      echo-e  "${green}[INFO]${nc}DOFLinx entry already exists in $RETROPIE_AUTOSTART_FILE. Skipping."
  else
      echo -e "${green}[INFO]${nc}Adding DOFLinx to $RETROPIE_AUTOSTART_FILE"
      if grep -q "pixelweb" "$RETROPIE_AUTOSTART_FILE"; then
          sudo sed -i '/pixelweb/a '"$RETROPIE_LINE_TO_ADD" "$RETROPIE_AUTOSTART_FILE" 
      else
          echo "$RETROPIE_LINE_TO_ADD" | sudo tee -a "$RETROPIE_AUTOSTART_FILE" > /dev/null
      fi
      echo -e "${green}[INFO]${nc}DOFLinx added to RetroPie autostart"
  fi
  sudo chmod +x "$RETROPIE_AUTOSTART_FILE"
else
  echo -e "${green}[INFO]${nc}Not on RetroPie, skipping RetroPie setup..."
fi

echo -e "${green}[INFO]${nc} Cleaning up"
cd ${INSTALLPATH}
rm -r ${INSTALLPATH}doflinx/temp

if [[ $install_successful == "true" ]]; then
   echo -e "${green}[INFO]${nc} DOFLinx Installed"
   echo -e "${green}[INFO]${nc} The guide can be found at https://doflinx.github.io/docs/"
   echo -e "${green}[INFO]${nc} Support can be found at http://www.vpforums.org/index.php?showforum=104"
   echo -e "${green}[INFO]${nc} Now setup DOFLinx to start at boot running via sudo"
   echo -e "${green}[INFO]${nc} A default DOFLinx.ini has been installed in ./DOFLinx/config and updated as best possible"
   echo -e "${green}[INFO]${nc} You may need to customise parameters for your system in ./config/DOFLinx.ini for paths and button input codes"
else
  echo -e "${red}[ERROR]${nc} DOFLinx installation failed"
fi
echo ""
