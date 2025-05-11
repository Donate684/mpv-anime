#Requires -Version 5.1
#Requires -RunAsAdministrator

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Script Configuration ---
$ScriptDir = $PSScriptRoot
$MpvExeName = "mpv.exe"
$UmpvwExeName = "umpvw.exe" # Wrapper for file associations, used for some registry keys
$IconName = "mpv-icon.ico"
$SettingsXmlName = "settings.xml" # Name for the updater settings file

$ParentDir = (Get-Item $ScriptDir).Parent.FullName
$MpvPath = Join-Path -Path $ParentDir -ChildPath $MpvExeName
$UmpvwPath = Join-Path -Path $ParentDir -ChildPath $UmpvwExeName
$IconPath = Join-Path -Path $ScriptDir -ChildPath $IconName
$SettingsXmlPath = Join-Path -Path $ParentDir -ChildPath $SettingsXmlName # Path for settings.xml

$MpvArgs = "" # Command line arguments to use when launching mpv from a file association

# Registry Paths
$ClassesRootKey = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Classes"
$AppPathsKeyBase = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths"
$AppKeyBase = "$ClassesRootKey\Applications"
$AutoplayKeyBase = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers"
$ClientsMediaKeyBase = "HKLM:\SOFTWARE\Clients\Media" 
$RegisteredAppsKey = "HKLM:\SOFTWARE\RegisteredApplications"

# Derived paths for mpv specific entries
$MpvClientKeyPath = Join-Path -Path $ClientsMediaKeyBase -ChildPath "mpv"
$CapabilitiesKeyPath = Join-Path -Path $MpvClientKeyPath -ChildPath "Capabilities"


# --- GUI Elements ---
$Global:MainForm = New-Object System.Windows.Forms.Form
$Global:LogTextBox = New-Object System.Windows.Forms.RichTextBox
$Global:InstallButton = New-Object System.Windows.Forms.Button
$Global:UninstallButton = New-Object System.Windows.Forms.Button 
$Global:UpdaterTaskCheckBox = New-Object System.Windows.Forms.CheckBox
$Global:OpenDefaultProgramsCheckBox = New-Object System.Windows.Forms.CheckBox

# --- Helper Functions ---
function Log-Message ($Message, $Color = "Black") {
    $Timestamp = Get-Date -Format "HH:mm:ss"
    $Global:LogTextBox.SelectionStart = $Global:LogTextBox.TextLength
    $Global:LogTextBox.SelectionLength = 0
    $Global:LogTextBox.SelectionColor = $Color
    $Global:LogTextBox.AppendText("[$Timestamp] $Message`n")
    $Global:LogTextBox.ScrollToCaret()
    $Global:MainForm.Update() 
}

function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function New-RegKeyIfNotExists ($Path) {
    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -Force -ErrorAction SilentlyContinue | Out-Null
        if ($?) {
            Log-Message "Created registry key: $Path"
        } else {
            Log-Message "ERROR: Failed to create registry key: $Path" -Color Red
            return $false
        }
    }
    return $true
}

function Set-RegValue ($Path, $Name, $Value, $Type = "String") {
    if (-not (Test-Path $Path)) {
        if (-not (New-RegKeyIfNotExists $Path)) { return $false }
    }
    try {
        New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type -Force -ErrorAction Stop | Out-Null
        Log-Message "Set registry value: $Path | $Name = $Value"
    } catch {
        Log-Message "ERROR: Failed to set registry value: $Path | $Name. Error: $($_.Exception.Message)" -Color Red
        return $false
    }
    return $true
}

function Remove-RegKey ($Path) {
    if (Test-Path $Path) {
        try {
            Remove-Item -Path $Path -Recurse -Force -ErrorAction Stop
            Log-Message "Removed registry key: $Path"
        } catch {
            Log-Message "ERROR: Failed to remove registry key: $Path. Error: $($_.Exception.Message)" -Color Red
        }
    } else {
        Log-Message "Registry key not found (already removed?): $Path" -Color "Gray"
    }
}

function Remove-RegValue ($Path, $Name) {
     if (Test-Path $Path) {
        try {
            if (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue) {
                Remove-ItemProperty -Path $Path -Name $Name -Force -ErrorAction Stop
                Log-Message "Removed registry value: $Path | $Name"
            } else {
                 Log-Message "Registry value not found (already removed?): $Path | $Name" -Color "Gray"
            }
        } catch {
            Log-Message "ERROR: Failed to remove registry value: $Path | $Name. Error: $($_.Exception.Message)" -Color Red
        }
    } else {
        Log-Message "Registry key for value not found: $Path" -Color "Gray"
    }
}

