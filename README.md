# mpv-anime

From trying to integrate Anime 4K to a collection of useful scripts.

![preview](preview.png?raw=true)

# What include?
1. <b>Anime 4K</b> - improves the quality of anime in real-time. (thx [bloc97](https://github.com/bloc97/Anime4K))
2. <b>Modernf</b> - amazing youtube like UI. (thx [FinnRaze mpv-osc-modern-f](https://github.com/FinnRaze/mpv-osc-modern-f/tree/main) and ideas/some code [eatsu youtube-ui](https://github.com/eatsu/mpv-osc-youtube-ui))
3. <b>Russian Layout Fix</b> - now there are no problems with hotkeys on the russian layout. (thx [Zenwar](https://github.com/zenwarr/mpv-config/blob/master/scripts/russian-layout-bindings.lua))
4. <b>Thumbfast</b> - High-performance on-the-fly thumbnailer script. (thx [po5](https://github.com/po5/thumbfast))
5. <b>Autoload</b> - Allows you to switch between files in the same folder. (thx [mpv dev](https://github.com/mpv-player/mpv/blob/master/TOOLS/lua/autoload.lua))
6. <b>SmartCopyPaste</b> - Allows you to use a simple ctrl+c to insert into the player a link from YouTube and not only. (thx [Eisa01](https://github.com/Eisa01/mpv-scripts))
7. <b>Discord RPC</b> - Allows others to see the title of what you are currently watching on Discord. (thx [noaione](https://github.com/noaione/mpv-discordRPC))
8. <b>mpv-install</b> - When integrated into a system, allows only one mpv window to be used if you open any file. (thx [SilverEzhik](https://github.com/SilverEzhik/mpv-install))

# How to install?
1. Download latest the [files in this repository](https://github.com/Donate684/mpv-anime/archive/refs/heads/main.zip) and extract anywhere.
2. Download [latest mpv build](https://sourceforge.net/projects/mpv-player-windows/files/)<br/>
Tip. 64bit-v3 require CPU circa 2015: [Intel Haswell](https://en.wikipedia.org/wiki/Haswell_(microarchitecture)) or [AMD Excavator](https://en.wikipedia.org/wiki/Excavator_(microarchitecture)) download builds without v3 if you have an older processor.
3. Extract archive in mpv folder.
4. If u want integration with OS run with admin mpv-install.bat in mpv folder (not in mpv\installer)
5. If u want youtube support run updater.bat

# Files?
| Plugin | Files |
| :-: | :-: |
| Anime 4K | mpv\portable_config\shaders\*.*, mpv\portable_config\mpv.conf #1-6, mpv\portable_config\input.conf #1-9|
| Modernf UI | mpv\portable_config\scripts\modernf.lua, mpv\portable_config\script-opts\modernf.conf |
| Russian Layout Fix | mpv\portable_config\scripts\russian-layout-bindings.lua |
| Thumbfast | mpv\portable_config\scripts\thumbfast.lua, mpv\portable_config\script-opts\thumbfast.conf |
| Autoload | mpv\portable_config\scripts\autoload.lua |
| SmartCopyPaste | mpv\portable_config\scripts\SmartCopyPaste.lua, mpv\portable_config\script-opts\SmartCopyPaste.conf |
| Discord RPC | mpv\portable_config\scripts\mpv-drpc.lua, mpv\discord-rpc.dll |
| mpv-install | mpv\mpv-document.ico, mpv\mpv-install.bat, mpv\mpv-uninstall.bat, mpv\umpvw.exe |
