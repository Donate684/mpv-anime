"""
mpv Installer — CustomTkinter GUI
Replicates the functionality of mpv-install.bat with a modern UI.
Requires: customtkinter
Run as Administrator on Windows Vista+.
pyinstaller --onefile --windowed --uac-admin --icon="mpv-icon.ico" mpv_installer.py
"""

import os
import sys
import locale
import platform
import subprocess
import ctypes
import winreg
import threading
from pathlib import Path

try:
    import customtkinter as ctk
except ImportError:
    subprocess.check_call([sys.executable, "-m", "pip", "install", "customtkinter"])
    import customtkinter as ctk


# ─── Localization ─────────────────────────────────────────────────────────────

STRINGS = {
    "ru": {
        "title":                "mpv Installer",
        "subtitle":             "Регистрация ассоциаций файлов для mpv",
        "install":              "Установить",
        "reinstall":            "Переустановить",
        "uninstall":            "Удалить",
        "advanced":             "Дополнительно",
        "browse":               "Обзор",
        "mpv_label":            "mpv.exe:",
        "icon_label":           "Иконка:",
        "args_label":           "Аргументы:",
        "args_hint":            "дополнительные аргументы (необязательно)",
        "browse_mpv_title":     "Выбрать mpv.exe",
        "browse_icon_title":    "Выбрать иконку",
        "status_installed":     "✅ mpv зарегистрирован: {path}",
        "status_not_installed": "❌ mpv не зарегистрирован в системе",
        "err_mpv_missing":      "❌ mpv.exe не найден. Укажите путь в разделе «Дополнительно».",
        "err_icon_missing":     "❌ mpv-icon.ico не найден. Укажите путь в разделе «Дополнительно».",
        "err_vista":            "❌ Поддерживается только Windows Vista и новее.",
        "busy_installing":      "Установка...",
        "busy_uninstalling":    "Удаление...",
        "err_generic":          "\n❌ Ошибка: {err}",
        # install log
        "log_app_paths":        "Регистрация App Paths...",
        "log_applications":     "Регистрация Applications...",
        "log_open_with":        "Добавление в «Открыть с помощью»...",
        "log_dvd":              "Регистрация DVD AutoPlay...",
        "log_bluray":           "Регистрация Blu-ray AutoPlay...",
        "log_capabilities":     "Регистрация Capabilities...",
        "log_default_progs":    "Регистрация Default Programs...",
        "log_long_paths":       "Включение длинных путей...",
        "log_shortcut":         "Создание ярлыка в меню «Пуск»...",
        "warn_shortcut":        "⚠ Ярлык не создан: {err}",
        "done_install":         "✅ Установка завершена!",
        # uninstall log
        "u_app_paths":          "Удаление App Paths...",
        "u_applications":       "Удаление Applications...",
        "u_open_with":          "Удаление из «Открыть с помощью»...",
        "u_autoplay":           "Удаление DVD / Blu-ray AutoPlay...",
        "u_capabilities":       "Удаление Capabilities...",
        "u_removing":           "Удаление {ext}",
        "u_registered_apps":    "Удаление из RegisteredApplications...",
        "u_shortcut":           "Удаление ярлыка из меню «Пуск»...",
        "warn_u_shortcut":      "⚠ Не удалось удалить ярлык: {err}",
        "done_uninstall":       "✅ Удаление завершено!",
    },
    "en": {
        "title":                "mpv Installer",
        "subtitle":             "Register file associations for mpv",
        "install":              "Install",
        "reinstall":            "Reinstall",
        "uninstall":            "Uninstall",
        "advanced":             "Advanced",
        "browse":               "Browse",
        "mpv_label":            "mpv.exe:",
        "icon_label":           "Icon:",
        "args_label":           "Arguments:",
        "args_hint":            "extra arguments (optional)",
        "browse_mpv_title":     "Select mpv.exe",
        "browse_icon_title":    "Select icon",
        "status_installed":     "✅ mpv is registered: {path}",
        "status_not_installed": "❌ mpv is not registered in the system",
        "err_mpv_missing":      "❌ mpv.exe not found. Set path in the Advanced section.",
        "err_icon_missing":     "❌ mpv-icon.ico not found. Set path in the Advanced section.",
        "err_vista":            "❌ Only Windows Vista and later are supported.",
        "busy_installing":      "Installing...",
        "busy_uninstalling":    "Uninstalling...",
        "err_generic":          "\n❌ Error: {err}",
        # install log
        "log_app_paths":        "Registering App Paths...",
        "log_applications":     "Registering Applications...",
        "log_open_with":        "Adding to 'Open with'...",
        "log_dvd":              "Registering DVD AutoPlay...",
        "log_bluray":           "Registering Blu-ray AutoPlay...",
        "log_capabilities":     "Registering Capabilities...",
        "log_default_progs":    "Registering Default Programs...",
        "log_long_paths":       "Enabling long paths...",
        "log_shortcut":         "Creating Start Menu shortcut...",
        "warn_shortcut":        "⚠ Shortcut not created: {err}",
        "done_install":         "✅ Installation complete!",
        # uninstall log
        "u_app_paths":          "Removing App Paths...",
        "u_applications":       "Removing Applications...",
        "u_open_with":          "Removing from 'Open with'...",
        "u_autoplay":           "Removing DVD / Blu-ray AutoPlay...",
        "u_capabilities":       "Removing Capabilities...",
        "u_removing":           "Removing {ext}",
        "u_registered_apps":    "Removing from RegisteredApplications...",
        "u_shortcut":           "Removing Start Menu shortcut...",
        "warn_u_shortcut":      "⚠ Could not remove shortcut: {err}",
        "done_uninstall":       "✅ Uninstall complete!",
    },
}


