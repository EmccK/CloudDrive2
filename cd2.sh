#!/bin/bash
# https://github.com/sublaim/clouddrive2
# INSTALL_PATH='/opt/clouddrive'
chmod +x "$0"
if [[ $EUID -ne 0 ]]; then
    echo -e "${YELLOW_COLOR}当前操作需要 root 权限，请输入您的密码后回车${RES}"
    exec sudo bash "$0" "$@"
fi

VERSION='latest'

if [ ! -n "$2" ]; then
  INSTALL_PATH='/opt/clouddrive'
else
  if [[ $2 == */ ]]; then
    INSTALL_PATH=${2%?}
  else
    INSTALL_PATH=$2
  fi
  if ! [[ $INSTALL_PATH == */clouddrive ]]; then
    INSTALL_PATH="$INSTALL_PATH/clouddrive"
  fi
fi

# Get_OS
os_type=$(uname)
if [[ "$os_type" == "Linux" ]]; then
  echo "当前系统为 Linux"
  os="linux"
  RED_COLOR='\e[1;31m'
  GREEN_COLOR='\e[1;32m'
  YELLOW_COLOR='\e[1;33m'
  BLUE_COLOR='\e[1;34m'
  PINK_COLOR='\e[1;35m'
  SHAN='\e[1;33;5m'
  RES='\e[0m'
elif [[ "$os_type" == "Darwin" ]]; then
  echo "当前系统为 macOS"
  os="macos"
  RED_COLOR=$(printf '\033[31m')
  GREEN_COLOR=$(printf '\033[32m')
  YELLOW_COLOR=$(printf '\033[33m')
  BLUE_COLOR=$(printf '\033[1m')
  PINK_COLOR=$(printf '\033[35m')
  SHAN=$(printf '\033[5m')
  RES=$(printf '\033[0m')
else
  echo -e "${RED_COLOR}系统未识别${RES}"
  exit 1
fi

clear


# Get platform
if command -v uname >/dev/null 2>&1; then
  platform=$(uname -m)
else
  platform=$(arch)
fi

ARCH="UNKNOWN"

if [ "$platform" = "x86_64" ]; then
  ARCH=amd64
elif [ "$platform" = "aarch64" ]; then
  ARCH=arm64
fi

if [ "$UID" != "0" ]; then
  echo -e "\r\n${RED_COLOR}出错了，请使用 root 权限重试！${RES}\r\n" 1>&2
  exit 1
elif [ "$ARCH" == "UNKNOWN" ]; then
  echo -e "\r\n${RED_COLOR}出错了${RES}，一键安装目前仅支持 x86_64和arm64 平台。\r\n"
  exit 1
elif ! command -v systemctl >/dev/null 2>&1; then
  if command -v opkg >/dev/null 2>&1; then
    if command -v docker >/dev/null 2>&1; then
      check_docker="exist"
    else
      if [ -e "/sbin/procd" ]; then
        check_procd="exist"
      else
        echo -e "\r\n${RED_COLOR}出错了，无法确定你当前的 Linux 发行版。${RES}\r\n"
        exit 1
      fi
    fi
  else
    echo -e "\r\n${RED_COLOR}出错了，无法确定你当前的 Linux 发行版。${RES}\r\n"
    exit 1
  fi
else
  if command -v netstat >/dev/null 2>&1; then
    check_port=$(netstat -lnp | grep 19798 | awk '{print $7}' | awk -F/ '{print $1}')
  else
    echo -e "${GREEN_COLOR}端口检查 ... 不同Linux发行版如报错可忽略${RES}"
    if command -v yum >/dev/null 2>&1; then
      yum install net-tools -y >/dev/null 2>&1
      check_port=$(netstat -lnp | grep 19798 | awk '{print $7}' | awk -F/ '{print $1}')
    else
      apt-get update >/dev/null 2>&1
      apt-get install net-tools -y >/dev/null 2>&1
      check_port=$(netstat -lnp | grep 19798 | awk '{print $7}' | awk -F/ '{print $1}')
    fi
  fi
fi

CHECK() {
  if [ -f "$INSTALL_PATH/clouddrive" ]; then
    echo "此位置已经安装，请选择其他位置"
    exit 0
  fi
  if [ $check_port ]; then
    kill -9 $check_port
  fi
  if [ ! -d "$INSTALL_PATH/" ]; then
    mkdir -p $INSTALL_PATH
  else
    rm -rf $INSTALL_PATH && mkdir -p $INSTALL_PATH
  fi
}

