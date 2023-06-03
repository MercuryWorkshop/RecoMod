<div align="center">
    <h1>RecoMod</h1>
</div>

## What is this?
RecoMod is a script that will install a custom utility toolkit into a standard chromeOS recovery image.
This is essentially the spiritual successor to MrChromebox's fixflags images and is useful for getting past certain bricks, and performing debugging and utility actions on the chromebook, especially if you have RW_LEGACY bios installed. If you find yourself in a situation where you either can't boot chromeos from the internal storage or it would be annoying to, this can help you perform whatever actions you need to.

This project utilizes MrChromebox's RW_LEGACY and UEFI roms. For more information on the fun little details, check out the [writeup](https://coolelectronics.me/blog/breaking-cros-4)
## What can it do?
Making sure you're in devmode, when you plug in a recovery image patched with this tool it will boot into a utility menu

![image](https://github.com/MercuryWorkshop/RecoMod/assets/58010778/97ed0e69-b756-4b0a-90bb-38bc29b4b69f)

You can enter a bash shell and mess around, edit gbb flags, mess with the firmware config, do flashrom stuff, etc. The toolkit is easy to modify so more tools can be added at your liking.

Note that only x86_64 chromebooks are supported, with arm images needing the --minimal flag to work (this will not show a GUI, just perform certain actions like fixing the gbb flags)
## How do I use it?
The build script must be ran on linux. If you don't have linux, a VM can be used. WSL may work but is not officially supported. Crostini may work and it might not. Doing it in chromeos's crosh shell may work or may not.

First, grab the script itself.
```
git clone https://github.com/MercuryWorkshop/RecoMod
cd RecoMod
chmod +x recomod.sh
```
Now, you need the actual recovery image itself. Head on over to either [chrome100.dev](https://chrome100.dev/) or [chromiumdash-serving-builds](https://chromiumdash.appspot.com/serving-builds?deviceCategory=ChromeOS) to get an image for your board.
If using the former, a R107 image is known to be most stable.

Unzip the file you downloaded and now actually build the image.
```
./recomod.sh -i /path/to/recovery/image.bin #[optional flags]
```
(run ./recomod.sh --help for a list of all build flags)

The script modifies the image in place, and once that's done, you can flash it with any USB flashing tool and plug it in your chromebook/box the same way you would a normal recovery image.


note for wsl users: ensure the image you want to modify is in your wsl (not windows) filesystem. WSL is not guarenteed to work

additional tip: you're going to have to wait 5 minutes before the menu loads due to a ChromeOS restriction, **UNLESS** you have rootfs verification disabled on both partitions, so do that before using it.
