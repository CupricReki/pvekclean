#!/bin/bash
: '
______________________________________________

              PVE Kernel Cleaner
               By Jordan Hillis
             jordan@hillis.email
           https://jordanhillis.com
______________________________________________

MIT License

Copyright (c) 2023 Jordan Hillis - jordan@hillis.email - https://jordanhillis.com

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
______________________________________________
'

# Percentage of used space in the /boot which would consider it critically full
boot_critical_percent="95"

# Default minimum number of old kernels to keep as fallback (besides current and latest)
# Set to 0 to disable, or override with --keep flag
default_keep_kernels="1"

# To check for updates or not
check_for_updates=true

# Dry run mode is for testing without actually removing anything
dry_run=false

# Current kernel
current_kernel=$(uname -r)

# Name of the program
program_name="pvekclean"

# Version
version="2.2.1"

# Text Colors
black="\e[38;2;0;0;0m"
gray="\e[30m"
red="\e[31m"
green="\e[32m"
yellow="\e[33m"
blue="\e[34m"
magenta="\e[35m"
cyan="\e[36m"
white="\e[37m"
orange="\e[38;5;202m"

# Background Colors
bg_black="\e[40m"
bg_red="\e[41m"
bg_green="\e[42m"
bg_yellow="\e[43m"
bg_blue="\e[44m"
bg_magenta="\e[45m"
bg_cyan="\e[46m"
bg_white="\e[47m"
bg_orange="\e[48;5;202m"

# Text Styles
bold="\e[1m"

# Reset formatting
reset="\e[0m"

# Force purging without dialog confirms
force_purge=false

# Allow removing kernels newer than current
remove_newer=false

# Check if script is ran as root, if not exit
check_root() {
	if [[ $EUID -ne 0 ]]; then
		printf "${bold}[!] Error:${reset} this script must be ran as the root user.\n"
		exit 1
	fi
}

# Shown current version
version() {
  printf $version"\n"
  exit 0
}

# Header for PVE Kernel Cleaner
header_info() {
echo -e " ${bg_black}${orange}                                                ${reset} \
 ${bg_black}${orange}   █▀▀█ ▀█ █▀ █▀▀   █ █ █▀▀ █▀▀█ █▀▀▄ █▀▀ █     ${reset} \
 ${bg_black}${orange}   █  █  █▄█  █▀▀   █▀▄ █▀▀ █▄▄▀ █  █ █▀▀ █     ${reset} 
 ${bg_black}${orange}   █▀▀▀   ▀   ▀▀▀   ▀ ▀ ▀▀▀ ▀ ▀▀ ▀  ▀ ▀▀▀ ▀▀▀   ${reset} \
 ${bg_black}${orange}                                                ${reset} \
 ${bg_black}${white}   █▀▀ █   █▀▀ █▀▀█ █▀▀▄ █▀▀ █▀▀█               ${reset} \
 ${bg_black}${white}   █   █   █▀▀ █▄▄█ █  █ █▀▀ █▄▄▀  ${white}${bold}⎦˚◡˚⎣ v$version ${reset} \
 ${bg_black}${white}   ▀▀▀ ▀▀▀ ▀▀▀ ▀  ▀ ▀  ▀ ▀▀▀ ▀ ▀▀               ${reset} \
 ${bg_orange}${black}      ${bold}By Jordan Hillis [jordan@hillis.email]    ${reset}
___________________________________________"
if [ "$dry_run" == "true" ]; then
	printf "          ${bg_yellow}${black}${bold}    DRY RUN MODE IS: ${red}ON    ${reset}\n"
	printf "${bg_green}${bold}${black} This is what the script would do in regular mode ${reset}\n${bg_green}${bold}${black}      (but without making actual changes)         ${reset}\n\n"
fi
}

# Function to get drive status based on usage percentage
get_drive_status() {
	local usage=$1
    # Check if the input is a number
    if ! [[ $usage =~ ^[0-9]+$ ]]; then
        echo "${bold}N/A${reset}"
    else
		if (( usage <= 50 )); then
			echo "${bold}${green}Healthy${reset}"
		elif (( usage > 50 && usage <= 75 )); then
			echo "${bold}${orange}Moderate Capacity${reset}"
		else
			echo "${bold}${red}Critically Full${reset}"
		fi
	fi
}

