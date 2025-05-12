# mpv-anime

Collection of useful scripts for mpv.

![preview](preview.png?raw=true)

# What include?
1. <b>ModernZ</b> - amazing UI. (thx [Samillion](https://github.com/Samillion/ModernZ))
2. <b>Thumbfast</b> - High-performance on-the-fly thumbnailer script. (thx [po5](https://github.com/po5/thumbfast))
3. <b>mpv-install</b> - When integrated into a system, allows only one mpv window to be used if you open any file. (thx [Donate684](https://github.com/Donate684/mpv-install-ps))
4. <b>Fuzzydir</b> - Search external audio/subtitles in the file's directory and all its subdirectories recursively (thx [sibwaf](https://github.com/sibwaf/mpv-scripts/blob/master/fuzzydir.lua))
5. <b>Autoload</b> - Script automatically loads playlist entries before and after thecurrently played file (thx [mpv dev](https://github.com/mpv-player/mpv/blob/master/TOOLS/lua/autoload.lua))

# How to install?
1. Download latest the [files in this repository](https://github.com/Donate684/mpv-anime/archive/refs/heads/main.zip) and extract mpv folder anywhere.
2. Download [latest mpv build](https://sourceforge.net/projects/mpv-player-windows/files/)<br/>
Tip. 64bit-v3 require CPU circa 2015: [Intel Haswell](https://en.wikipedia.org/wiki/Haswell_(microarchitecture)) or [AMD Excavator](https://en.wikipedia.org/wiki/Excavator_(microarchitecture)) download builds without v3 if you have an older processor.
3. Extract archive in mpv folder.
4. If u want integration with OS run install.bat in mpv\installer

# Files?
| Plugin | Files |
| :-: | :-: |
| ModernZ UI | mpv\portable_config\scripts\modernz.lua, mpv\portable_config\script-opts\modernz.conf |
| Thumbfast | mpv\portable_config\scripts\thumbfast.lua, mpv\portable_config\script-opts\thumbfast.conf |
| mpv-install | mpv\installer\mpv-single-instance-install.bat, mpv\installer\mpv-single-instance-uninstall.bat, mpv\umpvw.exe |
| Fuzzydir | mpv\portable_config\scripts\modernz.lua\fuzzydir.lua, mpv\portable_config\mpv.conf search # --- External Audio/Subtitle Loading (for fuzzydir.lua) --- |
| Autoload | mpv\portable_config\scripts\autoload.lua, mpv\portable_config\script-opts\autoload.conf |
