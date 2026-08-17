# ==============================================================================
#  AUTOMATED WINPE DEPLOYMENT ENGINE
# ==============================================================================

# Dynamically locate the directory where Deploy.ps1 is executed from
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

Clear-Host
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "     COM AUTOMATED WINPE DEPLOYMENT SYSTEM     " -ForegroundColor Cyan
Write-Host "      Author & Developer: Mohammad Kassas      " -ForegroundColor Yellow
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

# ------------------------------------------------------------------------------
# 1. HARDWARE & FILE SYSTEM SCANNING
# ------------------------------------------------------------------------------
Write-Host "[1/5] Scanning physical storage drives..." -ForegroundColor Yellow

# Query non-USB internal physical disks and rank them by speed (NVMe > SSD > HDD)
$Disks = Get-PhysicalDisk | Where-Object { $_.BusType -ne 'USB' -and $_.OperationalStatus -eq 'OK' } | 
    Sort-Object -Property @{Expression={$_.MediaType -eq 'NVMe'}; Descending=$true},
                          @{Expression={$_.MediaType -eq 'SSD'};  Descending=$true}

if (-not $Disks) {
    Write-Host "[ERROR] No internal storage drives (NVMe/SSD/HDD) detected!" -ForegroundColor Red
    return
}

# Dynamically scan the 'Image' folder for available .wim files
$ImageFolder = Join-Path -Path $ScriptDir -ChildPath "Image"
Write-Host "[2/5] Scanning folder for OS WIM images..." -ForegroundColor Yellow

if (Test-Path $ImageFolder) {
    $WimFiles = Get-ChildItem -Path $ImageFolder -Filter "*.wim"
} else {
    $WimFiles = @()
}

if (-not $WimFiles) {
    Write-Host "[ERROR] No .wim image files found in '$ImageFolder'!" -ForegroundColor Red
    return
}

# Dynamically scan the 'Partition' folder for partition script files
$PartitionFolder = Join-Path -Path $ScriptDir -ChildPath "Partition"
Write-Host "[3/5] Scanning folder for Partition scripts..." -ForegroundColor Yellow

if (Test-Path $PartitionFolder) {
    $PartitionFiles = Get-ChildItem -Path $PartitionFolder -File
} else {
    $PartitionFiles = @()
}

if (-not $PartitionFiles) {
    Write-Host "[ERROR] No partition files found in '$PartitionFolder'!" -ForegroundColor Red
    return
}

# Defaults Setup
$DefaultDisk = $Disks[0]

# OS Default: 'Win1125H2New.wim'
$PreferredWimName = "Win1125H2New.wim"
$FoundPreferredWim = $WimFiles | Where-Object { $_.Name -eq $PreferredWimName } | Select-Object -First 1
$DefaultWim = if ($FoundPreferredWim) { $FoundPreferredWim.Name } else { $WimFiles[0].Name }

# Partition Default: 'SFF Dell CreatePartitions-SSD' (or .txt equivalent)
$PreferredPartName = "SFF Dell CreatePartitions-SSD"
$FoundPreferredPart = $PartitionFiles | Where-Object { $_.BaseName -eq $PreferredPartName -or $_.Name -eq $PreferredPartName } | Select-Object -First 1
$DefaultPartFile = if ($FoundPreferredPart) { $FoundPreferredPart.Name } else { $PartitionFiles[0].Name }

# Hash table to record all user responses before running commands
$Config = @{
    TargetDiskIndex = $DefaultDisk.DeviceID
    TargetDiskName  = $DefaultDisk.FriendlyName
    TargetDiskType  = $DefaultDisk.MediaType
    DiskpartScript  = $DefaultPartFile
    OSImage         = $DefaultWim
    InjectUnattend  = $true
    RebootAtEnd     = $true
}

Write-Host "  -> Storage Auto-Detected : Disk $($Config.TargetDiskIndex) [$($Config.TargetDiskName) - $($Config.TargetDiskType)]" -ForegroundColor Green
Write-Host "  -> Default OS Image      : $($Config.OSImage)" -ForegroundColor Green
Write-Host "  -> Default Partition     : $($Config.DiskpartScript)" -ForegroundColor Green
Write-Host ""

# ------------------------------------------------------------------------------
# 2. USER CHOICE GATHERING PHASE (RECORD ANSWERS ONLY)
# ------------------------------------------------------------------------------
Write-Host "Please answer the configuration questions below." -ForegroundColor Cyan
Write-Host "--------------------------------------------------" -ForegroundColor DarkGray

