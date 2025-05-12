# mpv-anime

A curated collection of useful scripts and configurations for the mpv media player, optimized for a modern anime viewing experience on Windows.

![preview](preview.png?raw=true)

## Features

*   **Modern UI:** Includes the sleek and customizable **ModernZ** interface.
*   **Fast Preview Thumbnails:** Integrates **Thumbfast** for high-performance seekbar previews.
*   **Single Instance & OS Integration:** Uses **mpv-install** scripts to ensure only one mpv window opens and integrates with Windows file associations (optional).
*   **Recursive External File Search:** **Fuzzydir** automatically searches the current directory and subdirectories for matching external audio tracks and subtitles.
*   **Seamless Playlist Loading:** **Autoload** pre-loads adjacent files in the playlist for smoother transitions.
*   **Portable Configuration:** All settings and scripts are contained within the `portable_config` directory, keeping your main mpv configuration clean if you have one.

## Requirements

*   **Operating System:** Windows (due to the included installer scripts). The core scripts (ModernZ, Thumbfast, Fuzzydir, Autoload) may work on other OSes, but the installation process provided is Windows-specific.
*   **mpv Player:** A recent build of mpv for Windows.

## Installation

1.  **Download this Repository:** Download the latest ZIP archive of this repository by clicking [here](https://github.com/Donate684/mpv-anime/archive/refs/heads/main.zip) and extract the `mpv` folder somewhere on your computer.
2.  **Download mpv Player:** Download the [latest mpv build from sourceforge](https://sourceforge.net/projects/mpv-player-windows/files/).
    *   **Tip:** Builds marked `64bit-v3` require a relatively modern CPU (circa 2015+, like Intel Haswell or AMD Excavator). If you have an older processor, download a build *without* `v3` in its name (e.g., `x86_64`).
3.  **Combine Files:** Extract the downloaded mpv player archive. Copy the contents (including `mpv.exe`, `mpv.com`, `installer/mpv.ico`, etc.) directly into the `mpv` folder you extracted in Step 1. The `mpv.exe` file should be at the root of the `mpv` folder alongside the `portable_config` and `installer` directories.
4.  **(Optional) OS Integration:** If you want mpv to open files in a single window and associate video files with this setup, navigate into the `mpv\installer` directory, right-click on `install.bat` and select "Run as administrator".

## Included Components

| Component      | Files                                                                                                  | Original Author/Source                                                                |
| :------------- | :----------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------ |
| ModernZ UI     | `portable_config/scripts/modernz.lua`, `portable_config/script-opts/modernz.conf`                    | [Samillion/ModernZ](https://github.com/Samillion/ModernZ)                             |
| Thumbfast      | `portable_config/scripts/thumbfast.lua`, `portable_config/script-opts/thumbfast.conf`                  | [po5/thumbfast](https://github.com/po5/thumbfast)                                     |
| mpv-install    | `installer/install.bat`, `installer/install.ps1`, `installer/mpv-icon.ico`, `umpvw.exe`                  | [Donate684/mpv-install-ps](https://github.com/Donate684/mpv-install-ps)               |
| Fuzzydir       | `portable_config/scripts/fuzzydir.lua` (Configuration in `portable_config/mpv.conf`)                   | [sibwaf/mpv-scripts](https://github.com/sibwaf/mpv-scripts/blob/master/fuzzydir.lua)   |
| Autoload       | `portable_config/scripts/autoload.lua`, `portable_config/script-opts/autoload.conf`                    | [mpv-player/mpv Tools](https://github.com/mpv-player/mpv/blob/master/TOOLS/lua/autoload.lua) |

*Note: Fuzzydir settings are located within `portable_config/mpv.conf` under the section `# --- External Audio/Subtitle Loading (for fuzzydir.lua) ---`.*

## Configuration

*   Core mpv settings can be adjusted in `mpv\portable_config\mpv.conf`.
*   Script-specific options are located in `mpv\portable_config\script-opts\`.

## Acknowledgements

Special thanks to the creators of the included scripts:

*   [Samillion](https://github.com/Samillion) for ModernZ
*   [po5](https://github.com/po5) for Thumbfast
*   [sibwaf](https://github.com/sibwaf) for Fuzzydir
*   The [mpv developers](https://github.com/mpv-player/mpv) for the Autoload script and the player itself.
