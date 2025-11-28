![PVEKCLEAN Logo](assets/banner.png)

Easily remove old/unused PVE kernels on your Proxmox VE system

[![Version](https://img.shields.io/badge/Version-v2.2.1-brightgreen)](https://github.com/CupricReki/pvekclean)
[![License: MIT](https://img.shields.io/badge/License-MIT-brightgreen.svg)](https://opensource.org/licenses/MIT)
![Updated](https://img.shields.io/github/last-commit/CupricReki/pvekclean)
![Proxmox](https://img.shields.io/badge/-Proxmox-orange)
![Debian](https://img.shields.io/badge/-Debian-red)
[![Security](https://img.shields.io/badge/Security-Audited-blue)](SECURITY_AUDIT.md)

### What is PVE Kernel Cleaner?

PVE Kernel Cleaner is a program to compliment Proxmox Virtual Environment which is an open-source server virtualization environment. PVE Kernel Cleaner allows you to purge old/unused kernels filling the /boot directory. As new kernels are released the older ones have to be manually removed frequently to make room for newer ones. This can become quite tedious and require extensive time spent monitoring the system when new kernels are released and when older ones need to be cleared out to make room. With this issue existing, PVE Kernel Cleaner was created to solve it.

## Example Usage

![PVEKCLEAN Example](assets/example-2.0.2.png)

## Features

* Removes old PVE kernels from your system safely with multiple protection layers
* **NEW:** Default retention of 1 old kernel as fallback (configurable with `--keep`)
* **NEW:** Exact version matching prevents accidental removal of critical kernels
* **NEW:** Enhanced bootloader detection (proxmox-boot-tool and GRUB) with safety checks
* **NEW:** Fatal error exits prevent system damage from failed bootloader updates
* Ability to schedule PVE kernels to automatically be removed on a daily/weekly/monthly basis
* Run a simple pvekclean command for ease of access
* Checks health of boot disk based on space available
* Detects and removes orphaned kernel files from EFI System Partition (ESP)
* True dry-run mode for testing (guaranteed zero system modifications)
* Update function to easily update the program to the latest version
* Allows you to specify the minimum number of most recent PVE kernels to retain
* Support for the latest Proxmox versions and PVE kernels
* Comprehensive error handling with recovery instructions

## Latest Version

* **v2.2.1** - Major security and safety improvements ([see audit](SECURITY_AUDIT.md))

## Prerequisites

Before using this program you will need to have the following packages installed.
* cron
* curl
* git

To install all required packages enter the following command.

##### Debian:

```
sudo apt-get install cron curl git
```

## Installing

You can install PVE Kernel Cleaner using either Git or Curl. Choose the method that suits you best:

### Installation via Git

1. Open your terminal.

2. Enter the following commands one by one to install PVE Kernel Cleaner:

```bash
git clone https://github.com/CupricReki/pvekclean.git
cd pvekclean
./pvekclean.sh
```
### Installation via Curl

1. Open your terminal.

2. Use the following command to install PVE Kernel Cleaner:

```bash
curl -o pvekclean.sh https://raw.githubusercontent.com/CupricReki/pvekclean/master/pvekclean.sh
./pvekclean.sh
```

## Updating

PVE Kernel Cleaner checks for updates automatically when you run it. If an update is available, you'll be notified within the program. Simply follow the on-screen instructions to install the update, and you're all set with the latest version!

## Usage

Example of usage:
```
 pvekclean [OPTION1] [OPTION2]...

-k, --keep [number]   Keep the specified number of most recent PVE kernels on the system
                      Default: 1 (keeps one old kernel as fallback for safety)
                      Set to 0 to remove all old kernels (not recommended)
                      Can be used with -f or --force for non-interactive removal
-f, --force           Force the removal of old PVE kernels without confirm prompts
                      WARNING: Bypasses safety checks including kernel version verification
-rn, --remove-newer   Remove kernels that are newer than the currently running kernel
                      WARNING: Dangerous operation, use with caution
-s, --scheduler       Have old PVE kernels removed on a scheduled basis
-v, --version         Shows current version of pvekclean
-r, --remove          Uninstall pvekclean from the system
-i, --install         Install pvekclean to the system
-d, --dry-run         Run the program in dry run mode for testing without making system changes
                      Guarantees zero modifications (no installs, updates, or kernel removals)

```

## Usage Examples:
Here are some common ways to use PVE Kernel Cleaner:

* **Remove Old Kernels Non-Interactively:**
```bash
pvekclean -f
```
<sub> This command removes old PVE kernels without requiring user confirmation.</sub>

* **Set Number of Kernels to Keep:**
```bash
pvekclean -k 3
```
<sub>This command specifies the number of most recent PVE kernels to keep on the system.</sub>

* **Force Remove Old Kernels While Keeping a Certain Number:**
```bash
pvekclean -f -k 3
```
<sub>This command forces the removal of old PVE kernels while retaining a specific number of the most recent ones.</sub>

* **Remove Newer Kernels and Keep a Specific Number:**
```bash
pvekclean -rn -k 2
```
<sub>This command removes newer PVE kernels and keeps a specified number of the most recent ones.</sub>

* **Schedule Regular Kernel Removal:**
```bash
pvekclean -s
```
<sub>This command sets up PVE Kernel Cleaner to remove old PVE kernels on a scheduled basis. You can configure the schedule according to your needs.</sub>

* **Perform a Dry Run without Making Changes:**
```bash
pvekclean -d
```
<sub>This command runs PVE Kernel Cleaner in dry run mode, simulating actions without actually removing any kernels or making changes to your system. It's useful for testing and understanding what the script would do.</sub>

## Security & Safety

This script has undergone comprehensive security auditing to ensure safe operation on production Proxmox systems. Key safety features include:

* **Current kernel always protected** - Never removes the running kernel
* **Latest kernel always protected** - Preserves newest installed kernel (unless `--remove-newer` explicitly used)
* **Default fallback retention** - Keeps at least 1 old kernel for recovery
* **Bootloader verification** - Confirms bootloader configuration before making changes
* **Fatal error handling** - Exits immediately if critical operations fail
* **True dry-run mode** - Test safely without any system modifications
* **Package verification** - Validates all packages exist before attempting removal

For detailed security information, see [SECURITY_AUDIT.md](SECURITY_AUDIT.md).

### Recommended Usage Pattern

```bash
# 1. Always test with dry-run first
sudo ./pvekclean.sh --dry-run

# 2. Review the proposed changes carefully

# 3. Run with default safety settings
sudo ./pvekclean.sh

# 4. For extra safety, keep 2 old kernels
sudo ./pvekclean.sh --keep 2
```

**⚠️ Not Recommended:** Using `--keep 0` or `--force` without understanding the risks.

## Developers

* **Jordan Hillis** - *Lead Developer*

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details

## Acknowledgments

* This program is not an official program by Proxmox Server Solutions GmbH