# Q1: Target Disk Confirmation / Selection
Write-Host "Target Disk Selection:"
Write-Host " [0] Auto-Select Fastest: Disk $($Config.TargetDiskIndex) ($($Config.TargetDiskName))"
for ($i = 0; $i -lt $Disks.Count; $i++) {
    Write-Host " [$($i+1)] Disk $($Disks[$i].DeviceID): $($Disks[$i].FriendlyName) ($($Disks[$i].MediaType))"
}
$DiskChoice = Read-Host " Select drive number (Press Enter for Default [$($Config.TargetDiskIndex)])"
if ($DiskChoice -and $DiskChoice -ne '0') {
    $SelectedIndex = [int]$DiskChoice - 1
    if ($SelectedIndex -ge 0 -and $SelectedIndex -lt $Disks.Count) {
        $Config.TargetDiskIndex = $Disks[$SelectedIndex].DeviceID
        $Config.TargetDiskName  = $Disks[$SelectedIndex].FriendlyName
        $Config.TargetDiskType  = $Disks[$SelectedIndex].MediaType
    }
}

#Extra Disks Formatting (Calculated AFTER OS disk is chosen)
$RemainingDisks = $Disks | Where-Object { $_.DeviceID -ne $Config.TargetDiskIndex }

if ($RemainingDisks.Count -gt 0) {
    Write-Host "`nExtra Storage Drives Detected:"
    for ($i = 0; $i -lt $RemainingDisks.Count; $i++) {
        Write-Host " [$($i+1)] Disk $($RemainingDisks[$i].DeviceID): $($RemainingDisks[$i].FriendlyName)"
    }
    Write-Host " Select disks to wipe and format as empty Data drives."
    Write-Host " (Type '1', or '1,2' for multiple, or 'all'. Press Enter to skip)"
    
    $Valid = $false
    do {
        $FormatChoice = Read-Host " Format selection"
        
        if ([string]::IsNullOrWhiteSpace($FormatChoice)) {
            $Valid = $true # User wants to skip
        } elseif ($FormatChoice.ToLower() -eq 'all') {
            $Config.ExtraDisks = $RemainingDisks.DeviceID
            $Valid = $true
        } else {
            # Validate comma-separated list
            $SelectedIndices = $FormatChoice -split ',' | ForEach-Object { $_.Trim() }
            $AllNumbersValid = $true
            $TempExtraDisks = @()
            
            foreach ($idx in $SelectedIndices) {
                if ($idx -match '^\d+$' -and [int]$idx -ge 1 -and [int]$idx -le $RemainingDisks.Count) {
                    $i = [int]$idx - 1
                    $TempExtraDisks += $RemainingDisks[$i].DeviceID
                } else {
                    $AllNumbersValid = $false
                }
            }
            
            if ($AllNumbersValid -and $TempExtraDisks.Count -gt 0) {
                $Config.ExtraDisks = $TempExtraDisks
                $Valid = $true
            } else {
                Write-Host "[!] Invalid input. Please enter 'all', valid numbers like '1' or '1,2', or press Enter to skip." -ForegroundColor Red
            }
        }
    } until ($Valid)
}


# Q2: Dynamic Partition Scheme Selection
Write-Host "`nPartition Scheme Selection:"
for ($i = 0; $i -lt $PartitionFiles.Count; $i++) {
    $Tag = if ($PartitionFiles[$i].Name -eq $Config.DiskpartScript) { " (Default)" } else { "" }
    Write-Host " [$($i+1)] $($PartitionFiles[$i].Name)$Tag"
}

$Valid = $false

do {
    $PartChoice = Read-Host " Select Option (Press Enter for Default [$($Config.DiskpartScript)])"
    
    # Check if user just pressed Enter (Accept Default)
    if ([string]::IsNullOrWhiteSpace($PartChoice)) {
        $Valid = $true 
    } 
    # Check if user entered a valid integer
    elseif ([int]::TryParse($PartChoice, [ref]$null)) {
        $PartIndex = [int]$PartChoice - 1
        
        # Check if the integer is within the valid range of available files
        if ($PartIndex -ge 0 -and $PartIndex -lt $PartitionFiles.Count) {
            $Config.DiskpartScript = $PartitionFiles[$PartIndex].Name
            $Valid = $true
        } else {
            Write-Host "[!] Invalid number. Please enter a number between 1 and $($PartitionFiles.Count)." -ForegroundColor Red
        }
    } 
    # User entered text/symbols instead of a number
    else {
        Write-Host "[!] Invalid input. Please enter a valid number or press Enter." -ForegroundColor Red
    }
} until ($Valid)