def _detect_language() -> str:
    """Return 'ru' if the Windows UI language is Russian, else 'en'."""
    try:
        lang_id = ctypes.windll.kernel32.GetUserDefaultUILanguage()
        # Primary language ID is the low 10 bits; Russian = 0x19
        if (lang_id & 0x3FF) == 0x19:
            return "ru"
    except Exception:
        pass
    # Fallback: check locale
    loc = locale.getdefaultlocale()[0] or ""
    if loc.startswith("ru"):
        return "ru"
    return "en"


_LANG = _detect_language()
S = STRINGS[_LANG]


def t(key: str, **kwargs) -> str:
    """Get a translated string, with optional format kwargs."""
    return S.get(key, key).format(**kwargs) if kwargs else S.get(key, key)


# ─── Constants ────────────────────────────────────────────────────────────────

HKLM = winreg.HKEY_LOCAL_MACHINE

FILE_TYPES = [
    ("audio/ac3",                        "audio", "AC-3 Audio",                 [".ac3", ".a52"]),
    ("audio/eac3",                       "audio", "E-AC-3 Audio",               [".eac3"]),
    ("audio/vnd.dolby.mlp",              "audio", "MLP Audio",                  [".mlp"]),
    ("audio/vnd.dts",                    "audio", "DTS Audio",                  [".dts"]),
    ("audio/vnd.dts.hd",                 "audio", "DTS-HD Audio",               [".dts-hd", ".dtshd"]),
    ("",                                 "audio", "TrueHD Audio",               [".true-hd", ".thd", ".truehd", ".thd+ac3"]),
    ("",                                 "audio", "True Audio",                 [".tta"]),
    ("",                                 "audio", "PCM Audio",                  [".pcm"]),
    ("audio/wav",                        "audio", "Wave Audio",                 [".wav"]),
    ("audio/aiff",                       "audio", "AIFF Audio",                 [".aiff", ".aif", ".aifc"]),
    ("audio/amr",                        "audio", "AMR Audio",                  [".amr"]),
    ("audio/amr-wb",                     "audio", "AMR-WB Audio",              [".awb"]),
    ("audio/basic",                      "audio", "AU Audio",                   [".au", ".snd"]),
    ("",                                 "audio", "Linear PCM Audio",           [".lpcm"]),
    ("",                                 "video", "Raw YUV Video",              [".yuv"]),
    ("",                                 "video", "YUV4MPEG2 Video",            [".y4m"]),
    ("audio/x-ape",                      "audio", "Monkey's Audio",             [".ape"]),
    ("audio/x-wavpack",                  "audio", "WavPack Audio",              [".wv"]),
    ("audio/x-shorten",                  "audio", "Shorten Audio",              [".shn"]),
    ("video/vnd.dlna.mpeg-tts",          "video", "MPEG-2 Transport Stream",    [".m2ts", ".m2t", ".mts", ".mtv", ".ts", ".tsv", ".tsa", ".tts", ".trp"]),
    ("audio/vnd.dlna.adts",              "audio", "ADTS Audio",                 [".adts", ".adt"]),
    ("audio/mpeg",                       "audio", "MPEG Audio",                 [".mpa", ".m1a", ".m2a", ".mp1", ".mp2"]),
    ("audio/mpeg",                       "audio", "MP3 Audio",                  [".mp3"]),
    ("video/mpeg",                       "video", "MPEG Video",                 [".mpeg", ".mpg", ".mpe", ".mpeg2", ".m1v", ".m2v", ".mp2v", ".mpv", ".mpv2", ".mod", ".tod"]),
    ("video/dvd",                        "video", "Video Object",               [".vob", ".vro"]),
    ("",                                 "video", "Enhanced VOB",               [".evob", ".evo"]),
    ("video/mp4",                        "video", "MPEG-4 Video",               [".mpeg4", ".m4v", ".mp4", ".mp4v", ".mpg4"]),
    ("audio/mp4",                        "audio", "MPEG-4 Audio",               [".m4a"]),
    ("audio/aac",                        "audio", "Raw AAC Audio",              [".aac"]),
    ("",                                 "video", "Raw H.264/AVC Video",        [".h264", ".avc", ".x264", ".264"]),
    ("",                                 "video", "Raw H.265/HEVC Video",       [".hevc", ".h265", ".x265", ".265"]),
    ("audio/flac",                       "audio", "FLAC Audio",                 [".flac"]),
    ("audio/ogg",                        "audio", "Ogg Audio",                  [".oga", ".ogg"]),
    ("audio/ogg",                        "audio", "Opus Audio",                 [".opus"]),
    ("audio/ogg",                        "audio", "Speex Audio",                [".spx"]),
    ("video/ogg",                        "video", "Ogg Video",                  [".ogv", ".ogm"]),
    ("application/ogg",                  "video", "Ogg Video",                  [".ogx"]),
    ("video/x-matroska",                 "video", "Matroska Video",             [".mkv"]),
    ("video/x-matroska",                 "video", "Matroska 3D Video",          [".mk3d"]),
    ("audio/x-matroska",                 "audio", "Matroska Audio",             [".mka"]),
    ("video/webm",                       "video", "WebM Video",                 [".webm"]),
    ("audio/webm",                       "audio", "WebM Audio",                 [".weba"]),
    ("video/avi",                        "video", "Video Clip",                 [".avi", ".vfw"]),
    ("",                                 "video", "DivX Video",                 [".divx"]),
    ("",                                 "video", "3ivx Video",                 [".3iv"]),
    ("",                                 "video", "XVID Video",                 [".xvid"]),
    ("",                                 "video", "NUT Video",                  [".nut"]),
    ("video/flc",                        "video", "FLIC Video",                 [".flic", ".fli", ".flc"]),
    ("",                                 "video", "Nullsoft Streaming Video",   [".nsv"]),
    ("application/gxf",                  "video", "General Exchange Format",    [".gxf"]),
    ("application/mxf",                  "video", "Material Exchange Format",   [".mxf"]),
    ("audio/x-ms-wma",                   "audio", "Windows Media Audio",        [".wma"]),
    ("video/x-ms-wm",                    "video", "Windows Media Video",        [".wm"]),
    ("video/x-ms-wmv",                   "video", "Windows Media Video",        [".wmv"]),
    ("video/x-ms-asf",                   "video", "Windows Media Video",        [".asf"]),
    ("",                                 "video", "Microsoft Recorded TV Show", [".dvr-ms", ".dvr"]),
    ("",                                 "video", "Windows Recorded TV Show",   [".wtv"]),
    ("",                                 "video", "DV Video",                   [".dv", ".hdv"]),
    ("video/x-flv",                      "video", "Flash Video",                [".flv"]),
    ("video/mp4",                        "video", "Flash Video",                [".f4v"]),
    ("audio/mp4",                        "audio", "Flash Audio",                [".f4a"]),
    ("video/quicktime",                  "video", "QuickTime Video",            [".qt", ".mov"]),
    ("video/quicktime",                  "video", "QuickTime HD Video",         [".hdmov"]),
    ("application/vnd.rn-realmedia",     "video", "Real Media Video",           [".rm"]),
    ("application/vnd.rn-realmedia-vbr", "video", "Real Media Video",           [".rmvb"]),
    ("audio/vnd.rn-realaudio",           "audio", "Real Media Audio",           [".ra", ".ram"]),
    ("audio/3gpp",                       "audio", "3GPP Audio",                 [".3ga"]),
    ("audio/3gpp2",                      "audio", "3GPP Audio",                 [".3ga2"]),
    ("video/3gpp",                       "video", "3GPP Video",                 [".3gpp", ".3gp"]),
    ("video/3gpp2",                      "video", "3GPP Video",                 [".3gp2", ".3g2"]),
    ("",                                 "audio", "AY Audio",                   [".ay"]),
    ("",                                 "audio", "GBS Audio",                  [".gbs"]),
    ("",                                 "audio", "GYM Audio",                  [".gym"]),
    ("",                                 "audio", "HES Audio",                  [".hes"]),
    ("",                                 "audio", "KSS Audio",                  [".kss"]),
    ("",                                 "audio", "NSF Audio",                  [".nsf"]),
    ("",                                 "audio", "NSFE Audio",                 [".nsfe"]),
    ("",                                 "audio", "SAP Audio",                  [".sap"]),
    ("",                                 "audio", "SPC Audio",                  [".spc"]),
    ("",                                 "audio", "VGM Audio",                  [".vgm"]),
    ("",                                 "audio", "VGZ Audio",                  [".vgz"]),
    ("audio/x-mpegurl",                  "audio", "M3U Playlist",              [".m3u", ".m3u8"]),
    ("audio/x-scpls",                    "audio", "PLS Playlist",              [".pls"]),
    ("",                                 "audio", "CUE Sheet",                  [".cue"]),
]


