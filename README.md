# The Ubuntu NVIDIA "Kernel Nightmare Loop" — diagnosed and fixed

> You install/reinstall the NVIDIA driver. After the next reboot your **mouse,
> WiFi and Bluetooth are dead**, sometimes you even drop into an `initramfs`
> prompt. You boot an older kernel to get your machine back — but there the
> **NVIDIA driver is "gone"**. In desperation you `apt purge nvidia-*`,
> reinstall, reboot… and the loop starts again.

If this is you, your kernel is probably **incomplete** — and it is not your
fault. This repo documents the exact mechanism, the 30-second diagnosis, the
fix, and how to make it never happen again.

## The mechanism

On Ubuntu, NVIDIA's prebuilt kernel modules ship in per-kernel packages
(`linux-modules-nvidia-<ver>-<kernel>`). When you (re)install
`nvidia-driver-<ver>`, apt resolves those modules for the **newest kernel in
the archive** — and happily pulls in that new kernel as a dependency:

```
Install: linux-image-6.8.0-146-generic (automatic)
         linux-modules-6.8.0-146-generic (automatic)
         linux-modules-nvidia-595-open-6.8.0-146-generic (automatic)
```

Spot what's missing: **`linux-modules-extra-6.8.0-146-generic`**. That package
contains most laptop hardware drivers — **WiFi, Bluetooth, touchpads, USB
input, card readers**. It is only pulled in when the `linux-generic`
meta-package upgrades — which a driver install does *not* do.

GRUB then boots the newest kernel by default. Result:

1. New kernel boots with no WiFi/BT/input drivers → machine feels bricked
2. You boot the previous kernel → it has your hardware drivers, but **no
   NVIDIA module package for itself** → `nvidia-smi` fails → "driver wiped!"
3. Recovery attempts (`apt purge ^nvidia-*`) actually DO wipe the driver
4. Repeat on every kernel release

## Diagnosis (30 seconds)

```bash
# any installed kernel missing its modules-extra?
for img in $(dpkg -l 'linux-image-[0-9]*' | awk '/^ii/{print $2}'); do
  k=${img#linux-image-}
  dpkg -s "linux-modules-extra-$k" >/dev/null 2>&1 || echo "INCOMPLETE: $k"
done
```

Any `INCOMPLETE:` line = this bug. Also telling: the broken kernel's
initramfs in `/boot` is tens of MB smaller than its siblings.

## The fix

From the old (working) kernel:

```bash
sudo apt update
sudo apt install linux-generic linux-headers-generic   # completes the new kernel (modules-extra!)
sudo apt install nvidia-driver-595-open nvidia-prime   # your driver version here
sudo update-initramfs -u -k all
sudo reboot
```

You land in the new kernel with input, radios **and** NVIDIA all working.

## The two rules that end the loop

1. **After any NVIDIA driver install, run `sudo apt install linux-generic
   linux-headers-generic` before rebooting.** If apt dragged in a new kernel,
   this completes it.
2. **Never `apt purge nvidia-*` as a recovery step.** The old kernel's
   "missing" driver just means the per-kernel module package isn't installed
   for it — purging removes the driver everywhere and deepens the hole.

## Optional: a guard so it can't recur silently

[`check-complete-kernels.sh`](check-complete-kernels.sh) prints a loud warning
whenever any installed kernel lacks `modules-extra`. Install it as an apt
hook and you'll be told at the moment the trap is set, not at reboot:

```bash
sudo cp check-complete-kernels.sh /usr/local/sbin/
sudo chmod +x /usr/local/sbin/check-complete-kernels.sh
echo 'DPkg::Post-Invoke { "/usr/local/sbin/check-complete-kernels.sh || true"; };' \
 | sudo tee /etc/apt/apt.conf.d/99-complete-kernels
```

---

*Diagnosed in the wild on an ASUS ROG laptop (RTX 4090, Ubuntu 24.04,
nvidia-driver-595-open) after the loop had struck across multiple kernel
releases. Written up so the next person searches their symptoms and finds an
answer instead of a purge command.*