# Show current system information
kernel_info() {
    # Determine boot method - check what bootloader is actually being used
    local use_pbt=false
    local use_grub=false
    
    # Check for proxmox-boot-tool (EFI System Partition method)
    if [ -x "/usr/sbin/proxmox-boot-tool" ]; then
        if [ -d "/sys/firmware/efi" ]; then
            if /usr/sbin/proxmox-boot-tool status &>/dev/null; then
                if /usr/sbin/proxmox-boot-tool status 2>/dev/null | grep -qi "ESP"; then
                    use_pbt=true
                fi
            fi
        fi
    fi
    
    # Check for GRUB (if proxmox-boot-tool not detected)
    if [ "$use_pbt" = false ]; then
        if [ -x "/usr/sbin/update-grub" ] && [ -f "/boot/grub/grub.cfg" ]; then
            use_grub=true
        fi
    fi

	# Lastest kernel installed
	local latest_installed_kernel_ver
    latest_installed_kernel_ver=$(dpkg-query -W -f='${Version}\n' 'proxmox-kernel-*-pve' 'pve-kernel-*-pve' 2>/dev/null | sed -n 's/.*-\([0-9].*\)/\1/p' | sort -V | tail -n 1)
	[ -z "$latest_installed_kernel_ver" ] && latest_installed_kernel_ver="N/A"

    printf " ${bold}OS:${reset} $(cat /etc/os-release | grep "PRETTY_NAME" | sed 's/PRETTY_NAME=//g' | sed 's/[ \\"]//g' | awk '{print $0}')\n"
    
    # Display detected bootloader
    if [ "$use_pbt" = true ]; then
        printf " ${bold}Boot Method:${reset} proxmox-boot-tool (EFI System Partition)\n"
        local esp_uuid
        esp_uuid=$(proxmox-boot-tool status 2>/dev/null | grep -oE '[0-9A-F]{4}-[0-9A-F]{4}' | head -n 1)
        local boot_total_h=""
        local boot_used_h=""
        local boot_free_h=""
        local boot_percent="N/A"
        if [ -n "$esp_uuid" ]; then
            local mount_point="/var/tmp/pvekclean_esp_mount_$$"
            mkdir -p "$mount_point"
            if mount -o ro /dev/disk/by-uuid/"$esp_uuid" "$mount_point" 2>/dev/null; then
                local boot_details=($(df -P "$mount_point" | tail -1))
                if [ ${#boot_details[@]} -ge 5 ]; then
                    boot_total_h=$(df -h "$mount_point" 2>/dev/null | tail -1 | awk '{print $2}')
                    boot_used_h=$(df -h "$mount_point" 2>/dev/null | tail -1 | awk '{print $3}')
                    boot_free_h=$(df -h "$mount_point" 2>/dev/null | tail -1 | awk '{print $4}')
                    boot_percent=${boot_details[4]%?}
                fi
                umount "$mount_point"
                rmdir "$mount_point"
            fi
        fi
        boot_info=("" "$boot_total_h" "$boot_used_h" "$boot_free_h" "$boot_percent")
        local boot_drive_status=$(get_drive_status "${boot_info[4]}")
		printf " ${bold}Boot Disk:${reset} ${boot_info[4]}%% full [${boot_info[2]}/${boot_info[1]} used, ${boot_info[3]} free] \n"
    elif [ "$use_grub" = true ]; then
        printf " ${bold}Boot Method:${reset} GRUB (/boot)\n"
        local boot_details=($(df -P /boot 2>/dev/null | tail -1))
        local boot_total_h=""
        local boot_used_h=""
        local boot_free_h=""
        local boot_percent="N/A"
        if [ ${#boot_details[@]} -ge 5 ]; then
            boot_total_h=$(df -h /boot 2>/dev/null | tail -1 | awk '{print $2}')
            boot_used_h=$(df -h /boot 2>/dev/null | tail -1 | awk '{print $3}')
            boot_free_h=$(df -h /boot 2>/dev/null | tail -1 | awk '{print $4}')
            boot_percent=${boot_details[4]%?}
        fi
        boot_info=("" "$boot_total_h" "$boot_used_h" "$boot_free_h" "$boot_percent")
        local boot_drive_status=$(get_drive_status "${boot_info[4]}")
		printf " ${bold}Boot Disk:${reset} ${boot_info[4]}%% full [${boot_info[2]}/${boot_info[1]} used, ${boot_info[3]} free] \n"
    else
        # No supported bootloader detected
        printf " ${bold}Boot Method:${reset} ${red}UNKNOWN/UNSUPPORTED${reset}\n"
        printf "${bold}${red}[!] WARNING:${reset} Could not detect a supported bootloader!\n"
        printf "${bold}[!]${reset} This script may not be safe to use on this system.\n"
    fi


	printf " ${bold}Current Kernel:${reset} $current_kernel\n"
    # Check if we are running the latest kernel, if not warn
    if [[ "$latest_installed_kernel_ver" != "$current_kernel" ]]; then
        printf " ${bold}Latest Kernel:${reset} ${latest_installed_kernel_ver}\n"
        printf "\n${bold}${yellow}[!] WARNING:${reset} You are NOT booted into the latest kernel!\n"
        printf "${bold}[!]${reset} Current: $current_kernel\n"
        printf "${bold}[!]${reset} Latest:  ${latest_installed_kernel_ver}\n"
        printf "${bold}[!]${reset} It is recommended to:\n"
        printf "    1. Reboot into the latest kernel (${latest_installed_kernel_ver})\n"
        printf "    2. Verify the system boots successfully\n"
        printf "    3. Re-run this script after confirming the new kernel works\n"
        printf "${bold}[!]${reset} This ensures you can fall back to the current kernel if needed.\n\n"
        if [ "$force_purge" = false ]; then
            printf "${bold}[*]${reset} Do you want to continue anyway? [y/N]: "
            read -n 1 -r
            printf "\n"
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                printf "\nExiting. Please reboot to the latest kernel first.\n"
                printf "${bold}[-]${reset} Good bye!\n"
                exit 0
            fi
        fi
    fi

    if [[ "$current_kernel" != *"pve"* ]]; then
        printf "___________________________________________
"
        printf "${bold}[!]${reset} Warning, you're not running a PVE kernel\n"
        printf "${bold}[*]${reset} Would you like to continue [y/N] "
        read -n 1 -r
        printf "\n"
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            printf "${bold}[-]${reset} Alright, we will continue on\n"
        else
            printf "\nGood bye!\n"
            exit 0
        fi
    fi
	printf "___________________________________________
"
}

# Usage information on how to use PVE Kernel Clean
show_usage() {
	# Skip showing usage when force_purge is enabled
	if [ $force_purge == false ]; then
		printf "${bold}Usage:${reset} $(basename $0) [OPTION1] [OPTION2]...\n\n"
		printf "  -k, --keep [number]   Keep the specified number of most recent PVE kernels on the system\n"
		printf "                        ${bold}Default: $default_keep_kernels${reset} (keeps fallback kernel for safety)\n"
		printf "                        Set to 0 to remove all old kernels (not recommended)\n"
		printf "                        Can be used with -f or --force for non-interactive removal\n"
		printf "  -f, --force           Force the removal of old PVE kernels without confirm prompts\n"
		printf "                        ${bold}WARNING:${reset} Bypasses safety checks including kernel version verification\n"
		printf "  -rn, --remove-newer   Remove kernels that are newer than the currently running kernel\n"
		printf "                        ${bold}WARNING:${reset} Dangerous operation, use with caution\n"
		printf "  -s, --scheduler       Have old PVE kernels removed on a scheduled basis\n"
		printf "  -v, --version         Shows current version of $program_name\n"
		printf "  -r, --remove          Uninstall $program_name from the system\n"
		printf "  -i, --install         Install $program_name to the system\n"
		printf "  -d, --dry-run         Run the program in dry run mode for testing without making system changes\n"
		printf "___________________________________________
"
	fi
}

# Schedule PVE Kernel Cleaner at a time desired
scheduler() {
	# Check if pvekclean is on the system, if not exit
	if [ ! -f /usr/local/sbin/$program_name ]; then
		printf "${bold}[!]${reset} Sorry $program_name is required to be installed on the system for this functionality.\n"
		exit 1
	fi
	# Check if cron is installed
    if ! [ -x "$(command -v crontab)" ]; then
      printf "${bold}[*]${reset} Error, cron does not appear to be installed.\n"
      printf "    Please install cron with the command 'sudo apt-get install cron'\n\n"
      exit 1
    fi
	# Check if the cronjob exists on the system
	check_cron_exists=$(crontab -l | grep "$program_name")
	# Cronjob exists
	if [ -n "$check_cron_exists" ]; then
		# Get the current cronjob scheduling
		cron_current=$(crontab -l | grep "$program_name" | sed "s/[^a-zA-Z']/ /g" | sed -e "s/\b(.)/\u\1/g" | awk '{print $1;}')
		# Ask the user if they would like to remove the scheduling
		printf "${bold}[-]${reset} Would you like to remove the currently scheduled PVE Kernel Cleaner? (Current: $cron_current) [y/N] "
		read -n 1 -r
		if [[ $REPLY =~ ^[Yy]$ ]]; then
			# Remove the cronjob
			(crontab -l | grep -v "$program_name")| crontab -
			printf "\n[*] Successfully removed the ${cron_current,,} scheduled PVE Kernel Cleaner!\n"
		else
			# Keep it
			printf "\n\nAlright we will keep your current settings then.\n"
		fi
	# Cronjob does not exist
	else
		# Ask how often the would like to check for old PVE kernels
		printf "${bold}[-]${reset} How often would you like to check for old PVE kernels?\n    1) Daily\n    2) Weekly\n    3) Monthly\n\n  - Enter a number option above? "
		read -r -p "" response
		case "$response" in
			1)
				cron_time="daily"
			;;
			2)
				cron_time="weekly"
			;;
			3)
				cron_time="monthly"
			;;
			*)
				printf "\nThat is not a valid option!\n"
				exit 1
			;;
		esac
		# Ask if they want to set a specific number of kernels to keep
        printf "${bold}[-]${reset} Enter the number of latest kernels to keep (or press Enter to skip): "
		read number_of_kernels
        if [[ "$number_of_kernels" =~ ^[0-9]+$ ]]; then
            kernel_option=" -k $number_of_kernels"
			printf "${bold}[-]${reset} Okay, we will keep at least $number_of_kernels kernels on the system."
        else
            kernel_option=""
        fi
		# Add the cronjob
		(crontab -l ; echo "@$cron_time /usr/local/sbin/$program_name -f$kernel_option")| crontab -
		printf "\n[-] Scheduled $cron_time PVE Kernel Cleaner successfully!\n"
	fi
	exit 0
}

