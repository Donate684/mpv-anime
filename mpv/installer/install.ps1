#Requires -Version 5.1
#Requires -RunAsAdministrator

# --- Script Overview ---
# This script provides a graphical user interface for installing and uninstalling
# the mpv media player, including file associations, context menus, and
# default program registration in Windows.
# It is designed to be placed in a 'mpv-installer' subdirectory alongside the main mpv directory.
#
# Directory Structure Expectation:
# /some_folder/
# ├── mpv/              <-- Main mpv directory
# │   ├── mpv.exe
# │   ├── umpvw.exe         <-- Wrapper for file associations
# │   └── ... (other mpv files)
# │
# └── mpv-installer/      <-- Script directory
#       ├── install-mpv.ps1   <-- This script
#       └── mpv-icon.ico

#region --- Configuration and Initial Setup ---

# Add required assemblies for GUI
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Script Configuration ---
$ScriptDir       = $PSScriptRoot
$ParentDir       = (Get-Item $ScriptDir).Parent.FullName
$MpvDir          = $ParentDir # Assuming parent dir is the mpv root

$MpvExeName      = "mpv.exe"
$UmpvwExeName    = "umpvw.exe" # Wrapper for file associations
$IconName        = "mpv-icon.ico"
$SettingsXmlName = "settings.xml"

$MpvPath         = Join-Path -Path $MpvDir -ChildPath $MpvExeName
$UmpvwPath       = Join-Path -Path $MpvDir -ChildPath $UmpvwExeName
$IconPath        = Join-Path -Path $ScriptDir -ChildPath $IconName
$SettingsXmlPath = Join-Path -Path $MpvDir -ChildPath $SettingsXmlName

# --- Registry Paths ---
$ClassesRootKey      = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Classes"
$AppPathsKeyBase     = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths"
$AppKeyBase          = "$ClassesRootKey\Applications"
$AutoplayKeyBase     = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers"
$ClientsMediaKeyBase = "HKLM:\SOFTWARE\Clients\Media"
$RegisteredAppsKey   = "HKLM:\SOFTWARE\RegisteredApplications"

# Derived paths for mpv specific entries
$MpvClientKeyPath    = Join-Path -Path $ClientsMediaKeyBase -ChildPath "mpv"
$CapabilitiesKeyPath = Join-Path -Path $MpvClientKeyPath -ChildPath "Capabilities"

#endregion

#region --- File Type Data (CSV Here-String) ---

