<div align="center">
    <h1>RecoMod</h1>
</div>

## What is this?
RecoMod is a script that will install a custom utility toolkit into a standard chromeOS recovery image.
This is essentially the spiritual successor to MrChromebox's fixflags images and is useful for getting past certain bricks, and performing debugging and utility actions on the chromebook, especially if you have RW_LEGACY bios installed.
For more information, check out the [writeup](https://coolelectronics.me/blog/breaking-cros-4)
## What can it do?
[insert image 1]
[insert image 2]

Note that only x86_64 chromebooks are supported, with arm images needing the --minimal flag to work (this will not show a GUI, just perform certain actions like fixing the gbb flags)
## How do I use it?
The build script must be ran on linux. If you don't have linux, a VM can be used. WSL may work but is not officially supported. Crostini probably won't work. Crosh

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


note for wsl users: ensure the image you want to modify is in your wsl (not windows) filesystem. WSL is not guarenteed to work