# Installs PVE Kernel Cleaner for easier access
install_program() {
	# Skip installation prompts in dry-run mode (no system modifications allowed)
	if [ "$dry_run" = "true" ]; then
		return 0
	fi
	
	force_pvekclean_update=false
    local tmp_file="/tmp/.pvekclean_install_lock"
    local install=false
    local ask_interval=3600  # 1 hour in seconds	
	# If pvekclean exists on the system
	if [ -e /usr/local/sbin/$program_name ]; then
		# Get current version of pvekclean
		pvekclean_installed_version=$(/usr/local/sbin/$program_name -v | awk '{printf $0}')
		# If the version differs, update it to the latest from the script
		if [ $version != $pvekclean_installed_version ] && [ $force_purge == false ]; then
			printf "${bold}[!]${reset} A new version of PVE Kernel Cleaner has been detected (Installed: $pvekclean_installed_version | New: $version).\n"
			printf "${bold}[*]${reset} Installing update...\n"
			force_pvekclean_update=true
		fi
	fi
    # Check if the file doesn't exist or it's been over an hour since the last ask
    if [ ! -e "$tmp_file" ] || [ ! -f "$tmp_file" ] || [ $(( $(date +%s) - $(cat "$tmp_file") )) -gt $ask_interval ] || [ $force_pvekclean_update == true ] || [ -n "$force_pvekclean_install" ]; then	
		# If pvekclean does not exist on the system or force_purge is enabled
		if [ ! -f /usr/local/sbin/$program_name ] || [ $force_pvekclean_update == true ] || [ -n "$force_pvekclean_install" ]; then
			# Ask user if we can install it to their system
			if [ $force_purge == true ]; then
				REPLY="n"
			else
				# Update the timestamp in the file to record the time of the last ask
				echo $(date +%s) > "$tmp_file"
				# Ask if we can install it
				printf "${bold}[-]${reset} Can we install PVE Kernel Cleaner to your /usr/local/sbin for easier access [y/N] " 
				read -n 1 -r
				printf "\n"
			fi
			# User agrees to have it installed
			if [[ $REPLY =~ ^[Yy]$ ]]; then
				# Copy the script to /usr/local/sbin and set execution permissions
				cp $0 /usr/local/sbin/$program_name
				chmod +x /usr/local/sbin/$program_name
				# Tell user how to use it
				printf "${bold}[*]${reset} Installed PVE Kernel Cleaner to /usr/local/sbin/$program_name\n"
				printf "${bold}[*]${reset} Run the command \"$program_name\" to begin using this program.\n"
				printf "${bold}[-]${reset} Run the command \"$program_name -r\" to remove this program at any time.\n"
				exit 0
			fi
			# if [ -n "$force_pvekclean_install" ]; then
			# 	exit 0
			# fi
		fi
	fi
	if [ -n "$force_pvekclean_install" ]; then
		exit 0
	fi
}