function Add-Verbs ($AppKeyPath) {
    $ShellPath = Join-Path -Path $AppKeyPath -ChildPath "shell"
    New-RegKeyIfNotExists $ShellPath | Out-Null
    Set-RegValue -Path $ShellPath -Name "(Default)" -Value "play"

    $OpenPath = Join-Path -Path $ShellPath -ChildPath "open"
    New-RegKeyIfNotExists $OpenPath | Out-Null
    Set-RegValue -Path $OpenPath -Name "LegacyDisable" -Value "" 
    Set-RegValue -Path (Join-Path $OpenPath "command") -Name "(Default)" -Value "`"$UmpvwPath`" `"%1`""

    $PlayPath = Join-Path -Path $ShellPath -ChildPath "play"
    New-RegKeyIfNotExists $PlayPath | Out-Null
    Set-RegValue -Path $PlayPath -Name "(Default)" -Value "&Play"
    Set-RegValue -Path (Join-Path $PlayPath "command") -Name "(Default)" -Value "`"$UmpvwPath`" `"%1`""
}

function Register-MpvFileType ($MimeType, $PerceivedType, $FriendlyName, [string[]]$Extensions) {
    Log-Message "Registering type: $FriendlyName ($($Extensions -join ', '))" -Color "DarkBlue"
    $ProgId = "io.mpv$($Extensions[0])" 
    $ProgIdPath = Join-Path -Path $ClassesRootKey -ChildPath $ProgId

    New-RegKeyIfNotExists $ProgIdPath | Out-Null
    Set-RegValue -Path $ProgIdPath -Name "(Default)" -Value $FriendlyName
    Set-RegValue -Path $ProgIdPath -Name "EditFlags" -Value 4259840 -Type DWord 
    Set-RegValue -Path $ProgIdPath -Name "FriendlyTypeName" -Value $FriendlyName
    Set-RegValue -Path (Join-Path $ProgIdPath "DefaultIcon") -Name "(Default)" -Value $IconPath
    Add-Verbs -AppKeyPath $ProgIdPath

    $UmpvwAppKeyPath = Join-Path $AppKeyBase $UmpvwExeName 
    $AppSupportedTypesPath = Join-Path -Path $UmpvwAppKeyPath -ChildPath "SupportedTypes"
    New-RegKeyIfNotExists $AppSupportedTypesPath | Out-Null

    $CapabilitiesFileAssocPath = Join-Path -Path $CapabilitiesKeyPath -ChildPath "FileAssociations"
    New-RegKeyIfNotExists $CapabilitiesFileAssocPath | Out-Null

    foreach ($Ext in $Extensions) {
        $ExtKeyPath = Join-Path -Path $ClassesRootKey -ChildPath $Ext
        New-RegKeyIfNotExists $ExtKeyPath | Out-Null
        if (-not [string]::IsNullOrEmpty($MimeType)) { Set-RegValue -Path $ExtKeyPath -Name "Content Type" -Value $MimeType }
        if (-not [string]::IsNullOrEmpty($PerceivedType)) { Set-RegValue -Path $ExtKeyPath -Name "PerceivedType" -Value $PerceivedType }
        
        $OpenWithProgIdsPath = Join-Path -Path $ExtKeyPath -ChildPath "OpenWithProgids"
        New-RegKeyIfNotExists $OpenWithProgIdsPath | Out-Null
        Set-RegValue -Path $OpenWithProgIdsPath -Name $ProgId -Value "" 
        
        Set-RegValue -Path $AppSupportedTypesPath -Name $Ext -Value ""
        Set-RegValue -Path $CapabilitiesFileAssocPath -Name $Ext -Value $ProgId
    }
}

