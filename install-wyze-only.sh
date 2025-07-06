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

msg "📥 Descargando instalador integrado de Wyze Bridge..."
cd /root
if ! wget -O wyze-bridge.py https://raw.githubusercontent.com/MondoBoricua/proxmox-wyze-bridge/main/wyze-bridge.py; then
    error "No se pudo descargar el instalador de Wyze Bridge"
fi

chmod +x wyze-bridge.py

msg "🚀 Instalando Wyze Bridge usando el instalador integrado..."
msg "💡 Esto puede tomar varios minutos..."
msg "🔧 Basado en el instalador de GiZZoR pero integrado en nuestro proyecto"

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

# Colores para el comando wyze
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Función para mostrar el banner principal
show_banner() {
    clear
    echo -e "${MAGENTA}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                🚀 WYZE BRIDGE CONTROL CENTER                    ║"
    echo "║                    Gestión Completa Boricua                     ║"
    echo "║                      PR Made in PR 🇵🇷                          ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo
    
    # Información del sistema
    local IP=$(hostname -I | awk '{print $1}')
    local HOSTNAME=$(hostname)
    local UPTIME=$(uptime -p | sed 's/up //')
    
    echo -e "${CYAN}💻 Sistema:${NC} $HOSTNAME ($IP)"
    echo -e "${CYAN}⏱️ Uptime:${NC} $UPTIME"
    
    # Estado de servicios
    if systemctl is-active --quiet wyze-bridge; then
        echo -e "${CYAN}🚀 Wyze Bridge:${NC} ${GREEN}●ACTIVO${NC}"
    else
        echo -e "${CYAN}🚀 Wyze Bridge:${NC} ${RED}●INACTIVO${NC}"
    fi
    
    echo
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                        MENÚ PRINCIPAL                           ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${YELLOW}1.${NC} ${GREEN}🚀${NC} Iniciar Servicios"
    echo -e "${YELLOW}2.${NC} ${RED}⏹️${NC} Parar Servicios"
    echo -e "${YELLOW}3.${NC} ${BLUE}🔄${NC} Reiniciar Servicios"
    echo -e "${YELLOW}4.${NC} ${CYAN}📊${NC} Ver Estado"
    echo -e "${YELLOW}5.${NC} ${MAGENTA}📋${NC} Ver Logs en Tiempo Real"
    echo -e "${YELLOW}6.${NC} ${GREEN}⚙️${NC} Configurar Credenciales"
    echo -e "${YELLOW}7.${NC} ${BLUE}🔄${NC} Actualizar Sistema"
    echo -e "${YELLOW}8.${NC} ${CYAN}ℹ️${NC} Información de Acceso"
    echo -e "${YELLOW}9.${NC} ${YELLOW}📦${NC} Instalar FFmpeg"
    echo -e "${YELLOW}0.${NC} ${RED}🚪${NC} Salir"
    echo
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                      ACCESO RÁPIDO                              ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo -e "${GREEN}🌐 Acceso Web:${NC} http://$IP:5000"
    echo -e "${GREEN}📺 RTSP:${NC} rtsp://$IP:8554/[camera_name]"
    echo
}

# Función para mostrar información simple
show_simple_info() {
    local IP=$(hostname -I | awk '{print $1}')
    echo -e "${CYAN}🚀 Wyze Bridge - Comandos disponibles:${NC}"
    echo -e "  ${GREEN}wyze start${NC}         - Iniciar servicios"
    echo -e "  ${RED}wyze stop${NC}          - Parar servicios"
    echo -e "  ${BLUE}wyze restart${NC}       - Reiniciar servicios"
    echo -e "  ${CYAN}wyze status${NC}        - Ver estado"
    echo -e "  ${MAGENTA}wyze logs${NC}          - Ver logs en tiempo real"
    echo -e "  ${GREEN}wyze config${NC}        - Configurar credenciales"
    echo -e "  ${BLUE}wyze update${NC}        - Actualizar"
    echo -e "  ${CYAN}wyze info${NC}          - Mostrar información de acceso"
    echo -e "  ${YELLOW}wyze install-ffmpeg${NC} - Instalar FFmpeg manualmente"
    echo -e "  ${MAGENTA}wyze menu${NC}          - Mostrar menú interactivo"
    echo
    echo -e "${GREEN}🌐 Acceso Web:${NC} http://$IP:5000"
    echo -e "${GREEN}📺 RTSP:${NC} rtsp://$IP:8554/[camera_name]"
}

