#!/bin/bash
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

local_ip=$(hostname -I | awk '{print $1}')
arch=$(uname -m)

echo -e "${GREEN}============================================================================${NC}"
echo -e "${GREEN}==================== Script Install GenieACS All In One. ===================${NC}"
echo -e "${GREEN}==================== NodeJS, MongoDB, GenieACS, NVM ========================${NC}"
echo -e "${GREEN}============================================================================${NC}"
echo -e "${GREEN}Sebelum melanjutkan, pastikan Anda menggunakan Ubuntu 20.04 (Focal) atau 22.04 (Jammy).${NC}"
echo -e "${GREEN}Apakah Anda ingin melanjutkan? (y/n)${NC}"
read confirmation
if [ "$confirmation" != "y" ]; then
    echo -e "${GREEN}Install dibatalkan. Tidak ada perubahan dalam server Anda.${NC}"
    exit 1
fi

for ((i = 5; i >= 1; i--)); do
	sleep 1
    echo "Melanjutkan dalam $i. Tekan ctrl+c untuk membatalkan."
done

# Fungsi untuk memeriksa dan menginstal NVM dan Node.js
install_nvm_and_node() {
    echo -e "${GREEN}================== Memeriksa dan Menginstal NVM & NodeJS ==================${NC}"
    if ! command -v nvm &> /dev/null; then
        echo -e "${GREEN}NVM tidak terdeteksi, menginstal NVM...${NC}"
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash

        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

        if ! command -v nvm &> /dev/null; then
            echo -e "${RED}Gagal menginstal NVM. Silakan coba jalankan skrip lagi.${NC}"
            exit 1
        fi
        echo -e "${GREEN}NVM berhasil diinstal.${NC}"
    else
        echo -e "${GREEN}NVM sudah terinstal.${NC}"
    fi

    # Memeriksa versi Node.js yang sudah ada
    if command -v node &> /dev/null; then
        current_node_version=$(node -v)
        echo -e "${GREEN}Node.js sudah terinstal: ${current_node_version}. Memeriksa ketersediaan versi terbaru...${NC}"
    fi

    # Menginstal versi LTS terbaru dari Node.js
    nvm install --lts
    nvm use --lts
    nvm alias default 'lts/*'
    echo -e "${GREEN}Node.js versi LTS terbaru berhasil diinstal: $(node -v).${NC}"
    echo -e "${GREEN}================== NodeJS dan NVM berhasil diinstal ==================${NC}"
}

# Memeriksa dan menginstal GenieACS
install_genieacs() {
    if ! systemctl is-active --quiet genieacs-{cwmp,fs,ui,nbi}; then
        echo -e "${GREEN}================== Menginstal genieACS CWMP, FS, NBI, UI ==================${NC}"
        npm install -g genieacs@1.2.13
        useradd --system --no-create-home --user-group genieacs || true
        mkdir -p /opt/genieacs
        mkdir -p /opt/genieacs/ext
        chown genieacs:genieacs /opt/genieacs/ext
        cat << EOF > /opt/genieacs/genieacs.env
GENIEACS_CWMP_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-cwmp-access.log
GENIEACS_NBI_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-nbi-access.log
GENIEACS_FS_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-fs-access.log
GENIEACS_UI_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-ui-access.log
GENIEACS_DEBUG_FILE=/var/log/genieacs/genieacs-debug.yaml
GENIEACS_EXT_DIR=/opt/genieacs/ext
GENIEACS_UI_JWT_SECRET=secret
EOF
        chown genieacs:genieacs /opt/genieacs/genieacs.env
        chown genieacs. /opt/genieacs -R
        chmod 600 /opt/genieacs/genieacs.env
        mkdir -p /var/log/genieacs
        chown genieacs. /var/log/genieacs
        
        # create systemd unit files
        ## CWMP
        cat << EOF > /etc/systemd/system/genieacs-cwmp.service
[Unit]
Description=GenieACS CWMP
After=network.target

[Service]
User=genieacs
EnvironmentFile=/opt/genieacs/genieacs.env
ExecStart=/usr/bin/env genieacs-cwmp

[Install]
WantedBy=default.target
EOF

        ## NBI
        cat << EOF > /etc/systemd/system/genieacs-nbi.service
[Unit]
Description=GenieACS NBI
After=network.target
 
[Service]
User=genieacs
EnvironmentFile=/opt/genieacs/genieacs.env
ExecStart=/usr/bin/env genieacs-nbi
 
[Install]
WantedBy=default.target
EOF

        ## FS
        cat << EOF > /etc/systemd/system/genieacs-fs.service
[Unit]
Description=GenieACS FS
After=network.target
 
[Service]
User=genieacs
EnvironmentFile=/opt/genieacs/genieacs.env
ExecStart=/usr/bin/env genieacs-fs
 
[Install]
WantedBy=default.target
EOF

        ## UI
        cat << EOF > /etc/systemd/system/genieacs-ui.service
[Unit]
Description=GenieACS UI
After=network.target
 
[Service]
User=genieacs
EnvironmentFile=/opt/genieacs/genieacs.env
ExecStart=/usr/bin/env genieacs-ui
 
[Install]
WantedBy=default.target
EOF

        # config logrotate
        cat << EOF > /etc/logrotate.d/genieacs
/var/log/genieacs/*.log /var/log/genieacs/*.yaml {
    daily
    rotate 30
    compress
    delaycompress
    dateext
}
EOF
        echo -e "${GREEN}========== Install APP GenieACS selesai... ==============${NC}"
        systemctl daemon-reload
        systemctl enable --now genieacs-{cwmp,fs,ui,nbi}
        systemctl start genieacs-{cwmp,fs,ui,nbi}    
        echo -e "${GREEN}================== Sukses genieACS CWMP, FS, NBI, UI ==================${NC}"
    else
        echo -e "${GREEN}============================================================================${NC}"
        echo -e "${GREEN}=================== GenieACS sudah terinstal sebelumnya. ==================${NC}"
    fi
}

# Menjalankan fungsi-fungsi instalasi
install_nvm_and_node
install_mongodb
install_genieacs

# Sukses
echo -e "${GREEN}============================================================================${NC}"
echo -e "${GREEN}========== GenieACS UI akses port 3000. : http://$local_ip:3000 ============${NC}"
echo -e "${GREEN}============================================================================${NC}"
