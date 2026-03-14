#!/bin/bash
# Run this script with:
# wget https://raw.githubusercontent.com/alinke/DOFLinx-for-Linux/refs/heads/main/setup-doflinx.sh && chmod +x setup-doflinx.sh && ./setup-doflinx.sh
# /usr/bin/emulatorlauncher -system mame -rom /userdata/roms/mame/1942.zip   # Test in Batocera

version=9
install_successful=true

batocera=false
batocera_version=""
batocera_40_plus_version=40

RETROPIE_AUTOSTART_FILE="/opt/retropie/configs/all/autostart.sh"
BATOCERA_MAME_GENERATOR_V41="/usr/lib/python3.11/site-packages/configgen/generators/mame/mameGenerator.py"
BATOCERA_MAME_GENERATOR_V42="/usr/lib/python3.12/site-packages/configgen/generators/mame/mameGenerator.py"
BATOCERA_CONFIG_FILE="/userdata/system/batocera.conf"
BATOCERA_CONFIG_LINE1="mame.core=mame"
BATOCERA_CONFIG_LINE2="mame.emulator=mame"
BATOCERA_PLUGIN_PATH="/userdata/saves/mame/plugins"
DOFLINX_INI_FILE="${HOME}/doflinx/config/DOFLinx.ini"
RETROPIE_LINE_TO_ADD="cd ~/doflinx && ./DOFLinx -PATH_INI=~/doflinx/config/DOFLinx.ini"

NEWLINE=$'\n'

# Color definitions
cyan='\033[0;36m'
red='\033[0;31m'
yellow='\033[0;33m'
green='\033[0;32m'
magenta='\033[0;35m'
orange='\033[0;33m'

blue='\033[0;34m'
purple='\033[0;35m'
white='\033[1;37m'
black='\033[0;30m'
gray='\033[1;30m'
light_blue='\033[1;34m'
light_green='\033[1;32m'
light_cyan='\033[1;36m'

bold='\033[1m'
bold_red='\033[1;31m'
bold_green='\033[1;32m'
bold_yellow='\033[1;33m'

bg_black='\033[40m'
bg_red='\033[41m'
bg_green='\033[42m'
bg_yellow='\033[43m'
bg_blue='\033[44m'
bg_magenta='\033[45m'
bg_cyan='\033[46m'
bg_white='\033[47m'

nc='\033[0m'

BACKUP_DIR="${HOME}/doflinx/backup"

if command -v batocera-info >/dev/null 2>&1 && batocera-info | grep -q 'System'; then
   batocera=true
fi

get_joystick_number() {
    local device_pattern="$1"
    local js_number=""

    js_number=$(grep -i -A 5 "Name=.*$device_pattern" /proc/bus/input/devices | grep "Handlers" | grep -o "js[0-9]*" | head -1)

    if [ -n "$js_number" ]; then
        local num="${js_number#js}"
        echo "$((num + 1))"
    else
        echo "none"
    fi
}

download_github_file() {
    local github_url="$1"
    local filename="$2"
    local download_dir="$3"
    local output_path="${download_dir}/${filename}"

    local raw_url
    raw_url=$(echo "$github_url" | sed 's|github.com|raw.githubusercontent.com|' | sed 's|/blob/|/|')

    echo "Downloading: $filename to ${download_dir}"
    wget -q -O "$output_path" "$raw_url" || {
        echo "Error downloading $filename"
        return 1
    }

    echo "Downloaded: $filename"
    return 0
}

backup_file() {
    local file_path="$1"
    local backup_name="$2"

    mkdir -p "$BACKUP_DIR"

    if [ -f "$file_path" ] && [ ! -f "$BACKUP_DIR/$backup_name" ]; then
        echo "Backing up: $file_path to $BACKUP_DIR/$backup_name"
        cp "$file_path" "$BACKUP_DIR/$backup_name"
    fi
}

