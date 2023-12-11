#!/bin/bash

# 延迟打字
print_with_delay() {
    text="$1"
    delay="$2"
    for ((i = 0; i < ${#text}; i++)); do
        echo -n "${text:$i:1}"
        sleep $delay
    done
    echo
}

# 自定义字体彩色，read 函数
red() { echo -e "\033[31m\033[01m$*\033[0m"; }  # 红色
green() { echo -e "\033[32m\033[01m$*\033[0m"; }   # 绿色
yellow() { echo -e "\033[33m\033[01m$*\033[0m"; }   # 黄色

#信息提示
show_notice() {
    local message="$1"

    local reset="\e[0m"
    local bold="\e[1m"

    local terminal_width=$(tput cols)
    local line=""

    local padding=$(( (terminal_width - ${#message}) / 2 ))
    local padded_message="$(printf "%*s%s" $padding '' "$message")"

    for ((i=1; i<=terminal_width; i++)); do
        line+="*"
    done

    red "${bold}${line}${reset}"
    echo ""
    red "${bold}${padded_message}${reset}"
    echo ""
    red "${bold}${line}${reset}"
}



# 安装依赖
install_base(){
  # 安装qrencode jq
  local packages=("qrencode" "jq")
  for package in "${packages[@]}"; do
    if ! command -v "$package" &> /dev/null; then
      echo "正在安装 $package..."
      if [ -n "$(command -v apt)" ]; then
        sudo apt update > /dev/null 2>&1
        sudo apt install -y "$package" > /dev/null 2>&1
      elif [ -n "$(command -v yum)" ]; then
        sudo yum install -y "$package"
      elif [ -n "$(command -v dnf)" ]; then
        sudo dnf install -y "$package"
      else
        echo "无法安装 $package。请手动安装，并重新运行脚本。"
        exit 1
      fi
      echo "$package 已安装。"
    else
      echo "$package 已安装。"
    fi
  done
}

# 下载cloudflared和sb
download_singbox(){
  arch=$(uname -m)
  echo "Architecture: $arch"
  # Map architecture names
  case ${arch} in
      x86_64)
          arch="amd64"
          ;;
      aarch64)
          arch="arm64"
          ;;
      armv7l)
          arch="armv7"
          ;;
  esac
  # Fetch the latest (including pre-releases) release version number from GitHub API
  # 正式版
  #latest_version_tag=$(curl -s "https://api.github.com/repos/SagerNet/sing-box/releases" | grep -Po '"tag_name": "\K.*?(?=")' | head -n 1)
  #beta版本
  latest_version_tag=$(curl -s "https://api.github.com/repos/SagerNet/sing-box/releases" | grep -Po '"tag_name": "\K.*?(?=")' | sort -V | tail -n 1)
  latest_version=${latest_version_tag#v}  # Remove 'v' prefix from version number
  echo "Latest version: $latest_version"
  # Detect server architecture
  # Prepare package names
  package_name="sing-box-${latest_version}-linux-${arch}"
  # Prepare download URL
  url="https://github.com/SagerNet/sing-box/releases/download/${latest_version_tag}/${package_name}.tar.gz"
  # Download the latest release package (.tar.gz) from GitHub
  curl -sLo "/root/${package_name}.tar.gz" "$url"

  # Extract the package and move the binary to /root
  tar -xzf "/root/${package_name}.tar.gz" -C /root
  mv "/root/${package_name}/sing-box" /root/sbox

  # Cleanup the package
  rm -r "/root/${package_name}.tar.gz" "/root/${package_name}"

  # Set the permissions
  chown root:root /root/sbox/sing-box
  chmod +x /root/sbox/sing-box
}

download_cloudflared(){
  arch=$(uname -m)
  # Map architecture names
  case ${arch} in
      x86_64)
          cf_arch="amd64"
          ;;
      aarch64)
          cf_arch="arm64"
          ;;
      armv7l)
          cf_arch="arm"
          ;;
  esac

  # install cloudflared linux
  cf_url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${cf_arch}"
  curl -sLo "/root/sbox/cloudflared-linux" "$cf_url"
  chmod +x /root/sbox/cloudflared-linux
  echo ""
}


# client configuration
show_client_configuration() {

  # 获取当前ip
  server_ip=$(grep -o "SERVER_IP='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
  
  # reality
  # reality当前端口
  reality_port=$(grep -o "REALITY_PORT='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
  # 当前偷取的网站
  reality_server_name=$(grep -o "REALITY_SERVER_NAME='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
  # 当前reality uuid
  reality_uuid=$(grep -o "REALITY_UUID='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
  # 获取公钥
  public_key=$(grep -o "PUBLIC_KEY='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
  # 获取short_id
  short_id=$(grep -o "SHORT_ID='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
  #聚合reality
  reality_link="vless://$reality_uuid@$server_ip:$reality_port?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$reality_server_name&fp=chrome&pbk=$public_key&sid=$short_id&type=tcp&headerType=none#SING-BOX-REALITY"
  echo ""
  echo ""
  show_notice "Vision Reality通用链接 二维码 通用参数" 
  echo ""
  green "通用链接如下"
  echo "" 
  echo "$reality_link"
  echo ""
  green "二维码如下"
  echo ""
  qrencode -t UTF8 $reality_link
  echo ""
  green "客户端通用参数如下"
  echo ""
  echo "服务器ip: $server_ip"
  echo "监听端口: $reality_port"
  echo "UUID: $reality_uuid"
  echo "域名SNI: $reality_server_name"
  echo "Public Key: $public_key"
  echo "Short ID: $short_id"
  echo ""

  # hy port
  hy_port=$(grep -o "HY_PORT='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
  # hy sni
  hy_server_name=$(grep -o "HY_SERVER_NAME='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
  # hy password
  hy_password=$(grep -o "HY_PASSWORD='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
  
  # Generate the hy link
  hy2_link="hysteria2://$hy_password@$server_ip:$hy_port?insecure=1&sni=$hy_server_name"

  echo ""
  echo "" 
  show_notice "Hysteria2通用链接 二维码 通用参数" 
  echo ""
  green "通用链接如下"
  echo "" 
  echo "$hy2_link"
  green "二维码如下"
  echo ""
  qrencode -t UTF8 $hy2_link  
  echo ""
  green "客户端通用参数如下"
  echo ""
  echo "服务器ip: $server_ip"
  echo "端口号: $hy_port"
  echo "密码password: $hy_password"
  echo "域名SNI: $hy_server_name"
  echo "跳过证书验证（允许不安全）: True"
  echo ""
  green "Hysteria2 官方yaml如下" 
  echo ""
cat << EOF

server: $server_ip:$hy_port
auth: $hy_password
tls:
  sni: $hy_server_name
  insecure: true
# 可自己修改对应带宽，不添加则默认为bbr，否则使用hy2的brutal拥塞控制
# bandwidth:
#   up: 100 mbps
#   down: 100 mbps
fastOpen: true
socks5:
  listen: 127.0.0.1:50000

EOF
  echo "" 
  sleep 2
  cat /root/sbox/argo.log | grep trycloudflare.com | awk 'NR==2{print}' | awk -F// '{print $2}' | awk '{print $1}' | xargs -I {} sed -i "s/ARGO_DOMAIN='.*'/ARGO_DOMAIN='{}'/g" /root/sbox/config
  rm -f /root/sbox/argo.log
  #argo域名
  argo_domain=$(grep -o "ARGO_DOMAIN='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')

  vmess_uuid=$(grep -o "VMESS_UUID='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
  ws_path=$(grep -o "WS_PATH='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
  
  vmesswss_link='vmess://'$(echo '{"add":"speed.cloudflare.com","aid":"0","host":"'$argo_domain'","id":"'$vmess_uuid'","net":"ws","path":"'${ws_path}?ed=2048'","port":"443","ps":"sing-box-vmess-tls","tls":"tls","type":"none","v":"2"}' | base64 -w 0)
  vmessws_link='vmess://'$(echo '{"add":"speed.cloudflare.com","aid":"0","host":"'$argo_domain'","id":"'$vmess_uuid'","net":"ws","path":"'${ws_path}?ed=2048'","port":"80","ps":"sing-box-vmess","tls":"","type":"none","v":"2"}' | base64 -w 0)
  echo ""
  echo ""
  show_notice "vmess ws(s) 通用链接和二维码"
  echo ""
  echo ""
  yellow "vmess wss通用链接,替换speed.cloudflare.com为自己的优选ip可获得极致体验"
  echo ""
  echo "$vmesswss_link"
  echo ""
  yellow "vmess wss二维码"
  echo ""
  qrencode -t UTF8 $vmesswss_link
  echo ""
  red  "上述链接为wss 端口 443 可改为 2053 2083 2087 2096 8443"
  echo ""
  yellow "vmess ws链接，替换speed.cloudflare.com为自己的优选ip可获得极致体验"
  echo ""
  echo "$vmessws_link"
  echo ""
  yellow "vmess ws 二维码"
  echo ""
  qrencode -t UTF8 $vmessws_link
  echo ""
  red "上述链接为ws 端口 80 可改为 8080 8880 2052 2082 2086 2095" 
  echo ""
  echo ""

  show_notice "clash-meta配置参数"
cat << EOF

port: 7890
allow-lan: true
mode: rule
log-level: info
unified-delay: true
global-client-fingerprint: chrome
ipv6: true
dns:
  enable: true
  listen: :53
  ipv6: true
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  default-nameserver: 
    - 223.5.5.5
    - 8.8.8.8
  nameserver:
    - https://dns.alidns.com/dns-query
    - https://doh.pub/dns-query
  fallback:
    - https://1.0.0.1/dns-query
    - tls://dns.google
  fallback-filter:
    geoip: true
    geoip-code: CN
    ipcidr:
      - 240.0.0.0/4

proxies:        
  - name: Reality
    type: vless
    server: $server_ip
    port: $reality_port
    uuid: $reality_uuid
    network: tcp
    udp: true
    tls: true
    flow: xtls-rprx-vision
    servername: $reality_server_name
    client-fingerprint: chrome
    reality-opts:
      public-key: $public_key
      short-id: $short_id

  - name: Hysteria2
    type: hysteria2
    server: $server_ip
    port: $hy_port
    #  up和down均不写或为0则使用BBR流控
    # up: "30 Mbps" # 若不写单位，默认为 Mbps
    # down: "200 Mbps" # 若不写单位，默认为 Mbps
    password: $hy_password
    sni: $hy_server_name
    skip-cert-verify: true
    alpn:
      - h3
  - name: Vmess
    type: vmess
    server: speed.cloudflare.com
    port: 443
    uuid: $vmess_uuid
    alterId: 0
    cipher: auto
    udp: true
    tls: true
    client-fingerprint: chrome  
    skip-cert-verify: true
    servername: $argo_domain
    network: ws
    ws-opts:
      path: ${ws_path}?ed=2048
      headers:
        Host: $argo_domain

proxy-groups:
  - name: 节点选择
    type: select
    proxies:
      - 自动选择
      - Reality
      - Hysteria2
      - Vmess
      - DIRECT

  - name: 自动选择
    type: url-test #选出延迟最低的机场节点
    proxies:
      - Reality
      - Hysteria2
      - Vmess
    url: "http://www.gstatic.com/generate_204"
    interval: 300
    tolerance: 50


rules:
    - GEOIP,LAN,DIRECT
    - GEOIP,CN,DIRECT
    - MATCH,节点选择

EOF

show_notice "sing-box客户端配置参数"
cat << EOF
{
  "log": {
    "level": "debug",
    "timestamp": true
  },
  "dns": {
    "servers": [
      {
        "tag": "proxyDns",
        "address": "8.8.8.8",
        "detour": "proxy"
      },
      {
        "tag": "localDns",
        "address": "https://223.5.5.5/dns-query",
        "detour": "direct"
      },
      {
        "tag": "block",
        "address": "rcode://success"
      },
      {
        "tag": "remote",
        "address": "fakeip"
      }
    ],
    "rules": [
      {
        "domain": [
          "ghproxy.com",
          "cdn.jsdelivr.net",
          "testingcf.jsdelivr.net"
        ],
        "server": "localDns"
      },
      {
        "geosite": "category-ads-all",
        "server": "block"
      },
      {
        "outbound": "any",
        "server": "localDns",
        "disable_cache": true
      },
      {
        "geosite": "cn",
        "server": "localDns"
      },
      {
        "clash_mode": "direct",
        "server": "localDns"
      },
      {
        "clash_mode": "global",
        "server": "proxyDns"
      },
      {
        "geosite": "geolocation-!cn",
        "server": "proxyDns"
      },
      {
        "query_type": [
          "A",
          "AAAA"
        ],
        "server": "remote"
      }
    ],
    "fakeip": {
      "enabled": true,
      "inet4_range": "198.18.0.0/15",
      "inet6_range": "fc00::/18"
    },
    "independent_cache": true,
    "strategy": "ipv4_only"
  },
  "inbounds": [
    {
      "type": "tun",
      "inet4_address": "172.19.0.1/30",
      "mtu": 9000,
      "auto_route": true,
      "strict_route": true,
      "sniff": true,
      "endpoint_independent_nat": false,
      "stack": "system",
      "platform": {
        "http_proxy": {
          "enabled": true,
          "server": "127.0.0.1",
          "server_port": 2080
        }
      }
    },
    {
      "type": "mixed",
      "listen": "127.0.0.1",
      "listen_port": 2080,
      "sniff": true,
      "users": []
    }
  ],
  "outbounds": [
    {
      "tag": "proxy",
      "type": "selector",
      "outbounds": [
        "auto",
        "direct",
        "sing-box-reality",
        "sing-box-hysteria2",
        "sing-box-vmess"
      ]
    },
    {
      "type": "vless",
      "tag": "sing-box-reality",
      "uuid": "$reality_uuid",
      "flow": "xtls-rprx-vision",
      "packet_encoding": "xudp",
      "server": "$server_ip",
      "server_port": $reality_port,
      "tls": {
        "enabled": true,
        "server_name": "$reality_server_name",
        "utls": {
          "enabled": true,
          "fingerprint": "chrome"
        },
        "reality": {
          "enabled": true,
          "public_key": "$public_key",
          "short_id": "$short_id"
        }
      }
    },
    {
            "type": "hysteria2",
            "server": "$server_ip",
            "server_port": $hy_port,
            "tag": "sing-box-hysteria2",
            
            "up_mbps": 100,
            "down_mbps": 100,
            "password": "$hy_password",
            "tls": {
                "enabled": true,
                "server_name": "$hy_server_name",
                "insecure": true,
                "alpn": [
                    "h3"
                ]
            }
        },
        {
            "server": "speed.cloudflare.com",
            "server_port": 443,
            "tag": "sing-box-vmess",
            "tls": {
                "enabled": true,
                "server_name": "$argo_domain",
                "insecure": true,
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                }
            },
            "packet_encoding": "packetaddr",
            "transport": {
                "headers": {
                    "Host": [
                        "$argo_domain"
                    ]
                },
                "path": "$ws_path",
                "type": "ws",
                "max_early_data": 2048,
                "early_data_header_name": "Sec-WebSocket-Protocol"
            },
            "type": "vmess",
            "security": "auto",
            "uuid": "$vmess_uuid"
        },
    {
      "tag": "direct",
      "type": "direct"
    },
    {
      "tag": "block",
      "type": "block"
    },
    {
      "tag": "dns-out",
      "type": "dns"
    },
    {
      "tag": "auto",
      "type": "urltest",
      "outbounds": [
        "sing-box-reality",
        "sing-box-hysteria2",
        "sing-box-vmess"
      ],
      "url": "http://www.gstatic.com/generate_204",
      "interval": "1m",
      "tolerance": 50
    }
  ],
  "route": {
    "auto_detect_interface": true,
    "final": "proxy",
    "geoip": {
      "download_url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geoip.db",
      "download_detour": "direct"
    },
    "geosite": {
      "download_url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geosite.db",
      "download_detour": "direct"
    },
    "rules": [
      {
        "protocol": "dns",
        "outbound": "dns-out"
      },
      {
        "network": "udp",
        "port": 443,
        "outbound": "block"
      },
      {
        "geosite": "category-ads-all",
        "outbound": "block"
      },
      {
        "clash_mode": "direct",
        "outbound": "direct"
      },
      {
        "clash_mode": "global",
        "outbound": "proxy"
      },
      {
        "domain": [
          "clash.razord.top",
          "yacd.metacubex.one",
          "yacd.haishan.me",
          "d.metacubex.one"
        ],
        "outbound": "direct"
      },
      {
        "geosite": "geolocation-!cn",
        "outbound": "proxy"
      },
      {
        "geoip": [
          "private",
          "cn"
        ],
        "outbound": "direct"
      },
      {
        "geosite": "cn",
        "outbound": "direct"
      }
    ]
  },
  "experimental": {
    "clash_api": {
      "external_controller": "127.0.0.1:9090",
      "external_ui_download_url": "",
      "external_ui_download_detour": "",
      "external_ui": "ui",
      "secret": "",
      "default_mode": "rule",
      "store_selected": true,
      "cache_file": "",
      "cache_id": ""
    }
  }
}
EOF

show_notice "sing-box1.8.0及以上客户端配置参数"
cat << EOF
{
  "log": {
    "level": "debug",
    "timestamp": true
  },
  "experimental": {
    "clash_api": {
      "external_controller": "127.0.0.1:9090",
      "external_ui_download_url": "",
      "external_ui_download_detour": "",
      "external_ui": "ui",
      "secret": "",
      "default_mode": "rule"
    },
    "cache_file": {
      "enabled": true,
      "store_fakeip": false
    }
  },
  "dns": {
    "servers": [
      {
        "tag": "proxyDns",
        "address": "https://8.8.8.8/dns-query",
        "detour": "proxy"
      },
      {
        "tag": "localDns",
        "address": "https://223.5.5.5/dns-query",
        "detour": "direct"
      },
      {
        "tag": "block",
        "address": "rcode://success"
      },
      {
        "tag": "remote",
        "address": "fakeip"
      }
    ],
    "rules": [
      {
        "domain": [
          "ghproxy.com",
          "cdn.jsdelivr.net",
          "testingcf.jsdelivr.net"
        ],
        "server": "localDns"
      },
      {
        "rule_set": "geosite-category-ads-all",
        "server": "block"
      },
      {
        "outbound": "any",
        "server": "localDns",
        "disable_cache": true
      },
      {
        "rule_set": "geosite-cn",
        "server": "localDns"
      },
      {
        "clash_mode": "direct",
        "server": "localDns"
      },
      {
        "clash_mode": "global",
        "server": "proxyDns"
      },
      {
        "rule_set": "geosite-geolocation-!cn",
        "server": "proxyDns"
      },
      {
        "query_type": [
          "A",
          "AAAA"
        ],
        "server": "remote"
      }
    ],
    "fakeip": {
      "enabled": true,
      "inet4_range": "198.18.0.0/15",
      "inet6_range": "fc00::/18"
    },
    "independent_cache": true,
    "strategy": "ipv4_only"
  },
  "inbounds": [
    {
      "type": "tun",
      "inet4_address": "172.19.0.1/30",
      "mtu": 9000,
      "auto_route": true,
      "strict_route": true,
      "sniff": true,
      "endpoint_independent_nat": false,
      "stack": "system",
      "platform": {
        "http_proxy": {
          "enabled": true,
          "server": "127.0.0.1",
          "server_port": 2080
        }
      }
    },
    {
      "type": "mixed",
      "listen": "127.0.0.1",
      "listen_port": 2080,
      "sniff": true,
      "users": []
    }
  ],
  "outbounds": [
    {
      "tag": "proxy",
      "type": "selector",
      "outbounds": [
        "auto",
        "direct",
        "sing-box-reality",
        "sing-box-hysteria2",
        "sing-box-vmess"
      ]
    },
    {
      "type": "vless",
      "tag": "sing-box-reality",
      "uuid": "$reality_uuid",
      "flow": "xtls-rprx-vision",
      "packet_encoding": "xudp",
      "server": "$server_ip",
      "server_port": $reality_port,
      "tls": {
        "enabled": true,
        "server_name": "$reality_server_name",
        "utls": {
          "enabled": true,
          "fingerprint": "chrome"
        },
        "reality": {
          "enabled": true,
          "public_key": "$public_key",
          "short_id": "$short_id"
        }
      }
    },
    {
            "type": "hysteria2",
            "server": "$server_ip",
            "server_port": $hy_port,
            "tag": "sing-box-hysteria2",
            
            "up_mbps": 100,
            "down_mbps": 100,
            "password": "$hy_password",
            "tls": {
                "enabled": true,
                "server_name": "$hy_server_name",
                "insecure": true,
                "alpn": [
                    "h3"
                ]
            }
        },
        {
            "server": "speed.cloudflare.com",
            "server_port": 443,
            "tag": "sing-box-vmess",
            "tls": {
                "enabled": true,
                "server_name": "$argo_domain",
                "insecure": true,
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                }
            },
            "packet_encoding": "packetaddr",
            "transport": {
                "headers": {
                    "Host": [
                        "$argo_domain"
                    ]
                },
                "path": "$ws_path",
                "type": "ws",
                "max_early_data": 2048,
                "early_data_header_name": "Sec-WebSocket-Protocol"
            },
            "type": "vmess",
            "security": "auto",
            "uuid": "$vmess_uuid"
        },
    {
      "tag": "direct",
      "type": "direct"
    },
    {
      "tag": "block",
      "type": "block"
    },
    {
      "tag": "dns-out",
      "type": "dns"
    },
    {
      "tag": "auto",
      "type": "urltest",
      "outbounds": [
        "sing-box-reality",
        "sing-box-hysteria2",
        "sing-box-vmess"
      ],
      "url": "http://www.gstatic.com/generate_204",
      "interval": "1m",
      "tolerance": 50
    }
  ],
  "route": {
    "auto_detect_interface": true,
    "final": "proxy",
    "rules": [
      {
        "protocol": "dns",
        "outbound": "dns-out"
      },
      {
        "network": "udp",
        "port": 443,
        "outbound": "block"
      },
      {
        "rule_set": "geosite-category-ads-all",
        "outbound": "block"
      },
      {
        "clash_mode": "direct",
        "outbound": "direct"
      },
      {
        "clash_mode": "global",
        "outbound": "proxy"
      },
      {
        "domain": [
          "clash.razord.top",
          "yacd.metacubex.one",
          "yacd.haishan.me",
          "d.metacubex.one"
        ],
        "outbound": "direct"
      },
      {
        "rule_set": "geosite-geolocation-!cn",
        "outbound": "proxy"
      },
      {
        "ip_is_private": true,
        "outbound": "direct"
      },
      {
        "rule_set": "geoip-cn",
        "outbound": "direct"
      },
      {
        "rule_set": "geosite-cn",
        "outbound": "direct"
      }
    ],
    "rule_set": [
      {
        "tag": "geoip-cn",
        "type": "remote",
        "format": "binary",
        "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geoip/cn.srs",
        "download_detour": "direct"
      },
      {
        "tag": "geosite-cn",
        "type": "remote",
        "format": "binary",
        "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/cn.srs",
        "download_detour": "direct"
      },
      {
        "tag": "geosite-geolocation-!cn",
        "type": "remote",
        "format": "binary",
        "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/geolocation-!cn.srs",
        "download_detour": "direct"
      },
      {
        "tag": "geosite-category-ads-all",
        "type": "remote",
        "format": "binary",
        "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/category-ads-all.srs",
        "download_detour": "direct"
      }
    ]
  }
}
EOF


}

#enable bbr
enable_bbr() {
    # temporary workaround for installing bbr
    bash <(curl -L -s https://raw.githubusercontent.com/teddysun/across/master/bbr.sh)
    echo ""
}
#修改sb
modify_singbox() {
    #modifying reality configuration
    show_notice "开始修改reality端口号和域名"
    reality_current_port=$(grep -o "REALITY_PORT='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
    while true; do
        read -p "请输入想要修改的端口号 (当前端口号为 $reality_current_port): " reality_port
        reality_port=${reality_port:-$reality_current_port}
        if [ "$reality_port" -eq "$reality_current_port" ]; then
            break
        fi
        if ss -tuln | grep -q ":$reality_port\b"; then
            echo "端口 $reality_port 已经被占用，请选择其他端口。"
        else
            break
        fi
    done
    reality_current_server_name=$(grep -o "REALITY_SERVER_NAME='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
    read -p "请输入想要偷取的域名 (当前域名为 $reality_current_server_name): " reality_server_name
    reality_server_name=${reality_server_name:-$reality_current_server_name}
    echo ""
    # modifying hysteria2 configuration
    show_notice "开始修改hysteria2端口号"
    echo ""
    hy_current_port=$(grep -o "HY_PORT='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
    while true; do
        read -p "请输入想要修改的端口号 (当前端口号为 $hy_current_port): " hy_port
        hy_port=${hy_port:-$hy_current_port}
        if [ "$hy_port" -eq "$hy_current_port" ]; then
            break
        fi
        if ss -tuln | grep -q ":$hy_port\b"; then
            echo "端口 $hy_port 已经被占用，请选择其他端口。"
        else
            break
        fi
    done

    # 修改sing-box
    jq --arg reality_port "$reality_port" \
        --arg hy_port "$hy_port" \
        --arg reality_server_name "$reality_server_name" \
        '
        (.inbounds[] | select(.type == "vless") | .listen_port) |= ($reality_port | tonumber) |
        (.inbounds[] | select(.type == "hysteria2") | .listen_port) |= ($hy_port | tonumber) |
        (.inbounds[] | select(.type == "vless") | .tls.server_name) |= $reality_server_name |
        (.inbounds[] | select(.type == "vless") | .tls.reality.handshake.server) |= $reality_server_name
        ' /root/sbox/sbconfig_server.json > temp_config.json && mv temp_config.json /root/sbox/sbconfig_server.json
    #修改config
    sed -i "s/REALITY_PORT='[^']*'/REALITY_PORT='$reality_port'/" /root/sbox/config
    sed -i "s/REALITY_SERVER_NAME='[^']*'/REALITY_SERVER_NAME='$reality_server_name'/" /root/sbox/config
    sed -i "s/HY_PORT='[^']*'/HY_PORT='$hy_port'/" /root/sbox/config

    # Restart sing-box service
    systemctl restart sing-box
}

# 创建快捷方式
create_shortcut() {
  cat > /root/sbox/mianyang.sh << EOF
#!/usr/bin/env bash
bash <(curl -fsSL https://github.com/vveg26/sing-box-reality-hysteria2/raw/main/beta.sh) \$1
EOF
  chmod +x /root/sbox/mianyang.sh
  ln -sf /root/sbox/mianyang.sh /usr/bin/mianyang

}

uninstall_singbox() {

    disable_hy2hopping
    # Stop and disable services
    systemctl stop sing-box argo
    systemctl disable sing-box argo > /dev/null 2>&1

    # Remove service files
    rm -f /etc/systemd/system/sing-box.service
    rm -f /etc/systemd/system/argo.service

    # Remove configuration and executable files
    rm -f /root/sbox/sbconfig_server.json
    rm -f /root/sbox/sing-box
    rm -f /usr/bin/mianyang
    rm -f /root/sbox/mianyang.sh
    rm -f /root/sbox/cloudflared-linux
    rm -f /root/sbox/self-cert/private.key
    rm -f /root/sbox/self-cert/cert.pem
    rm -f /root/sbox/config

    # Remove directories
    rm -rf /root/sbox/self-cert/
    rm -rf /root/sbox/

    echo "卸载完成"
}

warp_enable(){
    echo "开始注册warp"
    # 注册warp
    output=$(bash -c "$(curl -L warp-reg.vercel.app)")

    # 获取关键词
    v6=$(echo "$output" | grep -oP '"v6": "\K[^"]+' | awk 'NR==2')
    private_key=$(echo "$output" | grep -oP '"private_key": "\K[^"]+')
    reserved=$(echo "$output" | grep -oP '"reserved_str": "\K[^"]+')
    echo $v6
    # File path of the JSON configuration
    config_file="/root/sbox/sbconfig_server.json"

    # Command to modify the JSON configuration in-place
jq --arg private_key "$private_key" --arg v6 "$v6" --arg reserved "$reserved" '
    .route = {
      "rules": [
        {
          "rule_set": "geosite-openai",
          "outbound": "warp-IPv6-out"
        },
        {
          "rule_set": "geosite-netflix",
          "outbound": "warp-IPv6-out" 
        },
        {
          "domain_keyword": [
            "ipaddress"
          ],
          "outbound": "warp-IPv6-out" 
        }
      ],
      "rule_set": [
        { 
          "tag": "geosite-openai",
          "type": "remote",
          "format": "binary",
          "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/openai.srs",
          "download_detour": "direct"
        },
        {
          "tag": "geosite-netflix",
          "type": "remote",
          "format": "binary",
          "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/netflix.srs",
          "download_detour": "direct"
        }
      ]
    } | .outbounds += [
      {
        "type": "direct",
        "tag": "warp-IPv4-out",
        "detour": "wireguard-out",
        "domain_strategy": "ipv4_only"
      },
      {
        "type": "direct",
        "tag": "warp-IPv6-out",
        "detour": "wireguard-out",
        "domain_strategy": "ipv6_only"
      },
      {
        "type": "wireguard",
        "tag": "wireguard-out",
        "server": "162.159.192.1",
        "server_port": 2408,
        "local_address": [
          "172.16.0.2/32",
          $v6 + "/128"
        ],
        "private_key": $private_key,
        "peer_public_key": "bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=",
        "reserved": $reserved,
        "mtu": 1280
      }
    ]' "$config_file" > temp_config.json && mv temp_config.json "$config_file"

    sed -i "s/WARP_ENABLE=FALSE/WARP_ENABLE=TRUE/" /root/sbox/config

    systemctl reload sing-box
}

warp_disable(){
    # File path of the JSON configuration
    config_file="/root/sbox/sbconfig_server.json"

    # Command to remove specific content from the JSON configuration
    jq 'del(.route) | del(.outbounds[] | select(.tag == "warp-IPv4-out" or .tag == "warp-IPv6-out" or .tag == "wireguard-out"))' "$config_file" > temp_config.json && mv temp_config.json "$config_file"
    sed -i "s/WARP_ENABLE=TRUE/WARP_ENABLE=FALSE/" /root/sbox/config
}
#更新singbox
update_singbox(){
      green "更新singbox..."
      download_singbox
      # 检查配置
      if /root/sbox/sing-box check -c /root/sbox/sbconfig_server.json; then
          green "检查配置文件，启动服务..."
          systemctl restart sing-box
      fi
      echo ""  
}

process_singbox() {
    case "$1" in
        1)
            green "重启sing-box..."
            # 检查配置
            if /root/sbox/sing-box check -c /root/sbox/sbconfig_server.json; then
                green "检查配置文件，启动服务..."
                systemctl restart sing-box
            fi
            green "重启完成"
            ;;
        2)
            update_singbox
            ;;
        3)
            echo "singbox基本信息如下："
            systemctl status sing-box
            ;;
        4)
            echo "singbox日志如下："
            journalctl -u sing-box -o cat -f
            ;;
        5)
            echo "singbox服务端如下："
            cat /root/sbox/sbconfig_server.json
            ;;
        *)
            echo "请输入正确选项: $1"
            ;;
    esac
}
# 开启hysteria2端口跳跃
enable_hy2hopping(){

    hy_current_port=$(grep -o "HY_PORT='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
    read -p "选择IPv版本 (输入4或6，默认为4): " -r ip_version
    ip_version=${ip_version:-4}

    if [ "$ip_version" == "4" ]; then
        read -p "输入UDP端口范围的起始值(默认20000): " -r start_port
        start_port=${start_port:-20000}

        read -p "输入UDP端口范围的结束值(默认30000): " -r end_port
        end_port=${end_port:-30000}

        iptables -t nat -A PREROUTING -i eth0 -p udp --dport $start_port:$end_port -j DNAT --to-destination :$hy_current_port

        sed -i "s/HY_HOPPING_START='[^']*'/HY_HOPPING_START='$start_port'/" /root/sbox/config
        sed -i "s/HY_HOPPING_END='[^']*'/HY_HOPPING_END='$end_port'/" /root/sbox/config
        sed -i "s/HY_HOPPING=FALSE/HY_HOPPING='TRUE'/" /root/sbox/config
        echo "IPv4规则已设置：iptables -t nat -A PREROUTING -i eth0 -p udp --dport $start_port:$end_port -j DNAT --to-destination :$hy_current_port"
    elif [ "$ip_version" == "6" ]; then
        read -p "输入UDP端口范围的起始值(默认20000): " -r start_port
        start_port=${start_port:-20000}

        read -p "输入UDP端口范围的结束值(默认30000): " -r end_port
        end_port=${end_port:-30000}

        ip6tables -t nat -A PREROUTING -i eth0 -p udp --dport $start_port:$end_port -j DNAT --to-destination :$hy_current_port

        sed -i "s/HY_HOPPING_START='[^']*'/HY_HOPPING_START='$start_port'/" /root/sbox/config
        sed -i "s/HY_HOPPING_END='[^']*'/HY_HOPPING_END='$end_port'/" /root/sbox/config

        sed -i "s/HY_HOPPING=FALSE/HY_HOPPING='TRUE'/" /root/sbox/config
        echo "IPv6规则已设置：ip6tables -t nat -A PREROUTING -i eth0 -p udp --dport $start_port:$end_port -j DNAT --to-destination :$hy_current_port"
    else
        echo "无效的选择。请输入 '4' 或 '6'。"
    fi
}

disable_hy2hopping(){
  hy_current_port=$(grep -o "HY_PORT='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
  start_port=$(grep -o "HY_HOPPING_START='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
  end_port=$(grep -o "HY_HOPPING_END='[^']*'" /root/sbox/config | awk -F"'" '{print $2}')
  # IPv4
  iptables -t nat -D PREROUTING -i eth0 -p udp --dport $start_port:$end_port -j DNAT --to-destination :$hy_current_port
  # IPv6
  ip6tables -t nat -D PREROUTING -i eth0 -p udp --dport $start_port:$end_port -j DNAT --to-destination :$hy_current_port

  sed -i "s/HY_HOPPING_START='[^']*'/HY_HOPPING_START='0'/" /root/sbox/config
  sed -i "s/HY_HOPPING_END='[^']*'/HY_HOPPING_END='0'/" /root/sbox/config
  sed -i "s/HY_HOPPING='TRUE'/HY_HOPPING=FALSE/" /root/sbox/config


}

# 作者介绍
print_with_delay "Reality Hysteria2 二合一脚本 by 绵阿羊" 0.03
echo ""
echo ""

install_base

# Check if reality.json, sing-box, and sing-box.service already exist
if [ -f "/root/sbox/sbconfig_server.json" ] && [ -f "/root/sbox/config" ] && [ -f "/root/sbox/mianyang.sh" ] && [ -f "/usr/bin/mianyang" ] && [ -f "/root/sbox/sing-box" ] && [ -f "/etc/systemd/system/sing-box.service" ]; then
    echo ""
    yellow "sing-box-reality-hysteria2已经安装"
    echo ""
    green "请选择选项:"
    echo ""
    green "1. 重新安装"
    green "2. 修改配置"
    green "3. 显示客户端配置"
    green "4. sing-box基础操作"
    green "5. 一键开启bbr"
    green "6. warp开启/关闭(v6解锁奈飞和openai)"
    green "7. 重启argo隧道"
    green "8. hysteria2端口跳跃"
    green "0. 卸载"
    echo ""
    read -p "请输入对应数字 (0-8): " choice

    case $choice in
      1)
          show_notice "开始卸载..."
          uninstall_singbox
        ;;
      2)
          #修改sb
          modify_singbox
          show_client_configuration
          exit 0
        ;;
      3)  
          show_client_configuration
          exit 0
      ;;	
      4)  
          echo ""
          echo ""
          green "请选择选项："
          echo ""
          green "1. 重启sing-box"
          green "2. 更新sing-box内核"
          green "3. 查看sing-box状态"
          green "4. 查看sing-box实时日志"
          green "5. 查看sing-box服务端配置"
          echo ""
          read -p "请输入对应数字（1-5）: " user_input
          exit 0
          ;;
      5)
          enable_bbr
          exit 0
          ;;
      6)
          iswarp=$(grep '^WARP_ENABLE=' /root/sbox/config | cut -d'=' -f2)

              if [ "$iswarp" = "FALSE" ]; then
                  yellow "warp分流未开启，准备开启"
                  read -p "是否开启? (y/n): " confirm
                  if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                    warp_enable
                  fi
              else
                  yellow "warp分流已经开启，是否删除warp路由规则"
                  read -p "注意：此操作会覆盖原有分流配置，输入y继续? (y/n): " confirm
                  if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                    warp_disable
                  fi
              fi
              echo "配置文件更新成功"

          exit 0
          ;;
      7)
          systemctl stop argo
          systemctl start argo
          echo "重新启动完成，查看新的客户端信息"
          show_client_configuration
          exit 0
          ;;
      8)
          ishopping=$(grep '^HY_HOPPING=' /root/sbox/config | cut -d'=' -f2)

          if [ "$ishopping" = "FALSE" ]; then
              # 开启端口跳跃
              echo "开始设置端口跳跃范围"
              enable_hy2hopping
              
          else
              yellow "端口跳跃已开启"
              echo ""
              green "请选择选项："
              echo ""
              green "1. 关闭端口跳跃"
              green "2. 重新设置"
              green "3. 查看规则"
              echo ""
              read -p "请输入对应数字（1-3）: " hopping_input
              echo ""
              case $hopping_input in
                1)
                  disable_hy2hopping
                  echo "端口跳跃规则已删除"
                  ;;
                2)
                  disable_hy2hopping
                  echo "端口跳跃规则已删除"
                  echo "开始重新设置端口跳跃"
                  enable_hy2hopping
                  ;;
                3)
                  # 查看IPv4的NAT规则
                  iptables -t nat -L -n -v | grep "udp"
                  # 查看IPv6的NAT规则
                  ip6tables -t nat -L -n -v | grep "udp"
                  ;;
                *)
                  echo "无效的选项"
                  ;;
              esac
          fi

          exit 0
          ;;
      0)

          uninstall_singbox
	        exit 0
          ;;
      *)
          echo "Invalid choice. Exiting."
          exit 1
          ;;
	esac
	fi