# Q3: Dynamic Operating System Selection
Write-Host "`nWindows Version Selection:"
for ($i = 0; $i -lt $WimFiles.Count; $i++) {
    $Tag = if ($WimFiles[$i].Name -eq $Config.OSImage) { " (Default)" } else { "" }
    Write-Host " [$($i+1)] $($WimFiles[$i].Name)$Tag"
}

$Valid = $false
do {
    $OSChoice = Read-Host " Select OS (Press Enter for Default [$($Config.OSImage)])"
    
    if ([string]::IsNullOrWhiteSpace($OSChoice)) {
        $Valid = $true 
    } 
    elseif ([int]::TryParse($OSChoice, [ref]$null)) {
        $OSIndex = [int]$OSChoice - 1
        
        if ($OSIndex -ge 0 -and $OSIndex -lt $WimFiles.Count) {
            $Config.OSImage = $WimFiles[$OSIndex].Name
            $Valid = $true
        } else {
            Write-Host "[!] Invalid number. Please enter a number between 1 and $($WimFiles.Count)." -ForegroundColor Red
        }
    } 
    else {
        Write-Host "[!] Invalid input. Please enter a valid number or press Enter." -ForegroundColor Red
    }
} until ($Valid)

# Q4: Unattend Credentials Injection Selection
Write-Host "`nOOBE / Credentials Bypass:"
Write-Host " Automatically apply company regional, network, and admin settings?"

$Valid = $false
do {
    $UnattendChoice = Read-Host " Inject default settings? [Y/N] (Press Enter for Default [Y])"
    
    if ([string]::IsNullOrWhiteSpace($UnattendChoice)) {
        # User pressed Enter, keep default (assumes $Config.InjectUnattend is $true by default)
        $Valid = $true 
    } 
    elseif ($UnattendChoice -match '^[Yy]$') {
        $Config.InjectUnattend = $true
        $Valid = $true
    } 
    elseif ($UnattendChoice -match '^[Nn]$') {
        $Config.InjectUnattend = $false
        $Valid = $true
    } 
    else {
        Write-Host "[!] Invalid input. Please type Y for Yes, N for No, or press Enter." -ForegroundColor Red
    }
} until ($Valid)

# Q5: Post-Install Action Selection
Write-Host "`nCompletion Action:"

$Valid = $false
do {
    $RebootChoice = Read-Host " Reboot automatically when setup completes? [Y/N] (Press Enter for Default [Y])"
    
    if ([string]::IsNullOrWhiteSpace($RebootChoice)) {
        # User pressed Enter, keep default (assumes $Config.RebootAtEnd is $true by default)
        $Valid = $true 
    } 
    elseif ($RebootChoice -match '^[Yy]$') {
        $Config.RebootAtEnd = $true
        $Valid = $true
    } 
    elseif ($RebootChoice -match '^[Nn]$') {
        $Config.RebootAtEnd = $false
        $Valid = $true
    } 
    else {
        Write-Host "[!] Invalid input. Please type Y for Yes, N for No, or press Enter." -ForegroundColor Red
    }
} until ($Valid)

# ------------------------------------------------------------------------------
# 3. CONFIRMATION CHECKPOINT
# ------------------------------------------------------------------------------
Clear-Host
Write-Host "==================================================" -ForegroundColor Yellow
Write-Host "          CONFIRM DEPLOYMENT SETTINGS             " -ForegroundColor Yellow
Write-Host "==================================================" -ForegroundColor Yellow
Write-Host " Target Drive    : Disk $($Config.TargetDiskIndex) ($($Config.TargetDiskName))"
Write-Host " Partition Script: $($Config.DiskpartScript)"
Write-Host " Windows Image   : $($Config.OSImage)"
Write-Host " Auto Credentials: $($Config.InjectUnattend)"
Write-Host " Auto Reboot     : $($Config.RebootAtEnd)"
Write-Host "==================================================" -ForegroundColor Yellow
Write-Host " WARNING: ALL DATA ON DISK $($Config.TargetDiskIndex) WILL BE WIPED!" -ForegroundColor Red
Write-Host ""

$Confirm = Read-Host "Type 'YES' to begin installation"

if ($Confirm -ne "YES" -and $Confirm -ne "yes") {
    Write-Host "`nDeployment cancelled by user. Exiting script." -ForegroundColor Red
    return
}

# ------------------------------------------------------------------------------
# 4. EXECUTION PHASE
# ------------------------------------------------------------------------------
Clear-Host