restore_files() {
    echo -e "${magenta}Uninstall mode detected. Restoring original files...${nc}"

    if [ ! -d "$BACKUP_DIR" ]; then
        echo -e "${red}No backups found to restore.${nc}"
        exit 0
    fi

    if [ -f "$BACKUP_DIR/mameGenerator.py.original" ]; then
        if [ -f "$BATOCERA_MAME_GENERATOR_V41" ]; then
            echo -e "${cyan}[INFO] Restoring: $BATOCERA_MAME_GENERATOR_V41${nc}"
            cp "$BACKUP_DIR/mameGenerator.py.original" "$BATOCERA_MAME_GENERATOR_V41"
        elif [ -f "$BATOCERA_MAME_GENERATOR_V42" ]; then
            echo -e "${cyan}[INFO] Restoring: $BATOCERA_MAME_GENERATOR_V42${nc}"
            cp "$BACKUP_DIR/mameGenerator.py.original" "$BATOCERA_MAME_GENERATOR_V42"
        else
            echo -e "${red}Could not determine Batocera MAME generator path for restoration${nc}"
        fi
    fi

    if [ -f "$BACKUP_DIR/batocera.conf.original" ] && [ -f "$BATOCERA_CONFIG_FILE" ]; then
        echo -e "${cyan}[INFO] Restoring: $BATOCERA_CONFIG_FILE${nc}"
        cp "$BACKUP_DIR/batocera.conf.original" "$BATOCERA_CONFIG_FILE"
    fi

    if [ -f "$BACKUP_DIR/autostart.sh.original" ] && [ -f "$RETROPIE_AUTOSTART_FILE" ]; then
        echo -e "${cyan}[INFO] Restoring: $RETROPIE_AUTOSTART_FILE${nc}"
        cp "$BACKUP_DIR/autostart.sh.original" "$RETROPIE_AUTOSTART_FILE"
    fi

    if [ -f "$BACKUP_DIR/DOFLinx.ini.original" ] && [ -f "$DOFLINX_INI_FILE" ]; then
        echo -e "${cyan}[INFO] Restoring: $DOFLINX_INI_FILE${nc}"
        cp "$BACKUP_DIR/DOFLinx.ini.original" "$DOFLINX_INI_FILE"
    fi

    if [ "$batocera" = "true" ]; then
        PLUGIN_PATH="${BATOCERA_PLUGIN_PATH}"
    else
        PLUGIN_PATH=$(find / -name init.lua 2>/dev/null | grep hiscore | xargs dirname | xargs dirname | head -n 1)
        if [ -z "$PLUGIN_PATH" ]; then
            PLUGIN_PATH="/usr/local/share/mame/plugins"
        fi
    fi

    if [ -d "${PLUGIN_PATH}/doflinx" ]; then
        echo -e "${cyan}[INFO] Removing DOFLinx plugin from MAME plugins directory: ${PLUGIN_PATH}/doflinx${nc}"
        rm -rf "${PLUGIN_PATH}/doflinx" || sudo rm -rf "${PLUGIN_PATH}/doflinx"
    fi

    if [ "$batocera" = "true" ]; then
        if [ -f "${HOME}/services/doflinx" ]; then
            echo -e "${cyan}[INFO] Disabling and removing DOFLinx service${nc}"
            batocera-services disable doflinx 2>/dev/null
            rm -f "${HOME}/services/doflinx"
        fi

        if [ -L "/usr/bin/mame/plugins/doflinx" ] || [ -e "/usr/bin/mame/plugins/doflinx" ]; then
            rm -rf /usr/bin/mame/plugins/doflinx
        fi

        if batocera-save-overlay 2>/dev/null; then
            echo "Changes saved to Batocera overlay"
        else
            echo "Warning: Could not save to overlay. Changes will be restored at next boot."
        fi
    fi

    if [ -d "${HOME}/doflinx" ]; then
        echo -e "${cyan}[INFO] Removing DOFLinx installation directory${nc}"
        rm -rf "${HOME}/doflinx"
    fi

    echo -e "${magenta}DOFLinx Uninstallation complete. All modified files have been restored${nc}"
    exit 0
}

pause() {
    read -s -n 1 -p "Press any key to continue . . ."
    echo ""
}

commandLineArg=$1

if [ "$commandLineArg" = "undo" ]; then
    restore_files
fi

echo -e ""
echo -e "       ${magenta}DOFLinx for Linux : Installer Version $version${nc}"
echo -e ""
echo -e "This script will install the DOFLinx software in $HOME/doflinx"
echo -e "You'll need at least 300 MB of free disk space in $HOME"
echo -e ""

if test -f "${HOME}/doflinx/DOFLinx"; then
   echo -e "${cyan}[INFO] Existing DOFLinx installation found${nc}"
   if pgrep -x "DOFLinx" > /dev/null; then
     echo -e "${cyan}[INFO] Stopping DOFLinx${nc}"
     "${HOME}/doflinx/DOFLinxMsg" QUIT
   fi
fi

machine_arch="default"
pi3=false
pi4=false
pi5=false
pizero=false
odroidn2=false

if uname -m | grep -q 'armv6'; then
   echo -e "${cyan}arm_v6 Detected...${nc}"
   machine_arch=arm_v6
fi

if uname -m | grep -q 'armv7'; then
   echo -e "${cyan}arm_v7 Detected...${nc}"
   machine_arch=arm_v7
fi

if uname -m | grep -q 'aarch32'; then
   echo -e "${cyan}aarch32 Detected...${nc}"
   machine_arch=arm_v7
