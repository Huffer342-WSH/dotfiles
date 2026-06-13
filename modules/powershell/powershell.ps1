<#
.SYNOPSIS
    PowerShell 环境配置脚本
.DESCRIPTION
    1. 安装必需模块: PSReadLine, posh-git, CompletionPredictor
    2. 安装 Starship 和 Carapace
    3. 部署 PowerShell Profile 到 $PROFILE
    4. 部署 Starship 主题
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
    <#
    .SYNOPSIS
        根据 $Source 参数和当前环境决定使用本地还是远程文件
    #>
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
    <#
    .SYNOPSIS
        返回本地仓库根目录；非本地模式返回 $null
    #>
    try {
        $root = git -C $PSScriptRoot rev-parse --show-toplevel 2>$null
        if ($root) { return (Resolve-Path $root).Path }
    }
    catch { }
    return $null
}

function Get-ConfigContent {
    <#
    .SYNOPSIS
        根据相对路径获取配置文件内容
    .DESCRIPTION
        Local  模式: 从本地仓库读取 (相对于仓库根目录)
        Remote 模式: 从 BaseUrl 下载
    #>
    param(
        [string]$RelativePath
    )

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

function Install-PowerShellModule {
    <#
    .SYNOPSIS
        安装/更新 PowerShell 模块 (CurrentUser 范围)
    #>
    param(
        [string]$Name
    )
    Write-Host "  检查模块 $Name ..." -ForegroundColor Gray
    try {
        if (Get-Module -ListAvailable -Name $Name -ErrorAction SilentlyContinue) {
            Write-Host "    $Name 已安装，尝试更新..." -ForegroundColor Gray
            Update-Module -Name $Name -Scope CurrentUser -ErrorAction SilentlyContinue
        }
        else {
            Write-Host "    正在安装 $Name ..."
            Install-Module -Name $Name -Scope CurrentUser -Force -AllowClobber -SkipPublisherCheck
        }
        Write-Host "    $Name 就绪。" -ForegroundColor Cyan
    }
    catch {
        # 某些模块可能不允许通过 Update-Module 更新 (如 PSReadLine 自带)
        Write-Host "    $Name : $_" -ForegroundColor Yellow
        if (-not (Get-Module -ListAvailable -Name $Name -ErrorAction SilentlyContinue)) {
            try {
                Install-Module -Name $Name -Scope CurrentUser -Force -AllowClobber -SkipPublisherCheck
                Write-Host "    $Name (force install) 就绪。" -ForegroundColor Cyan
            }
            catch {
                Write-Error "$Name 安装失败: $_"
            }
        }
    }
}

function Install-WingetPackage {
    <#
    .SYNOPSIS
        通过 winget 安装包 (如已安装则跳过)
    #>
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

function Get-FontDownloadUrls {
    <#
    .SYNOPSIS
        查询字体最新版本的下载 URL
    #>
    $Fonts = @(
        @{
            Name = "SarasaMonoSC"
            Repo = "be5invis/Sarasa-Gothic"
            AssetPattern = "^SarasaMonoSC-TTF-.*\.7z$"
        },
        @{
            Name = "CascadiaCode"
            Repo = "microsoft/cascadia-code"
            AssetPattern = "^CascadiaCode-.*\.zip$"
        }
    )

    $Headers = @{
        "User-Agent" = "PowerShell"
    }

    $result = foreach ($font in $Fonts) {
        try {
            $release = Invoke-RestMethod `
                -Uri "https://api.github.com/repos/$($font.Repo)/releases/latest" `
                -Headers $Headers

            $asset = $release.assets |
                Where-Object { $_.name -match $font.AssetPattern } |
                Select-Object -First 1

            if ($asset) {
                [PSCustomObject]@{
                    Name        = $font.Name
                    Version     = $release.tag_name
                    FileName    = $asset.name
                    DownloadUrl = $asset.browser_download_url
                }
            }
        }
        catch {
            Write-Warning "获取 $($font.Name) 最新版本失败: $_"
        }
    }

    return $result
}

function Deploy-File {
    <#
    .SYNOPSIS
        将配置文件内容部署到目标路径
    .DESCRIPTION
        - 若目标已存在且未指定 -Force，跳过并提示
        - 若目标已存在且指定 -Force，备份后覆盖
        - 确保目标目录存在
    #>
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
        # 确保内容以换行结尾，避免拼接问题
        $content = $content.TrimEnd() + "`n"
        Set-Content -Path $TargetPath -Value $content -Encoding UTF8 -Force
        Write-Host "  $Description 部署完成。" -ForegroundColor Cyan
    }
    catch {
        Write-Error "部署 $Description 失败: $_"
    }
}

# ==========================================
# 2. 安装 PowerShell 模块
# ==========================================
Write-Host "`n[1/5] 安装 PowerShell 模块..." -ForegroundColor Green

$requiredModules = @("PSReadLine", "PSCompletions", "CompletionPredictor")
foreach ($module in $requiredModules) {
    Install-PowerShellModule -Name $module
}

# 配置 PSCompletions
import-Module PSCompletions
psc config enable_completions_update 0
psc menu config enable_enter_when_single 1
psc add git python

# ==========================================
# 3. 安装 Starship
# ==========================================
Write-Host "`n[2/5] 安装 Starship..." -ForegroundColor Green
if (Get-Command winget -ErrorAction SilentlyContinue) {
    Install-WingetPackage -Id "Starship.Starship" -CommandName "starship"
}
else {
    Write-Error "未检测到 winget。请手动安装 Starship: https://starship.rs/"
}

# ==========================================
# 4. 安装 Carapace
# ==========================================
Write-Host "`n[3/5] 安装 Carapace..." -ForegroundColor Green
if (Get-Command winget -ErrorAction SilentlyContinue) {
    Install-WingetPackage -Id "rsteube.Carapace" -CommandName "carapace"
}
else {
    Write-Error "未检测到 winget。请手动安装 Carapace: https://carapace.sh/"
}

# ==========================================
# 5. 部署配置文件
# ==========================================
Write-Host "`n[4/5] 部署配置文件..." -ForegroundColor Green

# --- PowerShell Profile ---
Deploy-File `
    -RelativeSourcePath "configs/powershell/Microsoft.PowerShell_profile.ps1" `
    -TargetPath $PROFILE `
    -Description "PowerShell Profile"

# --- Starship 主题 ---
$starshipTarget = Join-Path $env:USERPROFILE ".config\starship.toml"
Deploy-File `
    -RelativeSourcePath "configs/starship/Starship.toml" `
    -TargetPath $starshipTarget `
    -Description "Starship 主题"

# ==========================================
# 6. 收尾
# ==========================================
Write-Host "`n[5/5] 完成" -ForegroundColor Green
Write-Host ("=" * 64) -ForegroundColor Cyan
Write-Host "  脚本执行完毕！已安装/更新的内容:"
Write-Host "    - 模块: PSReadLine, posh-git, CompletionPredictor"
Write-Host "    - 工具: Starship, Carapace"
Write-Host "    - Profile: $PROFILE"
Write-Host "    - 主题:   $starshipTarget"
Write-Host ""
Write-Host "  后续手动操作：" -ForegroundColor Yellow
Write-Host "  1. 安装 Nerd 字体 (解决图标乱码)"
Write-Host "     推荐: Cascadia Mono NF + Sarasa Mono SC (英文 Cascadia, 中文更纱黑体)" -ForegroundColor Gray
Write-Host ""
Write-Host "     获取最新版下载链接:" -ForegroundColor Cyan
$fontUrls = Get-FontDownloadUrls
foreach ($f in $fontUrls) {
    Write-Host "     - $($f.Name) ($($f.Version))"
    Write-Host "       $($f.DownloadUrl)"
}
Write-Host ""
Write-Host "  2. 在终端中设置字体为 Nerd Font"
Write-Host "     (Windows Terminal / VS Code 内均需设置)"
Write-Host ""
Write-Host "  3. 重启 PowerShell 以查看效果"
Write-Host ("=" * 64) -ForegroundColor Cyan

Pause
