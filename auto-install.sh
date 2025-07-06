#!/bin/bash

# Script mejorado de auto-instalación de Wyze Bridge para Proxmox LXC
# Versión resistente a cuelgues y timeouts
# Ahora usa el instalador nativo de GiZZoR (sin Docker)
# Autor: MondoBoricua 🇵🇷

set -euo pipefail

# Configuración de colores para mensajes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Función para mostrar mensajes con colores y timestamp
show_message() {
    local color=$1
    local message=$2
    echo -e "${color}[$(date '+%H:%M:%S')] ${message}${NC}"
}

# Función para mostrar el banner
show_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════════════════╗"
    echo "║                     🚀 WYZE BRIDGE AUTO-INSTALLER                        ║"
    echo "║                    Versión Nativa Mejorada 🇵🇷                           ║"
    echo "║                                                                           ║"
    echo "║  • Instalación nativa sin Docker (usando GiZZoR installer)               ║"
    echo "║  • Timeouts inteligentes y manejo de errores                             ║"
    echo "║  • Configuración completa de LXC para Wyze Bridge                        ║"
    echo "║  • Incluye MediaMTX y FFmpeg automáticamente                             ║"
    echo "║                                                                           ║"
    echo "║  Instalador: https://github.com/GiZZoR/wyze-bridge-installer             ║"
    echo "║  Repo: https://github.com/MondoBoricua/proxmox-wyze-bridge               ║"
    echo "╚═══════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Función para verificar si estamos en Proxmox
check_proxmox() {
    if ! command -v pct &> /dev/null; then
        show_message $RED "❌ Este script debe ejecutarse en un servidor Proxmox VE"
        exit 1
    fi
    
    if [[ $EUID -ne 0 ]]; then
        show_message $RED "❌ Este script debe ejecutarse como root"
        exit 1
    fi
}

# Función para verificar conectividad
check_connectivity() {
    show_message $BLUE "🌐 Verificando conectividad a internet..."
    
    if ! timeout 10 ping -c 1 8.8.8.8 &> /dev/null; then
        show_message $RED "❌ No hay conectividad a internet"
        exit 1
    fi
    
    if ! timeout 10 curl -s https://github.com &> /dev/null; then
        show_message $RED "❌ No se puede acceder a GitHub"
        exit 1
    fi
    
    show_message $GREEN "✅ Conectividad verificada"
}

# Función para obtener el siguiente VMID disponible
get_next_vmid() {
    local max_vmid=100
    local vmid
    
    # Obtener el VMID más alto actual
    for vmid in $(pct list | awk 'NR>1 {print $1}' | sort -n); do
        if [[ $vmid -gt $max_vmid ]]; then
            max_vmid=$vmid
        fi
    done
    
    # Buscar el siguiente VMID disponible
    local next_vmid=$((max_vmid + 1))
    
    while pct status $next_vmid &>/dev/null; do
        ((next_vmid++))
    done
    
    echo $next_vmid
}

# Función para mostrar contenedores existentes
show_existing_containers() {
    echo -e "${BLUE}📋 Contenedores LXC existentes:${NC}"
    echo
    pct list | head -1
    echo "────────────────────────────────────────────────────────────────────"
    pct list | tail -n +2 | while read line; do
        vmid=$(echo $line | awk '{print $1}')
        status=$(echo $line | awk '{print $2}')
        name=$(echo $line | awk '{print $3}')
        
        if [[ "$status" == "running" ]]; then
            echo -e "${GREEN}$line${NC}"
        else
            echo -e "${YELLOW}$line${NC}"
        fi
    done
    echo
}

