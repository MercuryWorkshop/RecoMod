<div align="center">
    <h1>RecoMod</h1>
</div>

## What is this?
RecoMod is a script that will install a custom utility toolkit into a standard chromeOS recovery image.

For more information, check out the [writeup](https://coolelectronics.me/blog/breaking-cros-4)
## Why would I use this?
This is useful for easily getting past certain chromebook bricks and debugging various issues that can arise when using chromebooks in certain ways. It's a nice tool to have around when you're tinkering
## How do I use it?
The build script must be ran on linux. If you don't have linux, a VM can be used. WSL may work but is not officially supported.

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