fi

if uname -m | grep -q 'aarch64'; then
   echo -e "${cyan}[INFO] aarch64 Detected...${nc}"
   machine_arch=arm64
fi

if uname -m | grep -q 'x86'; then
   if uname -m | grep -q 'x86_64'; then
      echo -e "${cyan}[INFO] x86 64-bit Detected...${nc}"
      machine_arch=x64
   else
      echo -e "${red}[ERROR] x86 32-bit Detected...not supported${nc}"
      machine_arch=386
   fi
fi

if uname -m | grep -q 'amd64'; then
   echo -e "${cyan}[INFO] x86 64-bit Detected...${nc}"
   machine_arch=x64
fi

if test -f /proc/device-tree/model; then
   if grep -q 'Raspberry Pi 3' /proc/device-tree/model; then
      echo -e "${cyan}[INFO] Raspberry Pi 3 detected...${nc}"
      pi3=true
   fi
   if grep -q 'Pi 4' /proc/device-tree/model; then
      echo -e "${cyan}[INFO] Raspberry Pi 4 detected...${nc}"
      pi4=true
   fi
   if grep -q 'Pi 5' /proc/device-tree/model; then
      echo -e "${cyan}[INFO] Raspberry Pi 5 detected...${nc}"
      pi5=true
   fi
   if grep -q 'Pi Zero W' /proc/device-tree/model; then
      echo -e "${cyan}[INFO] Raspberry Pi Zero detected...${nc}"
      pizero=true
   fi
   if grep -q 'ODROID-N2' /proc/device-tree/model; then
      echo -e "${cyan}[INFO] ODroid N2 or N2+ detected...${nc}"
      odroidn2=true
   fi
fi

if [ "$batocera" = "true" ]; then
    batocera_version="$(batocera-es-swissknife --version | cut -c1-2)"
    if [ "$batocera_version" -lt "39" ]; then
        echo -e "${red}[ERROR] Sorry, Batocera version 39 or higher is required. Please update and try again: exiting...${nc}"
        exit 1
    fi
fi

if [[ "$machine_arch" == "default" ]]; then
  echo -e "${red}[ERROR] Your device platform was not detected${nc}"
  echo -e "${yellow}[WARNING] Guessing x64 but be aware DOFLinx may not work${nc}"
  machine_arch=x64
fi

mkdir -p "${HOME}/doflinx"
mkdir -p "${HOME}/doflinx/temp"

echo -e "${cyan}[INFO] Installing DOFLinx Software...${nc}"

cd "${HOME}/doflinx/temp" || exit 1

doflinx_url="https://github.com/DOFLinx/DOFLinx-for-Linux/releases/download/doflinx/doflinx.zip"
wget -O "${HOME}/doflinx/temp/doflinx.zip" "$doflinx_url"
if [ $? -ne 0 ]; then
   echo -e "${red}[ERROR]${nc} Failed to download DOFLinx"
   install_successful=false
else
   unzip -o doflinx.zip -d "${HOME}/doflinx"
   if [ $? -ne 0 ]; then
      echo -e "${red}[ERROR]${nc} Failed to unzip DOFLinx"
      install_successful=false
   else
        cp -f "${HOME}/doflinx/${machine_arch}/"* "${HOME}/doflinx/"
        if [ $? -ne 0 ]; then
            echo -e "${red}[ERROR]${nc} Failed to copy DOFLinx files"
            install_successful=false
        fi

        if [ "$batocera" = "true" ]; then
            PLUGIN_PATH="${BATOCERA_PLUGIN_PATH}"
        else
            echo "Not on Batocera, finding plugin path"
            PLUGIN_PATH=$(find / -name init.lua 2>/dev/null | grep hiscore | xargs dirname | xargs dirname | head -n 1)
            if [ -z "$PLUGIN_PATH" ]; then
                echo "Warning: Could not find plugin path. Using default path."
                PLUGIN_PATH="/usr/local/share/mame/plugins"
            fi
        fi

        DOFLINX_DIR="${PLUGIN_PATH}/doflinx"
        if [ ! -d "$DOFLINX_DIR" ]; then
            echo -e "${cyan}[INFO] Creating directory: $DOFLINX_DIR${nc}"
            mkdir -p "$DOFLINX_DIR"
        fi

        cp -f -r "${HOME}/doflinx/DOFLinx Mame Integration/doflinx" "${PLUGIN_PATH}/"
        if [ $? -ne 0 ]; then
            echo -e "${yellow}[WARNING]${nc} Failed to copy DOFLinx plugin, will attempt via sudo"
            sudo cp -f -r "${HOME}/doflinx/DOFLinx Mame Integration/doflinx" "${PLUGIN_PATH}/"
            if [ $? -ne 0 ]; then
                echo -e "${red}[ERROR]${nc} Failed to copy DOFLinx plugin"
                install_successful=false
            fi
        fi

        cp -f "${HOME}/doflinx/DLSocket/${machine_arch}/DLSocket" "${PLUGIN_PATH}/doflinx/"
        if [ $? -ne 0 ]; then
            echo -e "${yellow}[WARNING]${nc} Failed to copy DLSocket to DOFLinx plugin directory, will attempt via sudo"
            sudo cp -f "${HOME}/doflinx/DLSocket/${machine_arch}/DLSocket" "${PLUGIN_PATH}/doflinx/"
            if [ $? -ne 0 ]; then
                echo -e "${red}[ERROR]${nc} Failed to copy DLSocket to DOFLinx plugin directory"
                install_successful=false
            fi
        fi
   fi
