#!/bin/bash

# Colores para mensajes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Variables globales
CONFIG_FILE="/etc/hysteria/config.json"
BACKUP_DIR="/etc/hysteria/backups"
LOG_FILE="/var/log/hysteria_manager.log"

# Función para logging
log_message() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo -e "$message" >> "$LOG_FILE"
}

# Función para verificar root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Este script debe ejecutarse como root${NC}"
        exit 1
    fi
}

# Función para respaldar configuración
backup_config() {
    if [ ! -d "$BACKUP_DIR" ]; then
        mkdir -p "$BACKUP_DIR"
    fi
    if [ -f "$CONFIG_FILE" ]; then
        cp "$CONFIG_FILE" "${BACKUP_DIR}/config_$(date +%Y%m%d_%H%M%S).json"
        log_message "Configuración respaldada exitosamente"
    fi
}

# Función para generar contraseñas
generate_password() {
    openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 16
}

# Función para verificar dependencias
check_dependencies() {
    local deps=("curl" "wget" "openssl" "jq")
    local missing=()

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done

    if [ ${#missing[@]} -ne 0 ]; then
        echo -e "${YELLOW}Instalando dependencias faltantes: ${missing[*]}${NC}"
        apt-get update
        apt-get install -y "${missing[@]}"
    fi
}

# Función para obtener IP
get_ip() {
    local ip_type=$1
    if [ "$ip_type" = "public" ]; then
        curl -s https://api.ipify.org || wget -qO- https://api.ipify.org
    else
        ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n 1
    fi
}

# Función para monitorear recursos
monitor_resources() {
    echo -e "${BLUE}Estado actual del sistema:${NC}"
    echo "CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}')%"
    echo "Memoria: $(free -m | awk 'NR==2{printf "%.2f%%", $3*100/$2}')"
    echo "Espacio en disco: $(df -h / | awk 'NR==2{print $5}')"
    echo "Conexiones activas: $(netstat -an | grep :$PORT | grep ESTABLISHED | wc -l)"
}

# Función mejorada de instalación
install_hysteria() {
    check_root
    check_dependencies

    echo -e "${YELLOW}Instalando Hysteria...${NC}"
    log_message "Iniciando instalación de Hysteria"

    # Verificar instalación previa
    if [ -f "/usr/local/bin/hysteria" ]; then
        echo -e "${YELLOW}Hysteria ya está instalado. ¿Desea reinstalar? (s/n)${NC}"
        read -r reinstall
        if [ "$reinstall" != "s" ]; then
            return
        fi
        backup_config
    fi

    # Obtener última versión de GitHub
    LATEST_VERSION=$(curl -s https://api.github.com/repos/apernet/hysteria/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')
    DOWNLOAD_URL="https://github.com/apernet/hysteria/releases/download/${LATEST_VERSION}/hysteria-linux-amd64"

    wget -O /usr/local/bin/hysteria "$DOWNLOAD_URL"
    chmod +x /usr/local/bin/hysteria

    # Configuración mejorada
    mkdir -p /etc/hysteria

    PUBLIC_IP=$(get_ip "public")
    PRIVATE_IP=$(get_ip "private")
    PORT=$(shuf -i 10000-65535 -n 1)
    OBFS_PASSWORD=$(generate_password)
    AUTH_PASSWORD=$(generate_password)
    UPLOAD_SPEED=100
    DOWNLOAD_SPEED=100

    # Preguntar por valores personalizados
    echo -e "${YELLOW}¿Desea personalizar la configuración? (s/n)${NC}"
    read -r customize
    if [ "$customize" = "s" ]; then
        read -p "Puerto (default: $PORT): " custom_port
        read -p "Velocidad de subida en Mbps (default: $UPLOAD_SPEED): " custom_upload
        read -p "Velocidad de bajada en Mbps (default: $DOWNLOAD_SPEED): " custom_download

        PORT=${custom_port:-$PORT}
        UPLOAD_SPEED=${custom_upload:-$UPLOAD_SPEED}
        DOWNLOAD_SPEED=${custom_download:-$DOWNLOAD_SPEED}
    fi

    # Crear configuración con formato mejorado usando jq
    cat > "$CONFIG_FILE" << EOF
{
    "listen": ":$PORT",
    "protocol": "udp",
    "up_mbps": $UPLOAD_SPEED,
    "down_mbps": $DOWNLOAD_SPEED,
    "obfs": {
        "type": "salamander",
        "password": "$OBFS_PASSWORD"
    },
    "auth": {
        "type": "password",
        "password": "$AUTH_PASSWORD"
    },
    "masquerade": {
        "type": "proxy",
        "proxy": {
            "url": "https://www.google.com",
            "rewrite_host": true
        }
    },
    "resolver": {
        "type": "udp",
        "tcp": false,
        "udp": true,
        "timeout": "10s",
        "address": "8.8.8.8:53"
    },
    "acl": {
        "inline": [
            "block(inbound(cidr(\"192.168.0.0/16\")))",
            "block(inbound(cidr(\"172.16.0.0/12\")))",
            "block(inbound(cidr(\"10.0.0.0/8\")))"
        ]
    }
}
EOF

    # Crear servicio systemd mejorado
    cat > /etc/systemd/system/hysteria.service << EOF
[Unit]
Description=Hysteria Server
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/hysteria server -c /etc/hysteria/config.json
Restart=always
RestartSec=3
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF

    # Configurar firewall
    if command -v ufw &> /dev/null; then
        ufw allow "$PORT"/udp
    elif command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --add-port="$PORT"/udp
        firewall-cmd --reload
    fi

    systemctl daemon-reload
    systemctl enable hysteria
    systemctl start hysteria

    echo -e "${GREEN}Instalación completada exitosamente.${NC}"
    log_message "Instalación completada"
    show_config
}

# Función mejorada para mostrar configuración
show_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}Hysteria no está instalado o configurado.${NC}"
        return
    }

    echo -e "${YELLOW}Configuración de Hysteria:${NC}"
    echo "IP pública: $PUBLIC_IP"
    echo "IP privada: $PRIVATE_IP"
    echo "Puerto: $PORT"
    echo "Contraseña de ofuscación: $OBFS_PASSWORD"
    echo "Contraseña de autenticación: $AUTH_PASSWORD"
    echo "Velocidad de subida: $UPLOAD_SPEED Mbps"
    echo "Velocidad de bajada: $DOWNLOAD_SPEED Mbps"

    # Generar cadenas de importación para diferentes clientes
    NEKOBOX_IMPORT="hy2://${AUTH_PASSWORD}@${PUBLIC_IP}:${PORT}/?insecure=1&obfs=salamander&obfs-password=${OBFS_PASSWORD}#Hysteria_Server"
    CLASH_IMPORT="- name: Hysteria_Server\n  type: hysteria\n  server: ${PUBLIC_IP}\n  port: ${PORT}\n  auth-str: ${AUTH_PASSWORD}\n  obfs: salamander\n  obfs-password: ${OBFS_PASSWORD}\n  up: ${UPLOAD_SPEED}\n  down: ${DOWNLOAD_SPEED}"

    echo -e "\n${BLUE}Cadenas de importación:${NC}"
    echo -e "${YELLOW}NekoBox:${NC}\n$NEKOBOX_IMPORT"
    echo -e "\n${YELLOW}Clash:${NC}\n$CLASH_IMPORT"

    # Mostrar estado del servicio
    echo -e "\n${BLUE}Estado del servicio:${NC}"
    systemctl status hysteria --no-pager | grep -E "Active:|Status:"

    # Mostrar estadísticas de conexión
    echo -e "\n${BLUE}Estadísticas de conexión:${NC}"
    monitor_resources
}

