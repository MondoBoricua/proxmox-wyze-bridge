#!/bin/bash

# Script de instalación rápida de Wyze Bridge para Proxmox LXC
# Versión simplificada que usa el instalador nativo de GiZZoR
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

# Verificar que estamos en Proxmox
if ! command -v pct &> /dev/null; then
    error "Este script debe ejecutarse en un servidor Proxmox VE"
fi

if [[ $EUID -ne 0 ]]; then
    error "Este script debe ejecutarse como root"
fi

# Banner
clear
echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║           🚀 WYZE BRIDGE QUICK INSTALLER 🇵🇷                    ║"
echo "║                                                                  ║"
echo "║  Instalación rápida con configuración automática                ║"
echo "║  Usa el instalador nativo de GiZZoR (sin Docker)                ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Verificar conectividad
msg "Verificando conectividad..."
if ! timeout 10 ping -c 1 8.8.8.8 &> /dev/null; then
    error "No hay conectividad a internet"
fi

# Obtener siguiente VMID disponible
get_next_vmid() {
    local max_vmid=100
    for vmid in $(pct list | awk 'NR>1 {print $1}' | sort -n); do
        if [[ $vmid -gt $max_vmid ]]; then
            max_vmid=$vmid
        fi
    done
    
    local next_vmid=$((max_vmid + 1))
    while pct status $next_vmid &>/dev/null; do
        ((next_vmid++))
    done
    
    echo $next_vmid
}

# Configuración automática
VMID=$(get_next_vmid)
HOSTNAME="wyze-bridge-${VMID}"

msg "Configuración automática:"
echo "  VMID: $VMID"
echo "  Hostname: $HOSTNAME"
echo "  RAM: 2GB"
echo "  CPU: 2 cores"
echo "  Disco: 12GB"
echo

read -p "¿Continuar con la instalación? (y/N): " -r
if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
    error "Instalación cancelada"
fi

# Descargar template si no existe
msg "Verificando template de Ubuntu 22.04..."
if [[ ! -f "/var/lib/vz/template/cache/ubuntu-22.04-standard_22.04-1_amd64.tar.zst" ]]; then
    msg "Descargando template..."
    pveam download local ubuntu-22.04-standard_22.04-1_amd64.tar.zst
fi

# Crear contenedor
msg "Creando contenedor LXC..."
pct create $VMID \
    local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst \
    --hostname $HOSTNAME \
    --memory 2048 \
    --swap 512 \
    --cores 2 \
    --rootfs local-lvm:12 \
    --net0 name=eth0,bridge=vmbr0,ip=dhcp,firewall=1 \
    --onboot 1 \
    --start 1 \
    --features nesting=1 \
    --unprivileged 1 \
    --ostype ubuntu \
    --arch amd64 \
    --description "Wyze Bridge - Instalación Nativa Quick"

# Iniciar contenedor
msg "Iniciando contenedor..."
pct start $VMID

# Esperar que esté listo
msg "Esperando que el contenedor esté listo..."
sleep 10
for i in {1..30}; do
    if pct exec $VMID -- echo "ready" &>/dev/null; then
        break
    fi
    sleep 2
done

# Instalar Wyze Bridge
msg "Instalando Wyze Bridge (esto puede tomar 10-15 minutos)..."

# Crear script de instalación
cat > /tmp/quick-wyze-install.sh << 'EOF'
#!/bin/bash

# Configurar entorno no interactivo
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

# Actualizar sistema
apt update

# Instalar dependencias esenciales
apt install -y curl wget python3 python3-pip python3-venv python3-dev build-essential

# Configurar firewall
ufw --force enable
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 5000/tcp
ufw allow 8554/tcp
ufw allow 8888/tcp
ufw allow 8889/tcp

# Crear directorios
mkdir -p /opt/wyze-bridge
cd /opt/wyze-bridge

# Descargar instalador de GiZZoR
wget -O wyze-bridge-installer.py https://github.com/GiZZoR/wyze-bridge-installer/raw/refs/heads/main/wyze-bridge.py
chmod +x wyze-bridge-installer.py

# Instalar Wyze Bridge
python3 wyze-bridge-installer.py install --APP_IP 0.0.0.0 --APP_PORT 5000 --APP_GUNICORN 1

