# 🚀 Wyze Bridge para Proxmox LXC - Versión Nativa

[![GitHub stars](https://img.shields.io/github/stars/MondoBoricua/proxmox-wyze-bridge?style=social)](https://github.com/MondoBoricua/proxmox-wyze-bridge)
[![GitHub forks](https://img.shields.io/github/forks/MondoBoricua/proxmox-wyze-bridge?style=social)](https://github.com/MondoBoricua/proxmox-wyze-bridge)
[![GitHub license](https://img.shields.io/github/license/MondoBoricua/proxmox-wyze-bridge)](https://github.com/MondoBoricua/proxmox-wyze-bridge/blob/main/LICENSE)

> **Instalador automático mejorado para Wyze Bridge en Proxmox LXC usando instalación nativa (sin Docker)**

## 🎯 ¿Qué es esto?

Este script automatiza completamente la instalación de **Wyze Bridge** en contenedores LXC de Proxmox, usando el instalador nativo de [GiZZoR](https://github.com/GiZZoR/wyze-bridge-installer) que **no requiere Docker**, perfecto para evitar virtualización anidada.

### 🆕 **Versión Mejorada - Instalación Nativa**

- ✅ **Sin Docker**: Usa el instalador nativo de GiZZoR
- ✅ **Todo Incluido**: Wyze Bridge + MediaMTX + FFmpeg automáticamente
- ✅ **Resistente a Cuelgues**: Timeouts inteligentes y manejo de errores
- ✅ **Panel de Control**: Interfaz completa de gestión
- ✅ **Configuración Automática**: Servicios systemd listos para usar

## 🚀 Instalación Ultra-Rápida

### Opción 1: Instalación Directa (Recomendada)

```bash
# Ejecutar desde Proxmox VE (como root)
bash <(curl -s https://raw.githubusercontent.com/MondoBoricua/proxmox-wyze-bridge/main/auto-install.sh)
```

### Opción 2: Descarga Manual

```bash
# Descargar y ejecutar
wget https://raw.githubusercontent.com/MondoBoricua/proxmox-wyze-bridge/main/auto-install.sh
chmod +x auto-install.sh
./auto-install.sh
```

## 🎮 Características Principales

### 📦 **Instalación Completa Automática**
- **Wyze Bridge**: Aplicación principal (sin Docker)
- **MediaMTX**: Servidor RTSP/WebRTC integrado
- **FFmpeg**: Procesamiento de video optimizado
- **Servicios Systemd**: Configuración automática
- **Firewall**: Configuración de puertos automática

### 🎯 **Panel de Control Avanzado**
- **Menú Interactivo**: `wyze-bridge-menu`
- **Gestión de Servicios**: Iniciar/parar/reiniciar
- **Configuración**: Editor de credenciales integrado
- **Logs en Tiempo Real**: Monitoreo completo
- **Actualizaciones**: Sistema de actualización automática

### 🛡️ **Seguridad y Estabilidad**
- **Timeouts Inteligentes**: Resistente a cuelgues
- **Manejo de Errores**: Recuperación automática
- **Firewall Configurado**: Puertos necesarios abiertos
- **Autologin**: Acceso directo al panel de control

## 📋 Puertos Configurados

| Puerto | Servicio | Descripción |
|--------|----------|-------------|
| 5000   | Web UI   | Interfaz web de Wyze Bridge |
| 8554   | RTSP     | Streaming RTSP |
| 8888   | WebRTC   | Streaming WebRTC |
| 8889   | HLS      | Streaming HLS |

## 🎯 Después de la Instalación

### 1. **Acceder al Contenedor**
```bash
# Desde Proxmox VE
pct enter [VMID]
```

### 2. **Panel de Control**
```bash
# Ejecutar menú principal
wyze-bridge-menu
```

### 3. **Configurar Credenciales**
- Usar opción 3 en el menú principal
- Editar `/etc/wyze-bridge/app.env`
- Reiniciar servicios para aplicar cambios

### 4. **Acceso Web**
```
http://[IP_CONTENEDOR]:5000
```

### 5. **Streams RTSP**
```
rtsp://[IP_CONTENEDOR]:8554/[nombre_camara]
```

## 🛠️ Herramientas Disponibles

### **Comandos Principales**
```bash
# Panel de control completo
wyze-bridge-menu

# Actualizar Wyze Bridge
python3 /root/wyze-bridge.py update

# Estado del servicio
systemctl status wyze-bridge

# Logs en tiempo real
journalctl -u wyze-bridge -f

# Ver configuración actual
python3 /root/wyze-bridge.py show-settings
```

### **Gestión de Servicios**
```bash
# Iniciar servicios
systemctl start wyze-bridge mediamtx

# Parar servicios
systemctl stop wyze-bridge mediamtx

# Reiniciar servicios
systemctl restart wyze-bridge mediamtx

# Habilitar al inicio
systemctl enable wyze-bridge mediamtx
```

## 📁 Estructura de Archivos

```
/srv/wyze-bridge/          # Aplicación principal
/srv/mediamtx/             # Servidor MediaMTX
/etc/wyze-bridge/          # Configuración
├── app.env                # Variables de entorno
└── install.json           # Configuración de instalación
/root/wyze-bridge.py       # Instalador de GiZZoR
/var/log/wyze-bridge/      # Logs
/root/wyze-bridge-info.txt # Información de instalación
```

## 🔧 Configuración Avanzada

### **Variables de Entorno** (`/etc/wyze-bridge/app.env`)
```bash
# Credenciales Wyze
WYZE_EMAIL=tu_email@ejemplo.com
WYZE_PASSWORD=tu_password

# Configuración de cámaras
FILTER_NAMES=Camara1,Camara2
FILTER_MACS=AABBCCDDEEFF,112233445566

# Configuración de streaming
QUALITY=HD
BITRATE=3000
FPS=20

# Configuración de red
RTSP_PROTOCOLS=tcp
ENABLE_AUDIO=true
```

### **Opciones del Instalador de GiZZoR**
```bash
# Instalación personalizada
python3 /root/wyze-bridge.py install \
    --APP_IP 0.0.0.0 \
    --APP_PORT 5000 \
    --APP_USER wyze \
    --APP_GUNICORN 1 \
    --APP_VERSION latest
```

## 🔍 Solución de Problemas

### **Problemas Comunes**

#### 1. **Servicio no inicia**
```bash
# Ver logs detallados
journalctl -u wyze-bridge -f

# Verificar configuración
python3 /root/wyze-bridge.py show-settings

# Reiniciar servicios
systemctl restart wyze-bridge mediamtx
```

#### 2. **No se conectan las cámaras**
```bash
# Verificar credenciales en app.env
nano /etc/wyze-bridge/app.env

# Reiniciar después de cambios
systemctl restart wyze-bridge
```

#### 3. **Stream RTSP no funciona**
```bash
# Verificar puertos
netstat -tuln | grep 8554

# Probar con VLC
vlc rtsp://[IP]:8554/[camera_name]
```

#### 4. **Interfaz web no accesible**
```bash
# Verificar servicio
systemctl status wyze-bridge

# Verificar puerto
netstat -tuln | grep 5000

# Verificar firewall
ufw status
```

## 📊 Recursos Recomendados

| Componente | Mínimo | Recomendado |
|------------|--------|-------------|
| RAM        | 1GB    | 2GB         |
| CPU        | 1 core | 2 cores     |
| Disco      | 8GB    | 12GB        |
| Red        | 100Mbps| 1Gbps       |

## 🔄 Actualización

### **Actualizar Wyze Bridge**
```bash
# Método 1: Usando el panel de control
wyze-bridge-menu  # Opción 4

# Método 2: Comando directo
cd /root
python3 wyze-bridge.py update
```

### **Actualizar Sistema**
```bash
# Actualizar paquetes
apt update && apt upgrade -y

# Reiniciar servicios
systemctl restart wyze-bridge mediamtx
```

## 🎯 Integración con Otros Sistemas

### **Home Assistant**
```yaml
# configuration.yaml
camera:
  - platform: generic
    name: Wyze Cam 1
    stream_source: rtsp://[IP]:8554/cam1
    still_image_url: http://[IP]:5000/snapshot/cam1
```

### **Frigate**
```yaml
# frigate.yml
cameras:
  wyze_cam_1:
    ffmpeg:
      inputs:
        - path: rtsp://[IP]:8554/cam1
          roles:
            - detect
            - record
```

### **Blue Iris**
1. Agregar nueva cámara como IP Camera
2. URL: `rtsp://[IP]:8554/[camera_name]`
3. Configurar codec H.264

## 🙏 Créditos y Reconocimientos

### **Instalador Principal**
Este proyecto usa el excelente instalador nativo de **GiZZoR**:
- **Repositorio**: [GiZZoR/wyze-bridge-installer](https://github.com/GiZZoR/wyze-bridge-installer)
- **Características**: Instalación sin Docker, MediaMTX integrado, FFmpeg incluido

### **Nuestras Contribuciones**
- 🚀 Sistema de auto-instalación para Proxmox LXC
- 🎮 Panel de control con interfaz boricua
- 🛡️ Configuración de seguridad y firewall
- 📚 Documentación completa en español
- 🔧 Herramientas de gestión y diagnóstico

## 📄 Licencia

Este proyecto está bajo la licencia MIT. Ver el archivo [LICENSE](LICENSE) para más detalles.

## 🤝 Contribuir

¡Las contribuciones son bienvenidas!

1. Fork el repositorio
2. Crea una rama para tu feature
3. Commit tus cambios con comentarios en español
4. Push a la rama
5. Abre un Pull Request

## 📞 Soporte

- **GitHub Issues**: [Reportar problema](https://github.com/MondoBoricua/proxmox-wyze-bridge/issues)
- **Documentación**: [Wiki del proyecto](https://github.com/MondoBoricua/proxmox-wyze-bridge/wiki)
- **Discusiones**: [GitHub Discussions](https://github.com/MondoBoricua/proxmox-wyze-bridge/discussions)

---

**🇵🇷 Desarrollado en Puerto Rico con mucho ☕ café para la comunidad de Proxmox**

_¿Te gusta el proyecto? ¡Dale una ⭐ y compártelo con tus panas!_ 