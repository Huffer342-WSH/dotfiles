[Console]::OutputEncoding = [System.Text.Encoding]::UTF8


$IsInteractiveConsole =
    $Host.Name -eq 'ConsoleHost' -and
    -not [Console]::IsInputRedirected -and
    -not [Console]::IsOutputRedirected

if ($IsInteractiveConsole) {
    # posh-git
    Import-Module posh-git

    # PSReadLine
    Import-Module PSReadLine
    Import-Module CompletionPredictor
    Set-PSReadLineOption -EditMode Emacs
    Set-PSReadLineOption -PredictionViewStyle InlineView
    Set-PSReadLineOption -PredictionSource Plugin
    Set-PSReadLineKeyHandler -Chord Ctrl+v -Function Paste
    Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete

    # carapace 自动补全  winget install -e --id rsteube.Carapace
    $env:CARAPACE_BRIDGES = 'zsh,fish,bash,inshellisense'
    carapace _carapace | Out-String | Invoke-Expression

    # Starship - 美化Prompt
    if (Get-Command starship -ErrorAction SilentlyContinue) {
        Invoke-Expression (& starship init powershell)
    }
}

# 设置代理
$reg = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey("Software\Microsoft\Windows\CurrentVersion\Internet Settings")
$proxyEnable = $reg.GetValue("ProxyEnable")
$server = $reg.GetValue("ProxyServer")

if ($proxyEnable -eq 1) {
    $server = $reg.GetValue("ProxyServer")
    if ($server) {
        $url = if ($server -like "http://*") { $server } else { "http://$server" }
        $env:HTTP_PROXY = $env:HTTPS_PROXY = $url
    }
}
