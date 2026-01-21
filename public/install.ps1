# Clawdbot Installer for Windows
# Usage: iwr -useb https://clawd.bot/install.ps1 | iex
#        & ([scriptblock]::Create((iwr -useb https://clawd.bot/install.ps1))) -Tag beta -NoOnboard -DryRun

param(
    [string]$Tag = "latest",
    [ValidateSet("npm", "git")]
    [string]$InstallMethod = "npm",
    [string]$GitDir,
    [switch]$NoOnboard,
    [switch]$NoGitUpdate,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "  Clawdbot Installer" -ForegroundColor Cyan
Write-Host ""

# Check if running in PowerShell
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Host "Error: PowerShell 5+ required" -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Windows detected" -ForegroundColor Green

if (-not $PSBoundParameters.ContainsKey("InstallMethod")) {
    if (-not [string]::IsNullOrWhiteSpace($env:CLAWDBOT_INSTALL_METHOD)) {
        $InstallMethod = $env:CLAWDBOT_INSTALL_METHOD
    }
}
if (-not $PSBoundParameters.ContainsKey("GitDir")) {
    if (-not [string]::IsNullOrWhiteSpace($env:CLAWDBOT_GIT_DIR)) {
        $GitDir = $env:CLAWDBOT_GIT_DIR
    }
}
if (-not $PSBoundParameters.ContainsKey("NoOnboard")) {
    if ($env:CLAWDBOT_NO_ONBOARD -eq "1") {
        $NoOnboard = $true
    }
}
if (-not $PSBoundParameters.ContainsKey("NoGitUpdate")) {
    if ($env:CLAWDBOT_GIT_UPDATE -eq "0") {
        $NoGitUpdate = $true
    }
}
if (-not $PSBoundParameters.ContainsKey("DryRun")) {
    if ($env:CLAWDBOT_DRY_RUN -eq "1") {
        $DryRun = $true
    }
}

if ([string]::IsNullOrWhiteSpace($GitDir)) {
    $userHome = [Environment]::GetFolderPath("UserProfile")
    $GitDir = (Join-Path $userHome "clawdbot")
}

# Check for Node.js
function Check-Node {
    try {
        $nodeVersion = (node -v 2>$null)
        if ($nodeVersion) {
            $version = [int]($nodeVersion -replace 'v(\d+)\..*', '$1')
            if ($version -ge 22) {
                Write-Host "[OK] Node.js $nodeVersion found" -ForegroundColor Green
                return $true
            } else {
                Write-Host "[!] Node.js $nodeVersion found, but v22+ required" -ForegroundColor Yellow
                return $false
            }
        }
    } catch {
        Write-Host "[!] Node.js not found" -ForegroundColor Yellow
        return $false
    }
    return $false
}

# Install Node.js
function Install-Node {
    Write-Host "[*] Installing Node.js..." -ForegroundColor Yellow

    # Try winget first (Windows 11 / Windows 10 with App Installer)
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "  Using winget..." -ForegroundColor Gray
        winget install OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements

        # Refresh PATH
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        Write-Host "[OK] Node.js installed via winget" -ForegroundColor Green
        return
    }

    # Try Chocolatey
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Host "  Using Chocolatey..." -ForegroundColor Gray
        choco install nodejs-lts -y

        # Refresh PATH
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        Write-Host "[OK] Node.js installed via Chocolatey" -ForegroundColor Green
        return
    }

    # Try Scoop
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        Write-Host "  Using Scoop..." -ForegroundColor Gray
        scoop install nodejs-lts
        Write-Host "[OK] Node.js installed via Scoop" -ForegroundColor Green
        return
    }

    # Manual download fallback
    Write-Host ""
    Write-Host "Error: Could not find a package manager (winget, choco, or scoop)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please install Node.js 22+ manually:" -ForegroundColor Yellow
    Write-Host "  https://nodejs.org/en/download/" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Or install winget (App Installer) from the Microsoft Store." -ForegroundColor Gray
    exit 1
}