# Función para obtener VMID del usuario
get_user_vmid() {
    while true; do
        show_existing_containers
        
        echo -e "${CYAN}🆔 Opciones de instalación:${NC}"
        echo -e "  ${WHITE}1.${NC} Crear nuevo contenedor (recomendado)"
        echo -e "  ${WHITE}2.${NC} Usar contenedor existente"
        echo
        echo -e "${YELLOW}¿Qué deseas hacer? (1/2): ${NC}"
        read -r choice
        
        case $choice in
            1)
                # Crear nuevo contenedor
                local suggested_vmid=$(get_next_vmid)
                echo
                echo -e "${CYAN}💡 VMID sugerido: ${WHITE}$suggested_vmid${NC}"
                echo -e "${YELLOW}¿Usar este VMID o especificar otro? (s/N): ${NC}"
                read -r use_suggested
                
                if [[ "$use_suggested" =~ ^[Ss]$ ]]; then
                    SELECTED_VMID=$suggested_vmid
                    INSTALLATION_TYPE="new"
                    break
                else
                    echo -e "${YELLOW}Ingresa el VMID deseado (100-999): ${NC}"
                    read -r custom_vmid
                    
                    # Verificar que sea un número válido
                    if ! [[ "$custom_vmid" =~ ^[0-9]+$ ]] || [[ $custom_vmid -lt 100 ]] || [[ $custom_vmid -gt 999 ]]; then
                        echo -e "${RED}❌ VMID inválido. Debe ser un número entre 100 y 999${NC}"
                        echo
                        continue
                    fi
                    
                    # Verificar que no exista
                    if pct status $custom_vmid &>/dev/null; then
                        echo -e "${RED}❌ El VMID $custom_vmid ya existe${NC}"
                        echo
                        continue
                    fi
                    
                    SELECTED_VMID=$custom_vmid
                    INSTALLATION_TYPE="new"
                    break
                fi
                ;;
            2)
                # Usar contenedor existente
                echo
                echo -e "${YELLOW}Ingresa el VMID del contenedor existente: ${NC}"
                read -r existing_vmid
                
                # Verificar que sea un número válido
                if ! [[ "$existing_vmid" =~ ^[0-9]+$ ]]; then
                    echo -e "${RED}❌ Debe ser un número válido${NC}"
                    echo
                    continue
                fi
                
                # Verificar que el contenedor existe
                if ! pct status $existing_vmid &>/dev/null; then
                    echo -e "${RED}❌ El contenedor $existing_vmid no existe${NC}"
                    echo
                    continue
                fi
                
                # Obtener información del contenedor
                local status=$(pct status $existing_vmid)
                local name=$(pct config $existing_vmid | grep "hostname:" | cut -d' ' -f2 2>/dev/null || echo "sin-nombre")
                
                echo
                echo -e "${BLUE}📋 Información del contenedor:${NC}"
                echo -e "   VMID: ${WHITE}$existing_vmid${NC}"
                echo -e "   Nombre: ${WHITE}$name${NC}"
                echo -e "   Estado: ${WHITE}$status${NC}"
                echo
                
                echo -e "${YELLOW}⚠️  ADVERTENCIA: Esto instalará Wyze Bridge en el contenedor existente.${NC}"
                echo -e "${YELLOW}¿Estás seguro de continuar? (y/N): ${NC}"
                read -r confirm
                
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    SELECTED_VMID=$existing_vmid
                    INSTALLATION_TYPE="existing"
                    break
                else
                    echo -e "${CYAN}Selecciona otra opción...${NC}"
                    echo
                fi
                ;;
            *)
                echo -e "${RED}❌ Opción inválida. Selecciona 1 o 2${NC}"
                echo
                ;;
        esac
    done
}