# ─── Registry Helpers ─────────────────────────────────────────────────────────

def reg_add(key_path: str, value_name: str = None, data=None,
            reg_type: int = winreg.REG_SZ, hive=HKLM):
    key = winreg.CreateKeyEx(hive, key_path, 0, winreg.KEY_WRITE | winreg.KEY_WOW64_64KEY)
    if value_name is not None or data is not None:
        winreg.SetValueEx(key, value_name, 0, reg_type, data if data is not None else "")
    elif data is not None:
        winreg.SetValueEx(key, "", 0, reg_type, data)
    winreg.CloseKey(key)


def reg_set_default(key_path: str, data: str, hive=HKLM):
    key = winreg.CreateKeyEx(hive, key_path, 0, winreg.KEY_WRITE | winreg.KEY_WOW64_64KEY)
    winreg.SetValueEx(key, "", 0, winreg.REG_SZ, data)
    winreg.CloseKey(key)


def reg_set_if_absent(key_path: str, value_name: str, data: str, hive=HKLM):
    try:
        key = winreg.OpenKeyEx(hive, key_path, 0, winreg.KEY_READ | winreg.KEY_WOW64_64KEY)
        winreg.QueryValueEx(key, value_name)
        winreg.CloseKey(key)
    except (FileNotFoundError, OSError):
        reg_add(key_path, value_name, data, hive=hive)