# Función para el menú interactivo
interactive_menu() {
    while true; do
        show_banner
        echo -e "${YELLOW}Selecciona una opción [0-9]:${NC} \c"
        read -r choice
        
        case $choice in
            1)
                echo -e "${GREEN}🚀 Iniciando servicios...${NC}"
                systemctl start wyze-bridge mediamtx
                echo -e "${GREEN}✅ Servicios iniciados${NC}"
                read -p "Presiona Enter para continuar..."
                ;;
            2)
                echo -e "${RED}⏹️ Parando servicios...${NC}"
                systemctl stop wyze-bridge mediamtx
                echo -e "${RED}⏹️ Servicios detenidos${NC}"
                read -p "Presiona Enter para continuar..."
                ;;
            3)
                echo -e "${BLUE}🔄 Reiniciando servicios...${NC}"
                systemctl restart wyze-bridge mediamtx
                echo -e "${BLUE}🔄 Servicios reiniciados${NC}"
                read -p "Presiona Enter para continuar..."
                ;;
            4)
                echo -e "${CYAN}📊 Estado de servicios:${NC}"
                systemctl status wyze-bridge mediamtx
                read -p "Presiona Enter para continuar..."
                ;;
            5)
                echo -e "${MAGENTA}📋 Mostrando logs en tiempo real (Ctrl+C para salir)...${NC}"
                journalctl -u wyze-bridge -f
                ;;
            6)
                echo -e "${GREEN}⚙️ Abriendo configuración...${NC}"
                nano /etc/wyze-bridge/app.env
                echo -e "${YELLOW}💡 Reinicia los servicios después de cambiar la configuración: wyze restart${NC}"
                read -p "Presiona Enter para continuar..."
                ;;
            7)
                echo -e "${BLUE}🔄 Actualizando sistema...${NC}"
                cd /root
                python3 wyze-bridge.py update
                read -p "Presiona Enter para continuar..."
                ;;
            8)
                local IP=$(hostname -I | awk '{print $1}')
                echo -e "${CYAN}ℹ️ Información de acceso:${NC}"
                echo -e "${GREEN}🌐 Acceso Web:${NC} http://$IP:5000"
                echo -e "${GREEN}📺 RTSP:${NC} rtsp://$IP:8554/[camera_name]"
                echo -e "${GREEN}🔧 Configuración:${NC} /etc/wyze-bridge/app.env"
                read -p "Presiona Enter para continuar..."
                ;;
            9)
                echo -e "${YELLOW}📦 Instalando FFmpeg...${NC}"
                apt update && apt install -y ffmpeg
                echo -e "${GREEN}✅ FFmpeg instalado desde repositorios del sistema${NC}"
                read -p "Presiona Enter para continuar..."
                ;;
            0)
                echo -e "${RED}🚪 Saliendo del menú...${NC}"
                echo -e "${CYAN}💡 Usa 'wyze menu' para volver al panel de control${NC}"
                break
                ;;
            *)
                echo -e "${RED}❌ Opción inválida. Intenta de nuevo.${NC}"
                read -p "Presiona Enter para continuar..."
                ;;
        esac
    done
}

# Lógica principal del comando
case "$1" in
    start)
        systemctl start wyze-bridge mediamtx
        echo -e "${GREEN}✅ Servicios iniciados${NC}"
        ;;
    stop)
        systemctl stop wyze-bridge mediamtx
        echo -e "${RED}⏹️ Servicios detenidos${NC}"
        ;;
    restart)
        systemctl restart wyze-bridge mediamtx
        echo -e "${BLUE}🔄 Servicios reiniciados${NC}"
        ;;
    status)
        systemctl status wyze-bridge mediamtx
        ;;
    logs)
        journalctl -u wyze-bridge -f
        ;;
    config)
        nano /etc/wyze-bridge/app.env
        echo -e "${YELLOW}💡 Reinicia los servicios después de cambiar la configuración: wyze restart${NC}"
        ;;
    update)
        cd /root
        python3 wyze-bridge.py update
        ;;
    info)
        local IP=$(hostname -I | awk '{print $1}')
        echo -e "${GREEN}🌐 Acceso Web:${NC} http://$IP:5000"
        echo -e "${GREEN}📺 RTSP:${NC} rtsp://$IP:8554/[camera_name]"
        echo -e "${GREEN}🔧 Configuración:${NC} /etc/wyze-bridge/app.env"
        ;;
    install-ffmpeg)
        echo -e "${YELLOW}📦 Instalando FFmpeg...${NC}"
        apt update && apt install -y ffmpeg
        echo -e "${GREEN}✅ FFmpeg instalado desde repositorios del sistema${NC}"
        ;;
    menu)
        interactive_menu
        ;;
    *)
        show_simple_info
        ;;