if ($Config.ExtraDisks.Count -gt 0) {
    Write-Host "[*] Formatting Additional Data Drives..." -ForegroundColor Cyan
    foreach ($ExtraDisk in $Config.ExtraDisks) {
        Write-Host " -> Cleaning and formatting Disk $ExtraDisk as NTFS Data drive..."
        
        $DPData = @"
select disk $ExtraDisk
clean
convert gpt
create partition primary
format quick fs=ntfs label="Data"
assign
exit
"@
        $DPData | Out-File "$ScriptDir\dp_extra.txt" -Encoding ASCII
        diskpart /s "$ScriptDir\dp_extra.txt" | Out-Null
        Remove-Item "$ScriptDir\dp_extra.txt" -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "[1/4] Partitioning Target Disk using $($Config.DiskpartScript)..." -ForegroundColor Cyan

# 1. Read the contents of the selected partition script
$DPOS = Get-Content "$ScriptDir\Partition\$($Config.DiskpartScript)"

# 2. Dynamically replace target disk index
$DPOS = $DPOS -replace "select disk \d+", "select disk $($Config.TargetDiskIndex)"

# 3. Save to temp script and execute
$DPOS | Out-File "$ScriptDir\dp_os_temp.txt" -Encoding ASCII
diskpart /s "$ScriptDir\dp_os_temp.txt"
Remove-Item "$ScriptDir\dp_os_temp.txt" -Force -ErrorAction SilentlyContinue

# Auto-detect target drive letter (Checks W: first, falls back to B:)
$TargetDrive = if (Test-Path "W:\") { "W:" } elseif (Test-Path "B:\") { "B:" } else { "W:" }

Write-Host "`n[2/4] Applying OS Image ($($Config.OSImage)) to drive $TargetDrive..." -ForegroundColor Cyan
dism /Apply-Image /ImageFile:"$ScriptDir\Image\$($Config.OSImage)" /Index:1 /ApplyDir:"$TargetDrive\"

Write-Host "`n[3/4] Configuring Boot Files..." -ForegroundColor Cyan
& "$TargetDrive\Windows\System32\bcdboot.exe" "$TargetDrive\Windows" /s S:

# Step: Configure Windows Recovery Environment (WinRE)
Write-Host "`n[*] Configuring Windows Recovery Environment (WinRE)..." -ForegroundColor Cyan

$WinRESource = "$TargetDrive\Windows\System32\Recovery\Winre.wim"
$WinREDestDir = "R:\Recovery\WindowsRE"

if (Test-Path $WinRESource) {
    # 1. Create destination folder
    New-Item -ItemType Directory -Path $WinREDestDir -Force | Out-Null
    
    # 2. Copy Winre.wim
    Copy-Item -Path $WinRESource -Destination "$WinREDestDir\Winre.wim" -Force
    attrib +h +s "$WinREDestDir\Winre.wim"
    
    # 3. Register using the TARGET OS Reagentc.exe (Matches ApplyImage.bat behavior)
    & "$TargetDrive\Windows\System32\Reagentc.exe" /setreimage /path $WinREDestDir /target "$TargetDrive\Windows"
    & "$TargetDrive\Windows\System32\Reagentc.exe" /info /target "$TargetDrive\Windows"
    
    # 4. Hide Recovery Partition letter R:
    Get-Partition -DriveLetter 'R' | Remove-PartitionAccessPath -AccessPath 'R:\' -ErrorAction SilentlyContinue
    
    Write-Host " -> WinRE successfully registered." -ForegroundColor Green
} else {
    Write-Host " -> [WARNING] Winre.wim not found. Skipping WinRE configuration." -ForegroundColor Yellow
}

if ($Config.InjectUnattend) {
    Write-Host "`n[4/4] Injecting Automated Unattend Answer File..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Path "$TargetDrive\Windows\Panther" -Force | Out-Null
    Copy-Item "$ScriptDir\unattend.xml" -Destination "$TargetDrive\Windows\Panther\unattend.xml" -Force
} else {
    Write-Host "`n[4/4] Skipping Unattend Answer File Injection." -ForegroundColor Gray
}

Write-Host "`n==================================================" -ForegroundColor Green
Write-Host "       WINDOWS DEPLOYMENT COMPLETED SUCCESS       " -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green

if ($Config.RebootAtEnd) {
    Write-Host "Rebooting in 5 seconds..." -ForegroundColor Yellow
    Start-Sleep -Seconds 5
    wpeutil reboot
} else {
    Write-Host "Script completed. You may now close WinPE manually." -ForegroundColor Yellow
}