# --- Installation Logic ---
function Start-Installation {
    $Global:InstallButton.Enabled = $false
    $Global:UninstallButton.Enabled = $false
    Log-Message "Starting mpv installation..."

    Log-Message "Checking prerequisites..."
    if (-not (Test-Path $MpvPath -PathType Leaf)) { Log-Message "$MpvExeName not found at $MpvPath" -Color Red; $Global:InstallButton.Enabled = $true; $Global:UninstallButton.Enabled = $true; return }
    if (-not (Test-Path $UmpvwPath -PathType Leaf)) { Log-Message "WARNING: $UmpvwExeName not found at $UmpvwPath. File associations might not work as intended with the wrapper." -Color Orange }
    if (-not (Test-Path $IconPath -PathType Leaf)) { Log-Message "$IconName not found at $IconPath" -Color Red; $Global:InstallButton.Enabled = $true; $Global:UninstallButton.Enabled = $true; return }
    Log-Message "Prerequisites check passed."

    Log-Message "Registering App Paths for $UmpvwExeName..."
    $CurrentAppPath = Join-Path -Path $AppPathsKeyBase -ChildPath $UmpvwExeName
    Set-RegValue -Path $CurrentAppPath -Name "(Default)" -Value $UmpvwPath
    Set-RegValue -Path $CurrentAppPath -Name "UseUrl" -Value 1 -Type DWord

    Log-Message "Registering Applications key for $UmpvwExeName..."
    $CurrentAppKey = Join-Path -Path $AppKeyBase -ChildPath $UmpvwExeName
    Set-RegValue -Path $CurrentAppKey -Name "FriendlyAppName" -Value "mpv"
    Add-Verbs -AppKeyPath $CurrentAppKey

    Log-Message "Adding mpv to generic 'Open with' list..."
    Set-RegValue -Path "$ClassesRootKey\SystemFileAssociations\video\OpenWithList\$UmpvwExeName" -Name "(Default)" -Value ""
    Set-RegValue -Path "$ClassesRootKey\SystemFileAssociations\audio\OpenWithList\$UmpvwExeName" -Name "(Default)" -Value ""

    Log-Message "Adding DVD AutoPlay handler..."
    $DvdProgId = "io.mpv.dvd"; $DvdProgIdPath = Join-Path -Path $ClassesRootKey -ChildPath $DvdProgId
    Set-RegValue -Path (Join-Path $DvdProgIdPath "shell\play") -Name "(Default)" -Value "&Play"
    Set-RegValue -Path (Join-Path $DvdProgIdPath "shell\play\command") -Name "(Default)" -Value "`"$MpvPath`" $MpvArgs dvd:// --dvd-device=""%L"""
    $DvdHandler = Join-Path -Path $AutoplayKeyBase -ChildPath "Handlers\MpvPlayDVDMovieOnArrival"
    Set-RegValue -Path $DvdHandler -Name "Action" -Value "Play DVD movie"; Set-RegValue -Path $DvdHandler -Name "DefaultIcon" -Value "$MpvPath,0"
    Set-RegValue -Path $DvdHandler -Name "InvokeProgID" -Value $DvdProgId; Set-RegValue -Path $DvdHandler -Name "InvokeVerb" -Value "play"
    Set-RegValue -Path $DvdHandler -Name "Provider" -Value "mpv"
    Set-RegValue -Path (Join-Path $AutoplayKeyBase "EventHandlers\PlayDVDMovieOnArrival") -Name "MpvPlayDVDMovieOnArrival" -Value "" -Type String

    Log-Message "Adding Blu-ray AutoPlay handler..."
    $BluRayProgId = "io.mpv.bluray"; $BluRayProgIdPath = Join-Path -Path $ClassesRootKey -ChildPath $BluRayProgId
    Set-RegValue -Path (Join-Path $BluRayProgIdPath "shell\play") -Name "(Default)" -Value "&Play"
    Set-RegValue -Path (Join-Path $BluRayProgIdPath "shell\play\command") -Name "(Default)" -Value "`"$MpvPath`" $MpvArgs bd:// --bluray-device=""%L"""
    $BluRayHandler = Join-Path -Path $AutoplayKeyBase -ChildPath "Handlers\MpvPlayBluRayOnArrival"
    Set-RegValue -Path $BluRayHandler -Name "Action" -Value "Play Blu-ray movie"; Set-RegValue -Path $BluRayHandler -Name "DefaultIcon" -Value "$MpvPath,0"
    Set-RegValue -Path $BluRayHandler -Name "InvokeProgID" -Value $BluRayProgId; Set-RegValue -Path $BluRayHandler -Name "InvokeVerb" -Value "play"
    Set-RegValue -Path $BluRayHandler -Name "Provider" -Value "mpv"
    Set-RegValue -Path (Join-Path $AutoplayKeyBase "EventHandlers\PlayBluRayOnArrival") -Name "MpvPlayBluRayOnArrival" -Value "" -Type String

    Log-Message "Adding Capabilities key for Default Programs..."
    New-RegKeyIfNotExists $CapabilitiesKeyPath | Out-Null 
    Set-RegValue -Path $CapabilitiesKeyPath -Name "ApplicationName" -Value "mpv"
    Set-RegValue -Path $CapabilitiesKeyPath -Name "ApplicationDescription" -Value "mpv media player"
    
    Log-Message "Registering file types..."
    # --- Start of FULL file type registration (как в предыдущей полной версии) ---
    Register-MpvFileType "audio/ac3" "audio" "AC-3 Audio" @(".ac3", ".a52")
    Register-MpvFileType "audio/eac3" "audio" "E-AC-3 Audio" @(".eac3")
    Register-MpvFileType "audio/vnd.dolby.mlp" "audio" "MLP Audio" @(".mlp")
    Register-MpvFileType "audio/vnd.dts" "audio" "DTS Audio" @(".dts")
    Register-MpvFileType "audio/vnd.dts.hd" "audio" "DTS-HD Audio" @(".dts-hd", ".dtshd")
    Register-MpvFileType "" "audio" "TrueHD Audio" @(".true-hd", ".thd", ".truehd", ".thd+ac3")
    Register-MpvFileType "" "audio" "True Audio" @(".tta")
    Register-MpvFileType "" "audio" "PCM Audio" @(".pcm")
    Register-MpvFileType "audio/wav" "audio" "Wave Audio" @(".wav")
    Register-MpvFileType "audio/aiff" "audio" "AIFF Audio" @(".aiff", ".aif", ".aifc")
    Register-MpvFileType "audio/amr" "audio" "AMR Audio" @(".amr")
    Register-MpvFileType "audio/amr-wb" "audio" "AMR-WB Audio" @(".awb")
    Register-MpvFileType "audio/basic" "audio" "AU Audio" @(".au", ".snd")
    Register-MpvFileType "" "audio" "Linear PCM Audio" @(".lpcm")
    Register-MpvFileType "" "video" "Raw YUV Video" @(".yuv")
    Register-MpvFileType "" "video" "YUV4MPEG2 Video" @(".y4m")
    Register-MpvFileType "audio/x-ape" "audio" "Monkey's Audio" @(".ape")
    Register-MpvFileType "audio/x-wavpack" "audio" "WavPack Audio" @(".wv")
    Register-MpvFileType "audio/x-shorten" "audio" "Shorten Audio" @(".shn")
    Register-MpvFileType "video/vnd.dlna.mpeg-tts" "video" "MPEG-2 Transport Stream" @(".m2ts", ".m2t", ".mts", ".mtv", ".ts", ".tsv", ".tsa", ".tts", ".trp")
    Register-MpvFileType "audio/vnd.dlna.adts" "audio" "ADTS Audio" @(".adts", ".adt")
    Register-MpvFileType "audio/mpeg" "audio" "MPEG Audio" @(".mpa", ".m1a", ".m2a", ".mp1", ".mp2")
    Register-MpvFileType "audio/mpeg" "audio" "MP3 Audio" @(".mp3")
    Register-MpvFileType "video/mpeg" "video" "MPEG Video" @(".mpeg", ".mpg", ".mpe", ".mpeg2", ".m1v", ".m2v", ".mp2v", ".mpv", ".mpv2", ".mod", ".tod")
    Register-MpvFileType "video/dvd" "video" "Video Object" @(".vob", ".vro")
    Register-MpvFileType "" "video" "Enhanced VOB" @(".evob", ".evo")
    Register-MpvFileType "video/mp4" "video" "MPEG-4 Video" @(".mpeg4", ".m4v", ".mp4", ".mp4v", ".mpg4")
    Register-MpvFileType "audio/mp4" "audio" "MPEG-4 Audio" @(".m4a")
    Register-MpvFileType "audio/aac" "audio" "Raw AAC Audio" @(".aac")
    Register-MpvFileType "" "video" "Raw H.264/AVC Video" @(".h264", ".avc", ".x264", ".264")
    Register-MpvFileType "" "video" "Raw H.265/HEVC Video" @(".hevc", ".h265", ".x265", ".265")
    Register-MpvFileType "audio/flac" "audio" "FLAC Audio" @(".flac")
    Register-MpvFileType "audio/ogg" "audio" "Ogg Audio" @(".oga", ".ogg")
    Register-MpvFileType "audio/ogg" "audio" "Opus Audio" @(".opus")
    Register-MpvFileType "audio/ogg" "audio" "Speex Audio" @(".spx")
    Register-MpvFileType "video/ogg" "video" "Ogg Video" @(".ogv", ".ogm")
    Register-MpvFileType "application/ogg" "video" "Ogg Video" @(".ogx")
    Register-MpvFileType "video/x-matroska" "video" "Matroska Video" @(".mkv")
    Register-MpvFileType "video/x-matroska" "video" "Matroska 3D Video" @(".mk3d")
    Register-MpvFileType "audio/x-matroska" "audio" "Matroska Audio" @(".mka")
    Register-MpvFileType "video/webm" "video" "WebM Video" @(".webm")
    Register-MpvFileType "audio/webm" "audio" "WebM Audio" @(".weba")
    Register-MpvFileType "video/avi" "video" "Video Clip" @(".avi", ".vfw")
    Register-MpvFileType "" "video" "DivX Video" @(".divx")
    Register-MpvFileType "" "video" "3ivx Video" @(".3iv")
    Register-MpvFileType "" "video" "XVID Video" @(".xvid")
    Register-MpvFileType "" "video" "NUT Video" @(".nut")
    Register-MpvFileType "video/flc" "video" "FLIC Video" @(".flic", ".fli", ".flc")
    Register-MpvFileType "" "video" "Nullsoft Streaming Video" @(".nsv")
    Register-MpvFileType "application/gxf" "video" "General Exchange Format" @(".gxf")
    Register-MpvFileType "application/mxf" "video" "Material Exchange Format" @(".mxf")
    Register-MpvFileType "audio/x-ms-wma" "audio" "Windows Media Audio" @(".wma")
    Register-MpvFileType "video/x-ms-wm" "video" "Windows Media Video" @(".wm")
    Register-MpvFileType "video/x-ms-wmv" "video" "Windows Media Video" @(".wmv")
    Register-MpvFileType "video/x-ms-asf" "video" "Windows Media Video" @(".asf")
    Register-MpvFileType "" "video" "Microsoft Recorded TV Show" @(".dvr-ms", ".dvr")
    Register-MpvFileType "" "video" "Windows Recorded TV Show" @(".wtv")
    Register-MpvFileType "" "video" "DV Video" @(".dv", ".hdv")
    Register-MpvFileType "video/x-flv" "video" "Flash Video" @(".flv")
    Register-MpvFileType "video/mp4" "video" "Flash Video" @(".f4v")
    Register-MpvFileType "audio/mp4" "audio" "Flash Audio" @(".f4a")
    Register-MpvFileType "video/quicktime" "video" "QuickTime Video" @(".qt", ".mov")
    Register-MpvFileType "video/quicktime" "video" "QuickTime HD Video" @(".hdmov")
    Register-MpvFileType "application/vnd.rn-realmedia" "video" "Real Media Video" @(".rm")
    Register-MpvFileType "application/vnd.rn-realmedia-vbr" "video" "Real Media Video" @(".rmvb")
    Register-MpvFileType "audio/vnd.rn-realaudio" "audio" "Real Media Audio" @(".ra", ".ram")
    Register-MpvFileType "audio/3gpp" "audio" "3GPP Audio" @(".3ga")
    Register-MpvFileType "audio/3gpp2" "audio" "3GPP Audio" @(".3ga2")
    Register-MpvFileType "video/3gpp" "video" "3GPP Video" @(".3gpp", ".3gp")
    Register-MpvFileType "video/3gpp2" "video" "3GPP Video" @(".3gp2", ".3g2")
    Register-MpvFileType "" "audio" "AY Audio" @(".ay")
    Register-MpvFileType "" "audio" "GBS Audio" @(".gbs")
    Register-MpvFileType "" "audio" "GYM Audio" @(".gym")
    Register-MpvFileType "" "audio" "HES Audio" @(".hes")
    Register-MpvFileType "" "audio" "KSS Audio" @(".kss")
    Register-MpvFileType "" "audio" "NSF Audio" @(".nsf")
    Register-MpvFileType "" "audio" "NSFE Audio" @(".nsfe")
    Register-MpvFileType "" "audio" "SAP Audio" @(".sap")
    Register-MpvFileType "" "audio" "SPC Audio" @(".spc")
    Register-MpvFileType "" "audio" "VGM Audio" @(".vgm")
    Register-MpvFileType "" "audio" "VGZ Audio" @(".vgz")
    Register-MpvFileType "audio/x-mpegurl" "audio" "M3U Playlist" @(".m3u", ".m3u8")
    Register-MpvFileType "audio/x-scpls" "audio" "PLS Playlist" @(".pls")
    Register-MpvFileType "" "audio" "CUE Sheet" @(".cue")
    # --- End of FULL file type registration ---

    Log-Message "Registering for Default Programs control panel..."
    Set-RegValue -Path $RegisteredAppsKey -Name "mpv" -Value "SOFTWARE\Clients\Media\mpv\Capabilities"

    if ($Global:UpdaterTaskCheckBox.Checked) {
        Log-Message "Creating auto-updater scheduled task..."
        $UpdaterScriptPath = "C:\ProgramData\mpv\updater.bat" 
        $TaskName = "mpv updater"
        $TaskAction = New-ScheduledTaskAction -Execute $UpdaterScriptPath
        $TaskTrigger = New-ScheduledTaskTrigger -AtStartup -RandomDelay (New-TimeSpan -Seconds 60) 
        $TaskPrincipal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest
        $TaskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 0) 

        if (-not (Test-Path (Split-Path $UpdaterScriptPath -Parent) -PathType Container)) {
             New-Item -ItemType Directory -Path (Split-Path $UpdaterScriptPath -Parent) -Force | Out-Null
             Log-Message "Created directory C:\ProgramData\mpv for updater script."
        }
        
        try {
            Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
            Register-ScheduledTask -TaskName $TaskName -Action $TaskAction -Trigger $TaskTrigger -Principal $TaskPrincipal -Settings $TaskSettings -Force -ErrorAction Stop
            Log-Message "Scheduled task '$TaskName' created/updated successfully."
        } catch {
            Log-Message "ERROR: Failed to create scheduled task '$TaskName'. Error: $($_.Exception.Message)" -Color Red
        }

        # --- Create settings.xml ---
        Log-Message "Creating $SettingsXmlName for updater..."
        $SettingsXmlContent = @"
<settings>
  <channel>weekly</channel>
  <arch>x86_64-v3</arch>
  <autodelete>true</autodelete>
  <getffmpeg>false</getffmpeg>
</settings>
"@
        try {
            Set-Content -Path $SettingsXmlPath -Value $SettingsXmlContent -Encoding UTF8 -Force -ErrorAction Stop
            Log-Message "$SettingsXmlName created successfully at $SettingsXmlPath"
        } catch {
            Log-Message "ERROR: Failed to create $SettingsXmlName at $SettingsXmlPath. Error: $($_.Exception.Message)" -Color Red
        }
        # --- End Create settings.xml ---
    }

    Log-Message "Installation complete!" -Color Green
    $Global:InstallButton.Text = "Installed"
    $Global:UninstallButton.Enabled = $true 
}

