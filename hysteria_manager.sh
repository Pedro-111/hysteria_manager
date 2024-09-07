#!/bin/bash

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Función para generar una contraseña aleatoria
generate_password() {
    openssl rand -base64 12
}

# Función para instalar y configurar Hysteria
install_hysteria() {
    echo -e "${YELLOW}Verificando instalación de Hysteria...${NC}"
    
    if [ -f "/usr/local/bin/hysteria" ]; then
        echo -e "${GREEN}Hysteria ya está instalado.${NC}"
    else
        echo -e "${YELLOW}Instalando Hysteria...${NC}"
        
        # Actualizar el sistema e instalar dependencias
        apt update && apt upgrade -y
        apt install -y curl wget unzip openssl

        # Descargar e instalar Hysteria
        wget https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-amd64
        chmod +x hysteria-linux-amd64
        mv hysteria-linux-amd64 /usr/local/bin/hysteria
    fi

    if [ ! -d "/etc/hysteria" ]; then
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

        # Crear archivo de configuración
        create_config
    else
        echo -e "${GREEN}Configuración de Hysteria ya existe.${NC}"
    fi

    # Crear servicio systemd si no existe
    if [ ! -f "/etc/systemd/system/hysteria.service" ]; then
        create_systemd_service
    fi

    # Habilitar e iniciar el servicio
    systemctl enable hysteria
    systemctl start hysteria

    echo -e "${GREEN}Hysteria instalado y configurado exitosamente.${NC}"
    show_config
}

# Función para crear el archivo de configuración
create_config() {
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
}

# Función para crear el servicio systemd
create_systemd_service() {
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
}

# Función para mostrar la configuración
show_config() {
    if [ ! -f "/etc/hysteria/config.json" ]; then
        echo -e "${RED}Hysteria no está instalado o configurado.${NC}"
        return
    fi

    PUBLIC_IP=$(curl -s https://api.ipify.org)
    PRIVATE_IP=$(hostname -I | awk '{print $1}')
    PORT=$(grep -oP '"listen": ":\K[0-9]+' /etc/hysteria/config.json)
    OBFS_PASSWORD=$(grep -oP '"password": "\K[^"]+' /etc/hysteria/config.json | head -1)
    AUTH_PASSWORD=$(grep -oP '"password": "\K[^"]+' /etc/hysteria/config.json | tail -1)

    echo -e "${YELLOW}Configuración de Hysteria:${NC}"
    echo "IP pública: $PUBLIC_IP"
    echo "IP privada: $PRIVATE_IP"
    echo "Puerto: $PORT"
    echo "Contraseña de ofuscación: $OBFS_PASSWORD"
    echo "Contraseña de autenticación: $AUTH_PASSWORD"
}

# Función para cambiar contraseñas
change_passwords() {
    if [ ! -f "/etc/hysteria/config.json" ]; then
        echo -e "${RED}Hysteria no está instalado o configurado.${NC}"
        return
    fi

    read -p "Nueva contraseña de ofuscación (dejar en blanco para generar aleatoriamente): " NEW_OBFS_PASSWORD
    NEW_OBFS_PASSWORD=${NEW_OBFS_PASSWORD:-$(generate_password)}

    read -p "Nueva contraseña de autenticación (dejar en blanco para generar aleatoriamente): " NEW_AUTH_PASSWORD
    NEW_AUTH_PASSWORD=${NEW_AUTH_PASSWORD:-$(generate_password)}

    # Actualizar el archivo de configuración usando un delimitador diferente
    sed -i "s|\"password\": \"$OBFS_PASSWORD\"|\"password\": \"$NEW_OBFS_PASSWORD\"|" /etc/hysteria/config.json
    sed -i "s|\"password\": \"$AUTH_PASSWORD\"|\"password\": \"$NEW_AUTH_PASSWORD\"|" /etc/hysteria/config.json

    systemctl restart hysteria

    echo -e "${GREEN}Contraseñas actualizadas exitosamente.${NC}"
    show_config
}


# Función para desinstalar Hysteria
uninstall_hysteria() {
    echo -e "${YELLOW}Desinstalando Hysteria...${NC}"
    
    # Detener y deshabilitar el servicio
    systemctl stop hysteria
    systemctl disable hysteria

    # Eliminar archivos
    rm -f /usr/local/bin/hysteria
    rm -rf /etc/hysteria
    rm -f /etc/systemd/system/hysteria.service

    # Recargar systemd
    systemctl daemon-reload

    echo -e "${GREEN}Hysteria ha sido desinstalado.${NC}"
}

# Menú principal
while true; do
    echo -e "\n${YELLOW}Menú de Hysteria${NC}"
    echo "1. Instalar y configurar Hysteria"
    echo "2. Ver configuración de Hysteria"
    echo "3. Cambiar contraseñas"
    echo "4. Desinstalar Hysteria"
    echo "5. Salir"
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
            echo "Saliendo..."
            exit 0
            ;;
        *)
            echo -e "${RED}Opción inválida. Por favor, intente de nuevo.${NC}"
            ;;
    esac
done
