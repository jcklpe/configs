# Configs

This repo is a collection of configs, dotfiles, code snippets, and scripts. This folder is then synced across all the different machines I use through a self hosted instance of the open-source personal cloud platform [[NextCloud]](https://nextcloud.com/).

I work in windows, mac, and linux environments. My goal is to create something that's extremely modular and contained.

I use [[zsh]](https://www.zsh.org/) as my CLI shell. _(mac, windows, linux compatible)_

I use [ueli](https://github.com/oliverschwendener/ueli) as my launcher. _(mac, windows compatible)_

I use [[hyper]](https://hyper.is/) as my terminal emulator. _(mac, windows, linux compatible)_

I use [[vscode]](https://code.visualstudio.com/) as my code editor. _(mac, windows, linux compatible)_

As you can see almost all of these programs work on all three operating systems. This is on purpose. I am trying to make it so that no matter what OS I'm on, my basic experience remains the same.

I want to transcend operating systems! :alien:

Someday I'd like to get the kinks so worked out that I can simply pull down this git repo on a machine, run a script and have everything basically fold out like George Jetson's briefcase car.

But until then this it's a work in progress, while I better figure out my pipeline.

##TODO:

- [ ] integrate vscode-enzo extension as submodule



Short term fix:

- [ ] fix vscode-enzo theme errors when used as an extension
- [ ] extend theme build process to produce custom css/js injection files
- [ ] make css/js injection files available via github cdn
- [ ] extend theme build process to produce a neutral settings.json file for easy symlinking (this will basically mean that the settings file produced for symlinking will not have theme file stuff in it, but will have commented out code for examples in case I on the file need to make some changes and want to see the results immediately)

Long term fix:

- [ ] rip out highlighter extension and integrate into my extension directly
- [ ] rip out css/js injection extension and integrate into my extension directly
- [ ] extend theme build process to produce a neutral settings.json file for easy symlinking (this will basically mean that the settings file produced for symlinking will not have theme file stuff in it, but will have commented out code for examples in case I on the file need to make some changes and want to see the results immediately)