# Using a CSV Here-String separates data from logic, making it vastly easier to maintain.
$FileTypesCsv = @"
MimeType,PerceivedType,FriendlyName,Extensions
"audio/ac3","audio","AC-3 Audio",".ac3,.a52"
"audio/eac3","audio","E-AC-3 Audio",".eac3"
"audio/vnd.dolby.mlp","audio","MLP Audio",".mlp"
"audio/vnd.dts","audio","DTS Audio",".dts"
"audio/vnd.dts.hd","audio","DTS-HD Audio",".dts-hd,.dtshd"
"","audio","TrueHD Audio",".true-hd,.thd,.truehd,.thd+ac3"
"","audio","True Audio",".tta"
"","audio","PCM Audio",".pcm"
"audio/wav","audio","Wave Audio",".wav"
"audio/aiff","audio","AIFF Audio",".aiff,.aif,.aifc"
"audio/amr","audio","AMR Audio",".amr"
"audio/amr-wb","audio","AMR-WB Audio",".awb"
"audio/basic","audio","AU Audio",".au,.snd"
"","audio","Linear PCM Audio",".lpcm"
"","video","Raw YUV Video",".yuv"
"","video","YUV4MPEG2 Video",".y4m"
"audio/x-ape","audio","Monkey's Audio",".ape"
"audio/x-wavpack","audio","WavPack Audio",".wv"
"audio/x-shorten","audio","Shorten Audio",".shn"
"video/vnd.dlna.mpeg-tts","video","MPEG-2 Transport Stream",".m2ts,.m2t,.mts,.mtv,.ts,.tsv,.tsa,.tts,.trp"
"audio/vnd.dlna.adts","audio","ADTS Audio",".adts,.adt"
"audio/mpeg","audio","MPEG Audio",".mpa,.m1a,.m2a,.mp1,.mp2"
"audio/mpeg","audio","MP3 Audio",".mp3"
"video/mpeg","video","MPEG Video",".mpeg,.mpg,.mpe,.mpeg2,.m1v,.m2v,.mp2v,.mpv,.mpv2,.mod,.tod"
"video/dvd","video","Video Object",".vob,.vro"
"","video","Enhanced VOB",".evob,.evo"
"video/mp4","video","MPEG-4 Video",".mpeg4,.m4v,.mp4,.mp4v,.mpg4"
"audio/mp4","audio","MPEG-4 Audio",".m4a"
"audio/aac","audio","Raw AAC Audio",".aac"
"","video","Raw H.264/AVC Video",".h264,.avc,.x264,.264"
"","video","Raw H.265/HEVC Video",".hevc,.h265,.x265,.265"
"audio/flac","audio","FLAC Audio",".flac"
"audio/ogg","audio","Ogg Audio",".oga,.ogg"
"audio/ogg","audio","Opus Audio",".opus"
"audio/ogg","audio","Speex Audio",".spx"
"video/ogg","video","Ogg Video",".ogv,.ogm"
"application/ogg","video","Ogg Video",".ogx"
"video/x-matroska","video","Matroska Video",".mkv"
"video/x-matroska","video","Matroska 3D Video",".mk3d"
"audio/x-matroska","audio","Matroska Audio",".mka"
"video/webm","video","WebM Video",".webm"
"audio/webm","audio","WebM Audio",".weba"
"video/avi","video","Video Clip",".avi,.vfw"
"","video","DivX Video",".divx"
"","video","3ivx Video",".3iv"
"","video","XVID Video",".xvid"
"","video","NUT Video",".nut"
"video/flc","video","FLIC Video",".flic,.fli,.flc"
"","video","Nullsoft Streaming Video",".nsv"
"application/gxf","video","General Exchange Format",".gxf"
"application/mxf","video","Material Exchange Format",".mxf"
"audio/x-ms-wma","audio","Windows Media Audio",".wma"
"video/x-ms-wm","video","Windows Media Video",".wm"
"video/x-ms-wmv","video","Windows Media Video",".wmv"
"video/x-ms-asf","video","Windows Media Video",".asf"
"","video","Microsoft Recorded TV Show",".dvr-ms,.dvr"
"","video","Windows Recorded TV Show",".wtv"
"","video","DV Video",".dv,.hdv"
"video/x-flv","video","Flash Video",".flv"
"video/mp4","video","Flash Video",".f4v"
"audio/mp4","audio","Flash Audio",".f4a"
"video/quicktime","video","QuickTime Video",".qt,.mov"
"video/quicktime","video","QuickTime HD Video",".hdmov"
"application/vnd.rn-realmedia","video","Real Media Video",".rm"
"application/vnd.rn-realmedia-vbr","video","Real Media Video",".rmvb"
"audio/vnd.rn-realaudio","audio","Real Media Audio",".ra,.ram"
"audio/3gpp","audio","3GPP Audio",".3ga"
"audio/3gpp2","audio","3GPP Audio",".3ga2"
"video/3gpp","video","3GPP Video",".3gpp,.3gp"
"video/3gpp2","video","3GPP Video",".3gp2,.3g2"
"","audio","AY Audio",".ay"
"","audio","GBS Audio",".gbs"
"","audio","GYM Audio",".gym"
"","audio","HES Audio",".hes"
"","audio","KSS Audio",".kss"
"","audio","NSF Audio",".nsf"
"","audio","NSFE Audio",".nsfe"
"","audio","SAP Audio",".sap"
"","audio","SPC Audio",".spc"
"","audio","VGM Audio",".vgm"
"","audio","VGZ Audio",".vgz"
"audio/x-mpegurl","audio","M3U Playlist",".m3u,.m3u8"
"audio/x-scpls","audio","PLS Playlist",".pls"
"","audio","CUE Sheet",".cue"
"@
$FileTypes = $FileTypesCsv | ConvertFrom-Csv