INSTALL() {
  # Download macFUSE
  if [[ "$os_type" == "Darwin" ]]; then
    fuse_version=$(curl -s https://api.github.com/repos/osxfuse/osxfuse/releases/latest | grep -Eo '\s\"name\": \"macfuse-.+?\.dmg\"' | awk -F'"' '{print $4}')
    echo -e "\r\n${GREEN_COLOR}下载 macFUSE $VERSION ...${RES}"
    curl -L https://gh-proxy.com/https://github.com/osxfuse/osxfuse/releases/latest/download/$fuse_version -o /tmp/macfuse.dmg $CURL_BAR
    sudo spctl --master-disable
    if [ $? -eq 0 ]; then
      echo -e "macFUSE 下载完成"
    else
      echo -e "${RED_COLOR}网络中断，请检查网络${RES}"
      exit 1
    fi
    hdiutil mount /tmp/macfuse.dmg
    sudo installer -pkg "/Volumes/macFUSE/Install macFUSE.pkg" -target /
    hdiutil unmount /Volumes/macFUSE
    rm -rf /tmp/macfuse.dmg
  fi
  # Download clouddrive2
  clouddrive_version=$(curl -s https://api.github.com/repos/cloud-fs/cloud-fs.github.io/releases/latest | grep -Eo "\s\"name\": \"clouddrive-2-$os-$platform-.+?\.tgz\"" | awk -F'"' '{print $4}')
  echo -e "\r\n${GREEN_COLOR}下载 clouddrive2 $VERSION ...${RES}"
  curl -L https://gh-proxy.com/https://github.com/cloud-fs/cloud-fs.github.io/releases/latest/download/$clouddrive_version -o /tmp/clouddrive.tgz $CURL_BAR
  if [ $? -eq 0 ]; then
    echo -e "clouddrive 下载完成"
  else
    echo -e "${RED_COLOR}网络中断，请检查网络${RES}"
    exit 1
  fi
  tar zxf /tmp/clouddrive.tgz -C $INSTALL_PATH/
  mv $INSTALL_PATH/clouddrive-2*/* $INSTALL_PATH/ && rm -rf $INSTALL_PATH/clouddrive-2*
  if [ -f $INSTALL_PATH/clouddrive ]; then
    echo -e "${GREEN_COLOR}校验文件成功\r\n${RES}"
  else
    echo -e "${RED_COLOR}校验 clouddrive-2-$os-$platform.tgz 文件失败！${RES}"
    exit 1
  fi
  # remove temp
  rm -f /tmp/clouddrive*
}

DOCKER() {
  # check op
  if command -v opkg >/dev/null 2>&1; then
    if ! grep -q "mount --make-shared /" "/etc/rc.local"; then
      sed -i '/exit 0/i\mount --make-shared /' "/etc/rc.local"
    fi
  fi
  # run docker
  if [ "$check_docker" == "exist" ]; then
    mount --make-shared $(df -P / | tail -1 | awk '{ print $6 }')
    echo -e "${GREEN_COLOR}正在下载 clouddrive 镜像，请稍候...${RES}"
    docker pull cloudnas/clouddrive2:latest 
    docker run -d \
    --name clouddrive \
    --restart unless-stopped \
    --env CLOUDDRIVE_HOME=/Config \
    -v /CloudNAS:/CloudNAS:shared \
    -v /Config:/Config \
    -v /media:/media:shared \
    --network host \
    --pid host \
    --privileged \
    --device /dev/fuse:/dev/fuse \
    cloudnas/clouddrive2:latest 
    if [ $? -eq 0 ]; then
      echo "clouddrive 容器已成功运行"
    else
      echo -e "${RED_COLOR}clouddrive 容器未能成功运行${RES}"
      exit 1
    fi
  fi
}

get-local-ipv4-using-hostname() {
  hostname -I 2>&- | awk '{print $1}'
}

# iproute2
get-local-ipv4-using-iproute2() {
  # OR ip route get 1.2.3.4 | awk '{print $7}'
  ip -4 route 2>&- | awk '{print $NF}' | grep -Eo --color=never '[0-9]+(\.[0-9]+){3}'
}

# net-tools
get-local-ipv4-using-ifconfig() {
  ( ifconfig 2>&- || ip addr show 2>&- ) | grep -Eo '^\s+inet\s+\S+' | grep -Eo '[0-9]+(\.[0-9]+){3}' | grep -Ev '127\.0\.0\.1|0\.0\.0\.0'
}

# 获取本机 IPv4 地址
get-local-ipv4() {
  set -o pipefail
  get-local-ipv4-using-hostname || get-local-ipv4-using-iproute2 || get-local-ipv4-using-ifconfig
}
get-local-ipv4-select() {
  local ips=$(get-local-ipv4)
  local retcode=$?
  if [ $retcode -ne 0 ]; then
      return $retcode
  fi
  grep -m 1 "^192\." <<<"$ips" || \
  grep -m 1 "^172\." <<<"$ips" || \
  grep -m 1 "^10\." <<<"$ips" || \
  head -n 1 <<<"$ips"
}

SESSIONS() {
if [[ "$os_type" == "Linux" ]]; then
  if [[ "$check_procd" == "exist" ]]; then
    touch /etc/init.d/clouddrive
    cat > /etc/init.d/clouddrive << EOF
#!/bin/sh /etc/rc.common

USE_PROCD=1

START=99
STOP=99

start_service() {
    procd_open_instance
    procd_set_param command $INSTALL_PATH/clouddrive
    procd_set_param respawn
    procd_set_param pidfile /var/run/clouddrive.pid
    procd_close_instance
}
EOF
    chmod +x /etc/init.d/clouddrive
    /etc/init.d/clouddrive start
    /etc/init.d/clouddrive enable
  else
  cat >/etc/systemd/system/clouddrive.service <<EOF
  [Unit]
  Description=clouddrive service
  Wants=network.target
  After=network.target network.service
  
  [Service]
  Type=simple
  WorkingDirectory=$INSTALL_PATH
  ExecStart=$INSTALL_PATH/clouddrive server
  KillMode=process
  
  [Install]
  WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl start clouddrive >/dev/null 2>&1
  systemctl enable clouddrive >/dev/null 2>&1
  fi
elif [[ "$os_type" == "Darwin" ]]; then
  cat >$HOME/Library/LaunchAgents/clouddrive.plist <<EOF
  <?xml version="1.0" encoding="UTF-8"?>
  <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
  <plist version="1.0">
      <dict>
          <key>Label</key>
          <string>clouddirve</string>
          <key>KeepAlive</key>
          <true/>
          <key>ProcessType</key>
          <string>Background</string>
          <key>RunAtLoad</key>
          <true/>
          <key>WorkingDirectory</key>
          <string>$INSTALL_PATH</string>
          <key>ProgramArguments</key>
          <array>
              <string>$INSTALL_PATH/clouddrive</string>
          </array>
      </dict>
  </plist>
EOF
  launchctl load $HOME/Library/LaunchAgents/clouddrive.plist
  launchctl start $HOME/Library/LaunchAgents/clouddrive.plist
fi
}

SUCCESS() {
  clear
  echo -e "\xe8\xb4\xad\xe4\xb9\xb0\xe4\xbc\x9a\xe5\x91\x98\xe5\xa1\xab\xe6\x8e\
\xa8\xe8\x8d\x90\xe7\xa0\x81\xe6\x9c\x80\xe9\xab\x98\xe4\xbc\x98\xe6\
\x83\xa0${GREEN_COLOR}\x31\x30\x30\xe5\x85\x83${RES}"
  echo -e "\xe4\xbc\x98\xe6\x83\xa0\xe7\xa0\x81\xef\xbc\x9a${GREEN_COLOR}\x58\x6d\x33\x4b\x32\x35\x44\x33${RES}\r\n"
  echo -e "${GREEN_COLOR}clouddrive2 安装成功！${RES}"
  echo -e "访问地址：${GREEN_COLOR}http://$(get-local-ipv4-select):19798/${RES}\r\n"
}

UNINSTALL() {
  if [ "$check_docker" == "exist" ]; then
    if docker ps -a --format "{{.Names}}" | grep -q "clouddrive"; then
      docker stop clouddrive
      docker rm clouddrive
      echo "clouddrive 服务已停止并移除"
      docker images --format "{{.Repository}}:{{.Tag}}" | grep "cloudnas/clouddrive2" | xargs docker rmi
      echo "clouddrive 镜像已移除"
    fi
  else
    echo -e "\r\n${GREEN_COLOR}卸载 clouddrive2 ...${RES}\r\n"
    echo -e "${GREEN_COLOR}停止进程${RES}"
    if [[ "$os_type" == "Darwin" ]]; then
      launchctl unload $HOME/Library/LaunchAgents/clouddrive.plist >/dev/null 2>&1
      launchctl stop $HOME/Library/LaunchAgents/clouddrive.plist >/dev/null 2>&1
      echo -e "${GREEN_COLOR}清除残留文件${RES}"
      rm -rf $INSTALL_PATH $HOME/Library/LaunchAgents/clouddrive.plist
      launchctl load $HOME/Library/LaunchAgents/clouddrive.plist >/dev/null 2>&1
    else
      if [[ "$check_procd" == "exist" ]]; then
        /etc/init.d/clouddrive stop
        /etc/init.d/clouddrive disable
        rm -rf $INSTALL_PATH "/etc/init.d/clouddrive"	
      else
        systemctl stop clouddrive >/dev/null 2>&1
        systemctl disable clouddrive >/dev/null 2>&1
        echo -e "${GREEN_COLOR}清除残留文件${RES}"
        rm -rf $INSTALL_PATH "/etc/systemd/system/clouddrive.service"
        systemctl daemon-reload
      fi
    fi
  fi
  echo -e "\r\n${GREEN_COLOR}clouddrive2 已在系统中移除！${RES}\r\n"
}


# CURL 进度显示
if curl --help | grep progress-bar >/dev/null 2>&1; then # $CURL_BAR
  CURL_BAR="--progress-bar"
fi

# The temp directory must exist
if [ ! -d "/tmp" ]; then
  mkdir -p /tmp
fi

# Fuck bt.cn (BT will use chattr to lock the php isolation config)
chattr -i -R $INSTALL_PATH >/dev/null 2>&1

if [ "$1" = "uninstall" ]; then
  UNINSTALL
elif [ "$1" = "install" ]; then
  if [ "$check_docker" == "exist" ]; then
    DOCKER 
    SUCCESS
  else
    CHECK
    INSTALL
    SESSIONS
    if [ -f "$INSTALL_PATH/clouddrive" ]; then
      SUCCESS
    else
      echo -e "${RED_COLOR} 安装失败${RES}"
    fi
  fi
else
  echo -e "${RED_COLOR} 错误的命令${RES}"
fi
