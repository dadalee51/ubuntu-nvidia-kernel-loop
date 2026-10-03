#!/bin/bash
# Warn about Ubuntu kernels installed WITHOUT linux-modules-extra
# (= no WiFi/Bluetooth/touchpad drivers on that kernel).
# See README: the NVIDIA driver pulls bare kernels in as dependencies.
missing=0
for img in $(dpkg -l 'linux-image-[0-9]*' 2>/dev/null | awk '/^ii/{print $2}'); do
  k=${img#linux-image-}
  case "$k" in *-generic|*-lowlatency) ;; *) continue ;; esac
  if ! dpkg -s "linux-modules-extra-$k" >/dev/null 2>&1; then
    echo "" >&2
    echo "############################################################" >&2
    echo "# WARNING: kernel $k is INCOMPLETE" >&2
    echo "# linux-modules-extra-$k is NOT installed." >&2
    echo "# Booting it = no WiFi / Bluetooth / touchpad." >&2
    echo "# Fix BEFORE rebooting:  sudo apt install linux-generic" >&2
    echo "############################################################" >&2
    missing=1
  fi
done
exit 0