#endregion

#region --- Helper Functions ---

function Log-Message($Message, $Color = "Black") {
    # Logs a timestamped message to the GUI log box.
    if ($Global:LogTextBox) {
        $Timestamp = Get-Date -Format "HH:mm:ss"
        $Global:LogTextBox.SelectionStart = $Global:LogTextBox.TextLength
        $Global:LogTextBox.SelectionLength = 0
        $Global:LogTextBox.SelectionColor = $Color
        $Global:LogTextBox.AppendText("[$Timestamp] $Message`n")
        $Global:LogTextBox.ScrollToCaret()
        $Global:MainForm.Update()
    } else {
        Write-Host "[$Timestamp] $Message"
    }
}

function Set-RegValue {
    # Sets a registry value, with -WhatIf support.
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)] [string]$Path,
        [Parameter(Mandatory = $true)] [string]$Name,
        [Parameter(Mandatory = $true)] $Value,
        [string]$Type = "String"
    )
    if ($PSCmdlet.ShouldProcess("'$Path' -> '$Name' = '$Value'", "Set Registry Value")) {
        try {
            if (-not (Test-Path $Path)) {
                New-Item -Path $Path -Force -ErrorAction Stop | Out-Null
                Log-Message "Created key: $Path"
            }
            New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type -Force -ErrorAction Stop | Out-Null
            Log-Message "Set: $Path | $Name = $Value"
        } catch {
            Log-Message "ERROR: Failed to set value at $Path | $Name. $_" -Color Red
        }
    }
}

function Remove-RegKey {
    # Removes a registry key, with -WhatIf support.
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)] [string]$Path
    )
    if (Test-Path $Path) {
        if ($PSCmdlet.ShouldProcess($Path, "Remove Registry Key (and all subkeys)")) {
            try {
                Remove-Item -Path $Path -Recurse -Force -ErrorAction Stop
                Log-Message "Removed key: $Path"
            } catch {
                Log-Message "ERROR: Failed to remove key $Path. $_" -Color Red
            }
        }
    } else {
        Log-Message "Key not found (already removed?): $Path" -Color "Gray"
    }
}

function Remove-RegValue {
    # Removes a registry value, with -WhatIf support.
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)] [string]$Path,
        [Parameter(Mandatory = $true)] [string]$Name
    )
    if (Test-Path $Path) {
        if ((Get-Item -Path $Path).GetValue($Name, $null) -ne $null) {
            if ($PSCmdlet.ShouldProcess("'$Path' -> Value: '$Name'", "Remove Registry Value")) {
                try {
                    Remove-ItemProperty -Path $Path -Name $Name -Force -ErrorAction Stop
                    Log-Message "Removed value: $Path | $Name"
                } catch {
                    Log-Message "ERROR: Failed to remove value $Path | $Name. $_" -Color Red
                }
            }
        } else {
            Log-Message "Value not found (already removed?): $Path | $Name" -Color "Gray"
        }
    } else {
        Log-Message "Key for value not found: $Path" -Color "Gray"
    }
}

