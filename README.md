# mpv-anime

From trying to integrate Anime 4K to a collection of useful scripts.

![preview](preview.png?raw=true)

# What include?
1. <b>Anime 4K</b> - improves the quality of anime in real-time. (thx [bloc97](https://github.com/bloc97/Anime4K))
2. <b>ModernZ</b> - amazing UI. (thx [Samillion](https://github.com/Samillion/ModernZ))
3. <b>Thumbfast</b> - High-performance on-the-fly thumbnailer script. (thx [po5](https://github.com/po5/thumbfast))
4. <b>mpv-install</b> - When integrated into a system, allows only one mpv window to be used if you open any file. (thx [SilverEzhik](https://github.com/SilverEzhik/mpv-install))

# How to install?
1. Download latest the [files in this repository](https://github.com/Donate684/mpv-anime/archive/refs/heads/main.zip) and extract mpv folder anywhere.
2. Download [latest mpv build](https://sourceforge.net/projects/mpv-player-windows/files/)<br/>
Tip. 64bit-v3 require CPU circa 2015: [Intel Haswell](https://en.wikipedia.org/wiki/Haswell_(microarchitecture)) or [AMD Excavator](https://en.wikipedia.org/wiki/Excavator_(microarchitecture)) download builds without v3 if you have an older processor.
3. Extract archive in mpv folder.
4. If u want integration with OS run with admin mpv-single-instance-install.bat or mpv-install.bat in mpv\installer

# Files?
| Plugin | Files |
| :-: | :-: |
| Anime 4K | mpv\portable_config\shaders\*.*, mpv\portable_config\mpv.conf #1-6, mpv\portable_config\input.conf #1-9|
| ModernZ UI | mpv\portable_config\scripts\modernz.lua, mpv\portable_config\script-opts\modernz.conf |
| Thumbfast | mpv\portable_config\scripts\thumbfast.lua, mpv\portable_config\script-opts\thumbfast.conf |
| mpv-install | mpv\installer\mpv-single-instance-install.bat, mpv\installer\mpv-single-instance-uninstall.bat, mpv\umpvw.exe |