mkdir -p "/root/sbox/"

download_singbox

download_cloudflared

# reality
red "开始配置Reality"
echo ""
# Generate key pair
echo "自动生成基本参数"
echo ""
key_pair=$(/root/sbox/sing-box generate reality-keypair)
echo "Key pair生成完成"
echo ""

# Extract private key and public key
private_key=$(echo "$key_pair" | awk '/PrivateKey/ {print $2}' | tr -d '"')
public_key=$(echo "$key_pair" | awk '/PublicKey/ {print $2}' | tr -d '"')

# Generate necessary values
reality_uuid=$(/root/sbox/sing-box generate uuid)
short_id=$(/root/sbox/sing-box generate rand --hex 8)
echo "uuid和短id 生成完成"
echo ""
# Ask for listen port
while true; do
    read -p "请输入Reality端口号 (default: 443): " reality_port
    reality_port=${reality_port:-443}

    # 检测端口是否被占用
    if ss -tuln | grep -q ":$reality_port\b"; then
        echo "端口 $reality_port 已经被占用，请重新输入。"
    else
        break
    fi
done
echo ""
# Ask for server name (sni)
read -p "请输入想要偷取的域名,需要支持tls1.3 (default: itunes.apple.com): " reality_server_name
reality_server_name=${reality_server_name:-itunes.apple.com}
echo ""