function Add-MpvVerbs($KeyPath) {
    # Adds the standard 'open' and 'play' verbs for a ProgId.
    $shellPath = Join-Path -Path $KeyPath -ChildPath "shell"
    Set-RegValue -Path $shellPath -Name "(Default)" -Value "play" -WhatIf:$false # Set default verb

    $openPath = Join-Path -Path $shellPath -ChildPath "open"
    Set-RegValue -Path $openPath -Name "LegacyDisable" -Value ""
    Set-RegValue -Path (Join-Path $openPath "command") -Name "(Default)" -Value "`"$UmpvwPath`" `"%1`""

    $playPath = Join-Path -Path $shellPath -ChildPath "play"
    Set-RegValue -Path $playPath -Name "(Default)" -Value "&Play"
    Set-RegValue -Path (Join-Path $playPath "command") -Name "(Default)" -Value "`"$UmpvwPath`" `"%1`""
}
#endregion

#region --- Core Installation and Uninstallation Logic ---

function Start-Installation {
    $Global:InstallButton.Enabled = $false
    $Global:UninstallButton.Enabled = $false
    Log-Message "Starting mpv installation..." -Color "DarkBlue"

    # --- Prerequisite Checks ---
    Log-Message "Checking prerequisites..."
    if (-not (Test-Path $MpvPath -PathType Leaf)) { Log-Message "$MpvExeName not found at $MpvPath" -Color Red; return }
    if (-not (Test-Path $UmpvwPath -PathType Leaf)) { Log-Message "WARNING: $UmpvwExeName not found. File associations might not work." -Color Orange }
    if (-not (Test-Path $IconPath -PathType Leaf)) { Log-Message "$IconName not found at $IconPath" -Color Red; return }
    Log-Message "Prerequisites check passed."

    # --- Core Registrations ---
    Log-Message "Registering App Paths and Application keys..."
    $currentAppPath = Join-Path -Path $AppPathsKeyBase -ChildPath $UmpvwExeName
    Set-RegValue -Path $currentAppPath -Name "(Default)" -Value $UmpvwPath
    Set-RegValue -Path $currentAppPath -Name "UseUrl" -Value 1 -Type DWord

    $currentAppKey = Join-Path -Path $AppKeyBase -ChildPath $UmpvwExeName
    Set-RegValue -Path $currentAppKey -Name "FriendlyAppName" -Value "mpv"
    Add-MpvVerbs -KeyPath $currentAppKey
    
    Log-Message "Adding mpv to generic 'Open with' list..."
    Set-RegValue -Path "$ClassesRootKey\SystemFileAssociations\video\OpenWithList\$UmpvwExeName" -Name "(Default)" -Value ""
    Set-RegValue -Path "$ClassesRootKey\SystemFileAssociations\audio\OpenWithList\$UmpvwExeName" -Name "(Default)" -Value ""

    # --- Default Programs Capabilities ---
    Log-Message "Registering Capabilities for Default Programs..."
    Set-RegValue -Path $CapabilitiesKeyPath -Name "ApplicationName" -Value "mpv"
    Set-RegValue -Path $CapabilitiesKeyPath -Name "ApplicationDescription" -Value "mpv media player"
    Set-RegValue -Path $RegisteredAppsKey -Name "mpv" -Value "SOFTWARE\Clients\Media\mpv\Capabilities"

    # --- AutoPlay Handlers ---
    Log-Message "Adding AutoPlay handlers..."
    # DVD
    $dvdProgIdPath = Join-Path -Path $ClassesRootKey -ChildPath "io.mpv.dvd"
    Set-RegValue -Path (Join-Path $dvdProgIdPath "shell\play\command") -Name "(Default)" -Value "`"$MpvPath`" dvd:// --dvd-device=`"%L`""
    $dvdHandler = Join-Path -Path $AutoplayKeyBase -ChildPath "Handlers\MpvPlayDVDMovieOnArrival"
    Set-RegValue -Path $dvdHandler -Name "Action" -Value "Play DVD movie (mpv)"
    Set-RegValue -Path $dvdHandler -Name "Provider" -Value "mpv"
    Set-RegValue -Path $dvdHandler -Name "DefaultIcon" -Value $IconPath
    Set-RegValue -Path $dvdHandler -Name "InvokeProgID" -Value "io.mpv.dvd"
    Set-RegValue -Path $dvdHandler -Name "InvokeVerb" -Value "play"
    Set-RegValue -Path (Join-Path $AutoplayKeyBase "EventHandlers\PlayDVDMovieOnArrival") -Name "MpvPlayDVDMovieOnArrival" -Value ""
    # Blu-ray
    $bluRayProgIdPath = Join-Path -Path $ClassesRootKey -ChildPath "io.mpv.bluray"
    Set-RegValue -Path (Join-Path $bluRayProgIdPath "shell\play\command") -Name "(Default)" -Value "`"$MpvPath`" bd:// --bluray-device=`"%L`""
    $bluRayHandler = Join-Path -Path $AutoplayKeyBase -ChildPath "Handlers\MpvPlayBluRayOnArrival"
    Set-RegValue -Path $bluRayHandler -Name "Action" -Value "Play Blu-ray (mpv)"
    Set-RegValue -Path $bluRayHandler -Name "Provider" -Value "mpv"
    Set-RegValue -Path $bluRayHandler -Name "DefaultIcon" -Value $IconPath
    Set-RegValue -Path $bluRayHandler -Name "InvokeProgID" -Value "io.mpv.bluray"
    Set-RegValue -Path $bluRayHandler -Name "InvokeVerb" -Value "play"
    Set-RegValue -Path (Join-Path $AutoplayKeyBase "EventHandlers\PlayBluRayOnArrival") -Name "MpvPlayBluRayOnArrival" -Value ""

    # --- File Type Registration (Data-Driven) ---
    Log-Message "Registering file types..."
    $Global:ProgressBar.Maximum = $FileTypes.Count
    $Global:ProgressBar.Value = 0
    $Global:ProgressBar.Visible = $true

    $umpvwAppSupportedTypesPath = Join-Path -Path (Join-Path $AppKeyBase $UmpvwExeName) -ChildPath "SupportedTypes"
    $capabilitiesFileAssocPath = Join-Path -Path $CapabilitiesKeyPath -ChildPath "FileAssociations"

    foreach ($type in $FileTypes) {
        $Global:ProgressBar.Value++
        $extensions = $type.Extensions -split ',' | ForEach-Object { $_.Trim() }
        Log-Message "Registering: $($type.FriendlyName) ($($extensions -join ', '))" -Color "Gray"

        $progId = "io.mpv$($extensions[0])"
        $progIdPath = Join-Path -Path $ClassesRootKey -ChildPath $progId

        Set-RegValue -Path $progIdPath -Name "(Default)" -Value $type.FriendlyName
        # EditFlags: 0x00410000 -> FILE_ATTRIBUTE_NORMAL | DDE_EXEC_NO_CONSOLE
        Set-RegValue -Path $progIdPath -Name "EditFlags" -Value 0x410000 -Type DWord
        Set-RegValue -Path $progIdPath -Name "FriendlyTypeName" -Value $type.FriendlyName
        Set-RegValue -Path (Join-Path $progIdPath "DefaultIcon") -Name "(Default)" -Value $IconPath
        Add-MpvVerbs -KeyPath $progIdPath

        foreach ($ext in $extensions) {
            Set-RegValue -Path (Join-Path $ClassesRootKey "$ext\OpenWithProgids") -Name $progId -Value ""
            Set-RegValue -Path $umpvwAppSupportedTypesPath -Name $ext -Value ""
            Set-RegValue -Path $capabilitiesFileAssocPath -Name $ext -Value $progId
            if (-not [string]::IsNullOrEmpty($type.MimeType)) { Set-RegValue -Path (Join-Path $ClassesRootKey $ext) -Name "Content Type" -Value $type.MimeType }
            if (-not [string]::IsNullOrEmpty($type.PerceivedType)) { Set-RegValue -Path (Join-Path $ClassesRootKey $ext) -Name "PerceivedType" -Value $type.PerceivedType }
        }
    }
    $Global:ProgressBar.Visible = $false

    Log-Message "Installation complete!" -Color "Green"
    $Global:InstallButton.Text = "Re-install"
    $Global:InstallButton.Enabled = $true
    $Global:UninstallButton.Enabled = $true

    if ($Global:OpenDefaultProgramsCheckBox.Checked) {
        Log-Message "Opening Default Programs settings..."
        Start-Process "ms-settings:defaultapps"
    }
}

