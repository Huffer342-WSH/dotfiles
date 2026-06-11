<#
.SYNOPSIS
    Starship 提示符配置脚本
.DESCRIPTION
    1. 安装 Starship (通过 winget)
    2. 部署 Starship.toml 主题配置到 ~/.config/starship.toml
.PARAMETER Source
    配置文件来源: Auto (默认，仓库内用本地，否则远程), Local (仅本地), Remote (仅远程)
.PARAMETER Force
    强制覆盖已有配置文件 (默认会跳过已存在的文件)
.LINK
    https://github.com/Huffer342-WSH/dotfiles
#>

param(
    [ValidateSet("Auto", "Local", "Remote")]
    [string]$Source = "Auto",

    [switch]$Force
)

# ==========================================
# 常量
# ==========================================
$BaseUrl  = "https://raw.githubusercontent.com/Huffer342-WSH/dotfiles/refs/heads/windows"
$RepoName = "dotfiles"

# ==========================================
# 1. 辅助函数
# ==========================================

function Resolve-SourceMode {
    switch ($Source) {
        "Local"  { return "Local" }
        "Remote" { return "Remote" }
        "Auto" {
            try {
                $repoRoot = git -C $PSScriptRoot rev-parse --show-toplevel 2>$null
                if ($repoRoot -and (Split-Path $repoRoot -Leaf) -eq $RepoName) {
                    return "Local"
                }
            }
            catch { }
            return "Remote"
        }
    }
}

function Get-RepoRoot {
    try {
        $root = git -C $PSScriptRoot rev-parse --show-toplevel 2>$null
        if ($root) { return (Resolve-Path $root).Path }
    }
    catch { }
    return $null
}

function Get-ConfigContent {
    param([string]$RelativePath)

    $mode = Resolve-SourceMode
    Write-Host "  [模式: $mode] 获取 $RelativePath ..." -ForegroundColor DarkGray

    switch ($mode) {
        "Local" {
            $repoRoot = Get-RepoRoot
            if (-not $repoRoot) {
                throw "无法定位本地仓库根目录，请使用 -Source Remote"
            }
            $localPath = Join-Path $repoRoot $RelativePath
            if (-not (Test-Path $localPath)) {
                throw "本地文件不存在: $localPath"
            }
            return Get-Content -Path $localPath -Raw -Encoding UTF8
        }
        "Remote" {
            $url = "$BaseUrl/$RelativePath"
            try {
                return Invoke-RestMethod -Uri $url -UseBasicParsing
            }
            catch {
                throw "下载失败: $url`n$_"
            }
        }
    }
}

function Install-WingetPackage {
    param(
        [string]$Id,
        [string]$CommandName
    )
    Write-Host "  检查 $Id ..." -ForegroundColor Gray
    if (Get-Command $CommandName -ErrorAction SilentlyContinue) {
        Write-Host "    $Id 已安装，跳过。" -ForegroundColor Cyan
    }
    else {
        Write-Host "    正在通过 winget 安装 $Id ..."
        winget install --id $Id --exact --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    $Id 安装完成。" -ForegroundColor Cyan
        }
        else {
            Write-Error "$Id 安装失败 (退出码: $LASTEXITCODE)"
        }
    }
}

function Deploy-File {
    param(
        [string]$RelativeSourcePath,
        [string]$TargetPath,
        [string]$Description
    )

    Write-Host "`n部署 $Description ..." -ForegroundColor Green
    Write-Host "  目标: $TargetPath" -ForegroundColor DarkGray

    $targetDir = Split-Path $TargetPath -Parent
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        Write-Host "  创建目录: $targetDir" -ForegroundColor Gray
    }

    if ((Test-Path $TargetPath) -and -not $Force) {
        Write-Host "  目标已存在，跳过 (使用 -Force 强制覆盖)。" -ForegroundColor Yellow
        return
    }

    if (Test-Path $TargetPath) {
        $backupPath = "$TargetPath.backup.$(Get-Date -Format 'yyyyMMddHHmmss')"
        Copy-Item $TargetPath $backupPath
        Write-Host "  已备份至: $backupPath" -ForegroundColor Gray
    }

    try {
        $content = Get-ConfigContent -RelativePath $RelativeSourcePath
        $content = $content.TrimEnd() + "`n"
        Set-Content -Path $TargetPath -Value $content -Encoding UTF8 -Force
        Write-Host "  $Description 部署完成。" -ForegroundColor Cyan
    }
    catch {
        Write-Error "部署 $Description 失败: $_"
    }
}

# ==========================================
# 2. 安装 Starship
# ==========================================
Write-Host "`n[1/2] 安装 Starship..." -ForegroundColor Green
if (Get-Command winget -ErrorAction SilentlyContinue) {
    Install-WingetPackage -Id "Starship.Starship" -CommandName "starship"
}
else {
    Write-Error "未检测到 winget。请手动安装 Starship: https://starship.rs/"
}

# ==========================================
# 3. 部署主题
# ==========================================
Write-Host "`n[2/2] 部署 Starship 主题..." -ForegroundColor Green

$starshipTarget = Join-Path $env:USERPROFILE ".config\starship.toml"
Deploy-File `
    -RelativeSourcePath "configs/starship/Starship.toml" `
    -TargetPath $starshipTarget `
    -Description "Starship 主题"

# ==========================================
# 完成
# ==========================================
Write-Host "`nStarship 配置完成。" -ForegroundColor Cyan
Write-Host "  主题文件: $starshipTarget" -ForegroundColor Gray
Write-Host "  重启终端或以 starship 命令查看效果。" -ForegroundColor Gray
