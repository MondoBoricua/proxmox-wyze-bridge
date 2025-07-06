#!/bin/bash

# Wyze Bridge Auto-Installer para Proxmox LXC
# Versión Nativa Mejorada - Solo creación de contenedor
# Autor: MondoBoricua 🇵🇷
# Repo: https://github.com/MondoBoricua/proxmox-wyze-bridge

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # Sin color

# Variables globales
SELECTED_VMID=""
INSTALLATION_TYPE=""

# Función para mostrar mensajes con timestamp
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
    echo "║  • Creación automática de contenedor LXC                                 ║"
    echo "║  • Configuración optimizada para Wyze Bridge                             ║"
    echo "║  • Instalación en dos pasos (contenedor + software)                      ║"
    echo "║  • Compatible con instalador nativo de GiZZoR                            ║"
    echo "║                                                                           ║"
    echo "║  Instalador: https://github.com/GiZZoR/wyze-bridge-installer             ║"
    echo "║  Repo: https://github.com/MondoBoricua/proxmox-wyze-bridge               ║"
    echo "╚═══════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Función para verificar que estamos en Proxmox
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

# Función para verificar conectividad a internet
check_connectivity() {
    show_message $BLUE "🌐 Verificando conectividad a internet..."
    
    if timeout 10 ping -c 1 github.com &>/dev/null; then
        show_message $GREEN "✅ Conectividad verificada"
    else
        show_message $RED "❌ Sin conexión a internet. Verifica tu configuración de red."
        exit 1
    fi
}

# Función para listar contenedores existentes
list_containers() {
    echo -e "${CYAN}📋 Contenedores LXC existentes:${NC}"
    echo
    pct list
    echo
}

# Función para obtener VMID del usuario
get_user_vmid() {
    while true; do
        echo -e "${YELLOW}🆔 Opciones de instalación:${NC}"
        echo "  1. Crear nuevo contenedor (recomendado)"
        echo "  2. Usar contenedor existente"
        echo
        echo -e "${YELLOW}¿Qué deseas hacer? (1/2): ${NC}"
        read -r choice
        
        case $choice in
            1)
                # Crear nuevo contenedor
                local suggested_vmid=$(get_next_available_vmid)
                echo
                echo -e "${CYAN}💡 VMID sugerido: $suggested_vmid${NC}"
                echo -e "${YELLOW}¿Usar este VMID o especificar otro? (s/N): ${NC}"
                read -r use_suggested
                
                if [[ "$use_suggested" =~ ^[Ss]$ ]]; then
                    SELECTED_VMID=$suggested_vmid
                else
                    while true; do
                        echo -e "${YELLOW}Ingresa el VMID deseado (100-999): ${NC}"
                        read -r custom_vmid
                        
                        if [[ "$custom_vmid" =~ ^[0-9]+$ ]] && [[ $custom_vmid -ge 100 ]] && [[ $custom_vmid -le 999 ]]; then
                            if pct status $custom_vmid &>/dev/null; then
                                echo -e "${RED}❌ VMID $custom_vmid ya existe. Elige otro.${NC}"
                            else
                                SELECTED_VMID=$custom_vmid
                                break
                            fi
                        else
                            echo -e "${RED}❌ VMID inválido. Debe ser un número entre 100 y 999.${NC}"
                        fi
                    done
                fi
                
                INSTALLATION_TYPE="new"
                break
                ;;
            2)
                # Usar contenedor existente
                list_containers
                echo -e "${YELLOW}Ingresa el VMID del contenedor existente: ${NC}"
                read -r existing_vmid
                
                if ! pct status $existing_vmid &>/dev/null; then
                    echo -e "${RED}❌ Contenedor $existing_vmid no existe${NC}"
                    echo
                    continue
                fi
                
                local container_name=$(pct config $existing_vmid | grep "^hostname:" | cut -d' ' -f2)
                echo -e "${CYAN}📋 Contenedor seleccionado: $existing_vmid ($container_name)${NC}"
                echo -e "${YELLOW}¿Confirmar instalación en este contenedor? (y/N): ${NC}"
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

# Función para obtener el próximo VMID disponible
get_next_available_vmid() {
    local vmid=111
    while pct status $vmid &>/dev/null; do
        ((vmid++))
    done
    echo $vmid
}

