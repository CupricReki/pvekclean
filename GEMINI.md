# GEMINI.md

## Project Overview

This project, `pvekclean`, is a shell script designed to simplify the management of Proxmox VE (PVE) kernels. It helps users remove old and unused kernels from their systems, which is a common maintenance task in Proxmox environments to free up space in the `/boot` directory. The script is written in Bash and provides a command-line interface with several options for kernel management.

The key functionalities include:
- Removing old PVE kernels.
- Keeping a specified number of recent kernels.
- Forcing removal without interactive prompts.
- Scheduling automatic kernel cleaning (daily, weekly, or monthly) via cron.
- A dry-run mode to test the script without making changes.
- An built-in updater to fetch the latest version from GitHub.

## Building and Running

This project is a single-file shell script and does not require a build process.

### Running the script:

The script can be run directly from the repository or installed system-wide.

**Directly from the repository:**
```bash
chmod +x pvekclean.sh
./pvekclean.sh [options]
```

**Installation:**

The script can be installed to `/usr/local/sbin` for easier access.

```bash
./pvekclean.sh -i
```
or
```bash
./pvekclean.sh --install
```

Once installed, it can be run as a command:
```bash
pvekclean [options]
```

### Key Commands and Options:

-   `pvekclean -k <number>`: Keep a specified number of the most recent kernels.
-   `pvekclean -f`: Force removal of old kernels without confirmation.
-   `pvekclean -s`: Set up a cron job for scheduled cleaning.
-   `pvekclean -d`: Perform a dry run without deleting any files.
-   `pvekclean -r`: Uninstall the script.
-   `pvekclean -v`: Show the current version.

## Development Conventions

-   The script is written in Bash and follows common shell scripting practices.
-   It uses a set of predefined variables for colors and formatting to provide a user-friendly output.
-   The script checks for root privileges before executing critical commands.
-   It includes a self-update mechanism that fetches the latest version from the `master` branch of its GitHub repository.
-   The script is designed to be self-contained, with all functionality included in the `pvekclean.sh` file.
-   The version is managed in a `version.txt` file and also hardcoded in the script itself.