fi

chmod a+x "${HOME}/doflinx/DOFLinx" 2>/dev/null || true
chmod a+x "${HOME}/doflinx/DOFLinxMsg" 2>/dev/null || true
chmod +x "${PLUGIN_PATH}/doflinx/DLSocket" 2>/dev/null || true

sed -i -e "s|/home/arcade/|${HOME}/|g" "${HOME}/doflinx/config/DOFLinx.ini"
if [ $? -ne 0 ]; then
   echo -e "${red}[ERROR] Failed to edit DOFLinx.ini${nc}"
   install_successful=false
fi

# Checking for Batocera installation
if [ "$batocera" = "true" ]; then
   batocera_version="$(batocera-es-swissknife --version | cut -c1-2)"
   echo -e "${cyan}[INFO] Batocera Version ${batocera_version} Detected${nc}"

   if [[ $batocera_version -ge $batocera_40_plus_version ]]; then
      if [[ ! -d ${HOME}/services ]]; then
         mkdir "${HOME}/services"
      fi

      wget -O "${HOME}/services/doflinx" https://raw.githubusercontent.com/alinke/DOFLinx-for-Linux/main/batocera/doflinx
      chmod +x "${HOME}/services/doflinx"
      sleep 1
      batocera-services enable doflinx
      echo -e "${cyan}[INFO] DOFLinx added as a Batocera service for auto-start${nc}"
   else
      if [[ -f ${HOME}/custom.sh ]]; then
          if ! grep -q "DOFLinx PATH_INI=" "${HOME}/custom.sh"; then
              cp "${HOME}/custom.sh" "${HOME}/custom.sh.backup"

              if grep -q 'start)' "${HOME}/custom.sh"; then
                  sed -i '/start)/a\
        if [ ! -L "/usr/bin/mame/plugins/doflinx" ]; then\
            ln -sf /userdata/saves/mame/plugins/doflinx /usr/bin/mame/plugins/doflinx\
        fi\
        sleep 5\
        cd /userdata/system/doflinx && ./DOFLinx PATH_INI=/userdata/system/doflinx/config/DOFLinx.ini \&' "${HOME}/custom.sh"
              else
                  cat >> "${HOME}/custom.sh" << 'EOF'

case "$1" in
    start)
        if [ ! -L "/usr/bin/mame/plugins/doflinx" ]; then
            ln -sf /userdata/saves/mame/plugins/doflinx /usr/bin/mame/plugins/doflinx
        fi
        sleep 5
        cd /userdata/system/doflinx && ./DOFLinx PATH_INI=/userdata/system/doflinx/config/DOFLinx.ini &
        ;;
esac
EOF
              fi

              echo -e "${cyan}[INFO] Modified custom.sh for auto-starting DOFLinx on boot${nc}"
          else
              echo -e "${cyan}[INFO] DOFLinx startup already configured in custom.sh${nc}"
          fi
      else
          cat > "${HOME}/custom.sh" << 'EOF'
#!/bin/bash
# Code here will be executed on every boot and shutdown.

case "$1" in
    start)
        if [ ! -L "/usr/bin/mame/plugins/doflinx" ]; then
            ln -sf /userdata/saves/mame/plugins/doflinx /usr/bin/mame/plugins/doflinx
        fi
        sleep 5
        cd /userdata/system/doflinx && ./DOFLinx PATH_INI=/userdata/system/doflinx/config/DOFLinx.ini &
        ;;
    stop)
        ;;
    restart|reload)
        ;;
    *)
        ;;
esac