esac
EOF

chmod +x /usr/local/bin/wyze

# Configurar PATH para incluir /usr/local/bin
msg "🔧 Configurando PATH..."
# Asegurar que /usr/local/bin esté en PATH sin duplicar
if ! grep -q "/usr/local/bin" /root/.bashrc; then
    echo 'export PATH="/usr/local/bin:$PATH"' >> /root/.bashrc
    msg "✅ PATH configurado en .bashrc"
else
    msg "✅ PATH ya está configurado"
fi

# También configurar PATH para la sesión actual
export PATH="/usr/local/bin:$PATH"

# Configurar MOTD y .bashrc
msg "📄 Configurando mensaje de bienvenida..."
cat > /etc/motd << 'EOF'
╔══════════════════════════════════════════════════════════════════╗
║                🚀 WYZE BRIDGE LXC CONTAINER                     ║
║                      Listo para usar! 🇵🇷                        ║
║                                                                  ║
║  El menú se abrirá automáticamente...                          ║
║  Si no aparece, usa: wyze menu                                  ║
║                                                                  ║
║  Web: http://[IP]:5000                                          ║
║  RTSP: rtsp://[IP]:8554/[camera_name]                           ║
╚══════════════════════════════════════════════════════════════════╝

EOF

# Crear script de inicio automático más confiable
msg "🔧 Configurando inicio automático del menú..."
cat > /etc/profile.d/wyze-auto-menu.sh << 'PROFILE_EOF'
#!/bin/bash
# Auto-ejecutar menú de Wyze Bridge para usuarios interactivos
if [[ $- == *i* ]] && [[ -n "$PS1" ]] && [[ "$USER" == "root" ]]; then
    # Verificar si es un login directo (no un comando específico)
    if [[ -z "$SSH_ORIGINAL_COMMAND" ]] && [[ "$0" == "-bash" || "$0" == "bash" ]]; then
        # Evitar bucles infinitos con un flag temporal
        if [[ ! -f /tmp/.wyze_menu_active ]]; then
            touch /tmp/.wyze_menu_active
            # Limpiar el flag cuando termine
            trap 'rm -f /tmp/.wyze_menu_active' EXIT
            # Ejecutar el menú después de un breve delay
            sleep 0.5
            wyze menu
        fi
    fi
fi
PROFILE_EOF

chmod +x /etc/profile.d/wyze-auto-menu.sh

# Agregar información útil al .bashrc
cat >> /root/.bashrc << 'BASHRC_EOF'

# Función para mostrar información rápida si no se ejecuta el menú
wyze_info() {
    if [[ $- == *i* ]]; then
        echo "🚀 Wyze Bridge Container - Usa 'wyze menu' para el panel completo"
        echo "🌐 Web: http://$(hostname -I | awk '{print $1}'):5000"
    fi
}

# Backup: Si el menú automático no funciona, mostrar info básica
if [[ $- == *i* ]] && [[ -n "$PS1" ]]; then
    # Solo mostrar info si no hay menú activo
    if [[ ! -f /tmp/.wyze_menu_active ]]; then
        # Delay para ver si el menú se ejecuta
        (sleep 2 && [[ ! -f /tmp/.wyze_menu_active ]] && wyze_info) &
    fi
fi
BASHRC_EOF

# Recargar PATH para que funcione inmediatamente
msg "🔄 Recargando configuración de PATH..."
source /root/.bashrc

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
echo -e "${YELLOW}💡 Si 'wyze' no funciona, ejecuta: source /root/.bashrc${NC}" 