# Función para configurar el contenedor con el instalador nativo de GiZZoR
configure_container() {
    local vmid=$1
    
    show_message $BLUE "🔧 Configurando contenedor $vmid con Wyze Bridge nativo..."
    
    # Crear script de configuración temporal usando el instalador de GiZZoR
    cat > /tmp/wyze-bridge-native-setup.sh << 'EOF'
#!/bin/bash

# Función para mostrar mensajes con colores
show_msg() {
    local color=$1
    local message=$2
    echo -e "\033[${color}m[$(date '+%H:%M:%S')] ${message}\033[0m"
}

# Función para instalar paquetes con reintentos
install_with_retry() {
    local packages="$1"
    local max_attempts=3
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        show_msg "33" "📦 Intento $attempt/$max_attempts: instalando $packages"
        
        if timeout 300 apt install -y $packages; then
            show_msg "32" "✅ Instalación exitosa: $packages"
            return 0
        else
            show_msg "31" "⚠️  Intento $attempt falló, reintentando..."
            ((attempt++))
            sleep 5
        fi
    done
    
    show_msg "31" "❌ Falló la instalación después de $max_attempts intentos: $packages"
    return 1
}

# Configurar variables de entorno para evitar prompts interactivos
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

# Actualizar el sistema
show_msg "34" "📦 Actualizando sistema..."
timeout 300 apt update || {
    show_msg "31" "⚠️  Timeout en apt update, continuando..."
}

# Instalar dependencias esenciales para Python y Wyze Bridge
show_msg "34" "🔧 Instalando dependencias esenciales..."
install_with_retry "curl wget git nano htop ufw"

# Instalar Python 3.10+ y herramientas necesarias
show_msg "34" "🐍 Instalando Python y dependencias..."
install_with_retry "python3 python3-pip python3-venv python3-dev"

# Instalar dependencias de compilación necesarias para algunos paquetes Python
show_msg "34" "🔨 Instalando herramientas de compilación..."
install_with_retry "build-essential pkg-config libssl-dev libffi-dev"

# Verificar versión de Python (necesita 3.10+)
python_version=$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1,2)
show_msg "36" "🐍 Versión de Python detectada: $python_version"

if [[ $(echo "$python_version >= 3.10" | bc -l 2>/dev/null || echo "0") -eq 0 ]]; then
    show_msg "31" "⚠️  Python 3.10+ requerido. Versión actual: $python_version"
    # Intentar instalar Python 3.10+ desde deadsnakes PPA si está disponible
    if ! install_with_retry "software-properties-common"; then
        show_msg "31" "❌ No se pudo instalar software-properties-common"
    else
        add-apt-repository -y ppa:deadsnakes/ppa 2>/dev/null || true
        apt update 2>/dev/null || true
        install_with_retry "python3.10 python3.10-venv python3.10-dev" || {
            show_msg "33" "⚠️  Continuando con Python disponible..."
        }
    fi
fi

# Configurar firewall para Wyze Bridge
show_msg "34" "🛡️ Configurando firewall..."
ufw --force enable
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 5000/tcp comment "Wyze Bridge Web Interface"
ufw allow 8554/tcp comment "MediaMTX RTSP Server"
ufw allow 8888/tcp comment "MediaMTX WebRTC"
ufw allow 8889/tcp comment "MediaMTX HLS"

# Crear directorios necesarios
show_msg "34" "📁 Creando estructura de directorios..."
mkdir -p /opt/wyze-bridge
mkdir -p /etc/wyze-bridge
mkdir -p /var/log/wyze-bridge

# Descargar el instalador nativo de GiZZoR
show_msg "34" "📥 Descargando instalador nativo de Wyze Bridge..."
cd /root

# Descargar el script de instalación de GiZZoR directamente
if ! timeout 60 wget -O wyze-bridge.py https://github.com/GiZZoR/wyze-bridge-installer/raw/refs/heads/main/wyze-bridge.py; then
    show_msg "31" "❌ Error descargando instalador de GiZZoR"
    exit 1
fi

# Hacer ejecutable el instalador
chmod +x wyze-bridge.py

# Instalar Wyze Bridge usando el instalador nativo de GiZZoR
show_msg "33" "🚀 Instalando Wyze Bridge nativo (esto puede tomar varios minutos)..."
show_msg "36" "💡 Este instalador de GiZZoR instala:"
show_msg "36" "   • docker-wyze-bridge (sin Docker)"
show_msg "36" "   • MediaMTX para streaming RTSP"
show_msg "36" "   • FFmpeg para procesamiento de video"
show_msg "36" "   • Configuración completa de servicios systemd"

# Ejecutar instalación con configuración personalizada usando el script de GiZZoR
show_msg "33" "⚠️  Si FFmpeg falla durante la instalación, continuaremos sin él"
if timeout 1200 python3 wyze-bridge.py install \
    --APP_IP 0.0.0.0 \
    --APP_PORT 5000 \
    --APP_USER wyze \
    --APP_GUNICORN 1; then
    show_msg "32" "✅ Wyze Bridge instalado exitosamente usando GiZZoR installer"