exit $?
EOF
          chmod +x "${HOME}/custom.sh"
          echo -e "${cyan}[INFO] Created custom.sh for auto-starting DOFLinx on boot${nc}"
      fi
   fi

   chmod a+x "${HOME}/doflinx/DOFLinx" 2>/dev/null || true
   chmod a+x "${HOME}/doflinx/DOFLinxMsg" 2>/dev/null || true
   chmod a+x "${DOFLINX_DIR}/DLSocket" 2>/dev/null || true

   if [ ! -d "/usr/bin/mame/plugins" ]; then
      mkdir -p /usr/bin/mame/plugins
   fi

   if [ ! -L "/usr/bin/mame/plugins/doflinx" ]; then
      ln -sf /userdata/saves/mame/plugins/doflinx /usr/bin/mame/plugins/doflinx
      echo -e "${cyan}[INFO] DOFLinx plugin symlink created successfully${nc}"
   else
      echo -e "${cyan}[INFO] DOFLinx plugin symlink already exists, skipping...${nc}"
   fi

   echo -e "${cyan}[INFO] MAME DOFLinx plugin installed${nc}"

   if [ "$batocera_version" = "40" ]; then
        MAME_GENERATOR="$BATOCERA_MAME_GENERATOR_V41"
        echo -e "${cyan}[INFO] Detected Batocera V40${nc}"
   elif [ "$batocera_version" = "41" ]; then
        MAME_GENERATOR="$BATOCERA_MAME_GENERATOR_V41"
        echo -e "${cyan}[INFO] Detected Batocera V41${nc}"
   elif [ "$batocera_version" = "42" ]; then
        MAME_GENERATOR="$BATOCERA_MAME_GENERATOR_V42"
        echo -e "${cyan}[INFO] Detected Batocera V42${nc}"
   else
        if [ -f "$BATOCERA_MAME_GENERATOR_V41" ]; then
            MAME_GENERATOR="$BATOCERA_MAME_GENERATOR_V41"
            echo "Assuming Batocera V41 based on file path"
        elif [ -f "$BATOCERA_MAME_GENERATOR_V42" ]; then
            MAME_GENERATOR="$BATOCERA_MAME_GENERATOR_V42"
            echo "Assuming Batocera V42 based on file path"
        else
            echo "Error: Could not find mameGenerator.py. Please check your Batocera version."
            MAME_GENERATOR=""
        fi
   fi

   if [ -n "$MAME_GENERATOR" ]; then
      backup_file "$MAME_GENERATOR" "mameGenerator.py.original"
      echo "Modifying $MAME_GENERATOR"

      if grep -q 'pluginsToLoad += \[ "doflinx" \]' "$MAME_GENERATOR"; then
         echo -e "${cyan}[INFO] Skipped: The doflinx plugin is already added${nc}"
      else
         sed -i '/pluginsToLoad = \[\]/a\        pluginsToLoad += [ "doflinx" ]' "$MAME_GENERATOR"
         echo -e "${cyan}[INFO] Successfully added doflinx plugin${nc}"
      fi

      if grep -q 'commandArray += \[ "-output", "network" \]' "$MAME_GENERATOR"; then
         echo -e "${cyan}[INFO] Skipped: The network output line is already added${nc}"
      else
         sed -i '/if messSysName\[messMode\] == "" or messMode == -1:/i\        commandArray += [ "-output", "network" ]' "$MAME_GENERATOR"
         echo -e "${cyan}[INFO] Successfully added -output network command line option${nc}"
      fi
   fi

   if [[ -f "$BATOCERA_CONFIG_FILE" ]]; then
      backup_file "$BATOCERA_CONFIG_FILE" "batocera.conf.original"
   fi

   if [ ! -f "$BATOCERA_CONFIG_FILE" ]; then
        echo "Error: $BATOCERA_CONFIG_FILE does not exist. Skipping the config to switch to stand alone MAME which you'll need to do manually."
   else
        if ! grep -q "^$BATOCERA_CONFIG_LINE1$" "$BATOCERA_CONFIG_FILE"; then
            echo "$BATOCERA_CONFIG_LINE1" >> "$BATOCERA_CONFIG_FILE"
            echo -e "${cyan}[INFO] Added: $BATOCERA_CONFIG_LINE1${nc}"
        else
            echo -e "${cyan}[INFO] Skipped: $BATOCERA_CONFIG_LINE1 already exists${nc}"
        fi

        if ! grep -q "^$BATOCERA_CONFIG_LINE2$" "$BATOCERA_CONFIG_FILE"; then
            echo "$BATOCERA_CONFIG_LINE2" >> "$BATOCERA_CONFIG_FILE"
            echo -e "${cyan}[INFO] Added: $BATOCERA_CONFIG_LINE2${nc}"
        else
            echo -e "${cyan}[INFO] Skipped: $BATOCERA_CONFIG_LINE2 already exists${nc}"
        fi

        echo "Batocera configuration updated"
   fi

   if batocera-save-overlay; then
        echo "Changes saved to Batocera overlay"
   else
        echo "Warning: Could not save to overlay. Changes will be restored by custom.sh at next boot."
   fi