change_passwords() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}Hysteria no está instalado o configurado.${NC}"
        return
    }

    backup_config

    read -p "Nueva contraseña de ofuscación (dejar en blanco para generar aleatoriamente): " NEW_OBFS_PASSWORD
    NEW_OBFS_PASSWORD=${NEW_OBFS_PASSWORD:-$(generate_password)}
    read -p "Nueva contraseña de autenticación (dejar en blanco para generar aleatoriamente): " NEW_AUTH_PASSWORD
    NEW_AUTH_PASSWORD=${NEW_AUTH_PASSWORD:-$(generate_password)}

    # Usar jq para actualizar el archivo de configuración
    local temp_config
    temp_config=$(mktemp)
    jq --arg obfs "$NEW_OBFS_PASSWORD" --arg auth "$NEW_AUTH_PASSWORD" \
        '.obfs.password = $obfs | .auth.password = $auth' "$CONFIG_FILE" > "$temp_config"
    mv "$temp_config" "$CONFIG_FILE"

    systemctl restart hysteria
    echo -e "${GREEN}Contraseñas actualizadas exitosamente.${NC}"
    log_message "Contraseñas actualizadas"
    show_config
}

# Función mejorada para desinstalar
uninstall_hysteria() {
    echo -e "${YELLOW}¿Está seguro de que desea desinstalar Hysteria? (s/n)${NC}"
    read -r confirm
    if [ "$confirm" != "s" ]; then
        return
    fi

    echo -e "${YELLOW}¿Desea guardar una copia de la configuración? (s/n)${NC}"
    read -r backup
    if [ "$backup" = "s" ]; then
        backup_config
    fi

    systemctl stop hysteria
    systemctl disable hysteria

    rm -f /usr/local/bin/hysteria
    rm -rf /etc/hysteria
    rm -f /etc/systemd/system/hysteria.service

    # Limpiar reglas de firewall
    if command -v ufw &> /dev/null; then
        ufw delete allow "$PORT"/udp
    elif command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --remove-port="$PORT"/udp
        firewall-cmd --reload
    fi

    systemctl daemon-reload
    echo -e "${GREEN}Hysteria ha sido desinstalado.${NC}"
    log_message "Hysteria desinstalado"
}