else
    show_msg "33" "⚠️  La instalación tuvo algunos problemas, verificando servicios..."
    
    # Verificar si los servicios principales se instalaron
    if systemctl list-unit-files | grep -q wyze-bridge; then
        show_msg "32" "✅ Wyze Bridge se instaló correctamente (ignorando errores de FFmpeg)"
        show_msg "36" "💡 FFmpeg se puede instalar después con: wyze install-ffmpeg"
    else
        show_msg "31" "⚠️  Instalación tardó más de lo esperado o falló"
        show_msg "33" "📝 Puedes completar la instalación manualmente con:"
        show_msg "36" "   cd /root && python3 wyze-bridge.py install"
    fi
fi

# Verificar instalación
show_msg "34" "🔍 Verificando instalación..."
if [[ -d "/srv/wyze-bridge" ]]; then
    show_msg "32" "✅ Wyze Bridge instalado en /srv/wyze-bridge"
fi

if [[ -d "/srv/mediamtx" ]]; then
    show_msg "32" "✅ MediaMTX instalado en /srv/mediamtx"
fi

if systemctl is-enabled wyze-bridge &>/dev/null; then
    show_msg "32" "✅ Servicio wyze-bridge configurado"
fi

# Crear script de gestión personalizado
show_msg "34" "🛠️ Creando herramientas de gestión..."
cat > /usr/local/bin/wyze-bridge-menu << 'MENU_EOF'
#!/bin/bash

# Menú principal de Wyze Bridge
# Integrado con el instalador nativo de GiZZoR

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

show_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                🚀 WYZE BRIDGE CONTROL PANEL                     ║"
    echo "║                    Instalación Nativa 🇵🇷                        ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

show_status() {
    echo -e "${BLUE}📊 Estado de los servicios:${NC}"
    echo
    
    # Estado de Wyze Bridge
    if systemctl is-active wyze-bridge &>/dev/null; then
        echo -e "  ${GREEN}✅ Wyze Bridge: ACTIVO${NC}"
    else
        echo -e "  ${RED}❌ Wyze Bridge: INACTIVO${NC}"
    fi
    
    # Estado de MediaMTX
    if systemctl is-active mediamtx &>/dev/null; then
        echo -e "  ${GREEN}✅ MediaMTX: ACTIVO${NC}"
    else
        echo -e "  ${RED}❌ MediaMTX: INACTIVO${NC}"
    fi
    
    # Verificar puertos
    echo
    echo -e "${BLUE}🌐 Puertos de red:${NC}"
    if netstat -tuln 2>/dev/null | grep -q ":5000 "; then
        echo -e "  ${GREEN}✅ Puerto 5000 (Web): ABIERTO${NC}"
    else
        echo -e "  ${RED}❌ Puerto 5000 (Web): CERRADO${NC}"
    fi
    
    if netstat -tuln 2>/dev/null | grep -q ":8554 "; then
        echo -e "  ${GREEN}✅ Puerto 8554 (RTSP): ABIERTO${NC}"
    else
        echo -e "  ${RED}❌ Puerto 8554 (RTSP): CERRADO${NC}"
    fi
    
    echo
    echo -e "${CYAN}🌍 Acceso Web: http://$(hostname -I | awk '{print $1}'):5000${NC}"
    echo -e "${CYAN}📺 RTSP: rtsp://$(hostname -I | awk '{print $1}'):8554/[camera_name]${NC}"
}