else
  echo -e "${cyan}[INFO] Not on Batocera, skipping Batocera setup${nc}"
fi

# Checking for Retropie installation
if [[ -f "$RETROPIE_AUTOSTART_FILE" ]]; then
  echo -e "${cyan}[INFO] RetroPie detected${nc}"
  backup_file "$RETROPIE_AUTOSTART_FILE" "autostart.sh.original"
  if grep -q "DOFLinx" "$RETROPIE_AUTOSTART_FILE"; then
      echo -e "${green}[INFO]${nc} DOFLinx entry already exists in $RETROPIE_AUTOSTART_FILE. Skipping."
  else
      echo -e "${green}[INFO]${nc} Adding DOFLinx to $RETROPIE_AUTOSTART_FILE"
      echo "$RETROPIE_LINE_TO_ADD" | sudo tee -a "$RETROPIE_AUTOSTART_FILE" > /dev/null
      echo -e "${green}[INFO]${nc} DOFLinx added to RetroPie autostart"
  fi
  sudo chmod +x "$RETROPIE_AUTOSTART_FILE"
else
  echo -e "${green}[INFO]${nc} Not on RetroPie, skipping RetroPie setup..."
fi

# Initialize arrays to track detected joysticks
DETECTED_JS=()

if grep -i -q "X-Box" /proc/bus/input/devices; then
    XBOX_JS=$(get_joystick_number "X-Box")
    XBOX_CONNECTED=1
    DETECTED_JS+=($((XBOX_JS - 1)))
else
    XBOX_CONNECTED=0
    XBOX_JS="none"
fi

if grep -q "USB,2-axis 8-button gamepad" /proc/bus/input/devices; then
    GAMEPAD_JS=$(get_joystick_number "USB,2-axis 8-button gamepad")
    GAMEPAD_CONNECTED=1
    DETECTED_JS+=($((GAMEPAD_JS - 1)))
else
    GAMEPAD_CONNECTED=0
    GAMEPAD_JS="none"
fi

if grep -i -q "Nintendo Switch" /proc/bus/input/devices; then
    SWITCH_JS=$(get_joystick_number "Nintendo Switch")
    SWITCH_CONNECTED=1
    DETECTED_JS+=($((SWITCH_JS - 1)))
else
    SWITCH_CONNECTED=0
    SWITCH_JS="none"
fi