# hysteria2
green "开始配置hysteria2"
echo ""
# Generate hysteria necessary values
hy_password=$(/root/sbox/sing-box generate rand --hex 8)
echo "自动生成了8位随机密码"
echo ""
# Ask for listen port
while true; do
    read -p "请输入hysteria2监听端口 (default: 8443): " hy_port
    hy_port=${hy_port:-8443}

    # 检测端口是否被占用
    if ss -tuln | grep -q ":$hy_port\b"; then
        echo "端口 $hy_port 已经被占用，请选择其他端口。"
    else
        break
    fi
done
echo ""

# Ask for self-signed certificate domain
read -p "输入自签证书域名 (default: bing.com): " hy_server_name
hy_server_name=${hy_server_name:-bing.com}
mkdir -p /root/sbox/self-cert/ && openssl ecparam -genkey -name prime256v1 -out /root/sbox/self-cert/private.key && openssl req -new -x509 -days 36500 -key /root/sbox/self-cert/private.key -out /root/sbox/self-cert/cert.pem -subj "/CN=${hy_server_name}"
echo ""
echo "自签证书生成完成"
echo ""

# vmess ws
yellow "开始配置vmess"
echo ""
# Generate hysteria necessary values
vmess_uuid=$(/root/sbox/sing-box generate uuid)
while true; do
    read -p "请输入vmess端口，默认为18443(和tunnel通信用不会暴露在外): " vmess_port
    vmess_port=${vmess_port:-18443}

    # 检测端口是否被占用
    if ss -tuln | grep -q ":$vmess_port\b"; then
        echo "端口 $vmess_port 已经被占用，请选择其他端口。"
    else
        break
    fi