# ─── Installer Logic ─────────────────────────────────────────────────────────

def is_admin() -> bool:
    try:
        return ctypes.windll.shell32.IsUserAnAdmin() != 0
    except Exception:
        return False


def is_vista_or_later() -> bool:
    ver = platform.version().split(".")
    return int(ver[0]) >= 6


def add_verbs(key_path: str, mpv_path: str, mpv_args: str):
    reg_set_default(f"{key_path}\\shell", "play")
    reg_add(f"{key_path}\\shell\\open", "LegacyDisable", "")
    reg_set_default(f"{key_path}\\shell\\open\\command",
                    f'"{mpv_path}" {mpv_args} -- "%L"')
    reg_set_default(f"{key_path}\\shell\\play", "&Play")
    reg_set_default(f"{key_path}\\shell\\play\\command",
                    f'"{mpv_path}" {mpv_args} -- "%L"')


def add_progid(classes_root: str, prog_id: str, friendly_name: str,
               icon_path: str, mpv_path: str, mpv_args: str):
    pid_key = f"{classes_root}\\{prog_id}"
    reg_set_default(pid_key, friendly_name)
    reg_add(pid_key, "EditFlags", 65536, winreg.REG_DWORD)
    reg_add(pid_key, "FriendlyTypeName", friendly_name)
    reg_set_default(f"{pid_key}\\DefaultIcon", icon_path)
    add_verbs(pid_key, mpv_path, mpv_args)


def update_extension(classes_root: str, supported_types_key: str,
                     file_assoc_key: str, extension: str, prog_id: str,
                     mime_type: str, perceived_type: str):
    ext_key = f"{classes_root}\\{extension}"
    if mime_type:
        reg_set_if_absent(ext_key, "Content Type", mime_type)
    if perceived_type:
        reg_set_if_absent(ext_key, "PerceivedType", perceived_type)
    reg_add(f"{ext_key}\\OpenWithProgIds", prog_id, "")
    reg_add(supported_types_key, extension, "")
    reg_add(file_assoc_key, extension, prog_id)