# --- Uninstallation Logic ---
function Start-Uninstallation {
    $ConfirmResult = [System.Windows.Forms.MessageBox]::Show("Are you sure you want to completely uninstall mpv, its associations, and the updater settings.xml file (if present)? This action cannot be undone.", "Confirm Uninstall", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
    if ($ConfirmResult -ne [System.Windows.Forms.DialogResult]::Yes) {
        Log-Message "Uninstallation cancelled by user." -Color "Orange"
        return
    }

    $Global:InstallButton.Enabled = $false
    $Global:UninstallButton.Enabled = $false
    Log-Message "Starting mpv uninstallation..." -Color "DarkRed"
    Log-Message "Deleting App Paths entry..."
    Remove-RegKey -Path (Join-Path -Path $AppPathsKeyBase -ChildPath $UmpvwExeName)

    Log-Message "Deleting Applications key..."
    Remove-RegKey -Path (Join-Path -Path $AppKeyBase -ChildPath $UmpvwExeName)

    Log-Message "Deleting from generic OpenWithList..."
    Remove-RegValue -Path "$ClassesRootKey\SystemFileAssociations\video\OpenWithList" -Name $UmpvwExeName
    Remove-RegValue -Path "$ClassesRootKey\SystemFileAssociations\audio\OpenWithList" -Name $UmpvwExeName
    
    Log-Message "Deleting AutoPlay handlers..."
    Remove-RegKey -Path (Join-Path $AutoplayKeyBase "Handlers\MpvPlayDVDMovieOnArrival")
    Remove-RegValue -Path (Join-Path $AutoplayKeyBase "EventHandlers\PlayDVDMovieOnArrival") -Name "MpvPlayDVDMovieOnArrival"
    Remove-RegKey -Path (Join-Path $AutoplayKeyBase "Handlers\MpvPlayBluRayOnArrival")
    Remove-RegValue -Path (Join-Path $AutoplayKeyBase "EventHandlers\PlayBluRayOnArrival") -Name "MpvPlayBluRayOnArrival"
    Remove-RegKey -Path (Join-Path -Path $ClassesRootKey -ChildPath "io.mpv.dvd")
    Remove-RegKey -Path (Join-Path -Path $ClassesRootKey -ChildPath "io.mpv.bluray")

    Log-Message "Deleting Default Programs entries..."
    Remove-RegValue -Path $RegisteredAppsKey -Name "mpv"
    Remove-RegKey -Path $CapabilitiesKeyPath 
    if (Test-Path $MpvClientKeyPath) {
        if ((Get-ChildItem -Path $MpvClientKeyPath -ErrorAction SilentlyContinue).Count -eq 0 -and `
            (Get-ItemProperty -Path $MpvClientKeyPath -ErrorAction SilentlyContinue).PSObject.Properties.Count -eq 1 -and `
            (Get-ItemProperty -Path $MpvClientKeyPath -Name "(Default)" -ErrorAction SilentlyContinue)) { 
            Log-Message "Attempting to remove parent client key: $MpvClientKeyPath"
            Remove-RegKey -Path $MpvClientKeyPath
        }
    }

    Log-Message "Deleting mpv ProgIds from OpenWithProgIds lists for all extensions..."
    Get-ChildItem -Path $ClassesRootKey -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^\.\w+' } | ForEach-Object {
        $extKeyNode = $_ 
        $openWithProgIdsPath = Join-Path -Path $extKeyNode.PSPath -ChildPath "OpenWithProgids"
        if (Test-Path $openWithProgIdsPath) {
            (Get-Item -Path $openWithProgIdsPath).GetValueNames() | Where-Object { $_ -like "io.mpv*" } | ForEach-Object {
                $progIdValueToRemove = $_
                Log-Message "  Deleting '$progIdValueToRemove' from $($extKeyNode.PSChildName)\OpenWithProgids"
                Remove-ItemProperty -Path $openWithProgIdsPath -Name $progIdValueToRemove -Force -ErrorAction SilentlyContinue
            }
        }
    }
    
    Log-Message "Deleting main io.mpv.* ProgId keys from $ClassesRootKey..."
    Get-ChildItem -Path $ClassesRootKey -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -like "io.mpv*" } | ForEach-Object {
        Log-Message "  Deleting ProgId key: $($_.PSPath)"
        Remove-Item -Path $_.PSPath -Recurse -Force -ErrorAction SilentlyContinue
    }

    Log-Message "Deleting auto-updater scheduled task..."
    $TaskName = "mpv updater"
    if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
        if ($?) { Log-Message "Scheduled task '$TaskName' unregistered successfully." }
        else { Log-Message "Failed to unregister scheduled task '$TaskName'." -Color Red }
    } else {
        Log-Message "Scheduled task '$TaskName' not found (already removed?)." -Color "Gray"
    }

    # --- Delete settings.xml ---
    Log-Message "Attempting to delete $SettingsXmlName..."
    if (Test-Path $SettingsXmlPath -PathType Leaf) {
        try {
            Remove-Item -Path $SettingsXmlPath -Force -ErrorAction Stop
            Log-Message "$SettingsXmlName deleted successfully from $SettingsXmlPath"
        } catch {
            Log-Message "ERROR: Failed to delete $SettingsXmlName from $SettingsXmlPath. Error: $($_.Exception.Message)" -Color Red
        }
    } else {
        Log-Message "$SettingsXmlName not found at $SettingsXmlPath (already removed or never created)." -Color "Gray"
    }
    # --- End Delete settings.xml ---


    Log-Message "Uninstallation complete!" -Color "DarkGreen"
    $Global:UninstallButton.Text = "Uninstalled"
    $Global:InstallButton.Enabled = $true 
    $Global:InstallButton.Text = "Install MPV" 
}

