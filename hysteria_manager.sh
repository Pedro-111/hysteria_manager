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

# Función para instalar y configurar Hysteria
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
    echo -e "${YELLOW}Instalando Hysteria...${NC}"
    
    # Descargar e instalar Hysteria
    wget https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-amd64
    chmod +x hysteria-linux-amd64
    mv hysteria-linux-amd64 /usr/local/bin/hysteria
    # Crear directorio de configuración
    mkdir -p /etc/hysteria
    # Generar certificado autofirmado
    openssl req -x509 -nodes -newkey rsa:4096 -keyout /etc/hysteria/server.key -out /etc/hysteria/server.crt -days 365 -subj "/CN=hysteria.server"
    # Solicitar puerto
    read -p "Ingrese el puerto para Hysteria (default: 36712): " PORT
    PORT=${PORT:-36712}
    # Generar contraseñas aleatorias
    OBFS_PASSWORD=$(generate_password)
    AUTH_PASSWORD=$(generate_password)
    # Obtener la IP pública
    PUBLIC_IP=$(curl -s https://api.ipify.org)
    # Crear archivo de configuración
    cat > /etc/hysteria/config.json <<EOF
{
  "listen": ":$PORT",
  "tls": {
    "cert": "/etc/hysteria/server.crt",
    "key": "/etc/hysteria/server.key"
  },
  "obfs": {
    "type": "salamander",
    "salamander": {
      "password": "$OBFS_PASSWORD"
    }
  },
  "auth": {
    "type": "password",
    "password": "$AUTH_PASSWORD"
  }
}
EOF
    # Crear servicio systemd
    cat > /etc/systemd/system/hysteria.service <<EOF
[Unit]
Description=Hysteria VPN Server
After=network.target
[Service]
ExecStart=/usr/local/bin/hysteria server -c /etc/hysteria/config.json
Restart=always
RestartSec=3
[Install]
WantedBy=multi-user.target
EOF
    # Habilitar e iniciar el servicio
    systemctl enable hysteria
    systemctl start hysteria
    echo -e "${GREEN}Hysteria instalado y configurado exitosamente.${NC}"
    show_config
}
# Función para verificar e instalar jq
check_jq() {
    if ! command -v jq >/dev/null 2>&1; then
        echo -e "${YELLOW}jq no está instalado. Instalando...${NC}"
        apt-get update >/dev/null 2>&1
        apt-get install -y jq >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}jq instalado exitosamente.${NC}"
        else
            echo -e "${RED}Error al instalar jq. Por favor, instálelo manualmente.${NC}"
            exit 1
        fi
    fi
}

# Función para obtener valores del config sin jq (fallback)
get_config_value() {
    local file="$1"
    local key="$2"
    grep -o "\"$key\":[^,}]*" "$file" | cut -d':' -f2 | tr -d '" ' || echo ""
}