function Start-Uninstallation {
    # --- Confirmation ---
    $confirm = [System.Windows.Forms.MessageBox]::Show("Are you sure you want to completely uninstall mpv registrations? This will remove all file associations and registry keys created by this installer.", "Confirm Complete Uninstall", "YesNo", "Warning")
    if ($confirm -ne 'Yes') {
        Log-Message "Uninstallation cancelled." -Color "Orange"
        return
    }

    $Global:InstallButton.Enabled = $false
    $Global:UninstallButton.Enabled = $false
    Log-Message "Starting symmetrical mpv uninstallation..." -Color "DarkRed"

    # --- STAGE 1: Unregister file types (Reverse of File Type Registration) ---
    Log-Message "Unregistering file types..."
    $Global:ProgressBar.Maximum = $FileTypes.Count
    $Global:ProgressBar.Value = 0
    $Global:ProgressBar.Visible = $true
    
    foreach ($type in $FileTypes) {
        $Global:ProgressBar.Value++
        $extensions = $type.Extensions -split ',' | ForEach-Object { $_.Trim() }
        Log-Message "Unregistering: $($type.FriendlyName) ($($extensions -join ', '))" -Color "Gray"

        $progId = "io.mpv$($extensions[0])"
        
        foreach ($ext in $extensions) {
            # Remove link from extension's OpenWithProgids to our ProgId
            Remove-RegValue -Path (Join-Path $ClassesRootKey "$ext\OpenWithProgids") -Name $progId
            # Note: We don't touch "Content Type" or "PerceivedType" on uninstall to avoid
            # potentially breaking other apps if the value was pre-existing.
        }

        # Remove the ProgId key itself (io.mpv.mkv, etc.)
        Remove-RegKey -Path (Join-Path -Path $ClassesRootKey -ChildPath $progId)
    }
    $Global:ProgressBar.Visible = $false
    
    # --- STAGE 2: Unregister AutoPlay Handlers (Reverse Order) ---
    Log-Message "Removing AutoPlay handlers..."
    # Blu-ray
    Remove-RegValue -Path (Join-Path $AutoplayKeyBase "EventHandlers\PlayBluRayOnArrival") -Name "MpvPlayBluRayOnArrival"
    Remove-RegKey -Path (Join-Path $AutoplayKeyBase "Handlers\MpvPlayBluRayOnArrival")
    Remove-RegKey -Path (Join-Path -Path $ClassesRootKey -ChildPath "io.mpv.bluray")
    # DVD
    Remove-RegValue -Path (Join-Path $AutoplayKeyBase "EventHandlers\PlayDVDMovieOnArrival") -Name "MpvPlayDVDMovieOnArrival"
    Remove-RegKey -Path (Join-Path $AutoplayKeyBase "Handlers\MpvPlayDVDMovieOnArrival")
    Remove-RegKey -Path (Join-Path -Path $ClassesRootKey -ChildPath "io.mpv.dvd")

    # --- STAGE 3: Unregister Default Programs Capabilities (Reverse Order) ---
    Log-Message "Removing Capabilities for Default Programs..."
    Remove-RegValue -Path $RegisteredAppsKey -Name "mpv"
    # This next command removes the entire "HKLM\SOFTWARE\Clients\Media\mpv" key,
    # which includes the "Capabilities" subkey and all its file association values.
    Remove-RegKey -Path $MpvClientKeyPath

    # --- STAGE 4: Unregister Core Registrations (Reverse Order) ---
    Log-Message "Removing core application and path registrations..."
    # Generic 'Open with' list
    Remove-RegKey -Path "$ClassesRootKey\SystemFileAssociations\video\OpenWithList\$UmpvwExeName"
    Remove-RegKey -Path "$ClassesRootKey\SystemFileAssociations\audio\OpenWithList\$UmpvwExeName"
    
    # Applications key
    # This also removes the "SupportedTypes" subkey and shell verbs created during installation.
    Remove-RegKey -Path (Join-Path -Path $AppKeyBase -ChildPath $UmpvwExeName)

    # App Paths
    Remove-RegKey -Path (Join-Path -Path $AppPathsKeyBase -ChildPath $UmpvwExeName)
    
    # --- STAGE 5: Finalization ---
    Log-Message "Uninstallation complete! A system restart may be required for all changes to take full effect." -Color "DarkGreen"
    $Global:InstallButton.Text = "Install"
    $Global:InstallButton.Enabled = $true
    $Global:UninstallButton.Enabled = $true
    $Global:UninstallButton.Text = "Uninstall"
}

