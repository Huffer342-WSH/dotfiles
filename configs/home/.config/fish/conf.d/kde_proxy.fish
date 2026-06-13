# 从KDE读取系统代理环境变量到fish

function __sync_kde_proxy
    set -l kioslaverc "$HOME/.config/kioslaverc"

    if not test -f $kioslaverc
        return
    end

    # 读取 ProxyType
    set -l proxy_type (string match -r '^ProxyType=[0-9]$' < "$kioslaverc" | string replace -r '^ProxyType=' '')

    if test "$proxy_type" != "1"
        # 非手动代理模式，退出
        return
    end

    # 读取代理地址
    set -l http_proxy  (grep -m 1 '^httpProxy='  $kioslaverc | string replace -r '^httpProxy=' '')
    set -l https_proxy (grep -m 1 '^httpsProxy=' $kioslaverc | string replace -r '^httpsProxy=' '')
    set -l socks_proxy (grep -m 1 '^socksProxy=' $kioslaverc | string replace -r '^socksProxy=' '')

    # 设置环境变量（fish）
    if test -n "$http_proxy"
        set -gx http_proxy $http_proxy
        set -gx HTTP_PROXY $http_proxy
    end

    if test -n "$https_proxy"
        set -gx https_proxy $https_proxy
        set -gx HTTPS_PROXY $https_proxy
    end

    if test -n "$socks_proxy"
        set -gx all_proxy $socks_proxy
        set -gx ALL_PROXY $socks_proxy
    end
end

# shell 启动时执行一次
__sync_kde_proxy