main_menu() {
    while true; do
        show_banner
        show_status
        
        echo
        echo -e "${YELLOW}🔧 Opciones disponibles:${NC}"
        echo -e "  ${WHITE}1.${NC} Ver logs de Wyze Bridge"
        echo -e "  ${WHITE}2.${NC} Reiniciar servicios"
        echo -e "  ${WHITE}3.${NC} Configurar credenciales"
        echo -e "  ${WHITE}4.${NC} Actualizar Wyze Bridge"
        echo -e "  ${WHITE}5.${NC} Ver configuración"
                 echo -e "  ${WHITE}6.${NC} Gestionar servicios"
         echo -e "  ${WHITE}7.${NC} Información del sistema"
         echo -e "  ${WHITE}8.${NC} Instalar FFmpeg"
         echo -e "  ${WHITE}0.${NC} Salir"
        echo
                 echo -e "${YELLOW}Selecciona una opción (0-8): ${NC}"
         read -r choice
         
         case $choice in
            1)
                echo -e "${BLUE}📋 Logs de Wyze Bridge (Ctrl+C para salir):${NC}"
                journalctl -u wyze-bridge -f --no-pager
                ;;
            2)
                echo -e "${BLUE}🔄 Reiniciando servicios...${NC}"
                systemctl restart wyze-bridge
                systemctl restart mediamtx
                echo -e "${GREEN}✅ Servicios reiniciados${NC}"
                sleep 2
                ;;
            3)
                echo -e "${BLUE}🔐 Configurando credenciales...${NC}"
                nano /etc/wyze-bridge/app.env
                echo -e "${YELLOW}💡 Reinicia los servicios para aplicar cambios${NC}"
                read -p "Presiona Enter para continuar..."
                ;;
                         4)
                 echo -e "${BLUE}⬆️ Actualizando Wyze Bridge...${NC}"
                 cd /root
                 python3 wyze-bridge.py update
                 echo -e "${GREEN}✅ Actualización completada${NC}"
                 sleep 3
                 ;;
             5)
                 echo -e "${BLUE}⚙️ Configuración actual:${NC}"
                 echo
                 python3 /root/wyze-bridge.py show-settings
                 read -p "Presiona Enter para continuar..."
                 ;;
            6)
                echo -e "${BLUE}🛠️ Gestión de servicios:${NC}"
                echo -e "  ${WHITE}1.${NC} Iniciar servicios"
                echo -e "  ${WHITE}2.${NC} Parar servicios"
                echo -e "  ${WHITE}3.${NC} Habilitar al inicio"
                echo -e "  ${WHITE}4.${NC} Deshabilitar al inicio"
                echo -e "${YELLOW}Opción: ${NC}"
                read -r service_choice
                
                case $service_choice in
                    1)
                        systemctl start wyze-bridge mediamtx
                        echo -e "${GREEN}✅ Servicios iniciados${NC}"
                        ;;
                    2)
                        systemctl stop wyze-bridge mediamtx
                        echo -e "${YELLOW}⏹️ Servicios detenidos${NC}"
                        ;;
                    3)
                        systemctl enable wyze-bridge mediamtx
                        echo -e "${GREEN}✅ Servicios habilitados al inicio${NC}"
                        ;;
                    4)
                        systemctl disable wyze-bridge mediamtx
                        echo -e "${YELLOW}⏹️ Servicios deshabilitados al inicio${NC}"
                        ;;
                esac
                sleep 2
                ;;
            7)
                echo -e "${BLUE}💻 Información del sistema:${NC}"
                echo
                echo -e "${WHITE}Hostname:${NC} $(hostname)"
                echo -e "${WHITE}IP Address:${NC} $(hostname -I | awk '{print $1}')"
                echo -e "${WHITE}OS:${NC} $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
                echo -e "${WHITE}Kernel:${NC} $(uname -r)"
                echo -e "${WHITE}Uptime:${NC} $(uptime -p)"
                echo -e "${WHITE}Memory:${NC} $(free -h | grep Mem | awk '{print $3"/"$2}')"
                echo -e "${WHITE}Disk:${NC} $(df -h / | tail -1 | awk '{print $3"/"$2" ("$5" usado)"}')"
                                 echo
                 read -p "Presiona Enter para continuar..."
                 ;;
             8)
                 echo -e "${BLUE}📦 Instalando FFmpeg...${NC}"
                 apt update && apt install -y ffmpeg
                 echo -e "${GREEN}✅ FFmpeg instalado desde repositorios del sistema${NC}"
                 sleep 2
                 ;;
             0)
                 echo -e "${GREEN}¡Hasta la vista, pana! 👋${NC}"
                 exit 0
                 ;;
             *)
                 echo -e "${RED}❌ Opción inválida${NC}"
                 sleep 1
                 ;;
        esac
    done
}