# Uninstall pvekclean from the system
uninstall_program() {
	# If pvekclean exists on the system
	if [ -e /usr/local/sbin/$program_name ]; then
		# Confirm that they wish to remove it
		printf "${bold}[-]${reset} Are you sure that you would like to remove $program_name? [y/N] "
		read -n 1 -r
		printf "\n"
		if [[ $REPLY =~ ^[Yy]$ ]]; then
			# Remove the program
			rm -f /usr/local/sbin/$program_name
			printf "${bold}[*]${reset} Successfully removed PVE Kernel Cleaner from the system!\n"
			printf "${bold}[-]${reset} Sorry to see you go :(\n"
		else
			printf "\nExiting...\nThat was a close one ⎦˚◡˚⎣\n"
			printf "${bold}[-]${reset} Have a nice $(timeGreeting) ⎦˚◡˚⎣\n"
		fi
		exit 0
	else
		# Tell the user that it is not installed
		printf "${bold}[!]${reset} This program is not installed on the system.\n"
		exit 1
	fi
}

recover_esp_space() {
    printf "\n${bold}${yellow}[!] Attempting to recover space on EFI System Partition...${reset}\n"
    local esp_uuid
    esp_uuid=$(proxmox-boot-tool status | grep -oE '[0-9A-F]{4}-[0-9A-F]{4}' | head -n 1)
    if [ -z "$esp_uuid" ]; then
        printf "${bold}${red}[!] Could not determine ESP UUID. Aborting recovery.${reset}\n"
        return 1
    fi

    local mount_point="/mnt/esp_pvekclean"
    mkdir -p "$mount_point"
    if ! mount /dev/disk/by-uuid/"$esp_uuid" "$mount_point"; then
        printf "${bold}${red}[!] Failed to mount ESP at $mount_point. Aborting recovery.${reset}\n"
        rmdir "$mount_point"
        return 1
    fi

    local oldest_kernel_on_esp=""
    local running_kernel_ver
    running_kernel_ver=$(uname -r)

    local esp_kernels
    esp_kernels=$(ls "$mount_point"/vmlinuz-* 2>/dev/null | sed -n 's/.*vmlinuz-//p')

    for k in $esp_kernels; do
        if [[ "$k" == "$running_kernel_ver" ]]; then
            continue
        fi

        if [[ -z "$oldest_kernel_on_esp" ]]; then
            oldest_kernel_on_esp=$k
        else
            if dpkg --compare-versions "$k" "lt" "$oldest_kernel_on_esp"; then
                oldest_kernel_on_esp=$k
            fi
        fi
    done

    if [[ -n "$oldest_kernel_on_esp" ]]; then
        printf "${bold}[-]${reset} Found oldest unused kernel on ESP: ${cyan}$oldest_kernel_on_esp${reset}\n"
        if [ "$dry_run" != "true" ]; then
            printf "${bold}[-]${reset} Removing boot files to make space...\n"
            rm -f "$mount_point/vmlinuz-$oldest_kernel_on_esp"
            rm -f "$mount_point/initrd.img-$oldest_kernel_on_esp"
            printf "${bold}${green}[✔]${reset} Successfully removed old kernel files from ESP.\n"
        else
            printf "${bold}[-]${reset} Dry run: Would have removed vmlinuz-$oldest_kernel_on_esp and initrd.img-$oldest_kernel_on_esp from ESP.\n"
        fi
    else
        printf "${bold}${yellow}[!] Could not find an old kernel to remove from ESP.${reset}\n"
    fi

    umount "$mount_point"
    rmdir "$mount_point"
    printf "${bold}[-]${reset} Resuming normal cleanup...\n"
}