def run_install(mpv_path: str, icon_path: str, mpv_args: str, log_fn):
    classes_root = r"SOFTWARE\Classes"
    app_paths_key = r"SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\mpv.exe"
    app_key = f"{classes_root}\\Applications\\mpv.exe"
    autoplay_key = r"SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers"
    capabilities_key = r"SOFTWARE\Clients\Media\mpv\Capabilities"
    supported_types_key = f"{app_key}\\SupportedTypes"
    file_assoc_key = f"{capabilities_key}\\FileAssociations"

    log_fn(t("log_app_paths"))
    reg_set_default(app_paths_key, mpv_path)
    reg_add(app_paths_key, "UseUrl", 1, winreg.REG_DWORD)

    log_fn(t("log_applications"))
    reg_add(app_key, "FriendlyAppName", "mpv")
    add_verbs(app_key, mpv_path, mpv_args)

    log_fn(t("log_open_with"))
    reg_set_default(f"{classes_root}\\SystemFileAssociations\\video\\OpenWithList\\mpv.exe", "")
    reg_set_default(f"{classes_root}\\SystemFileAssociations\\audio\\OpenWithList\\mpv.exe", "")

    log_fn(t("log_dvd"))
    reg_set_default(f"{classes_root}\\io.mpv.dvd\\shell\\play", "&Play")
    reg_set_default(f"{classes_root}\\io.mpv.dvd\\shell\\play\\command",
                    f'"{mpv_path}" {mpv_args} dvd:// --dvd-device="%L"')
    reg_add(f"{autoplay_key}\\Handlers\\MpvPlayDVDMovieOnArrival", "Action", "Play DVD movie")
    reg_add(f"{autoplay_key}\\Handlers\\MpvPlayDVDMovieOnArrival", "DefaultIcon", f"{mpv_path},0")
    reg_add(f"{autoplay_key}\\Handlers\\MpvPlayDVDMovieOnArrival", "InvokeProgID", "io.mpv.dvd")
    reg_add(f"{autoplay_key}\\Handlers\\MpvPlayDVDMovieOnArrival", "InvokeVerb", "play")
    reg_add(f"{autoplay_key}\\Handlers\\MpvPlayDVDMovieOnArrival", "Provider", "mpv")
    reg_add(f"{autoplay_key}\\EventHandlers\\PlayDVDMovieOnArrival", "MpvPlayDVDMovieOnArrival", "")

    log_fn(t("log_bluray"))
    reg_set_default(f"{classes_root}\\io.mpv.bluray\\shell\\play", "&Play")
    reg_set_default(f"{classes_root}\\io.mpv.bluray\\shell\\play\\command",
                    f'"{mpv_path}" {mpv_args} bd:// --bluray-device="%L"')
    reg_add(f"{autoplay_key}\\Handlers\\MpvPlayBluRayOnArrival", "Action", "Play Blu-ray movie")
    reg_add(f"{autoplay_key}\\Handlers\\MpvPlayBluRayOnArrival", "DefaultIcon", f"{mpv_path},0")
    reg_add(f"{autoplay_key}\\Handlers\\MpvPlayBluRayOnArrival", "InvokeProgID", "io.mpv.bluray")
    reg_add(f"{autoplay_key}\\Handlers\\MpvPlayBluRayOnArrival", "InvokeVerb", "play")
    reg_add(f"{autoplay_key}\\Handlers\\MpvPlayBluRayOnArrival", "Provider", "mpv")
    reg_add(f"{autoplay_key}\\EventHandlers\\PlayBluRayOnArrival", "MpvPlayBluRayOnArrival", "")

    log_fn(t("log_capabilities"))
    reg_add(capabilities_key, "ApplicationName", "mpv")
    reg_add(capabilities_key, "ApplicationDescription", "mpv media player")

    total = len(FILE_TYPES)
    for i, (mime, perceived, friendly, extensions) in enumerate(FILE_TYPES, 1):
        primary = extensions[0]
        log_fn(f"[{i}/{total}] {primary}  —  {friendly}")
        prog_id = f"io.mpv{primary}"
        add_progid(classes_root, prog_id, friendly, icon_path, mpv_path, mpv_args)
        for ext in extensions:
            update_extension(classes_root, supported_types_key, file_assoc_key,
                             ext, prog_id, mime, perceived)

    log_fn(t("log_default_progs"))
    reg_add(r"SOFTWARE\RegisteredApplications", "mpv",
            r"SOFTWARE\Clients\Media\mpv\Capabilities")

    log_fn(t("log_long_paths"))
    reg_add(r"SYSTEM\CurrentControlSet\Control\FileSystem",
            "LongPathsEnabled", 1, winreg.REG_DWORD)

    log_fn(t("log_shortcut"))
    try:
        ps_cmd = (
            f'$s=(New-Object -COM WScript.Shell).CreateShortcut('
            f"'{os.environ['ProgramData']}\\Microsoft\\Windows\\Start Menu\\Programs\\mpv.lnk');"
            f"$s.TargetPath='{mpv_path}';$s.Save()"
        )
        subprocess.run(["powershell", "-Command", ps_cmd],
                        capture_output=True, check=True,
                        creationflags=subprocess.CREATE_NO_WINDOW)
    except Exception as e:
        log_fn(t("warn_shortcut", err=e))

    log_fn("")
    log_fn(t("done_install"))


