#Requires -Version 5.1
#Requires -RunAsAdministrator

# --- Script Overview ---
# This script provides a graphical user interface to download and update mpv.
# IT IS A DOWNLOADER ONLY.
# 1. Downloads the 'mpv-anime' configuration from GitHub.
# 2. Extracts the 'mpv' folder to C:\ProgramData\mpv, overwriting existing files.
# 3. Creates a default settings.xml for the updater.
# 4. Runs the updater.bat script to fetch the player binaries.
# 5. Optionally, runs the integration script (install.bat) for file associations.

#region --- Configuration and Initial Setup ---

# Add required assemblies for GUI
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Script Configuration ---
$DownloadUrl = "https://github.com/Donate684/mpv-anime/archive/refs/heads/main.zip"
$InstallDir  = "C:\ProgramData\mpv"

# Temporary path for the downloaded zip file
$TempDir     = Join-Path $env:TEMP "mpv-downloader"
$ZipFileName = "main.zip"
$ZipFilePath = Join-Path $TempDir $ZipFileName

#endregion

#region --- Helper Functions ---

function Log-Message($Message, $Color = "Black") {
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

#endregion

#region --- Core Installation Logic ---

function Start-Installation {
    $Global:InstallButton.Enabled = $false
    Log-Message "Starting mpv download and setup..." -Color "DarkBlue"

    try {
        # --- STAGE 1: Download ---
        Log-Message "[1/5] Creating temporary directory..."
        if (Test-Path $TempDir) { Remove-Item -Path $TempDir -Recurse -Force }
        New-Item -Path $TempDir -ItemType Directory -Force -ErrorAction Stop | Out-Null
        
        Log-Message "[1/5] Downloading from: $DownloadUrl"
        $Global:ProgressBar.Visible = $true
        $Global:ProgressBar.Style = "Marquee"
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $ZipFilePath -ErrorAction Stop
        Log-Message "[1/5] Download complete." -Color "Green"

        # --- STAGE 2: Unpack and Move Files ---
        $Global:ProgressBar.Style = "Continuous"
        Log-Message "[2/5] Unpacking archive..."
        $UnpackTempDir = Join-Path $TempDir "unpacked"
        New-Item -Path $UnpackTempDir -ItemType Directory -Force | Out-Null
        Expand-Archive -Path $ZipFilePath -DestinationPath $UnpackTempDir -Force
        $RepoRootFolder = Get-ChildItem -Path $UnpackTempDir -Directory | Select-Object -First 1
        if (-not $RepoRootFolder) { throw "Could not find root folder in ZIP." }
        $MpvSourcePath = Join-Path -Path $RepoRootFolder.FullName -ChildPath "mpv"
        if (-not (Test-Path $MpvSourcePath -PathType Container)) { throw "Required 'mpv' subfolder not found in archive." }
        New-Item -Path $InstallDir -ItemType Directory -Force | Out-Null
        Move-Item -Path ($MpvSourcePath + "\*") -Destination $InstallDir -Force
        Log-Message "[2/5] Unpacking and moving files complete."

        # --- STAGE 3: Create settings.xml ---
        Log-Message "[3/5] Creating settings.xml..."
        $SettingsXmlContent = @"
<settings>
  <channel>weekly</channel>
  <arch>x86_64-v3</arch>
  <autodelete>true</autodelete>
  <getffmpeg>true</getffmpeg>
</settings>
"@
        Set-Content -Path (Join-Path $InstallDir "settings.xml") -Value $SettingsXmlContent -Encoding UTF8
        Log-Message "[3/5] settings.xml created."

        # --- STAGE 4: Run updater.bat ---
        Log-Message "[4/5] Running updater.bat to fetch player binaries..."
        $UpdaterBatPath = Join-Path -Path $InstallDir -ChildPath "updater.bat"
        if (Test-Path $UpdaterBatPath) {
            $process = Start-Process -FilePath $UpdaterBatPath -WorkingDirectory $InstallDir -Wait -PassThru
            if ($process.ExitCode -ne 0) {
                Log-Message "WARNING: updater.bat finished with exit code: $($process.ExitCode)." -Color "Orange"
            } else {
                Log-Message "[4/5] updater.bat completed successfully."
            }
        } else {
            Log-Message "[4/5] updater.bat not found, skipping." -Color "Gray"
        }
        
        # --- STAGE 5: Run integration script (Optional) ---
        Log-Message "[5/5] Checking for system integration..."
        if ($Global:IntegrationCheckBox.Checked) {
            $IntegrationScriptPath = "C:\ProgramData\mpv\installer\install.bat"
            Log-Message "Attempting to run integration script at: $IntegrationScriptPath"
            if (Test-Path $IntegrationScriptPath) {
                try {
                    $process = Start-Process -FilePath $IntegrationScriptPath -WorkingDirectory (Split-Path $IntegrationScriptPath -Parent) -Wait -PassThru
                    if ($process.ExitCode -ne 0) {
                        Log-Message "WARNING: Integration script finished with exit code: $($process.ExitCode)." -Color "Orange"
                    } else {
                        Log-Message "Integration script completed successfully."
                    }
                } catch {
                    Log-Message "ERROR: Failed to run integration script. $_" -Color Red
                }
            } else {
                Log-Message "Integration script not found at '$IntegrationScriptPath', skipping." -Color "Gray"
            }
        } else {
            Log-Message "Skipping system integration as per user choice."
        }

        Log-Message "Process complete!" -Color "DarkGreen"

    } catch {
        Log-Message "FATAL ERROR: $_" -Color "Red"
    } finally {
        if (Test-Path $TempDir) { Remove-Item -Path $TempDir -Recurse -Force }
        $Global:ProgressBar.Visible = $false
        $Global:InstallButton.Enabled = $true
    }
}

#endregion

#region --- GUI Setup and Main Execution ---

function Initialize-Form {
    $Global:MainForm = New-Object System.Windows.Forms.Form
    $MainForm.Text = "mpv Downloader"
    $MainForm.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Dpi
    $MainForm.Size = New-Object System.Drawing.Size(640, 480)
    $MainForm.StartPosition = "CenterScreen"
    $MainForm.FormBorderStyle = "FixedDialog"
    $MainForm.MaximizeBox = $false

    $MainTable = New-Object System.Windows.Forms.TableLayoutPanel
    $MainTable.Dock = "Fill"; $MainTable.ColumnCount = 1; $MainTable.RowCount = 4
    $MainTable.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    $MainTable.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
    $MainTable.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
    $MainForm.Controls.Add($MainTable)

    $Global:LogTextBox = New-Object System.Windows.Forms.RichTextBox
    $LogTextBox.Dock = "Fill"; $LogTextBox.ReadOnly = $true
    $LogTextBox.Font = New-Object System.Drawing.Font("Consolas", 9)
    $LogTextBox.Margin = [System.Windows.Forms.Padding]::new(10, 10, 10, 5)
    $MainTable.Controls.Add($LogTextBox, 0, 0)

    $Global:ProgressBar = New-Object System.Windows.Forms.ProgressBar
    $ProgressBar.Dock = "Fill"; $ProgressBar.Visible = $false
    $ProgressBar.Margin = [System.Windows.Forms.Padding]::new(10, 0, 10, 5)
    $MainTable.Controls.Add($ProgressBar, 0, 1)

    $CheckboxPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $CheckboxPanel.Dock = "Fill"; $CheckboxPanel.FlowDirection = "TopDown"
    $CheckboxPanel.AutoSize = $true; $CheckboxPanel.Padding = [System.Windows.Forms.Padding]::new(10, 5, 10, 5)
    $MainTable.Controls.Add($CheckboxPanel, 0, 2)
    
    $Global:IntegrationCheckBox = New-Object System.Windows.Forms.CheckBox
    $IntegrationCheckBox.Text = "Вызвать механизм интеграции в систему"
    $IntegrationCheckBox.AutoSize = $true
    $IntegrationCheckBox.Checked = $true
    $CheckboxPanel.Controls.Add($IntegrationCheckBox)

    $ButtonPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $ButtonPanel.Dock = "Fill"; $ButtonPanel.FlowDirection = "RightToLeft"
    $ButtonPanel.AutoSize = $true; $ButtonPanel.Padding = [System.Windows.Forms.Padding]::new(10, 5, 5, 10)
    $MainTable.SetRow($ButtonPanel, 3) # Explicitly set row for the panel
    $MainTable.Controls.Add($ButtonPanel)

    $CloseButton = New-Object System.Windows.Forms.Button
    $CloseButton.Text = "Close"; $CloseButton.Size = New-Object System.Drawing.Size(100, 30)
    $CloseButton.add_Click({ $MainForm.Close() })
    $ButtonPanel.Controls.Add($CloseButton)

    $Global:InstallButton = New-Object System.Windows.Forms.Button
    $InstallButton.Text = "Download & Run Updater"
    $InstallButton.Size = New-Object System.Drawing.Size(200, 30)
    $InstallButton.Font = New-Object System.Drawing.Font($InstallButton.Font.FontFamily, 10, [System.Drawing.FontStyle]::Bold)
    $InstallButton.add_Click({ Start-Installation })
    $ButtonPanel.Controls.Add($InstallButton)

    Log-Message "Downloader Initialized."
    Log-Message "Target directory: $InstallDir"
    
    [void]$MainForm.ShowDialog()
}

function Main {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        $params = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        Start-Process powershell.exe -Verb RunAs -ArgumentList $params
        exit
    }
    
    try {
        Add-Type -TypeDefinition @"
        using System; using System.Runtime.InteropServices;
        public static class Win32 {
            [DllImport("user32.dll")]
            public static extern bool SetProcessDPIAware();
        }
"@
        [Win32]::SetProcessDPIAware() | Out-Null
    } catch {
        Write-Warning "Failed to set DPI awareness. GUI may appear blurry."
    }

    Initialize-Form
}

Main
#endregion
