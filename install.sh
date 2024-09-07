#!/bin/bash

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# URL del script
SCRIPT_URL="https://raw.githubusercontent.com/Pedro-111/hysteria_manager/develop/hysteria_manager.sh"

# Directorio de instalación
INSTALL_DIR="/usr/local/bin"

# Nombre del script
SCRIPT_NAME="hysteria_manager"

echo -e "${YELLOW}Instalando Hysteria Manager...${NC}"

# Verificar si se está ejecutando como root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Este script debe ejecutarse como root${NC}"
    exit 1
fi

# Descargar el script
if curl -sL "$SCRIPT_URL" -o "$INSTALL_DIR/$SCRIPT_NAME"; then
    echo -e "${GREEN}Script descargado exitosamente${NC}"
else
    echo -e "${RED}Error al descargar el script${NC}"
    exit 1
fi

# Hacer el script ejecutable
chmod +x "$INSTALL_DIR/$SCRIPT_NAME"

# Crear un enlace simbólico para fácil acceso
ln -sf "$INSTALL_DIR/$SCRIPT_NAME" /usr/bin/$SCRIPT_NAME

echo -e "${GREEN}Instalación completada${NC}"
echo -e "Puedes ejecutar Hysteria Manager con el comando: ${YELLOW}$SCRIPT_NAME${NC}"

# Preguntar si desea ejecutar el script ahora
read -p "¿Deseas ejecutar Hysteria Manager ahora? (s/n): " run_now
if [[ $run_now == "s" || $run_now == "S" ]]; then
    $SCRIPT_NAME
else
    echo -e "Puedes ejecutar Hysteria Manager más tarde con el comando: ${YELLOW}$SCRIPT_NAME${NC}"
fi