# Función para mostrar configuración
show_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}Hysteria no está instalado o configurado.${NC}"
        return
    fi
    
    # Verificar e instalar jq si es necesario
    check_jq
    
    echo -e "${YELLOW}Obteniendo configuración...${NC}"
    
    # Intentar obtener valores usando jq con manejo mejorado de la estructura
    if command -v jq >/dev/null 2>&1; then
        local port=$(jq -r '.listen' "$CONFIG_FILE" 2>/dev/null | grep -oP '\d+' || echo "Error")
        local upload_mbps=$(jq -r '.up_mbps // "100"' "$CONFIG_FILE" 2>/dev/null)
        local download_mbps=$(jq -r '.down_mbps // "100"' "$CONFIG_FILE" 2>/dev/null)
        # Manejo específico para la estructura de Salamander
        local obfs_password=$(jq -r '.obfs.salamander.password // .obfs.password // "Error"' "$CONFIG_FILE" 2>/dev/null)
        local auth_password=$(jq -r '.auth.password // "Error"' "$CONFIG_FILE" 2>/dev/null)
    else
        # Método alternativo sin jq
        local port=$(grep -o '"listen":"[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4 | grep -oP '\d+' || echo "Error")
        local upload_mbps="100"
        local download_mbps="100"
        local obfs_password=$(grep -o '"password":"[^"]*"' "$CONFIG_FILE" | head -1 | cut -d'"' -f4 || echo "Error")
        local auth_password=$(grep -o '"password":"[^"]*"' "$CONFIG_FILE" | tail -1 | cut -d'"' -f4 || echo "Error")
    fi
    
    # Obtener IPs
    echo -e "${YELLOW}Obteniendo IPs...${NC}"
    local public_ip
    local private_ip
    
    # Intentar múltiples métodos para obtener IP pública
    public_ip=$(curl -s https://api.ipify.org 2>/dev/null || 
                wget -qO- https://api.ipify.org 2>/dev/null || 
                curl -s https://ipinfo.io/ip 2>/dev/null || 
                curl -s https://icanhazip.com 2>/dev/null || 
                echo "No disponible")
    
    # Obtener IP privada
    private_ip=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n 1 || 
                 hostname -I | awk '{print $1}' || 
                 echo "No disponible")
    
    # Mostrar la configuración
    echo -e "\n${YELLOW}Configuración de Hysteria:${NC}"
    echo -e "${BLUE}IP pública:${NC} $public_ip"
    echo -e "${BLUE}IP privada:${NC} $private_ip"
    echo -e "${BLUE}Puerto:${NC} $port"
    echo -e "${BLUE}Contraseña de ofuscación:${NC} $obfs_password"
    echo -e "${BLUE}Contraseña de autenticación:${NC} $auth_password"
    echo -e "${BLUE}Velocidad de subida:${NC} $upload_mbps Mbps"
    echo -e "${BLUE}Velocidad de bajada:${NC} $download_mbps Mbps"
    
    # Generar y mostrar cadenas de importación solo si tenemos todos los valores necesarios
    if [ "$port" != "Error" ] && [ "$public_ip" != "No disponible" ] && 
       [ "$auth_password" != "Error" ] && [ "$obfs_password" != "Error" ]; then
        
        local nekobox_import="hy2://${auth_password}@${public_ip}:${port}/?insecure=1&obfs=salamander&obfs-password=${obfs_password}#Hysteria_Server"
        local clash_import="- name: Hysteria_Server\n  type: hysteria\n  server: ${public_ip}\n  port: ${port}\n  auth-str: ${auth_password}\n  obfs: salamander\n  obfs-password: ${obfs_password}\n  up: ${upload_mbps}\n  down: ${download_mbps}"
        
        echo -e "\n${BLUE}Cadenas de importación:${NC}"
        echo -e "${YELLOW}NekoBox:${NC}\n$nekobox_import"
        echo -e "\n${YELLOW}Clash:${NC}\n$clash_import"
    else
        echo -e "\n${RED}No se pudieron generar las cadenas de importación debido a valores faltantes.${NC}"
    fi
    
    # Mostrar estado del servicio
    echo -e "\n${BLUE}Estado del servicio:${NC}"
    if systemctl status hysteria >/dev/null 2>&1; then
        systemctl status hysteria --no-pager | grep -E "Active:|Status:"
    else
        echo -e "${RED}Servicio no encontrado${NC}"
    fi
    
    # Mostrar estadísticas de conexión
    echo -e "\n${BLUE}Estadísticas de conexión:${NC}"
    if command -v netstat >/dev/null 2>&1; then
        local connections=$(netstat -an | grep ":$port" | grep ESTABLISHED | wc -l)
        echo "Conexiones activas: $connections"
    elif command -v ss >/dev/null 2>&1; then
        local connections=$(ss -an | grep ":$port" | grep ESTAB | wc -l)
        echo "Conexiones activas: $connections"
    else
        echo -e "${RED}No se pueden obtener estadísticas de conexión (netstat/ss no disponible)${NC}"
    fi
}

change_passwords() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}Hysteria no está instalado o configurado.${NC}"
        return
    fi

    backup_config

    read -p "Nueva contraseña de ofuscación (dejar en blanco para generar aleatoriamente): " NEW_OBFS_PASSWORD
    NEW_OBFS_PASSWORD=${NEW_OBFS_PASSWORD:-$(generate_password)}
    read -p "Nueva contraseña de autenticación (dejar en blanco para generar aleatoriamente): " NEW_AUTH_PASSWORD
    NEW_AUTH_PASSWORD=${NEW_AUTH_PASSWORD:-$(generate_password)}

    # Usar jq para actualizar el archivo de configuración con la estructura correcta
    local temp_config
    temp_config=$(mktemp)
    jq --arg obfs "$NEW_OBFS_PASSWORD" --arg auth "$NEW_AUTH_PASSWORD" \
        '.obfs.salamander.password = $obfs | .auth.password = $auth' "$CONFIG_FILE" > "$temp_config"
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
