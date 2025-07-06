#!/bin/bash

# Script simple para instalar SOLO Wyze Bridge usando el instalador de GiZZoR
# Para usar DENTRO del contenedor LXC después de crearlo
# Autor: MondoBoricua 🇵🇷

set -euo pipefail

# Colores para mensajes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Función para mostrar mensajes
msg() {
    echo -e "${CYAN}[$(date '+%H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

# Banner simple
clear
echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║              🚀 WYZE BRIDGE INSTALLER ONLY 🇵🇷                  ║"
echo "║                                                                  ║"
echo "║  Solo instala Wyze Bridge usando el instalador de GiZZoR        ║"
echo "║  Ejecutar DENTRO del contenedor LXC                             ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Verificar que estamos en un contenedor
if [[ ! -f "/.dockerenv" ]] && [[ ! -f "/run/.containerenv" ]] && [[ ! -d "/proc/vz" ]]; then
    msg "⚠️  Este script está diseñado para ejecutarse dentro de un contenedor LXC"
    read -p "¿Continuar de todas formas? (y/N): " -r
    if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
        error "Instalación cancelada"
    fi
fi

# Configurar entorno no interactivo
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

msg "🔄 Actualizando sistema..."
apt update

msg "📦 Instalando dependencias esenciales..."
apt install -y curl wget ffmpeg python3 python3-pip python3-venv python3-dev build-essential

msg "🛡️ Configurando firewall..."
ufw --force enable
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 5000/tcp comment "Wyze Bridge Web"
ufw allow 8554/tcp comment "RTSP"
ufw allow 8888/tcp comment "WebRTC"
ufw allow 8889/tcp comment "HLS"

msg "📁 Creando directorios..."
mkdir -p /etc/wyze-bridge
mkdir -p /var/log/wyze-bridge

msg "📥 Descargando instalador de GiZZoR..."
cd /root
if ! wget -O wyze-bridge.py https://github.com/GiZZoR/wyze-bridge-installer/raw/refs/heads/main/wyze-bridge.py; then
    error "No se pudo descargar el instalador de GiZZoR"
fi

chmod +x wyze-bridge.py

msg "🚀 Instalando Wyze Bridge usando el instalador de GiZZoR..."
msg "💡 Esto puede tomar varios minutos..."

# Ejecutar instalación con manejo de errores mejorado
msg "⚠️  Si FFmpeg falla, continuaremos sin él (se puede instalar después)"
if python3 wyze-bridge.py install --APP_IP 0.0.0.0 --APP_PORT 5000 --APP_USER wyze --APP_GUNICORN 1; then
    success "Wyze Bridge instalado exitosamente"
else
    msg "⚠️  La instalación tuvo algunos problemas, verificando servicios..."
    
    # Verificar si los servicios principales se instalaron
    if systemctl list-unit-files | grep -q wyze-bridge; then
        success "Wyze Bridge se instaló correctamente (ignorando errores de FFmpeg)"
        msg "💡 FFmpeg se puede instalar manualmente después si es necesario"
    else
        error "Falló la instalación de Wyze Bridge - servicios no encontrados"
    fi
fi

# Crear comando simple de gestión
msg "🛠️ Creando comando de gestión..."
cat > /usr/local/bin/wyze << 'EOF'
#!/bin/bash
case "$1" in
    start)
        systemctl start wyze-bridge mediamtx
        echo "✅ Servicios iniciados"
        ;;
    stop)
        systemctl stop wyze-bridge mediamtx
        echo "⏹️ Servicios detenidos"
        ;;
    restart)
        systemctl restart wyze-bridge mediamtx
        echo "🔄 Servicios reiniciados"
        ;;
    status)
        systemctl status wyze-bridge mediamtx
        ;;
    logs)
        journalctl -u wyze-bridge -f
        ;;
    config)
        nano /etc/wyze-bridge/app.env
        echo "💡 Reinicia los servicios después de cambiar la configuración: wyze restart"
        ;;
    update)
        cd /root
        python3 wyze-bridge.py update
        ;;
    info)
        echo "🌐 Acceso Web: http://$(hostname -I | awk '{print $1}'):5000"
        echo "📺 RTSP: rtsp://$(hostname -I | awk '{print $1}'):8554/[camera_name]"
        echo "🔧 Configuración: /etc/wyze-bridge/app.env"
        ;;
    install-ffmpeg)
        echo "📦 Instalando FFmpeg..."
        apt update && apt install -y ffmpeg
        echo "✅ FFmpeg instalado desde repositorios del sistema"
        ;;
    *)
        echo "🚀 Wyze Bridge - Comandos disponibles:"
        echo "  wyze start         - Iniciar servicios"
        echo "  wyze stop          - Parar servicios"
        echo "  wyze restart       - Reiniciar servicios"
        echo "  wyze status        - Ver estado"
        echo "  wyze logs          - Ver logs en tiempo real"
        echo "  wyze config        - Configurar credenciales"
        echo "  wyze update        - Actualizar"
        echo "  wyze info          - Mostrar información de acceso"
        echo "  wyze install-ffmpeg - Instalar FFmpeg manualmente"
        echo
        echo "🌐 Acceso Web: http://$(hostname -I | awk '{print $1}'):5000"
        echo "📺 RTSP: rtsp://$(hostname -I | awk '{print $1}'):8554/[camera_name]"
        ;;
esac
EOF

chmod +x /usr/local/bin/wyze

# Configurar PATH para incluir /usr/local/bin
msg "🔧 Configurando PATH..."
echo 'export PATH="/usr/local/bin:$PATH"' >> /root/.bashrc

# Configurar MOTD y .bashrc
msg "📄 Configurando mensaje de bienvenida..."
cat > /etc/motd << 'EOF'
╔══════════════════════════════════════════════════════════════════╗
║                🚀 WYZE BRIDGE LXC CONTAINER                     ║
║                      Listo para usar! 🇵🇷                        ║
║                                                                  ║
║  Comandos: wyze start|stop|restart|status|logs|config|update     ║
║  Info: wyze info                                                 ║
║                                                                  ║
║  Web: http://[IP]:5000                                          ║
║  RTSP: rtsp://[IP]:8554/[camera_name]                           ║
╚══════════════════════════════════════════════════════════════════╝

EOF

# Agregar información útil al .bashrc
cat >> /root/.bashrc << 'BASHRC_EOF'

# Mostrar información de Wyze Bridge al hacer login
if [[ $- == *i* ]]; then
    echo "🚀 Wyze Bridge Container - Comandos disponibles:"
    echo "  wyze start|stop|restart|status|logs|config|update|info"
    echo "🌐 Acceso Web: http://$(hostname -I | awk '{print $1}'):5000"
    echo
fi
BASHRC_EOF

# Información final
success "🎉 Instalación completada!"
echo
echo -e "${CYAN}📋 Próximos pasos:${NC}"
echo "1. Configura credenciales: wyze config"
echo "2. Inicia servicios: wyze start"
echo "3. Ver información: wyze info"
echo
echo -e "${GREEN}🌐 Acceso Web: http://$(hostname -I | awk '{print $1}'):5000${NC}"
echo -e "${GREEN}📺 RTSP: rtsp://$(hostname -I | awk '{print $1}'):8554/[camera_name]${NC}"
echo
echo -e "${YELLOW}💡 Usa 'wyze' para gestionar el servicio${NC}" 