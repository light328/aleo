#!/bin/bash
APPROOT=$(dirname $(readlink -e $0))

# If you want to run as another user, please modify \$UID to be owned by this user
if [[ "$UID" -ne '0' ]]; then
  echo "Error: You must run this script as root!"; exit 1
fi

uninstall_package() {
  systemctl stop aleo
  systemctl disable aleo
  rm -f /etc/systemd/system/aleo.service
  rm -rf /start_aleo.sh
  rm -rf /stop_aleo.sh
  rm -rf /aleowrapper
  rm -rf /prover.log
  rm -rf /config.cfg
}

WORKER=
POOL=
while getopts "w:p:u" opt; do
  case "$opt" in
    w) echo "Worker: $OPTARG"
       WORKER=$OPTARG
       ;;
    p) echo "Pool  : $OPTARG"
       POOL=$OPTARG
       ;;
    u) echo "Uninstall aleo package..."
       uninstall_package
       echo "Done."
       exit 0
       ;;
    *) echo "Unknown option: \$opt"
       exit 1
       ;;
  esac
done

if [ ! -f $APPROOT/config.cfg ]; then
cat << EOF > /config.cfg
WORKER=$WORKER
POOL=$POOL
EOF
fi
source /config.cfg

if [[ "$POOL" == "xxx.xxx.xxx.xxx:xxxx" || "$POOL" == "" ]]; then
    echo -e "Please edit the '/config.cfg'\n"
    exit 1
fi

if [[ ! -f /aleominer ]]; then
    echo -e "aleominer not found\n"
    exit 1
fi
chmod +x /aleominer

cat << EOF > /etc/systemd/system/aleo.service
[Unit]
Description=Aleo Service
Documentation=https://www.f2pool.com/
After=network-online.target
Wants=network-online.target

[Service]
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=+$APPROOT/aleowrapper
Restart=on-failure
RestartPreventExitStatus=23

[Install]
WantedBy=multi-user.target
EOF

cat << SUPER-EOF > /aleowrapper
#!/bin/bash
set -o pipefail

source $APPROOT/config.cfg

if [[ "\$POOL" == "xxx.xxx.xxx.xxx:xxxx" || "\$POOL" == "" ]]; then
    echo -e "Please edit the '/config.cfg'\n"
    exit 1
fi

LOG_PATH="/prover.log"
APP_PATH="/aleominer"

cat << EOF >> \$LOG_PATH
=============================================================================
Account name    : \$WORKER
Pool            : \$POOL
=============================================================================
EOF
\$APP_PATH -w "\$WORKER" -u "\$POOL" >> \$LOG_PATH 2>&1
SUPER-EOF
chmod +x /aleowrapper

cat << EOF > /start_aleo.sh
#!/bin/bash
sudo systemctl start aleo
EOF
chmod +x /start_aleo.sh

cat << EOF > /stop_aleo.sh
#!/bin/bash
sudo systemctl stop aleo
EOF
chmod +x /stop_aleo.sh

systemctl enable aleo
systemctl start aleo
