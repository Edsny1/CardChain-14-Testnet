#!/bin/bash

# Renkler
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# ASCII Art
print_logo() {
    echo -e "${CYAN}"
    echo "  ██████╗ ███████╗██╗  ██╗██╗   ██╗ █████╗ ███╗   ██╗██╗  ██╗"
    echo "  ██╔═══██╗██╔════╝██║  ██║██║   ██║██╔══██╗████╗  ██║██║ ██╔╝"
    echo "  ██║   ██║███████╗███████║██║   ██║███████║██╔██╗ ██║█████╔╝ "
    echo "  ██║   ██║╚════██║██╔══██║╚██╗ ██╔╝██╔══██║██║╚██╗██║██╔═██╗ "
    echo "  ╚██████╔╝███████║██║  ██║ ╚████╔╝ ██║  ██║██║ ╚████║██║  ██╗"
    echo "   ╚═════╝ ╚══════╝╚═╝  ╚═╝  ╚═══╝  ╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝"
    echo -e "${NC}"
    echo -e "${YELLOW}============================================================${NC}"
    echo -e "${WHITE}         Cardchain-14 Testnet Kurulum Scripti${NC}"
    echo -e "${WHITE}              Hazırlayan: OshVanK${NC}"
    echo -e "${YELLOW}============================================================${NC}"
    echo
}

# Hata durumunda çıkış
set -e

# Fonksiyonlar
print_step() {
    echo -e "${GREEN}[ADIM]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[BİLGİ]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[UYARI]${NC} $1"
}

print_error() {
    echo -e "${RED}[HATA]${NC} $1"
}

# Kullanıcı girişleri
get_user_input() {
    print_step "Kullanıcı bilgileri alınıyor..."
    echo
    read -p "$(echo -e ${CYAN}Moniker adınızı girin: ${NC})" MONIKER
    read -p "$(echo -e ${CYAN}Port numaranızı girin (örn: 31): ${NC})" PORT
    
    # Wallet adı moniker ile aynı olacak
    WALLET=$MONIKER
    
    echo
    print_info "Moniker: $MONIKER"
    print_info "Wallet: $WALLET"
    print_info "Port: $PORT"
    echo
    read -p "$(echo -e ${YELLOW}Bilgiler doğru mu? (y/n): ${NC})" confirm
    if [[ $confirm != "y" && $confirm != "Y" ]]; then
        print_error "Kurulum iptal edildi."
        exit 1
    fi
}

# Sistem güncellemeleri
update_system() {
    print_step "Sistem güncelleniyor..."
    sudo apt update && sudo apt upgrade -y
    print_info "Sistem güncellendi."
}

# Gerekli paketleri kontrol et ve yükle
install_dependencies() {
    print_step "Gerekli paketler kontrol ediliyor..."
    
    PACKAGES="curl git wget htop tmux build-essential jq make lz4 gcc unzip"
    MISSING_PACKAGES=""
    
    for package in $PACKAGES; do
        if ! dpkg -l | grep -q "^ii  $package "; then
            MISSING_PACKAGES="$MISSING_PACKAGES $package"
        fi
    done
    
    if [ ! -z "$MISSING_PACKAGES" ]; then
        print_info "Eksik paketler yükleniyor:$MISSING_PACKAGES"
        sudo apt install $MISSING_PACKAGES -y
    else
        print_info "Tüm gerekli paketler zaten yüklü."
    fi
}