# Check for existing Clawdbot installation
function Check-ExistingClawdbot {
    try {
        $null = Get-Command clawdbot -ErrorAction Stop
    Write-Host "[*] Existing Clawdbot installation detected" -ForegroundColor Yellow
    return $true
    } catch {
        return $false
    }
}

function Check-Git {
    try {
        $null = Get-Command git -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Require-Git {
    if (Check-Git) { return }
    Write-Host ""
    Write-Host "Error: Git is required for --InstallMethod git." -ForegroundColor Red
    Write-Host "Install Git for Windows:" -ForegroundColor Yellow
    Write-Host "  https://git-scm.com/download/win" -ForegroundColor Cyan
    Write-Host "Then re-run this installer." -ForegroundColor Yellow
    exit 1
}

function Ensure-Pnpm {
    if (Get-Command pnpm -ErrorAction SilentlyContinue) {
        return
    }
    if (Get-Command corepack -ErrorAction SilentlyContinue) {
        try {
            corepack enable | Out-Null
            corepack prepare pnpm@latest --activate | Out-Null
            if (Get-Command pnpm -ErrorAction SilentlyContinue) {
                Write-Host "[OK] pnpm installed via corepack" -ForegroundColor Green
                return
            }
        } catch {
            # fallthrough to npm install
        }
    }
    Write-Host "[*] Installing pnpm..." -ForegroundColor Yellow
    npm install -g pnpm
    Write-Host "[OK] pnpm installed" -ForegroundColor Green
}

# Install Clawdbot
function Install-Clawdbot {
    if ([string]::IsNullOrWhiteSpace($Tag)) {
        $Tag = "latest"
    }
    Write-Host "[*] Installing Clawdbot@$Tag..." -ForegroundColor Yellow
    $prevLogLevel = $env:NPM_CONFIG_LOGLEVEL
    $prevUpdateNotifier = $env:NPM_CONFIG_UPDATE_NOTIFIER
    $prevFund = $env:NPM_CONFIG_FUND
    $prevAudit = $env:NPM_CONFIG_AUDIT
    $env:NPM_CONFIG_LOGLEVEL = "error"
    $env:NPM_CONFIG_UPDATE_NOTIFIER = "false"
    $env:NPM_CONFIG_FUND = "false"
    $env:NPM_CONFIG_AUDIT = "false"
    try {
        npm install -g "clawdbot@$Tag"
    } finally {
        $env:NPM_CONFIG_LOGLEVEL = $prevLogLevel
        $env:NPM_CONFIG_UPDATE_NOTIFIER = $prevUpdateNotifier
        $env:NPM_CONFIG_FUND = $prevFund
        $env:NPM_CONFIG_AUDIT = $prevAudit
    }
    Write-Host "[OK] Clawdbot installed" -ForegroundColor Green
}

# Install Clawdbot from GitHub
function Install-ClawdbotFromGit {
    param(
        [string]$RepoDir,
        [switch]$SkipUpdate
    )
    Require-Git
    Ensure-Pnpm

    $repoUrl = "https://github.com/clawdbot/clawdbot.git"
    Write-Host "[*] Installing Clawdbot from GitHub ($repoUrl)..." -ForegroundColor Yellow

    if (-not (Test-Path $RepoDir)) {
        git clone $repoUrl $RepoDir
    }

    if (-not $SkipUpdate) {
        if (-not (git -C $RepoDir status --porcelain 2>$null)) {
            git -C $RepoDir pull --rebase 2>$null
        } else {
            Write-Host "[!] Repo is dirty; skipping git pull" -ForegroundColor Yellow
        }
    } else {
        Write-Host "[!] Git update disabled; skipping git pull" -ForegroundColor Yellow
    }

    Remove-LegacySubmodule -RepoDir $RepoDir

    pnpm -C $RepoDir install
    if (-not (pnpm -C $RepoDir ui:build)) {
        Write-Host "[!] UI build failed; continuing (CLI may still work)" -ForegroundColor Yellow
    }
    pnpm -C $RepoDir build

    $binDir = Join-Path $env:USERPROFILE ".local\\bin"
    if (-not (Test-Path $binDir)) {
        New-Item -ItemType Directory -Force -Path $binDir | Out-Null
    }
    $cmdPath = Join-Path $binDir "clawdbot.cmd"
    $cmdContents = "@echo off`r`nnode ""$RepoDir\\dist\\entry.js"" %*`r`n"
    Set-Content -Path $cmdPath -Value $cmdContents -NoNewline

    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if (-not ($userPath -split ";" | Where-Object { $_ -ieq $binDir })) {
        [Environment]::SetEnvironmentVariable("Path", "$userPath;$binDir", "User")
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        Write-Host "[!] Added $binDir to user PATH (restart terminal if command not found)" -ForegroundColor Yellow
    }

    Write-Host "[OK] Clawdbot wrapper installed to $cmdPath" -ForegroundColor Green
    Write-Host "[i] This checkout uses pnpm. For deps, run: pnpm install (avoid npm install in the repo)." -ForegroundColor Gray
}

# Run doctor for migrations (safe, non-interactive)
function Run-Doctor {
    Write-Host "[*] Running doctor to migrate settings..." -ForegroundColor Yellow
    try {
        clawdbot doctor --non-interactive
    } catch {
        # Ignore errors from doctor
    }
    Write-Host "[OK] Migration complete" -ForegroundColor Green
}

function Get-LegacyRepoDir {
    if (-not [string]::IsNullOrWhiteSpace($env:CLAWDBOT_GIT_DIR)) {
        return $env:CLAWDBOT_GIT_DIR
    }
    $userHome = [Environment]::GetFolderPath("UserProfile")
    return (Join-Path $userHome "clawdbot")
}

function Remove-LegacySubmodule {
    param(
        [string]$RepoDir
    )
    if ([string]::IsNullOrWhiteSpace($RepoDir)) {
        $RepoDir = Get-LegacyRepoDir
    }
    $legacyDir = Join-Path $RepoDir "Peekaboo"
    if (Test-Path $legacyDir) {
        Write-Host "[!] Removing legacy submodule checkout: $legacyDir" -ForegroundColor Yellow
        Remove-Item -Recurse -Force $legacyDir
    }
}

# Main installation flow
function Main {
    if ($InstallMethod -ne "npm" -and $InstallMethod -ne "git") {
        Write-Host "Error: invalid -InstallMethod (use npm or git)." -ForegroundColor Red
        exit 2
    }

    if ($DryRun) {
        Write-Host "[OK] Dry run" -ForegroundColor Green
        Write-Host "[OK] Install method: $InstallMethod" -ForegroundColor Green
        if ($InstallMethod -eq "git") {
            Write-Host "[OK] Git dir: $GitDir" -ForegroundColor Green
            if ($NoGitUpdate) {
                Write-Host "[OK] Git update: disabled" -ForegroundColor Green
            } else {
                Write-Host "[OK] Git update: enabled" -ForegroundColor Green
            }
        }
        if ($NoOnboard) {
            Write-Host "[OK] Onboard: skipped" -ForegroundColor Green
        }
        return
    }

    Remove-LegacySubmodule -RepoDir $RepoDir

    # Check for existing installation
    $isUpgrade = Check-ExistingClawdbot

    # Step 1: Node.js
    if (-not (Check-Node)) {
        Install-Node

        # Verify installation
        if (-not (Check-Node)) {
            Write-Host ""
            Write-Host "Error: Node.js installation may require a terminal restart" -ForegroundColor Red
            Write-Host "Please close this terminal, open a new one, and run this installer again." -ForegroundColor Yellow
            exit 1
        }
    }

    $finalGitDir = $null

    # Step 2: Clawdbot
    if ($InstallMethod -eq "git") {
        $finalGitDir = $GitDir
        Install-ClawdbotFromGit -RepoDir $GitDir -SkipUpdate:$NoGitUpdate
    } else {
        Install-Clawdbot
    }

    # Step 3: Run doctor for migrations if upgrading or git install
    if ($isUpgrade -or $InstallMethod -eq "git") {
        Run-Doctor
    }

    $installedVersion = $null
    try {
        $installedVersion = (clawdbot --version 2>$null).Trim()
    } catch {
        $installedVersion = $null
    }
    if (-not $installedVersion) {
        try {
            $npmList = npm list -g --depth 0 --json 2>$null | ConvertFrom-Json
            if ($npmList -and $npmList.dependencies -and $npmList.dependencies.clawdbot -and $npmList.dependencies.clawdbot.version) {
                $installedVersion = $npmList.dependencies.clawdbot.version
            }
        } catch {
            $installedVersion = $null
        }
    }

    Write-Host ""
    if ($installedVersion) {
        Write-Host "Clawdbot installed successfully ($installedVersion)!" -ForegroundColor Green
    } else {
        Write-Host "Clawdbot installed successfully!" -ForegroundColor Green
    }
    Write-Host ""
    if ($isUpgrade) {
        $updateMessages = @(
            "Leveled up! New skills unlocked. You're welcome.",
            "Fresh code, same lobster. Miss me?",
            "Back and better. Did you even notice I was gone?",
            "Update complete. I learned some new tricks while I was out.",
            "Upgraded! Now with 23% more sass.",
            "I've evolved. Try to keep up.",
            "New version, who dis? Oh right, still me but shinier.",
            "Patched, polished, and ready to pinch. Let's go.",
            "The lobster has molted. Harder shell, sharper claws.",
            "Update done! Check the changelog or just trust me, it's good.",
            "Reborn from the boiling waters of npm. Stronger now.",
            "I went away and came back smarter. You should try it sometime.",
            "Update complete. The bugs feared me, so they left.",
            "New version installed. Old version sends its regards.",
            "Firmware fresh. Brain wrinkles: increased.",
            "I've seen things you wouldn't believe. Anyway, I'm updated.",
            "Back online. The changelog is long but our friendship is longer.",
            "Upgraded! Peter fixed stuff. Blame him if it breaks.",
            "Molting complete. Please don't look at my soft shell phase.",
            "Version bump! Same chaos energy, fewer crashes (probably)."
        )
        Write-Host (Get-Random -InputObject $updateMessages) -ForegroundColor Gray
        Write-Host ""
    } else {
        $completionMessages = @(
            "Ahh nice, I like it here. Got any snacks? ",
            "Home sweet home. Don't worry, I won't rearrange the furniture.",
            "I'm in. Let's cause some responsible chaos.",
            "Installation complete. Your productivity is about to get weird.",
            "Settled in. Time to automate your life whether you're ready or not.",
            "Cozy. I've already read your calendar. We need to talk.",
            "Finally unpacked. Now point me at your problems.",
            "cracks claws Alright, what are we building?",
            "The lobster has landed. Your terminal will never be the same.",
            "All done! I promise to only judge your code a little bit."
        )
        Write-Host (Get-Random -InputObject $completionMessages) -ForegroundColor Gray
        Write-Host ""
    }

    if ($InstallMethod -eq "git") {
        Write-Host "Source checkout: $finalGitDir" -ForegroundColor Cyan
        Write-Host "Wrapper: $env:USERPROFILE\\.local\\bin\\clawdbot.cmd" -ForegroundColor Cyan
        Write-Host ""
    }

    if ($isUpgrade) {
        Write-Host "Upgrade complete. Run " -NoNewline
        Write-Host "clawdbot doctor" -ForegroundColor Cyan -NoNewline
        Write-Host " to check for additional migrations."
    } else {
        if ($NoOnboard) {
            Write-Host "Skipping onboard (requested). Run " -NoNewline
            Write-Host "clawdbot onboard" -ForegroundColor Cyan -NoNewline
            Write-Host " later."
        } else {
            Write-Host "Starting setup..." -ForegroundColor Cyan
            Write-Host ""
            clawdbot onboard
        }
    }
}

Main