# Función para mostrar logs
show_logs() {
    if [ -f "$LOG_FILE" ]; then
        echo -e "${YELLOW}Últimas entradas del log:${NC}"
        tail -n 50 "$LOG_FILE"
    else
        echo -e "${RED}No se encontró el archivo de log.${NC}"
    fi
}

# Menú principal mejorado
show_menu() {
    echo -e "\n${YELLOW}=== Menú de Hysteria ===${NC}"
    echo -e "${BLUE}1.${NC} Instalar y configurar Hysteria"
    echo -e "${BLUE}2.${NC} Ver configuración de Hysteria"
    echo -e "${BLUE}3.${NC} Cambiar contraseñas"
    echo -e "${BLUE}4.${NC} Desinstalar Hysteria"
    echo -e "${BLUE}5.${NC} Mostrar logs"
    echo -e "${BLUE}6.${NC} Monitorear recursos"
    echo -e "${BLUE}7.${NC} Respaldar configuración"
    echo -e "${BLUE}8.${NC} Salir"
    echo -e "${YELLOW}===================${NC}"
}

# Bucle principal
while true; do
    show_menu
    read -p "Seleccione una opción: " choice
    case $choice in
        1)
            install_hysteria
            ;;
        2)
            show_config
            ;;
        3)
            change_passwords
            ;;
        4)
            uninstall_hysteria
            ;;
        5)
            show_logs
            ;;
        6)
            monitor_resources
            ;;
        7)
            backup_config
            echo -e "${GREEN}Configuración respaldada exitosamente.${NC}"
            ;;
        8)
            echo -e "${GREEN}Saliendo...${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Opción inválida. Por favor, intente de nuevo.${NC}"
            ;;
    esac

    echo -e "\nPresione Enter para continuar..."
    read -r
done