done
echo ""
read -p "ws路径 (无需加斜杠,默认随机生成): " ws_path
ws_path=${ws_path:-$(/root/sbox/sing-box generate rand --hex 6)}


#ip地址
server_ip=$(curl -s4m8 ip.sb -k) || server_ip=$(curl -s6m8 ip.sb -k)

#config配置文件
cat > /root/sbox/config <<EOF

# VPS ip
SERVER_IP='$server_ip'
# Singbox
# Reality
PRIVATE_KEY='$private_key'
PUBLIC_KEY='$public_key'
SHORT_ID='$short_id'
REALITY_UUID='$reality_uuid'
REALITY_PORT='$reality_port'
REALITY_SERVER_NAME='$reality_server_name'
# Hy2
HY_PORT='$hy_port'
HY_SERVER_NAME='$hy_server_name'
HY_PASSWORD='$hy_password'
HY_HOPPING=FALSE
HY_HOPPING_START='0'
HY_HOPPING_END='0'
# Vmess
VMESS_PORT=$vmess_port
VMESS_UUID='$vmess_uuid'
WS_PATH='$ws_path'

# Argo
ARGO_DOMAIN=''

# Warp
WARP_ENABLE=FALSE

EOF

#TODO argo开启
echo "设置argo"
cat > /etc/systemd/system/argo.service << EOF
[Unit]
Description=Cloudflare Tunnel
After=network.target