# Crear comando de gestión simple
cat > /usr/local/bin/wyze << 'WYZE_EOF'
#!/bin/bash
case "$1" in
    start)
        systemctl start wyze-bridge mediamtx
        echo "Servicios iniciados"
        ;;
    stop)
        systemctl stop wyze-bridge mediamtx
        echo "Servicios detenidos"
        ;;
    restart)
        systemctl restart wyze-bridge mediamtx
        echo "Servicios reiniciados"
        ;;
    status)
        systemctl status wyze-bridge mediamtx
        ;;
    logs)
        journalctl -u wyze-bridge -f
        ;;
    config)
        nano /etc/wyze-bridge/app.env
        ;;
    update)
        cd /opt/wyze-bridge
        python3 wyze-bridge-installer.py update
        ;;
    *)
        echo "Uso: wyze {start|stop|restart|status|logs|config|update}"
        echo
        echo "Comandos disponibles:"
        echo "  start   - Iniciar servicios"
        echo "  stop    - Parar servicios"
        echo "  restart - Reiniciar servicios"
        echo "  status  - Ver estado de servicios"
        echo "  logs    - Ver logs en tiempo real"
        echo "  config  - Editar configuración"
        echo "  update  - Actualizar Wyze Bridge"
        echo
        echo "Acceso web: http://$(hostname -I | awk '{print $1}'):5000"
        echo "RTSP: rtsp://$(hostname -I | awk '{print $1}'):8554/[camera_name]"
        ;;
esac
WYZE_EOF

chmod +x /usr/local/bin/wyze

# Configurar mensaje de bienvenida
cat > /etc/motd << 'MOTD_EOF'
╔══════════════════════════════════════════════════════════════════╗
║                🚀 WYZE BRIDGE LXC CONTAINER                     ║
║                     Quick Install 🇵🇷                            ║
║                                                                  ║
║  Comandos disponibles:                                           ║
║  • wyze start/stop/restart - Gestionar servicios                ║
║  • wyze status - Ver estado                                     ║
║  • wyze logs - Ver logs                                         ║
║  • wyze config - Configurar credenciales                       ║
║  • wyze update - Actualizar                                     ║
║                                                                  ║
║  Web: http://[IP]:5000                                          ║
║  RTSP: rtsp://[IP]:8554/[camera_name]                           ║
╚══════════════════════════════════════════════════════════════════╝

MOTD_EOF

echo "Instalación completada exitosamente!"
echo "Ejecuta 'wyze config' para configurar tus credenciales de Wyze"
EOF

# Copiar y ejecutar script
pct push $VMID /tmp/quick-wyze-install.sh /tmp/quick-wyze-install.sh
pct exec $VMID -- chmod +x /tmp/quick-wyze-install.sh

if timeout 1200 pct exec $VMID -- /tmp/quick-wyze-install.sh; then
    success "Instalación completada exitosamente!"
else
    error "La instalación tardó más de lo esperado"
fi

# Limpiar
pct exec $VMID -- rm -f /tmp/quick-wyze-install.sh
rm -f /tmp/quick-wyze-install.sh

# Obtener IP del contenedor
CONTAINER_IP=$(pct exec $VMID -- hostname -I | awk '{print $1}' 2>/dev/null || echo 'Obteniendo...')

# Mostrar información final
echo -e "${GREEN}"
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                    🎉 INSTALACIÓN COMPLETADA                    ║"
echo "║                                                                  ║"
echo "║  VMID: $VMID                                                      ║"
echo "║  Hostname: $HOSTNAME                                              ║"
echo "║  IP: $CONTAINER_IP                                                ║"
echo "║                                                                  ║"
echo "║  🌐 Web: http://$CONTAINER_IP:5000                                ║"
echo "║  📺 RTSP: rtsp://$CONTAINER_IP:8554/[camera_name]                 ║"
echo "║                                                                  ║"
echo "║  📋 Comandos útiles:                                             ║"
echo "║  • pct enter $VMID                                                ║"
echo "║  • wyze config (configurar credenciales)                        ║"
echo "║  • wyze start/stop/restart                                       ║"
echo "║                                                                  ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

msg "¡Wyze Bridge está listo para usar!"
msg "Próximos pasos:"
echo "  1. Accede al contenedor: pct enter $VMID"
echo "  2. Configura credenciales: wyze config"
echo "  3. Accede a la web: http://$CONTAINER_IP:5000" 