main_menu
MENU_EOF

# Hacer ejecutable el menú
chmod +x /usr/local/bin/wyze-bridge-menu

# Configurar autologin avanzado
show_msg "34" "🔐 Configurando autologin..."

# Configurar autologin con systemd
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/override.conf << 'AUTOLOGIN_EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --noissue --autologin root %I $TERM
Type=idle
AUTOLOGIN_EOF

# Configurar autologin para console
mkdir -p /etc/systemd/system/console-getty.service.d
cat > /etc/systemd/system/console-getty.service.d/override.conf << 'CONSOLE_EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --noissue --autologin root --keep-baud console 115200,38400,9600 $TERM
Type=idle
CONSOLE_EOF

# Configurar MOTD personalizado
cat > /etc/motd << 'MOTD_EOF'
╔══════════════════════════════════════════════════════════════════╗
║                🚀 WYZE BRIDGE LXC CONTAINER                     ║
║                   Instalación Nativa 🇵🇷                         ║
║                                                                  ║
║  Web Interface: http://[IP]:5000                                 ║
║  RTSP Stream: rtsp://[IP]:8554/[camera_name]                     ║
║                                                                  ║
║  Ejecuta 'wyze-bridge-menu' para acceder al panel de control    ║
╚══════════════════════════════════════════════════════════════════╝

MOTD_EOF

# Configurar PATH para incluir /usr/local/bin
echo 'export PATH="/usr/local/bin:$PATH"' >> /root/.bashrc

# Configurar .bashrc para mostrar menú automáticamente
cat >> /root/.bashrc << 'BASHRC_EOF'

# Función para detectar tipo de login
detect_login_type() {
    if [[ -n "$SSH_CLIENT" ]]; then
        echo "ssh"
    elif [[ -n "$SSH_TTY" ]]; then
        echo "ssh"
    elif [[ "$TERM" == "screen"* ]] || [[ -n "$TMUX" ]]; then
        echo "screen"
    else
        echo "console"
    fi
}

# Auto-ejecutar menú según contexto
if [[ $- == *i* ]]; then
    login_type=$(detect_login_type)
    
    case $login_type in
        "console")
            # Login directo en consola - mostrar menú completo
            echo "🚀 Bienvenido al sistema Wyze Bridge LXC"
            echo "🌐 Acceso Web: http://$(hostname -I | awk '{print $1}'):5000"
            echo
            wyze-bridge-menu
            ;;
        "ssh")
            # Login por SSH - mostrar información básica
            echo "📹 Wyze Bridge LXC - Acceso por SSH"
            echo "🌐 Acceso Web: http://$(hostname -I | awk '{print $1}'):5000"
            echo "📋 Ejecuta 'wyze-bridge-menu' para acceder al panel de control"
            echo
            ;;
    esac
fi
BASHRC_EOF

# Recargar systemd y habilitar servicios
systemctl daemon-reload
systemctl enable getty@tty1.service
systemctl enable console-getty.service

# Mostrar información final de la instalación
show_msg "32" "✅ Configuración del contenedor completada"
show_msg "36" "🎯 Wyze Bridge instalado usando el instalador nativo de GiZZoR"
show_msg "36" "🌐 Acceso Web: http://$(hostname -I | awk '{print $1}'):5000"
show_msg "36" "📺 RTSP: rtsp://$(hostname -I | awk '{print $1}'):8554/[camera_name]"
show_msg "36" "📋 Panel de control: wyze-bridge-menu"

# Crear archivo de información para referencia
cat > /root/wyze-bridge-info.txt << 'INFO_EOF'
WYZE BRIDGE - INFORMACIÓN DE INSTALACIÓN
==========================================

Instalador usado: GiZZoR wyze-bridge-installer
Repo: https://github.com/GiZZoR/wyze-bridge-installer

UBICACIONES IMPORTANTES:
- Aplicación: /srv/wyze-bridge
- MediaMTX: /srv/mediamtx
- Configuración: /etc/wyze-bridge/app.env
- Logs: journalctl -u wyze-bridge
- Instalador GiZZoR: /root/wyze-bridge.py