# --- GUI Setup ---
function Initialize-Form {
    $Global:MainForm.Text = "MPV Installer / Uninstaller"
    $Global:MainForm.Size = New-Object System.Drawing.Size(620, 520) 
    $Global:MainForm.StartPosition = "CenterScreen"
    $Global:MainForm.FormBorderStyle = "FixedDialog"
    $Global:MainForm.MaximizeBox = $false
    $Global:MainForm.MinimizeBox = $true

    $Global:LogTextBox.Location = New-Object System.Drawing.Point(10, 10)
    $Global:LogTextBox.Size = New-Object System.Drawing.Size(580, 350) 
    $Global:LogTextBox.Multiline = $true
    $Global:LogTextBox.ScrollBars = "Vertical"
    $Global:LogTextBox.ReadOnly = $true
    $Global:LogTextBox.Font = New-Object System.Drawing.Font("Consolas", 9)
    $Global:LogTextBox.BackColor = [System.Drawing.Color]::White

    $Global:UpdaterTaskCheckBox.Text = "Manage auto-updater task"
    $Global:UpdaterTaskCheckBox.Location = New-Object System.Drawing.Point(10, 370)
    $Global:UpdaterTaskCheckBox.AutoSize = $true
    $Global:UpdaterTaskCheckBox.Checked = $false 

    $Global:OpenDefaultProgramsCheckBox.Text = "Open Default Programs after installation"
    $Global:OpenDefaultProgramsCheckBox.Location = New-Object System.Drawing.Point(10, 395)
    $Global:OpenDefaultProgramsCheckBox.AutoSize = $true
    $Global:OpenDefaultProgramsCheckBox.Checked = $true 

    $Global:InstallButton.Text = "Install MPV"
    $Global:InstallButton.Location = New-Object System.Drawing.Point(150, 430) 
    $Global:InstallButton.Size = New-Object System.Drawing.Size(140, 30)
    $Global:InstallButton.Font = New-Object System.Drawing.Font($Global:InstallButton.Font.FontFamily, 10, [System.Drawing.FontStyle]::Bold)
    $Global:InstallButton.add_Click({ Start-Installation })

    $Global:UninstallButton.Text = "Uninstall MPV"
    $Global:UninstallButton.Location = New-Object System.Drawing.Point(310, 430) 
    $Global:UninstallButton.Size = New-Object System.Drawing.Size(140, 30)
    $Global:UninstallButton.Font = New-Object System.Drawing.Font($Global:UninstallButton.Font.FontFamily, 10, [System.Drawing.FontStyle]::Bold)
    $Global:UninstallButton.ForeColor = [System.Drawing.Color]::DarkRed
    $Global:UninstallButton.add_Click({ Start-Uninstallation })

    $CloseButton = New-Object System.Windows.Forms.Button
    $CloseButton.Text = "Close"
    $CloseButton.Location = New-Object System.Drawing.Point(490, 430) 
    $CloseButton.Size = New-Object System.Drawing.Size(100, 30)
    $CloseButton.add_Click({ $Global:MainForm.Close() })
    
    $Global:MainForm.Controls.Add($Global:LogTextBox)
    $Global:MainForm.Controls.Add($Global:UpdaterTaskCheckBox)
    $Global:MainForm.Controls.Add($Global:OpenDefaultProgramsCheckBox)
    $Global:MainForm.Controls.Add($Global:InstallButton)
    $Global:MainForm.Controls.Add($Global:UninstallButton)
    $Global:MainForm.Controls.Add($CloseButton)

    Log-Message "MPV Installer/Uninstaller GUI"
    Log-Message "Script directory: $ScriptDir"
    Log-Message "mpv.exe expected at: $MpvPath"
    Log-Message "umpvw.exe expected at: $UmpvwPath (for associations)"
    Log-Message "Icon expected at: $IconPath"
    Log-Message "If u press create auto update task settings.xml created at: $SettingsXmlPath"
	Log-Message "If u have very old cpu more than 10+ years without AVX2 in settings.xml change <arch>x86_64-v3</arch> to <arch>x86_64</arch>"


    if (-not (Test-Path $MpvPath -PathType Leaf)) { Log-Message "CRITICAL: mpv.exe not found. Installation will fail." -Color Red; $Global:InstallButton.Enabled = $false }
    if (-not (Test-Path $IconPath -PathType Leaf)) { Log-Message "CRITICAL: mpv-icon.ico not found. Icons will not be set correctly." -Color Red; $Global:InstallButton.Enabled = $false }
    if (-not (Test-Path $UmpvwPath -PathType Leaf)) { Log-Message "WARNING: umpvw.exe not found. File associations via wrapper might fail." -Color Orange }

    [void]$Global:MainForm.ShowDialog()
}


# --- Main Execution ---
if (-not (Test-Admin)) {
    Write-Warning "This script requires Administrator privileges."
    try {
        Start-Process powershell.exe -ArgumentList ("-NoProfile -File `"{0}`"" -f $PSCommandPath) -Verb RunAs -ErrorAction Stop
        exit 
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to elevate to Administrator. Please run this script as Administrator manually.", "Admin Rights Required", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        exit
    }
}

Initialize-Form