# ─── Detection ────────────────────────────────────────────────────────────────

def check_installed() -> tuple[bool, str]:
    try:
        key = winreg.OpenKeyEx(
            HKLM,
            r"SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\mpv.exe",
            0, winreg.KEY_READ | winreg.KEY_WOW64_64KEY)
        val, _ = winreg.QueryValueEx(key, "")
        winreg.CloseKey(key)
        return True, val
    except OSError:
        return False, ""


# ─── Uninstaller ──────────────────────────────────────────────────────────────

def _delete_key_tree(hive, key_path: str):
    try:
        key = winreg.OpenKeyEx(hive, key_path, 0,
                               winreg.KEY_READ | winreg.KEY_WRITE | winreg.KEY_WOW64_64KEY)
    except OSError:
        return
    subkeys = []
    try:
        i = 0
        while True:
            subkeys.append(winreg.EnumKey(key, i))
            i += 1
    except OSError:
        pass
    winreg.CloseKey(key)
    for sk in subkeys:
        _delete_key_tree(hive, f"{key_path}\\{sk}")
    try:
        winreg.DeleteKeyEx(hive, key_path, winreg.KEY_WOW64_64KEY, 0)
    except OSError:
        pass


def _delete_value_safe(hive, key_path: str, value_name: str):
    try:
        key = winreg.OpenKeyEx(hive, key_path, 0,
                               winreg.KEY_WRITE | winreg.KEY_WOW64_64KEY)
        winreg.DeleteValue(key, value_name)
        winreg.CloseKey(key)
    except OSError:
        pass


def run_uninstall(log_fn):
    classes_root = r"SOFTWARE\Classes"
    autoplay_key = r"SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers"

    log_fn(t("u_app_paths"))
    _delete_key_tree(HKLM, r"SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\mpv.exe")

    log_fn(t("u_applications"))
    _delete_key_tree(HKLM, f"{classes_root}\\Applications\\mpv.exe")

    log_fn(t("u_open_with"))
    _delete_key_tree(HKLM, f"{classes_root}\\SystemFileAssociations\\video\\OpenWithList\\mpv.exe")
    _delete_key_tree(HKLM, f"{classes_root}\\SystemFileAssociations\\audio\\OpenWithList\\mpv.exe")

    log_fn(t("u_autoplay"))
    _delete_key_tree(HKLM, f"{classes_root}\\io.mpv.dvd")
    _delete_key_tree(HKLM, f"{classes_root}\\io.mpv.bluray")
    _delete_key_tree(HKLM, f"{autoplay_key}\\Handlers\\MpvPlayDVDMovieOnArrival")
    _delete_key_tree(HKLM, f"{autoplay_key}\\Handlers\\MpvPlayBluRayOnArrival")
    _delete_value_safe(HKLM, f"{autoplay_key}\\EventHandlers\\PlayDVDMovieOnArrival",
                       "MpvPlayDVDMovieOnArrival")
    _delete_value_safe(HKLM, f"{autoplay_key}\\EventHandlers\\PlayBluRayOnArrival",
                       "MpvPlayBluRayOnArrival")

    log_fn(t("u_capabilities"))
    _delete_key_tree(HKLM, r"SOFTWARE\Clients\Media\mpv")

    total = len(FILE_TYPES)
    for i, (mime, perceived, friendly, extensions) in enumerate(FILE_TYPES, 1):
        primary = extensions[0]
        log_fn(f"[{i}/{total}] {t('u_removing', ext=primary)}")
        prog_id = f"io.mpv{primary}"
        _delete_key_tree(HKLM, f"{classes_root}\\{prog_id}")
        for ext in extensions:
            _delete_value_safe(HKLM, f"{classes_root}\\{ext}\\OpenWithProgIds", prog_id)

    log_fn(t("u_registered_apps"))
    _delete_value_safe(HKLM, r"SOFTWARE\RegisteredApplications", "mpv")

    log_fn(t("u_shortcut"))
    shortcut = os.path.join(
        os.environ.get("ProgramData", r"C:\ProgramData"),
        r"Microsoft\Windows\Start Menu\Programs\mpv.lnk")
    try:
        if os.path.exists(shortcut):
            os.remove(shortcut)
    except Exception as e:
        log_fn(t("warn_u_shortcut", err=e))

    log_fn("")
    log_fn(t("done_uninstall"))


# ─── GUI ──────────────────────────────────────────────────────────────────────

