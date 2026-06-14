<#
.SYNOPSIS
    dotfiles 模块安装器
.DESCRIPTION
    列出可用模块并安装指定模块。
    默认行为: 列出所有可安装模块。
    必须通过 -m / --modules 参数指定要安装的模块。
    可通过 -f / --force 将强制覆盖参数传递给子脚本。

    示例:
        .\install.ps1                    # 列出所有可安装模块
        .\install.ps1 -m powershell      # 安装指定模块
        .\install.ps1 -m powershell,foo  # 安装多个模块
        .\install.ps1 -m starship -f     # 强制覆盖已存在的配置文件
        .\install.ps1 -Help              # 显示帮助
.PARAMETER Modules
    指定要安装的模块名称 (多个用逗号分隔)。别名: -m, --modules.
.PARAMETER Force
    强制覆盖已有配置文件; 传递给子脚本。别名: -f, --force.
.PARAMETER Help
    显示帮助信息。
#>

param(
    [Alias('m')]
    [string[]]$Modules,

    [Alias('f')]
    [switch]$Force,

    [switch]$Help
)

# 支持 --force (跨平台风格参数名)
if ($MyInvocation.Line -split '\s+' -contains '--force') {
    $Force = $true
}

$basePath   = Split-Path -Parent $MyInvocation.MyCommand.Path
$modulePath = Join-Path $basePath "modules"

# ==========================================
# 帮助
# ==========================================
if ($Help) {
    Get-Help $MyInvocation.MyCommand.Path -Detailed
    exit
}

# ==========================================
# 发现可用模块
# ==========================================
$availableModules = Get-ChildItem $modulePath -Directory | ForEach-Object { $_.Name }

if (-not $Modules) {
    # 未指定模块: 列出可用模块并退出
    Write-Host "可用模块:" -ForegroundColor Cyan
    foreach ($mod in $availableModules) {
        $scriptFile = Join-Path $modulePath "$mod\$mod.ps1"
        $desc = ""

        # 尝试从脚本注释的 .SYNOPSIS 行提取简短描述
        if (Test-Path $scriptFile) {
            $raw = Get-Content -Path $scriptFile -Raw -Encoding UTF8
            if ($raw -match '\.SYNOPSIS\s*\n\s*(.+)') {
                $desc = "  | $($Matches[1].Trim())"
            }
        }

        Write-Host "  - ${mod}$desc" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "安装示例:" -ForegroundColor Gray
    Write-Host "  .\install.ps1 -m $($availableModules[0])" -ForegroundColor Gray
    Write-Host "  .\install.ps1 -m $($availableModules[0]) -f" -ForegroundColor Gray
    exit
}

# ==========================================
# 安装指定模块
# ==========================================
$childArgs = @()
if ($Force) { $childArgs += '-Force' }

foreach ($mod in $Modules) {
    $scriptFile = Join-Path $modulePath "$mod\$mod.ps1"

    if (-not (Test-Path $scriptFile)) {
        Write-Warning "模块 '$mod' 不存在。可用模块: $($availableModules -join ', ')"
        continue
    }

    Write-Host "--> 安装 $mod ..." -ForegroundColor Green
    & $scriptFile @childArgs
}
