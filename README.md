# Hysteria Manager

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
Un script de gestión completo para servidores Hysteria, diseñado para facilitar la instalación, configuración y monitoreo del servicio.

## 🚀 Características

- Instalación automatizada de Hysteria
- Gestión de configuración simplificada
- Monitor de usuarios en tiempo real
- Sistema de respaldo automático
- Monitoreo de recursos del sistema
- Gestión de contraseñas
- Compatibilidad con múltiples sistemas basados en Debian
- Registro detallado de operaciones
- Interfaz de usuario amigable con códigos de color

## 📋 Requisitos

- Sistema operativo basado en Debian, Ubuntu
- Privilegios de root
- Conexión a Internet

## 🔧 Instalación

### Método 1: Instalación Directa

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Pedro-111/hysteria_manager/develop/install.sh)
```

### Método 2: Instalación Manual

```bash
# Clonar el repositorio
git clone https://github.com/Pedro-111/hysteria_manager.git

# Entrar al directorio
cd hysteria_manager

# Dar permisos de ejecución
chmod +x hysteria_manager.sh

# Ejecutar el script
./hysteria_manager.sh
```

## 📖 Uso

Al ejecutar el script, se mostrará un menú interactivo con las siguientes opciones:

1. **Instalar y configurar Hysteria**
   - Instalación automatizada del servidor
   - Configuración inicial con valores optimizados
   - Generación de certificados SSL

2. **Ver configuración de Hysteria**
   - Muestra la configuración actual
   - Genera cadenas de importación para clientes
   - Visualiza estadísticas del servidor

3. **Cambiar contraseñas**
   - Modificación de contraseñas de autenticación
   - Modificación de contraseñas de ofuscación
   - Generación automática de contraseñas seguras

4. **Desinstalar Hysteria**
   - Eliminación completa del servidor
   - Opción de respaldo de configuración

5. **Mostrar logs**
   - Visualización de registros del sistema
   - Seguimiento de eventos en tiempo real

6. **Monitorear recursos**
   - Monitoreo de CPU
   - Monitoreo de memoria
   - Monitoreo de disco
   - Estadísticas de red

7. **Respaldar configuración**
   - Creación de copias de seguridad
   - Gestión de respaldos anteriores

8. **Monitor de usuarios en tiempo real**
   - Visualización de conexiones activas
   - Estadísticas de uso en tiempo real
   - Información detallada de clientes

## 🔐 Seguridad

- Generación automática de contraseñas seguras
- Certificados SSL autofirmados
- Respaldos automáticos de configuración
- Validación de entrada de usuario
- Registro de operaciones críticas

## 📝 Logs

El script mantiene un registro detallado de todas las operaciones en:
```
/var/log/hysteria_manager.log
```

## 🛠️ Configuración

Los archivos de configuración se almacenan en:
```
/etc/hysteria/
```

Los respaldos se guardan en:
```
/etc/hysteria/backups/
```

## 🤝 Contribución

Las contribuciones son bienvenidas. Por favor, sigue estos pasos:

1. Haz fork del repositorio
2. Crea una rama para tu característica (`git checkout -b feature/AmazingFeature`)
3. Commit tus cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abre un Pull Request

## 📄 Licencia

Este proyecto está bajo la Licencia MIT - ver el archivo [LICENSE](LICENSE) para más detalles.

## ⚡ Rendimiento

El script está optimizado para:
- Mínimo impacto en recursos del sistema
- Respuesta rápida en operaciones críticas
- Eficiente gestión de memoria
- Monitoreo en tiempo real sin sobrecarga

## 🔧 Solución de Problemas

Si encuentras algún problema:
1. Verifica los logs del sistema
2. Asegúrate de tener los permisos necesarios
3. Comprueba la conectividad a Internet
4. Verifica que los puertos necesarios estén abiertos

## 📮 Contacto

Si tienes preguntas o sugerencias, no dudes en:
- Abrir un issue en el repositorio
- Enviar un pull request con mejoras