class MpvInstallerApp(ctk.CTk):
    def __init__(self):
        super().__init__()
        self.title(t("title"))
        self.geometry("680x460")
        self.minsize(550, 380)
        self.resizable(True, True)

        ctk.set_appearance_mode("dark")
        ctk.set_default_color_theme("blue")

        self._build_ui()
        self._auto_detect_paths()
        self._check_status()

    # ── UI ────────────────────────────────────────────────────────────────

    def _build_ui(self):
        ctk.CTkLabel(self, text=t("title"),
                     font=ctk.CTkFont(size=22, weight="bold")).pack(pady=(18, 4))

        ctk.CTkLabel(self, text=t("subtitle"),
                     font=ctk.CTkFont(size=13), text_color="gray").pack(pady=(0, 8))

        self.status_label = ctk.CTkLabel(self, text="", font=ctk.CTkFont(size=13))
        self.status_label.pack(padx=20, pady=(0, 8))

        self.log_box = ctk.CTkTextbox(self, height=200, state="disabled",
                                      font=ctk.CTkFont(family="Consolas", size=12))
        self.log_box.pack(fill="both", expand=True, padx=20, pady=(0, 8))

        btn_frame = ctk.CTkFrame(self, fg_color="transparent")
        btn_frame.pack(fill="x", padx=20, pady=(0, 8))

        self.install_btn = ctk.CTkButton(btn_frame, text=t("install"),
                                         font=ctk.CTkFont(size=14, weight="bold"),
                                         height=40, command=self._on_install)
        self.install_btn.pack(side="left", expand=True, fill="x", padx=(0, 4))

        self.uninstall_btn = ctk.CTkButton(btn_frame, text=t("uninstall"),
                                           font=ctk.CTkFont(size=14, weight="bold"),
                                           height=40, fg_color="#b33",
                                           hover_color="#d44",
                                           command=self._on_uninstall)
        self.uninstall_btn.pack(side="left", expand=True, fill="x", padx=(4, 0))

        # ── Collapsible Advanced ──────────────────────────────────────────
        self._advanced_visible = False

        self.toggle_btn = ctk.CTkButton(self, text=f"▸ {t('advanced')}", width=160,
                                        height=28, fg_color="transparent",
                                        text_color="gray",
                                        hover_color=("gray85", "gray25"),
                                        font=ctk.CTkFont(size=12),
                                        command=self._toggle_advanced)
        self.toggle_btn.pack(pady=(0, 4))

        self.advanced_frame = ctk.CTkFrame(self)

        ctk.CTkLabel(self.advanced_frame, text=t("mpv_label"), anchor="w").grid(
            row=0, column=0, padx=(12, 6), pady=(12, 4), sticky="w")
        self.mpv_entry = ctk.CTkEntry(self.advanced_frame, width=400)
        self.mpv_entry.grid(row=0, column=1, padx=4, pady=(12, 4), sticky="ew")
        ctk.CTkButton(self.advanced_frame, text=t("browse"), width=80,
                       command=self._browse_mpv).grid(
            row=0, column=2, padx=(4, 12), pady=(12, 4))

        ctk.CTkLabel(self.advanced_frame, text=t("icon_label"), anchor="w").grid(
            row=1, column=0, padx=(12, 6), pady=(4, 4), sticky="w")
        self.icon_entry = ctk.CTkEntry(self.advanced_frame, width=400)
        self.icon_entry.grid(row=1, column=1, padx=4, pady=(4, 4), sticky="ew")
        ctk.CTkButton(self.advanced_frame, text=t("browse"), width=80,
                       command=self._browse_icon).grid(
            row=1, column=2, padx=(4, 12), pady=(4, 4))

        ctk.CTkLabel(self.advanced_frame, text=t("args_label"), anchor="w").grid(
            row=2, column=0, padx=(12, 6), pady=(4, 12), sticky="w")
        self.args_entry = ctk.CTkEntry(self.advanced_frame, width=400,
                                       placeholder_text=t("args_hint"))
        self.args_entry.grid(row=2, column=1, columnspan=2, padx=4, pady=(4, 12), sticky="ew")

        self.advanced_frame.columnconfigure(1, weight=1)

    def _toggle_advanced(self):
        if self._advanced_visible:
            self.advanced_frame.pack_forget()
            self.toggle_btn.configure(text=f"▸ {t('advanced')}")
            self._advanced_visible = False
        else:
            self.advanced_frame.pack(fill="x", padx=20, pady=(0, 12),
                                     after=self.toggle_btn)
            self.toggle_btn.configure(text=f"▾ {t('advanced')}")
            self._advanced_visible = True

    # ── Path helpers ──────────────────────────────────────────────────────

    def _auto_detect_paths(self):
        if getattr(sys, 'frozen', False):
            script_dir = Path(sys.executable).resolve().parent
        else:
            script_dir = Path(__file__).resolve().parent
        installed, reg_path = check_installed()
        if installed and os.path.isfile(reg_path):
            mpv_candidate = Path(reg_path)
        else:
            mpv_candidate = script_dir / "mpv.exe"
            if not mpv_candidate.exists():
                mpv_candidate = script_dir.parent / "mpv.exe"

        icon_candidate = script_dir / "mpv-icon.ico"
        if not icon_candidate.exists() and mpv_candidate.exists():
            icon_candidate = mpv_candidate.parent / "installer" / "mpv-icon.ico"

        if mpv_candidate.exists():
            self.mpv_entry.insert(0, str(mpv_candidate))
        if icon_candidate.exists():
            self.icon_entry.insert(0, str(icon_candidate))

    def _browse_mpv(self):
        from tkinter import filedialog
        path = filedialog.askopenfilename(
            title=t("browse_mpv_title"),
            filetypes=[("mpv executable", "mpv.exe"), ("All files", "*.*")])
        if path:
            self.mpv_entry.delete(0, "end")
            self.mpv_entry.insert(0, path)

    def _browse_icon(self):
        from tkinter import filedialog
        path = filedialog.askopenfilename(
            title=t("browse_icon_title"),
            filetypes=[("Icon files", "*.ico"), ("All files", "*.*")])
        if path:
            self.icon_entry.delete(0, "end")
            self.icon_entry.insert(0, path)

    # ── Logging ───────────────────────────────────────────────────────────

    def _log(self, msg: str):
        self.log_box.configure(state="normal")
        self.log_box.insert("end", msg + "\n")
        self.log_box.see("end")
        self.log_box.configure(state="disabled")

    # ── Status ────────────────────────────────────────────────────────────

    def _check_status(self):
        installed, reg_path = check_installed()
        if installed:
            self.status_label.configure(
                text=t("status_installed", path=reg_path), text_color="#6c6")
            self.install_btn.configure(text=t("reinstall"))
            self.uninstall_btn.configure(state="normal")
        else:
            self.status_label.configure(
                text=t("status_not_installed"), text_color="#c66")
            self.install_btn.configure(text=t("install"))
            self.uninstall_btn.configure(state="disabled")

    # ── Install ───────────────────────────────────────────────────────────

    def _on_install(self):
        mpv_path = self.mpv_entry.get().strip()
        icon_path = self.icon_entry.get().strip()
        mpv_args = self.args_entry.get().strip()

        if not mpv_path or not os.path.isfile(mpv_path):
            self._log(t("err_mpv_missing"))
            if not self._advanced_visible:
                self._toggle_advanced()
            return
        if not icon_path or not os.path.isfile(icon_path):
            self._log(t("err_icon_missing"))
            if not self._advanced_visible:
                self._toggle_advanced()
            return
        if not is_vista_or_later():
            self._log(t("err_vista"))
            return

        self._set_buttons_busy(True, t("busy_installing"))
        self._log("─" * 50)

        def worker():
            try:
                run_install(mpv_path, icon_path, mpv_args, self._log)
            except Exception as e:
                self._log(t("err_generic", err=e))
            finally:
                self._set_buttons_busy(False)
                self._check_status()

        threading.Thread(target=worker, daemon=True).start()

    # ── Uninstall ─────────────────────────────────────────────────────────

    def _on_uninstall(self):
        self._set_buttons_busy(True, t("busy_uninstalling"))
        self._log("─" * 50)

        def worker():
            try:
                run_uninstall(self._log)
            except Exception as e:
                self._log(t("err_generic", err=e))
            finally:
                self._set_buttons_busy(False)
                self._check_status()

        threading.Thread(target=worker, daemon=True).start()

    # ── Button state ──────────────────────────────────────────────────────

    def _set_buttons_busy(self, busy: bool, label: str = ""):
        if busy:
            self.install_btn.configure(state="disabled", text=label)
            self.uninstall_btn.configure(state="disabled")
        else:
            self.install_btn.configure(state="normal")
            self.uninstall_btn.configure(state="normal")


# ─── Entry point ──────────────────────────────────────────────────────────────

def elevate_if_needed():
    if is_admin():
        return
    params = " ".join(f'"{a}"' for a in sys.argv)
    ctypes.windll.shell32.ShellExecuteW(
        None, "runas", sys.executable, params, None, 1)
    sys.exit(0)


if __name__ == "__main__":
    elevate_if_needed()
    app = MpvInstallerApp()
    app.mainloop()