FALLBACK_JS=()
for js_device in /dev/input/js*; do
    if [ -c "$js_device" ]; then
        js_num=${js_device##*/js}
        if ! [[ " ${DETECTED_JS[*]} " =~ " ${js_num} " ]]; then
            FALLBACK_JS+=($js_num)
        fi
    fi
done

# Configure DOFLinx.ini without Pixelcade
if [ ! -f "$DOFLINX_INI_FILE" ]; then
  echo -e "${red}[ERROR] Config file not found at $DOFLINX_INI_FILE${nc}"
  install_successful=false
else
  backup_file "$DOFLINX_INI_FILE" "DOFLinx.ini.original"

  if ! grep -q "^DEBUG=" "$DOFLINX_INI_FILE"; then
    temp_file=$(mktemp)
    echo "#DEBUG=1 will enable debug logging which will show up in DOFLinx.log" > "$temp_file"
    echo "DEBUG=0" >> "$temp_file"
    cat "$DOFLINX_INI_FILE" >> "$temp_file"
    mv "$temp_file" "$DOFLINX_INI_FILE"
  fi

  if [ "$batocera" = "true" ]; then
    echo -e "${cyan}[INFO] Batocera detected, updating MAME_FOLDER to /usr/bin/mame/${nc}"
    sed -i 's|^MAME_FOLDER=.*$|MAME_FOLDER=/usr/bin/mame/|' "$DOFLINX_INI_FILE"
    sed -i 's|^MAME_HISCORE_FOLDER=.*$|MAME_HISCORE_FOLDER=/userdata/saves/mame/plugins/hiscore/|' "$DOFLINX_INI_FILE"
  else
    echo -e "${cyan}[INFO] Not on Batocera, updating MAME_FOLDER to /usr/games/${nc}"
    sed -i 's|^MAME_FOLDER=.*$|MAME_FOLDER=/usr/games/|' "$DOFLINX_INI_FILE"
  fi

  # Pixelcade-related config off
  sed -i 's|^PATH_PIXELCADE=.*$|#PATH_PIXELCADE=|' "$DOFLINX_INI_FILE"
  sed -i 's|^PATH_HI2TXT=.*$|#PATH_HI2TXT=|' "$DOFLINX_INI_FILE"
  sed -i 's|^PIXELCADE_GAME_START_HIGHSCORE=.*$|#PIXELCADE_GAME_START_HIGHSCORE=1|' "$DOFLINX_INI_FILE"
  sed -i 's|^PATH_MAME=.*pixelcade.*$|#PATH_MAME=|' "$DOFLINX_INI_FILE"

  if [ "$pi5" = "true" ] || uname -m | grep -q 'x86'; then
      if grep -q "^MAME_PLUGIN_LOOPS=" "$DOFLINX_INI_FILE"; then
        sed -i "s/^MAME_PLUGIN_LOOPS=.*$/MAME_PLUGIN_LOOPS=1/" "$DOFLINX_INI_FILE"
        echo -e "${cyan}[INFO] Updated MAME_PLUGIN_LOOPS to 1 for Pi5 or x86${nc}"
      else
        echo "" >> "$DOFLINX_INI_FILE"
        echo "#Set MAME_PLUGIN_LOOPS to a higher number for better performance for low powered devices, lower number down to 1 equals faster DOFLinx polling" >> "$DOFLINX_INI_FILE"
        echo "MAME_PLUGIN_LOOPS=1" >> "$DOFLINX_INI_FILE"
        echo -e "${cyan}[INFO] Added MAME_PLUGIN_LOOPS=1${nc}"
      fi
  else
      if grep -q "^MAME_PLUGIN_LOOPS=" "$DOFLINX_INI_FILE"; then
        sed -i "s/^MAME_PLUGIN_LOOPS=.*$/MAME_PLUGIN_LOOPS=2/" "$DOFLINX_INI_FILE"
        echo -e "${cyan}[INFO] Updated MAME_PLUGIN_LOOPS to 2${nc}"
      else
        echo "" >> "$DOFLINX_INI_FILE"
        echo "#Set MAME_PLUGIN_LOOPS to a higher number for better performance for low powered devices, lower number down to 1 equals faster DOFLinx polling" >> "$DOFLINX_INI_FILE"
        echo "MAME_PLUGIN_LOOPS=2" >> "$DOFLINX_INI_FILE"
        echo -e "${cyan}[INFO] Added MAME_PLUGIN_LOOPS=2${nc}"
      fi
  fi

  LINK_BUT_CN=$(grep -E "^LINK_BUT_CN=" "$DOFLINX_INI_FILE" | tr -d '\r' | tr -d '\n')
  LINK_BUT_P1=$(grep -E "^LINK_BUT_P1=" "$DOFLINX_INI_FILE" | tr -d '\r' | tr -d '\n')

  if [ -z "$LINK_BUT_CN" ]; then
      LINK_BUT_CN="LINK_BUT_CN=0000,Orange,6"
  fi
  if [ -z "$LINK_BUT_P1" ]; then
      LINK_BUT_P1="LINK_BUT_P1=0000,Cyan,2"
  fi

  LINK_BUT_CN=$(echo "$LINK_BUT_CN" | sed -E 's/,0000,Orange,J0[0-9][0-9][0-9]//g')
  LINK_BUT_P1=$(echo "$LINK_BUT_P1" | sed -E 's/,0000,Cyan,J0[0-9][0-9][0-9]//g')

  if [ "$GAMEPAD_JS" != "none" ]; then
      LINK_BUT_CN="${LINK_BUT_CN},0000,Orange,J0${GAMEPAD_JS}06"
      LINK_BUT_P1="${LINK_BUT_P1},0000,Cyan,J0${GAMEPAD_JS}07"
  fi

  if [ "$SWITCH_JS" != "none" ]; then
      LINK_BUT_CN="${LINK_BUT_CN},0000,Orange,J0${SWITCH_JS}09"
      LINK_BUT_P1="${LINK_BUT_P1},0000,Cyan,J0${SWITCH_JS}08"
  fi

  if [ "$XBOX_JS" != "none" ]; then
      LINK_BUT_CN="${LINK_BUT_CN},0000,Orange,J0${XBOX_JS}06"
      LINK_BUT_P1="${LINK_BUT_P1},0000,Cyan,J0${XBOX_JS}07"
  fi

  for js_num in "${FALLBACK_JS[@]}"; do
      js_logical=$((js_num + 1))
      LINK_BUT_CN="${LINK_BUT_CN},0000,Orange,J0${js_logical}06"
      LINK_BUT_P1="${LINK_BUT_P1},0000,Cyan,J0${js_logical}07"
      echo -e "${cyan}[INFO] Added fallback button configurations for unknown joystick at js${js_num} (configured as joystick ${js_logical})${nc}"
  done

  sed -i "s/^LINK_BUT_CN=.*$/${LINK_BUT_CN//\//\\/}/" "$DOFLINX_INI_FILE" 2>/dev/null || true
  if ! grep -q "^LINK_BUT_CN=" "$DOFLINX_INI_FILE"; then
      echo "$LINK_BUT_CN" >> "$DOFLINX_INI_FILE"
  fi

  sed -i "s/^LINK_BUT_P1=.*$/${LINK_BUT_P1//\//\\/}/" "$DOFLINX_INI_FILE" 2>/dev/null || true
  if ! grep -q "^LINK_BUT_P1=" "$DOFLINX_INI_FILE"; then
      echo "$LINK_BUT_P1" >> "$DOFLINX_INI_FILE"
  fi

  echo -e "${cyan}[INFO] DOFLinx.ini has been updated for Batocera without Pixelcade${nc}"
fi

echo -e "${cyan}[INFO] Cleaning up${nc}"
cd "${HOME}" || exit 1
rm -rf "${HOME}/doflinx/temp"

if [[ $install_successful == "true" ]]; then
   echo -e "${cyan}[INFO] DOFLinx in-game MAME effects installed${nc}"

   if [ "$batocera" = "true" ]; then
         MAME_OUTPUT=$(/usr/bin/mame/mame -version 2>/dev/null)

         if echo "$MAME_OUTPUT" | grep -q -E '^[0-9]+\.[0-9]+'; then
            MAME_VERSION=$(echo "$MAME_OUTPUT" | awk '{print $1}')
         elif echo "$MAME_OUTPUT" | grep -q -E 'MAME [0-9]+\.[0-9]+'; then
            MAME_VERSION=$(echo "$MAME_OUTPUT" | awk '{print $2}')
         else
            MAME_VERSION=$(echo "$MAME_OUTPUT" | grep -o -E '[0-9]+\.[0-9]+' | head -1)
         fi

         echo -e "${bg_magenta}${white}Please note your MAME core in Batocera has been switched to stand alone MAME version ${bold}${MAME_VERSION}${white}, ensure your MAME romset is compatible with this version${nc}"
    fi

   echo -e "${cyan}[INFO] DOFLinx guide can be found at https://doflinx.github.io/docs/${nc}"
   echo -e "${cyan}[INFO] Support can be found at http://www.vpforums.org/index.php?showforum=104${nc}"
   echo -e "${cyan}[INFO] Gamepad controller(s) detected and configured for coin input and player start in ${DOFLINX_INI_FILE}:${nc}"

   [ "$XBOX_CONNECTED" = "1" ] && echo -e "${cyan}[INFO]   * Xbox controller (Joystick ${XBOX_JS})${nc}"
   [ "$GAMEPAD_CONNECTED" = "1" ] && echo -e "${cyan}[INFO]   * USB 2-axis 8-button gamepad (Joystick ${GAMEPAD_JS})${nc}"
   [ "$SWITCH_CONNECTED" = "1" ] && echo -e "${cyan}[INFO]   * Nintendo Switch controller (Joystick ${SWITCH_JS})${nc}"

   for js_num in "${FALLBACK_JS[@]}"; do
      echo -e "${cyan}[INFO]   * Unknown joystick at js${js_num} (Joystick $((js_num + 1)))${nc}"
   done

   if [ "$XBOX_CONNECTED" != "1" ] && [ "$GAMEPAD_CONNECTED" != "1" ] && [ "$SWITCH_CONNECTED" != "1" ] && [ ${#FALLBACK_JS[@]} -eq 0 ]; then
      echo -e "${cyan}[INFO]   * No gamepads detected${nc}"
   fi

   echo -e "${cyan}--------------------------------${nc}"
   echo -e "${cyan}[INFO] If you want to uninstall DOFLinx, re-run this script and append: undo${nc}"
else
  echo -e "${bold_red}[ERROR] DOFLinx installation failed${nc}"
fi

echo -e "\n${magenta}Please now reboot and DOFLinx effects will be loaded automatically on startup${nc}"
echo -e "${magenta}Would you like to reboot now? (y/n)${nc}"

read -r answer

case ${answer:0:1} in
    y|Y )
        echo -e "${magenta}System will reboot now...${nc}"
        sleep 2
        reboot || sudo reboot
        ;;
    * )
        echo -e "${red}Reboot skipped. Please remember to reboot your system later.${nc}"
        pause
        echo -e "${cyan}[INFO] Now starting DOFLinx...${nc}"
        cd "${HOME}/doflinx" && ./DOFLinx PATH_INI="${HOME}/doflinx/config/DOFLinx.ini" &
        ;;
esac

echo ""