# Función para crear el contenedor LXC
create_container() {
    local vmid=$1
    
    show_message $BLUE "🚀 Creando contenedor LXC $vmid..."
    
    # Descargar template si no existe
    if [[ ! -f "/var/lib/vz/template/cache/ubuntu-22.04-standard_22.04-1_amd64.tar.zst" ]]; then
        show_message $BLUE "📥 Descargando template de Ubuntu 22.04..."
        pveam download local ubuntu-22.04-standard_22.04-1_amd64.tar.zst
    fi
    
    # Crear contenedor con configuración optimizada para Wyze Bridge
    pct create $vmid \
        local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst \
        --hostname wyze-bridge-lxc \
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

# Función para configurar el contenedor básico
configure_container() {
    local vmid=$1
    
    show_message $BLUE "🔧 Configurando contenedor básico..."
    
    # Instalar curl que es necesario para el siguiente paso
    pct exec $vmid -- apt update
    pct exec $vmid -- apt install -y curl
    
    show_message $GREEN "✅ Configuración básica completada"
}

# Función para instalar automáticamente Wyze Bridge
auto_install_wyze() {
    local vmid=$1
    
    show_message $BLUE "🚀 Instalando Wyze Bridge automáticamente..."
    show_message $CYAN "💡 Esto puede tomar varios minutos..."
    
    # Ejecutar el instalador de Wyze Bridge dentro del contenedor
    if pct exec $vmid -- bash -c "curl -s https://raw.githubusercontent.com/MondoBoricua/proxmox-wyze-bridge/main/install-wyze-only.sh | bash"; then
        show_message $GREEN "✅ Wyze Bridge instalado automáticamente"
        return 0
    else
        show_message $YELLOW "⚠️ La instalación automática falló o se interrumpió"
        show_message $CYAN "💡 Puedes completarla manualmente siguiendo las instrucciones"
        return 1
    fi
}

# Función para mostrar instrucciones finales
show_final_instructions() {
    local vmid=$1
    local container_ip=$(pct exec $vmid -- hostname -I | awk '{print $1}' 2>/dev/null || echo 'Obteniendo...')
    
    echo -e "${GREEN}"
    echo "╔═══════════════════════════════════════════════════════════════════════════╗"
    echo "║                   🎯 CONTENEDOR CREADO EXITOSAMENTE                       ║"
    echo "║                                                                           ║"
    echo "║  VMID: $vmid                                                              ║"
    echo "║  Hostname: wyze-bridge-lxc                                                ║"
    echo "║  IP: $container_ip                                                        ║"
    echo "║                                                                           ║"
    echo "╚═══════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    echo -e "${CYAN}📝 PRÓXIMOS PASOS - INSTALACIÓN MANUAL:${NC}"
    echo
    echo -e "${WHITE}🔧 PASO 1 - Entrar al contenedor:${NC}"
    echo -e "${BLUE}      pct enter $vmid${NC}"
    echo
    echo -e "${WHITE}🔧 PASO 2 - Instalar curl:${NC}"
    echo -e "${BLUE}      apt update && apt install -y curl${NC}"
    echo
    echo -e "${WHITE}🔧 PASO 3 - Instalar Wyze Bridge:${NC}"
    echo -e "${BLUE}      bash <(curl -s https://raw.githubusercontent.com/MondoBoricua/proxmox-wyze-bridge/main/install-wyze-only.sh)${NC}"
    echo
    echo -e "${WHITE}🔧 PASO 4 - Configurar PATH (si es necesario):${NC}"
    echo -e "${BLUE}      export PATH=/usr/local/bin:\$PATH${NC}"
    echo
    echo -e "${WHITE}🔧 PASO 5 - Gestionar servicios:${NC}"
    echo -e "${BLUE}      /usr/local/bin/wyze start${NC}"
    echo -e "${BLUE}      /usr/local/bin/wyze status${NC}"
    echo -e "${BLUE}      /usr/local/bin/wyze config${NC}"
    echo
    echo -e "${CYAN}📋 COMANDOS ÚTILES DENTRO DEL CONTENEDOR:${NC}"
    echo -e "${WHITE}• /usr/local/bin/wyze start|stop|restart|status|logs|config|info${NC}"
    echo -e "${WHITE}• systemctl start|stop|restart wyze-bridge${NC}"
    echo -e "${WHITE}• journalctl -u wyze-bridge -f${NC}"
    echo -e "${WHITE}• nano /etc/wyze-bridge/app.env${NC}"
    echo
    echo -e "${CYAN}📋 DESPUÉS DE LA INSTALACIÓN:${NC}"
    echo -e "${WHITE}• Interfaz web: http://$container_ip:5000${NC}"
    echo -e "${WHITE}• RTSP: rtsp://$container_ip:8554/[camera_name]${NC}"
    echo
    echo -e "${GREEN}✅ El contenedor está listo - Sigue los pasos de arriba${NC}"
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
    
    # Solicitar confirmación
    echo
    echo -e "${YELLOW}¿Deseas continuar creando el contenedor? (y/N): ${NC}"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        show_message $RED "❌ Operación cancelada"
        exit 0
    fi
    
    if [[ "$install_type" == "new" ]]; then
        # Crear nuevo contenedor
        create_container $vmid
        configure_container $vmid
    else
        # Configurar contenedor existente
        show_message $BLUE "🔧 Configurando contenedor existente..."
        
        # Verificar que el contenedor esté ejecutándose
        if [[ $(pct status $vmid) != "status: running" ]]; then
            show_message $BLUE "▶️ Iniciando contenedor $vmid..."
            pct start $vmid
            sleep 5
            
            if ! wait_for_container $vmid; then
                show_message $RED "❌ Error: contenedor no está respondiendo"
                exit 1
            fi
        fi
        
        configure_container $vmid
    fi
    
    # Mostrar mensaje informativo
    echo
    echo -e "${CYAN}💡 El contenedor está listo. Sigue las instrucciones de abajo para instalar Wyze Bridge${NC}"
    
    # Mostrar instrucciones finales
    show_final_instructions $vmid
}

# Ejecutar función principal
main "$@" 