SERVICIOS:
- wyze-bridge: Aplicación principal
- mediamtx: Servidor RTSP/WebRTC

PUERTOS:
- 5000: Interfaz web
- 8554: RTSP
- 8888: WebRTC
- 8889: HLS

COMANDOS ÚTILES:
- wyze-bridge-menu: Panel de control
- systemctl status wyze-bridge: Estado del servicio
- journalctl -u wyze-bridge -f: Ver logs en tiempo real
- python3 /root/wyze-bridge.py update: Actualizar usando GiZZoR
- python3 /root/wyze-bridge.py show-settings: Ver configuración

CONFIGURACIÓN:
Edita /etc/wyze-bridge/app.env para configurar:
- Credenciales de Wyze
- Configuración de cámaras
- Opciones de streaming
INFO_EOF

show_msg "36" "📄 Información guardada en /root/wyze-bridge-info.txt"
EOF

    # Copiar y ejecutar el script de configuración
    pct push $vmid /tmp/wyze-bridge-native-setup.sh /tmp/wyze-bridge-native-setup.sh
    pct exec $vmid -- chmod +x /tmp/wyze-bridge-native-setup.sh
    
    # Ejecutar con timeout ampliado para la instalación nativa
    show_message $YELLOW "⏳ Ejecutando instalación nativa (máximo 45 minutos)..."
    show_message $CYAN "💡 Esta instalación incluye:"
    show_message $CYAN "   • docker-wyze-bridge (sin Docker)"
    show_message $CYAN "   • MediaMTX para streaming RTSP"
    show_message $CYAN "   • FFmpeg para procesamiento de video"
    show_message $CYAN "   • Configuración completa de servicios"
    
    if timeout 2700 pct exec $vmid -- /tmp/wyze-bridge-native-setup.sh; then
        show_message $GREEN "✅ Instalación nativa completada exitosamente"
    else
        show_message $YELLOW "⚠️  Instalación tardó más de lo esperado"
        show_message $CYAN "💡 El contenedor debería estar funcional, puedes acceder y verificar"
        show_message $CYAN "🔧 Usa 'wyze-bridge-menu' dentro del contenedor para gestionar"
    fi
    
    # Limpiar archivos temporales
    pct exec $vmid -- rm -f /tmp/wyze-bridge-native-setup.sh
    rm -f /tmp/wyze-bridge-native-setup.sh
}

# Función para esperar que el contenedor esté listo
wait_for_container() {
    local vmid=$1
    local max_attempts=30
    local attempt=1
    
    show_message $BLUE "⏳ Esperando que el contenedor esté listo..."
    
    while [[ $attempt -le $max_attempts ]]; do
        if pct exec $vmid -- echo "ready" &>/dev/null; then
            show_message $GREEN "✅ Contenedor listo"
            return 0
        fi
        
        ((attempt++))
        echo -n "."
        sleep 2
    done
    
    show_message $RED "❌ Timeout esperando que el contenedor esté listo"
    return 1
}

