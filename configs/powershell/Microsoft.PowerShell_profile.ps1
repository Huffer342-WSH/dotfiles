$OutputEncoding = [console]::InputEncoding = [console]::OutputEncoding = [System.Text.UTF8Encoding]::new()

$IsInteractiveConsole =
    $Host.Name -eq 'ConsoleHost' -and
    -not [Console]::IsInputRedirected -and
    -not [Console]::IsOutputRedirected

if ($IsInteractiveConsole) {
    # PSReadLine
    Import-Module PSReadLine

    Set-PSReadLineOption -EditMode Emacs -PredictionViewStyle InlineView -PredictionSource HistoryAndPlugin -Colors @{ InlinePrediction = "`e[2;38;5;8m" }
    Set-PSReadLineKeyHandler -Chord Ctrl+v -Function Paste
    Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete

    Import-Module PSCompletions
    Import-Module CompletionPredictor

    # carapace 自动补全  winget install -e --id rsteube.Carapace
    $env:CARAPACE_TOOLTIP = 1
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