# Cleanup function for trap
cleanup_on_exit() {
    # Unmount any mounted ESPs
    local mount_patterns=("/var/tmp/pvekclean_esp_mount_*" "/mnt/esp_pvekclean")
    for pattern in "${mount_patterns[@]}"; do
        for mount_point in $pattern; do
            if [ -d "$mount_point" ] && mountpoint -q "$mount_point" 2>/dev/null; then
                umount "$mount_point" 2>/dev/null
                rmdir "$mount_point" 2>/dev/null
            fi
        done
    done
}

# Set trap to cleanup on exit, interrupt, or termination
trap cleanup_on_exit EXIT INT TERM

# PVE Kernel Clean main function
pve_kernel_clean() {

    # Determine boot method early - check what bootloader is actually being used
    local use_pbt=false
    local use_grub=false
    local bootloader_detected=false
    
    # Check for proxmox-boot-tool (EFI System Partition method)
    if [ -x "/usr/sbin/proxmox-boot-tool" ]; then
        # Check if system has EFI firmware
        if [ -d "/sys/firmware/efi" ]; then
            # Check if proxmox-boot-tool is actually configured with ESPs
            if /usr/sbin/proxmox-boot-tool status &>/dev/null; then
                # Verify at least one ESP is configured
                if /usr/sbin/proxmox-boot-tool status 2>/dev/null | grep -qi "ESP"; then
                    use_pbt=true
                    bootloader_detected=true
                fi
            fi
        fi
    fi
    
    # Check for GRUB (if proxmox-boot-tool not detected)
    if [ "$bootloader_detected" = false ]; then
        if [ -x "/usr/sbin/update-grub" ] && [ -f "/boot/grub/grub.cfg" ]; then
            use_grub=true
            bootloader_detected=true
        fi
    fi
    
    # Fail if we can't detect any supported bootloader
    if [ "$bootloader_detected" = false ]; then
        printf "${bold}${red}[!] CRITICAL ERROR:${reset} Cannot detect bootloader!\n"
        printf "${bold}[!]${reset} Neither proxmox-boot-tool nor GRUB could be detected.\n"
        printf "${bold}[!]${reset} This script requires one of:\n"
        printf "    - proxmox-boot-tool (EFI) with configured ESPs\n"
        printf "    - GRUB with /boot/grub/grub.cfg\n"
        printf "${bold}[!]${reset} Aborting to prevent system damage.\n"
        exit 1
    fi

    # --- Kernel Discovery ---
    local kernel_packages_to_remove=()
    local latest_installed_kernel_ver
    latest_installed_kernel_ver=$(dpkg-query -W -f='${Version}\n' 'proxmox-kernel-*-pve' 'pve-kernel-*-pve' 2>/dev/null | sed -n 's/.*-\([0-9].*\)/\1/p' | sort -V | tail -n 1)

    local discovery_source
    if [ "$use_pbt" = true ]; then
        discovery_source="ESP"
        local esp_kernels=()
        esp_uuid=$(proxmox-boot-tool status 2>/dev/null | grep -oE '[0-9A-F]{4}-[0-9A-F]{4}' | head -n 1)
        if [ -n "$esp_uuid" ]; then
            local mount_point="/var/tmp/pvekclean_esp_mount_$$"
            mkdir -p "$mount_point"
            if mount -o ro /dev/disk/by-uuid/"$esp_uuid" "$mount_point" 2>/dev/null; then
                # list kernels and strip the vmlinuz- prefix
                esp_kernels=($(ls "$mount_point"/vmlinuz-* 2>/dev/null | sed -n 's/.*vmlinuz-//p'))
                umount "$mount_point"
                rmdir "$mount_point"
            fi
        fi
        
        for k_ver in "${esp_kernels[@]}"; do
            # Always skip running kernel
            if [[ "$k_ver" == "$current_kernel" ]]; then
                continue
            fi
            # Skip latest kernel unless --remove-newer is set
            if [[ "$k_ver" == "$latest_installed_kernel_ver" ]]; then
                continue
            fi
            # Skip kernels newer than current unless --remove-newer is set
            if [ "$remove_newer" = false ]; then
                if dpkg --compare-versions "$k_ver" "gt" "$current_kernel"; then
                    continue
                fi
            fi
            # Construct potential package names and check if they exist
            for pkg_prefix in "pve-kernel-" "proxmox-kernel-"; do
                 pkg_name="${pkg_prefix}${k_ver}"
                 if dpkg-query -W -f='${Status}' "$pkg_name" 2>/dev/null | grep -q "ok installed"; then
                     kernel_packages_to_remove+=("$pkg_name")
                     headers_pkg_name=$(echo "$pkg_name" | sed 's/kernel/headers/')
                     if dpkg-query -W -f='${Status}' "$headers_pkg_name" 2>/dev/null | grep -q "ok installed"; then
                         kernel_packages_to_remove+=("$headers_pkg_name")
                     fi
                 fi
            done
        done
    else
        discovery_source="dpkg"
        local installed_kernel_packages
        installed_kernel_packages=$(dpkg --list | grep -E '^(ii|ri|ui|hi).*(pve|proxmox)-kernel-[0-9]+\.[0-9]+\.[0-9]+-[0-9]+-pve' | awk '{print $2}')
        for kernel_pkg in $installed_kernel_packages; do
            local kernel_version
            kernel_version=$(echo "$kernel_pkg" | sed -n 's/.*-\([0-9].*\)/\1/p')

            # Always skip running kernel
            if [[ "$kernel_version" == "$current_kernel" ]]; then
                continue
            fi
            # Skip latest kernel unless --remove-newer is set
            if [[ "$kernel_version" == "$latest_installed_kernel_ver" ]]; then
                continue
            fi
            # Skip kernels newer than current unless --remove-newer is set
            if [ "$remove_newer" = false ]; then
                if dpkg --compare-versions "$kernel_version" "gt" "$current_kernel"; then
                    continue
                fi
            fi
            kernel_packages_to_remove+=("$kernel_pkg")
            local kernel_headers_pkg
            kernel_headers_pkg=$(echo "$kernel_pkg" | sed 's/kernel/headers/')
            if dpkg-query -W -f='${Status}' "$kernel_headers_pkg" 2>/dev/null | grep -q "ok installed"; then
                kernel_packages_to_remove+=("$kernel_headers_pkg")
            fi
        done
    fi

    # --- Remove Duplicates from Package List ---
    # Using associative array to deduplicate (bash 4+)
    local -A seen_packages
    local unique_packages=()
    for pkg in "${kernel_packages_to_remove[@]}"; do
        if [[ -z "${seen_packages[$pkg]}" ]]; then
            seen_packages[$pkg]=1
            unique_packages+=("$pkg")
        fi
    done
    kernel_packages_to_remove=("${unique_packages[@]}")

    # --- Early Package Verification ---
    # Verify all packages in removal list actually exist and are removable
    local missing_packages=()
    local verification_failed=false
    for kernel_pkg in "${kernel_packages_to_remove[@]}"; do
        if ! dpkg-query -W -f='${Status}' "$kernel_pkg" 2>/dev/null | grep -q "ok installed"; then
            missing_packages+=("$kernel_pkg")
            verification_failed=true
        fi
    done

    if [ "$verification_failed" = true ]; then
        printf "${bold}${red}[!] CRITICAL ERROR:${reset} Package verification failed!\n"
        printf "${bold}[!]${reset} The following packages were identified for removal but are not properly installed:\n"
        for pkg in "${missing_packages[@]}"; do
            printf "  ${red}✗${reset} $pkg\n"
        done
        printf "\n${bold}[!]${reset} This indicates a mismatch between boot partition and dpkg database.\n"
        printf "${bold}[!]${reset} Aborting to prevent system damage. Please investigate manually.\n"
        exit 1
    fi
    
    # --- Warn if --remove-newer is being used ---
    if [ "$remove_newer" = true ]; then
        printf "${bold}${yellow}[!] WARNING:${reset} --remove-newer flag is active!\n"
        printf "${bold}[!]${reset} This will allow removal of kernels NEWER than the running kernel.\n"
        printf "${bold}[!]${reset} This is potentially dangerous if newer kernels are needed for hardware support.\n"
        if [ "$force_purge" = false ]; then
            printf "${bold}[*]${reset} Are you sure you want to continue? [y/N]: "
            read -n 1 -r
            printf "\n"
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                printf "\nExiting for safety.\n"
                printf "${bold}[-]${reset} Good bye!\n"
                exit 0
            fi
        fi
    fi

    local kernels_to_keep=()
	
	# Apply default kernel retention if user didn't specify --keep
	if [[ -z "$keep_kernels" ]] && [[ "$default_keep_kernels" =~ ^[0-9]+$ ]] && [ "$default_keep_kernels" -gt 0 ]; then
		keep_kernels="$default_keep_kernels"
		printf "${bold}[*]${reset} Applying default policy: keeping at least ${bold}$keep_kernels${reset} old kernel$([ "$keep_kernels" -eq 1 ] || echo 's') as fallback.\n"
		printf "${bold}[*]${reset} (You can override this with --keep <number> or set default_keep_kernels=0 in the script)\n"
	fi
	
	# If keep_kernels is set we remove this number from the array to remove
	if [[ -n "$keep_kernels" ]] && [[ "$keep_kernels" =~ ^[0-9]+$ ]]; then
		if [ "$keep_kernels" -gt 0 ]; then
			printf "${bold}[*]${reset} The last ${bold}$keep_kernels${reset} kernel$([ "$keep_kernels" -eq 1 ] || echo 's') will be held back from being removed.\n"
			
			local unique_kernels=($(printf "%s\n" "${kernel_packages_to_remove[@]}" | grep -v "headers" | sort -V -u))
			local num_unique_to_keep=$keep_kernels
			if [ "$num_unique_to_keep" -ge "${#unique_kernels[@]}" ]; then
				num_unique_to_keep=${#unique_kernels[@]}
			fi

            local unique_kernels_to_keep=("${unique_kernels[@]:${#unique_kernels[@]}-$num_unique_to_keep}")
            local temp_packages_to_remove=()

            for pkg in "${kernel_packages_to_remove[@]}"; do
                local is_kept=false
                for kept_kernel in "${unique_kernels_to_keep[@]}"; do
                    # Check if pkg is exactly the kept kernel OR its corresponding headers package
                    local kept_headers=$(echo "$kept_kernel" | sed 's/kernel/headers/')
                    if [[ "$pkg" == "$kept_kernel" ]] || [[ "$pkg" == "$kept_headers" ]]; then
                        kernels_to_keep+=("$pkg")
                        is_kept=true
                        break
                    fi
                done
                if [ "$is_kept" = false ]; then
                    temp_packages_to_remove+=("$pkg")
                fi
            done
            kernel_packages_to_remove=("${temp_packages_to_remove[@]}")
		fi
	fi

	# Show kernels to be removed
	printf "${bold}[-]${reset} Searching for old PVE kernels on your system (Source: $discovery_source)...
"
	printf "${bold}${green}[✓]${reset} Current kernel ($current_kernel) is ALWAYS protected from removal\n"
	for kernel_pkg in "${kernel_packages_to_remove[@]}"; do
		printf "  ${bold}${green}+${reset} \"$kernel_pkg\" added to the kernel remove list\n"
	done
	for kernel_pkg in "${kernels_to_keep[@]}"; do
		printf "  ${bold}${red}-${reset} \"$kernel_pkg\" is being held back from removal\n"
	done
	printf "${bold}[-]${reset} PVE kernel search complete!\n"

	# If there are no kernels to be removed then exit
	if [ ${#kernel_packages_to_remove[@]} -eq 0 ]; then
		printf "${bold}[!]${reset} It appears there are no old PVE kernels on your system ⎦˚◡˚⎣\n"
		printf "${bold}[-]${reset} Good bye!\n"
	# Kernels found in removal list
	else
		num_to_remove=${#kernel_packages_to_remove[@]}
		# Check if force removal was passed
		if [ $force_purge == true ]; then
			REPLY="y"
		# Ask the user if they want to remove the selected kernels found
		else
			printf "${bold}[!]${reset} Would you like to remove the ${bold}$num_to_remove${reset} selected PVE kernel package$([ "$num_to_remove" -eq 1 ] || echo 's') listed above? [y/N]: "
			read -n 1 -r
			printf "\n"
		fi
		# User wishes to remove the kernels
		if [[ $REPLY =~ ^[Yy]$ ]]; then
			printf "${bold}[*]${reset} Removing $num_to_remove old PVE kernel package$([ "$num_to_remove" -eq 1 ] || echo 's')...\n"
			
			if [ "$dry_run" != "true" ]; then
				DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get purge -y "${kernel_packages_to_remove[@]}"
				if [ $? -ne 0 ]; then
					printf "${bold}${red}[!] CRITICAL ERROR:${reset} Failed to remove kernel packages.\n"
					printf "${bold}[!]${reset} apt-get purge exited with an error.\n"
					printf "${bold}[!]${reset} System state may be inconsistent. Check 'dpkg -l | grep kernel' before proceeding.\n"
					printf "${bold}[!]${reset} Not attempting bootloader update to prevent further damage.\n"
					exit 1
				fi
			else
				printf "Dry run: Would have run 'apt-get purge -y ${kernel_packages_to_remove[*]}'\n"
			fi

			printf "${bold}[*]${reset} Updating bootloader...\n"
			# Update bootloader after kernels are removed
			if [ "$dry_run" != "true" ]; then
                if [ "$use_pbt" = true ]; then
                    # For proxmox-boot-tool (EFI), run update-initramfs first, then refresh
                    printf "${bold}[-]${reset} Running update-initramfs...\n"
                    /usr/sbin/update-initramfs -u
                    if [ $? -ne 0 ]; then
                        printf "${bold}${red}[!] CRITICAL ERROR:${reset} Failed to update initramfs.\n"
                        printf "${bold}[!]${reset} System may be unbootable. Manual intervention required.\n"
                        printf "${bold}[!]${reset} Try running: update-initramfs -u\n"
                        exit 1
                    fi
                    printf "${bold}[-]${reset} Running proxmox-boot-tool refresh...\n"
                    /usr/sbin/proxmox-boot-tool refresh
                    if [ $? -ne 0 ]; then
                        printf "${bold}${red}[!] CRITICAL ERROR:${reset} Failed to update bootloader with proxmox-boot-tool.\n"
                        printf "${bold}[!]${reset} System may be unbootable. Manual intervention required.\n"
                        printf "${bold}[!]${reset} Try running: proxmox-boot-tool refresh\n"
                        exit 1
                    fi
                elif [ "$use_grub" = true ]; then
                    # For GRUB, only update-grub is required
                    printf "${bold}[-]${reset} Running update-grub...\n"
				    /usr/sbin/update-grub
				    if [ $? -ne 0 ]; then
					    printf "${bold}${red}[!] CRITICAL ERROR:${reset} Failed to update GRUB.\n"
					    printf "${bold}[!]${reset} System may be unbootable. Manual intervention required.\n"
					    printf "${bold}[!]${reset} Try running: update-grub\n"
					    exit 1
				    fi
                else
                    # Should never reach here due to earlier check, but fail safe
                    printf "${bold}${red}[!] CRITICAL ERROR:${reset} No valid bootloader configuration found.\n"
                    exit 1
                fi
			else
				if [ "$use_pbt" = true ]; then
					printf "Dry run: Would have run 'update-initramfs -u' and 'proxmox-boot-tool refresh'\n"
				else
					printf "Dry run: Would have run 'update-grub'\n"
				fi
			fi
			printf "${bold}${green}DONE!${reset}\n"
			
			# Script finished successfully
			printf "${bold}[-]${reset} Have a nice $(timeGreeting) ⎦˚◡˚⎣\n"
		# User wishes to not remove the kernels above, exit
		else
			printf "\nExiting...\n"
			printf "See you later ⎦˚◡˚⎣\n"
		fi
	fi
	exit 0
}

# Function to check for updates
check_for_update() {
    # Skip update check in dry-run mode (no system modifications allowed)
    if [ "$dry_run" = "true" ]; then
        return 0
    fi
    
    # Check if running from within a git repository
    if git -C "$(dirname "$0")" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        local remote_version
        remote_version=$(curl -s -m 10 https://raw.githubusercontent.com/CupricReki/pvekclean/master/version.txt | tr -d '\n' || echo "")
        if [ -n "$remote_version" ] && [ "$remote_version" != "$version" ]; then
            printf "*** A new version $remote_version is available! ***\n"
            printf "${bold}[*]${reset} Please update by running 'git pull' in the repository.\n"
        fi
        return
    fi
    
	if [ "$check_for_updates" == "true" ] && [ "$force_purge" == "false" ]; then
		# Get latest version number
		local remote_version
        remote_version=$(curl -s -m 10 https://raw.githubusercontent.com/CupricReki/pvekclean/master/version.txt | tr -d '\n' || echo "")
		# Unable to fetch remote version, so just skip the update check
		if [ -z "$remote_version" ]; then
			printf "${bold}[*]${reset} Failed to check for updates. Skipping update check.\n"
			return
		fi
		# Validate the remote_version format using a regex
		if [[ ! "$remote_version" =~ ^[0-9]+(\.[0-9]+)*$ ]]; then
			printf "${bold}[*]${reset} Invalid remote version format: ${bold}${orange}$remote_version${reset}. Skipping update check.\n"
			return
		fi
		# If version isn't the same
		if [ "$remote_version" != "$version" ]; then
			printf "*** A new version $remote_version is available! ***\n"
			printf "${bold}[*]${reset} Do you want to update? [y/N] "
			read -n 1 -r
			printf "\n"
			if [[ $REPLY =~ ^[Yy]$ ]]; then
				local updated_script
                updated_script=$(curl -s -m 10 https://raw.githubusercontent.com/CupricReki/pvekclean/master/pvekclean.sh)
				# Check if the updated script contains the shebang line
				if [[ "$updated_script" == "#!/bin/bash"* ]]; then
					echo "$updated_script" > "$0"  # Overwrite the current script
					printf "${bold}[*]${reset} Successfully updated to version $remote_version\n"
					exec "$0" "$@"
				else
					printf "${bold}[*]${reset} The updated script does not contain the expected shebang line.\n"
					printf "${bold}[*]${reset} Update aborted!\n"
				fi
			fi
		fi
	fi
}

timeGreeting() {
    local h
    h=$(date +%k)  # Use %k to get the hour as a decimal number (no leading zero)
    ((h >= 5 && h < 12)) && echo "morning" && return
    ((h >= 12 && h < 17)) && echo "afternoon" && return
    ((h >= 17 && h < 21)) && echo "evening" && return
    echo "night"
}

main() {
	# Check for root
	check_root
	# Show header information
	header_info
	# Script usage
	show_usage
	# Show kernel information
	kernel_info
	# Check for updates
	check_for_update
	# Install program to /usr/local/sbin/
	install_program
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		-i|--install )
			force_pvekclean_install=true
			main
			install_program
		;;
		-r|--remove )
			main
			uninstall_program
		;;
		-s|--scheduler)
			main
			scheduler
		;;
		-v|--version)
			version
		;;
		-h|--help)
			main
			exit 0
		;;
		-k|--keep)
			if [[ $# -gt 1 && "$2" =~ ^[0-9]+$ ]]; then
                keep_kernels="$2"
                shift 2
				continue
            else
                echo -e "${bold}Error:${reset} --keep/-k requires a number argument."
                exit 1
            fi
		;;
		-f|--force)
			force_purge=true
			shift
			continue
		;;
		-rn|--remove-newer)
			remove_newer=true
			shift
			continue
		;;
		-d|--dry-run)
			dry_run=true
			shift
			continue
		;;
		*)
			echo -e "${bold}Unknown option:${reset} $1"
			exit 1
		;;
esac
    shift
done

main
pve_kernel_clean