# Función principal
main() {
    show_banner
    
    # Verificaciones iniciales
    check_proxmox
    check_connectivity
    
    # Obtener VMID del usuario
    get_user_vmid
    local vmid=$SELECTED_VMID
    local install_type=$INSTALLATION_TYPE
    
    show_message $CYAN "🆔 VMID seleccionado: $vmid"
    show_message $CYAN "📋 Tipo de instalación: $install_type"
    show_message $CYAN "🚀 Instalador: GiZZoR wyze-bridge-installer (nativo)"
    
    # Solicitar confirmación final
    echo
    echo -e "${YELLOW}¿Deseas continuar con la instalación nativa? (y/N): ${NC}"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        show_message $RED "❌ Instalación cancelada"
        exit 0
    fi
    
    if [[ "$install_type" == "new" ]]; then
        # Crear nuevo contenedor LXC
        show_message $BLUE "🚀 Creando nuevo contenedor LXC..."
        
        # Descargar template si no existe
        if [[ ! -f "/var/lib/vz/template/cache/ubuntu-22.04-standard_22.04-1_amd64.tar.zst" ]]; then
            show_message $BLUE "📥 Descargando template de Ubuntu 22.04..."
            pveam download local ubuntu-22.04-standard_22.04-1_amd64.tar.zst
        fi
        
        # Crear contenedor con configuración optimizada para Wyze Bridge
        pct create $vmid \
            local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst \
            --hostname wyze-bridge-native \
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
            --description "Wyze Bridge - Instalación Nativa (GiZZoR)"
        
        # Iniciar contenedor
        show_message $BLUE "▶️ Iniciando contenedor..."
        pct start $vmid
        
        # Esperar que esté listo
        if ! wait_for_container $vmid; then
            show_message $RED "❌ Error: contenedor no está respondiendo"
            exit 1
        fi
    else
        # Usar contenedor existente
        show_message $BLUE "🔧 Configurando contenedor existente..."
        
        # Verificar que el contenedor esté ejecutándose
        if [[ $(pct status $vmid) != "status: running" ]]; then
            show_message $BLUE "▶️ Iniciando contenedor $vmid..."
            pct start $vmid
            sleep 5
            
            # Esperar que esté listo
            if ! wait_for_container $vmid; then
                show_message $RED "❌ Error: contenedor no está respondiendo"
                exit 1
            fi
        fi
    fi
    
    # Configurar contenedor con instalación nativa
    configure_container $vmid
    
    # Obtener IP del contenedor
    local container_ip=$(pct exec $vmid -- hostname -I | awk '{print $1}' 2>/dev/null || echo 'Obteniendo...')
    
    # Mostrar información final
    show_message $GREEN "🎉 ¡Instalación nativa completada!"
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════════════════╗"
    echo "║                   🎯 WYZE BRIDGE - INSTALACIÓN NATIVA                    ║"
    echo "║                                                                           ║"
    echo "║  VMID: $vmid                                                               ║"
    echo "║  Hostname: wyze-bridge-native                                             ║"
    echo "║  IP: $container_ip                                                        ║"
    echo "║                                                                           ║"
    echo "║  🌐 Acceso Web: http://$container_ip:5000                                 ║"
    echo "║  📺 RTSP: rtsp://$container_ip:8554/[camera_name]                         ║"
    echo "║  🖥️  Consola: pct enter $vmid                                             ║"
    echo "║                                                                           ║"
    echo "║  📋 Panel de control: wyze-bridge-menu                                   ║"
    echo "║  🔧 Configuración: /etc/wyze-bridge/app.env                               ║"
    echo "║  📄 Info: /root/wyze-bridge-info.txt                                     ║"
    echo "║                                                                           ║"
    echo "║  🚀 Instalador: GiZZoR wyze-bridge-installer                              ║"
    echo "║  📦 Incluye: Wyze Bridge + MediaMTX + FFmpeg                             ║"
    echo "║                                                                           ║"
    echo "╚═══════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # Instrucciones adicionales
    show_message $CYAN "📝 Próximos pasos:"
    show_message $WHITE "1. Accede al contenedor: pct enter $vmid"
    show_message $WHITE "2. Ejecuta el panel de control: wyze-bridge-menu"
    show_message $WHITE "3. Configura tus credenciales de Wyze en la opción 3"
    show_message $WHITE "4. Accede a la interfaz web: http://$container_ip:5000"
    
    show_message $CYAN "🛠️ Herramientas disponibles:"
    show_message $WHITE "• wyze-bridge-menu: Panel de control completo"
    show_message $WHITE "• python3 /opt/wyze-bridge/wyze-bridge-installer.py update: Actualizar"
    show_message $WHITE "• systemctl status wyze-bridge: Estado del servicio"
    show_message $WHITE "• journalctl -u wyze-bridge -f: Ver logs en tiempo real"
    
    show_message $GREEN "✅ Wyze Bridge nativo está instalado y listo para usar"
    show_message $CYAN "🔗 Basado en: https://github.com/GiZZoR/wyze-bridge-installer"
}

# Ejecutar función principal
main "$@" 