[Service]
Type=simple
NoNewPrivileges=yes
TimeoutStartSec=0
ExecStart=/bin/bash -c "/root/sbox/cloudflared-linux tunnel --url http://localhost:$vmess_port --no-autoupdate --edge-ip-version auto --protocol http2>/root/sbox/argo.log 2>&1 "
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target

EOF

systemctl daemon-reload
systemctl enable argo > /dev/null 2>&1
systemctl start argo


# sbox配置文件
cat > /root/sbox/sbconfig_server.json << EOF
{
  "log": {
    "disabled": false,
    "level": "info",
    "timestamp": true
  },
  "inbounds": [
    {
      "sniff": true,
      "sniff_override_destination": true,
      "type": "vless",
      "tag": "vless-in",
      "listen": "::",
      "listen_port": $reality_port,
      "users": [
        {
          "uuid": "$reality_uuid",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "$reality_server_name",
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "$reality_server_name",
            "server_port": 443
          },
          "private_key": "$private_key",
          "short_id": ["$short_id"]
        }
      }
    },
    {
        "sniff": true,
        "sniff_override_destination": true,
        "type": "hysteria2",
        "tag": "hy2-in",
        "listen": "::",
        "listen_port": $hy_port,
        "users": [
            {
                "password": "$hy_password"
            }
        ],
        "tls": {
            "enabled": true,
            "alpn": [
                "h3"
            ],
            "certificate_path": "/root/sbox/self-cert/cert.pem",
            "key_path": "/root/sbox/self-cert/private.key"
        }
    },
    {
        "sniff": true,
        "sniff_override_destination": true,
        "type": "vmess",
        "tag": "vmess-in",
        "listen": "::",
        "listen_port": $vmess_port,
        "users": [
            {
                "uuid": "$vmess_uuid",
                "alterId": 0
            }
        ],
        "transport": {
            "type": "ws",
            "path": "$ws_path",
            "max_early_data":2048,
            "early_data_header_name":"Sec-WebSocket-Protocol"
        }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type": "block",
      "tag": "block"
    }
  ]
}
EOF





# Create sing-box.service
cat > /etc/systemd/system/sing-box.service <<EOF
[Unit]
After=network.target nss-lookup.target

[Service]
User=root
WorkingDirectory=/root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
ExecStart=/root/sbox/sing-box run -c /root/sbox/sbconfig_server.json
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF


# Check configuration and start the service
if /root/sbox/sing-box check -c /root/sbox/sbconfig_server.json; then
    echo "检查配置文件，启动服务..."
    systemctl daemon-reload
    systemctl enable sing-box > /dev/null 2>&1
    systemctl start sing-box
    systemctl restart sing-box
    create_shortcut
    show_client_configuration
    mianyang

else
    echo "配置错误"
fi
