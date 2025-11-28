#!/bin/bash
echo "=== Testing Flow ==="
echo "Step 1: Running main()"
source <(sed -n '/^main() {/,/^}/p' pvekclean.sh | sed 's/check_root/echo "  - check_root"/g; s/header_info/echo "  - header_info"/g; s/check_for_update/echo "  - check_for_update"/g; s/install_program/echo "  - install_program"/g; s/show_usage/echo "  - show_usage"/g; s/kernel_info/echo "  - kernel_info"/g')
main
echo "Step 2: main() completed"
echo "Step 3: About to run pve_kernel_clean()"
echo "=== Flow test complete ==="