#endregion

#region --- GUI Setup and Main Execution ---

function Initialize-Form {
    # --- Form Creation ---
    $Global:MainForm = New-Object System.Windows.Forms.Form
    $MainForm.Text = "mpv Installer / Uninstaller"
    
    # Это заставляет форму и ее дочерние элементы корректно изменять размер
    # в соответствии с настройками масштабирования Windows (например, 150%).
    # Это ключевой шаг для исправления "мыльности".
    $MainForm.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Dpi

    $MainForm.Size = New-Object System.Drawing.Size(640, 520)
    $MainForm.StartPosition = "CenterScreen"
    $MainForm.FormBorderStyle = "FixedDialog"
    $MainForm.MaximizeBox = $false

    # --- Layout Panels for Responsive Design ---
    $MainTable = New-Object System.Windows.Forms.TableLayoutPanel
    $MainTable.Dock = "Fill"
    $MainTable.ColumnCount = 1
    $MainTable.RowCount = 4
    $MainTable.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) # LogBox
    $MainTable.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))     # ProgressBar
    $MainTable.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))     # Checkboxes
    $MainTable.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))     # Buttons
    $MainForm.Controls.Add($MainTable)

    # --- Log Text Box ---
    $Global:LogTextBox = New-Object System.Windows.Forms.RichTextBox
    $LogTextBox.Dock = "Fill"
    $LogTextBox.ReadOnly = $true
    $LogTextBox.Font = New-Object System.Drawing.Font("Consolas", 9)
    $LogTextBox.Margin = [System.Windows.Forms.Padding]::new(10, 10, 10, 5)
    $MainTable.Controls.Add($LogTextBox, 0, 0)

    # --- Progress Bar ---
    $Global:ProgressBar = New-Object System.Windows.Forms.ProgressBar
    $ProgressBar.Dock = "Fill"
    $ProgressBar.Margin = [System.Windows.Forms.Padding]::new(10, 0, 10, 5)
    $ProgressBar.Visible = $false
    $MainTable.Controls.Add($ProgressBar, 0, 1)

    # --- CheckBox Panel ---
    $CheckboxPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $CheckboxPanel.Dock = "Fill"
    $CheckboxPanel.FlowDirection = "TopDown"
    $CheckboxPanel.AutoSize = $true
    $CheckboxPanel.Margin = [System.Windows.Forms.Padding]::new(10, 0, 10, 5)
    $MainTable.Controls.Add($CheckboxPanel, 0, 2)

    $Global:OpenDefaultProgramsCheckBox = New-Object System.Windows.Forms.CheckBox
    $OpenDefaultProgramsCheckBox.Text = "Open 'Default Apps' settings after installation"
    $OpenDefaultProgramsCheckBox.AutoSize = $true
    $OpenDefaultProgramsCheckBox.Checked = $true
    $CheckboxPanel.Controls.Add($OpenDefaultProgramsCheckBox)

    # --- Button Panel ---
    $ButtonPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $ButtonPanel.Dock = "Fill"
    $ButtonPanel.FlowDirection = "RightToLeft"
    $ButtonPanel.AutoSize = $true
    $ButtonPanel.Margin = [System.Windows.Forms.Padding]::new(10, 5, 5, 10)
    $MainTable.Controls.Add($ButtonPanel, 0, 3)

    $CloseButton = New-Object System.Windows.Forms.Button
    $CloseButton.Text = "Close"
    $CloseButton.Size = New-Object System.Drawing.Size(100, 30)
    $CloseButton.add_Click({ $MainForm.Close() })
    $ButtonPanel.Controls.Add($CloseButton)

    $Global:UninstallButton = New-Object System.Windows.Forms.Button
    $UninstallButton.Text = "Uninstall"
    $UninstallButton.Size = New-Object System.Drawing.Size(140, 30)
    $UninstallButton.Font = New-Object System.Drawing.Font($UninstallButton.Font.FontFamily, 10, [System.Drawing.FontStyle]::Bold)
    $UninstallButton.add_Click({ Start-Uninstallation })
    $ButtonPanel.Controls.Add($UninstallButton)

    $Global:InstallButton = New-Object System.Windows.Forms.Button
    $InstallButton.Text = "Install"
    $InstallButton.Size = New-Object System.Drawing.Size(140, 30)
    $InstallButton.Font = New-Object System.Drawing.Font($InstallButton.Font.FontFamily, 10, [System.Drawing.FontStyle]::Bold)
    $InstallButton.add_Click({ Start-Installation })
    $ButtonPanel.Controls.Add($InstallButton)


    # --- Initial Status Checks ---
    Log-Message "mpv Installer/Uninstaller Initialized"
    Log-Message "mpv path: $MpvPath"
    Log-Message "Icon path: $IconPath"
    
    # Check if essential files exist
    if (-not (Test-Path $MpvPath -PathType Leaf)) {
        Log-Message "CRITICAL: mpv.exe not found. Installation is disabled." -Color Red
        $InstallButton.Enabled = $false
    }
    if (-not (Test-Path $IconPath -PathType Leaf)) {
        Log-Message "CRITICAL: mpv-icon.ico not found. Installation is disabled." -Color Red
        $InstallButton.Enabled = $false
    }

    # Check current installation state to set button text
    if (Test-Path $CapabilitiesKeyPath) {
        Log-Message "Detected existing mpv installation." -Color "Blue"
        $InstallButton.Text = "Re-install"
    }

    # --- Show Form ---
    [void]$MainForm.ShowDialog()
}

# --- Main Execution Block ---
function Main {
    # Check for Admin privileges and self-elevate if necessary
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        $params = "& '" + $PSCommandPath + "'"
        Start-Process powershell.exe -Verb RunAs -ArgumentList $params
        exit
    }
    
    # --- DPI AWARENESS FIX ---
    # Attempt to set DPI awareness using a direct P/Invoke call to the WinAPI.
    # This must be done BEFORE any UI elements are created to prevent blurriness on high-DPI displays.
    try {
        $csharpSignature = @"
        using System;
        using System.Runtime.InteropServices;
        public static class Win32 {
            [DllImport("user32.dll")]
            [return: MarshalAs(UnmanagedType.Bool)]
            public static extern bool SetProcessDPIAware();
        }
"@
        Add-Type -TypeDefinition $csharpSignature -ErrorAction Stop
        [Win32]::SetProcessDPIAware() | Out-Null
    }
    catch {
        Write-Warning "Failed to set process DPI awareness. GUI may appear blurry on scaled displays."
    }

    # Launch the GUI
    Initialize-Form
}

Main
#endregion