# Go kurulumu kontrol et
install_go() {
    print_step "Go kurulumu kontrol ediliyor..."
    
    GO_VERSION="1.22.0"
    
    if command -v go &> /dev/null; then
        CURRENT_GO_VERSION=$(go version | grep -o 'go[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1)
        if [[ "$CURRENT_GO_VERSION" == "go$GO_VERSION" ]]; then
            print_info "Go $GO_VERSION zaten yüklü."
            return
        else
            print_warning "Farklı Go versiyonu tespit edildi: $CURRENT_GO_VERSION"
            print_info "Go $GO_VERSION yükleniyor..."
        fi
    else
        print_info "Go yüklü değil. Go $GO_VERSION yükleniyor..."
    fi
    
    cd $HOME
    wget "https://golang.org/dl/go${GO_VERSION}.linux-amd64.tar.gz"
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf "go${GO_VERSION}.linux-amd64.tar.gz"
    rm "go${GO_VERSION}.linux-amd64.tar.gz"
    
    # Path'i güncelle
    if ! grep -q "/usr/local/go/bin" ~/.bash_profile; then
        echo "export PATH=\$PATH:/usr/local/go/bin:\$HOME/go/bin" >> ~/.bash_profile
    fi
    
    source ~/.bash_profile
    export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin
    
    print_info "Go kurulumu tamamlandı: $(go version)"
}

# Eski kurulumu temizle
cleanup_old_installation() {
    print_step "Eski kurulum temizleniyor..."
    
    # Servisi durdur
    sudo systemctl stop cardchaind 2>/dev/null || true
    sudo systemctl disable cardchaind 2>/dev/null || true
    
    # Eski dosyaları temizle
    rm -rf ~/.cardchaind
    sudo rm -f /etc/systemd/system/cardchaind.service
    rm -f $HOME/go/bin/cardchaind
    
    print_info "Eski kurulum temizlendi."
}

# Çevre değişkenlerini ayarla
set_variables() {
    print_step "Çevre değişkenleri ayarlanıyor..."
    
    echo "export WALLET=\"$WALLET\"" >> $HOME/.bash_profile
    echo "export MONIKER=\"$MONIKER\"" >> $HOME/.bash_profile
    echo "export CARDCHAIN_CHAIN_ID=\"cardtestnet-14\"" >> $HOME/.bash_profile
    echo "export CARDCHAIN_PORT=\"$PORT\"" >> $HOME/.bash_profile
    source $HOME/.bash_profile
    
    # Geçici olarak bu session için de ayarla
    export WALLET="$WALLET"
    export MONIKER="$MONIKER"
    export CARDCHAIN_CHAIN_ID="cardtestnet-14"
    export CARDCHAIN_PORT="$PORT"
    
    print_info "Çevre değişkenleri ayarlandı."
}

# Binary dosyasını indir ve kur
install_binary() {
    print_step "Cardchain binary dosyası indiriliyor..."
    
    cd $HOME
    wget https://github.com/DecentralCardGame/Cardchain/releases/download/v0.18.0/cardchaind -O $HOME/go/bin/cardchaind
    chmod +x $HOME/go/bin/cardchaind
    
    print_info "Binary dosyası kuruldu."
}

# Node konfigürasyonu
configure_node() {
    print_step "Node konfigürasyonu yapılıyor..."
    
    cardchaind config node tcp://localhost:${CARDCHAIN_PORT}657
    cardchaind config keyring-backend os
    cardchaind config chain-id cardtestnet-14
    cardchaind init "$MONIKER" --chain-id cardtestnet-14
    
    print_info "Node konfigürasyonu tamamlandı."
}

# Genesis ve peer ayarları
setup_genesis_and_peers() {
    print_step "Genesis ve peer ayarları yapılıyor..."
    
    # Genesis dosyasını indir
    wget -O $HOME/.cardchaind/config/genesis.json https://cardchain.crowdcontrol.network/files/genesis.json
    
    # Peer ayarları
    SEEDS=""
    PEERS="1cb10562e90e6546fa7bc69b8bf634270b67a9f7@152.53.103.89:32056"
    sed -i -e "s/^seeds *=.*/seeds = \"$SEEDS\"/; s/^persistent_peers *=.*/persistent_peers = \"$PEERS\"/" $HOME/.cardchaind/config/config.toml
    
    print_info "Genesis ve peer ayarları tamamlandı."
}

# Port ayarları
configure_ports() {
    print_step "Port ayarları yapılıyor..."
    
    # app.toml port ayarları
    sed -i.bak -e "s%:1317%:${CARDCHAIN_PORT}317%g;
    s%:8080%:${CARDCHAIN_PORT}080%g;
    s%:9090%:${CARDCHAIN_PORT}090%g;
    s%:9091%:${CARDCHAIN_PORT}091%g;
    s%:8545%:${CARDCHAIN_PORT}545%g;
    s%:8546%:${CARDCHAIN_PORT}546%g;
    s%:6065%:${CARDCHAIN_PORT}065%g" $HOME/.cardchaind/config/app.toml
    
    # config.toml port ayarları
    sed -i.bak -e "s%:26658%:${CARDCHAIN_PORT}658%g;
    s%:26657%:${CARDCHAIN_PORT}657%g;
    s%:6060%:${CARDCHAIN_PORT}060%g;
    s%:26656%:${CARDCHAIN_PORT}656%g;
    s%^external_address = \"\"%external_address = \"$(wget -qO- eth0.me):${CARDCHAIN_PORT}656\"%;
    s%:26660%:${CARDCHAIN_PORT}660%g" $HOME/.cardchaind/config/config.toml
    
    print_info "Port ayarları tamamlandı."
}

# Pruning ve diğer ayarlar
configure_pruning_and_gas() {
    print_step "Pruning ve gas ayarları yapılıyor..."
    
    # Pruning ayarları
    sed -i -e "s/^pruning *=.*/pruning = \"nothing\"/" $HOME/.cardchaind/config/app.toml
    sed -i -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \"100\"/" $HOME/.cardchaind/config/app.toml
    sed -i -e "s/^pruning-interval *=.*/pruning-interval = \"50\"/" $HOME/.cardchaind/config/app.toml
    
    # Gas ve diğer ayarlar
    sed -i 's|minimum-gas-prices =.*|minimum-gas-prices = "0.0ubpf"|g' $HOME/.cardchaind/config/app.toml
    sed -i -e "s/prometheus = false/prometheus = true/" $HOME/.cardchaind/config/config.toml
    sed -i -e "s/^indexer *=.*/indexer = \"null\"/" $HOME/.cardchaind/config/config.toml
    
    print_info "Pruning ve gas ayarları tamamlandı."
}

# Servis dosyası oluştur
create_service() {
    print_step "Servis dosyası oluşturuluyor..."
    
    sudo tee /etc/systemd/system/cardchaind.service > /dev/null <<EOF
[Unit]
Description=Cardchain node
After=network-online.target
[Service]
User=$USER
WorkingDirectory=$HOME/.cardchaind
ExecStart=/root/go/bin/cardchaind start --home $HOME/.cardchaind
Restart=on-failure
RestartSec=5
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF
    
    print_info "Servis dosyası oluşturuldu."
}

# Servisi başlat
start_service() {
    print_step "Servis başlatılıyor..."
    
    sudo systemctl daemon-reload
    sudo systemctl enable cardchaind
    sudo systemctl restart cardchaind
    
    print_info "Servis başlatıldı."
}

# Kurulum tamamlandı mesajı
installation_complete() {
    echo
    echo -e "${GREEN}============================================================${NC}"
    echo -e "${WHITE}          KURULUM BAŞARIYLA TAMAMLANDI!${NC}"
    echo -e "${GREEN}============================================================${NC}"
    echo
    echo -e "${CYAN}Yararlı Komutlar:${NC}"
    echo -e "${YELLOW}Node durumu kontrol:${NC} sudo systemctl status cardchaind"
    echo -e "${YELLOW}Node logları:${NC} sudo journalctl -u cardchaind -fo cat"
    echo -e "${YELLOW}Node yeniden başlat:${NC} sudo systemctl restart cardchaind"
    echo
    echo -e "${CYAN}Cüzdan İşlemleri:${NC}"
    echo -e "${YELLOW}Yeni cüzdan:${NC} cardchaind keys add $WALLET"
    echo -e "${YELLOW}Cüzdan import:${NC} cardchaind keys add $WALLET --recover"
    echo -e "${YELLOW}Cüzdan listesi:${NC} cardchaind keys list"
    echo
    echo -e "${CYAN}Validator Oluşturma:${NC}"
    echo -e "${YELLOW}cardchaind tx staking create-validator \\"
    echo -e "--amount 1000000ubpf \\"
    echo -e "--from $WALLET \\"
    echo -e "--commission-rate 0.1 \\"
    echo -e "--commission-max-rate 0.2 \\"
    echo -e "--commission-max-change-rate 0.01 \\"
    echo -e "--min-self-delegation 1 \\"
    echo -e "--pubkey \$(cardchaind tendermint show-validator) \\"
    echo -e "--moniker \"$MONIKER\" \\"
    echo -e "--identity \"\" \\"
    echo -e "--details \"\" \\"
    echo -e "--chain-id cardtestnet-14 \\"
    echo -e "--gas auto --gas-adjustment 1.5 \\"
    echo -e "-y${NC}"
    echo
    echo -e "${GREEN}Sync durumunu kontrol etmek için birkaç dakika bekleyin!${NC}"
    echo
}

# Ana fonksiyon
main() {
    print_logo
    get_user_input
    update_system
    install_dependencies
    install_go
    cleanup_old_installation
    set_variables
    install_binary
    configure_node
    setup_genesis_and_peers
    configure_ports
    configure_pruning_and_gas
    create_service
    start_service
    installation_complete
    
    echo -e "${GREEN}Node loglarını görüntülemek için:${NC}"
    echo -e "${YELLOW}sudo journalctl -u cardchaind -fo cat${NC}"
}

# Scripti çalıştır
main
