# 🚀 Wyze Bridge Auto-Installer para Proxmox LXC

**Instalación nativa de Wyze Bridge en contenedores LXC de Proxmox VE**  
*Versión mejorada sin Docker - Usando el instalador de GiZZoR* 🇵🇷

## 📋 Descripción

Este proyecto automatiza la instalación de **Wyze Bridge** en contenedores LXC de Proxmox VE utilizando el instalador nativo de [GiZZoR](https://github.com/GiZZoR/wyze-bridge-installer). 

**Características principales:**
- ✅ **Instalación nativa** (sin Docker)
- ✅ **Proceso en dos pasos** (contenedor + software)
- ✅ **Configuración automática** de firewall y servicios
- ✅ **Instalación completa**: Wyze Bridge + MediaMTX + FFmpeg
- ✅ **Panel de control** avanzado incluido
- ✅ **Compatible** con Proxmox VE 7.x y 8.x

## 🛠️ Opciones de Instalación

### 🎯 Opción 1: Instalación Completa (Recomendada)

**Paso 1 - Crear contenedor:**
```bash
# Ejecutar desde Proxmox VE (como root)
bash <(curl -s https://raw.githubusercontent.com/MondoBoricua/proxmox-wyze-bridge/main/auto-install.sh)
```

**Paso 2 - Instalar Wyze Bridge:**
```bash
# Entrar al contenedor (reemplaza 111 con tu VMID)
pct enter 111

# Instalar Wyze Bridge
bash <(curl -s https://raw.githubusercontent.com/MondoBoricua/proxmox-wyze-bridge/main/install-wyze-only.sh)
```

### 🔧 Opción 2: Solo Wyze Bridge (Contenedor Existente)

Si ya tienes un contenedor LXC:
```bash
# Dentro del contenedor
bash <(curl -s https://raw.githubusercontent.com/MondoBoricua/proxmox-wyze-bridge/main/install-wyze-only.sh)
```

## 📦 ¿Qué se Instala?

### 🏗️ auto-install.sh
- **Crea contenedor LXC** optimizado para Wyze Bridge
- **Configuración:** 2GB RAM, 2 CPU cores, 12GB storage
- **Red:** DHCP con firewall habilitado
- **Características:** nesting=1, unprivileged
- **Opción:** Instalación automática o manual

### 📱 install-wyze-only.sh
- **Wyze Bridge** (versión nativa de GiZZoR)
- **MediaMTX** (servidor RTSP/WebRTC)
- **FFmpeg** (procesamiento de video)
- **Servicios systemd** configurados
- **Firewall** con puertos necesarios
- **Panel de control** completo

## 🔧 Configuración de Puertos

| Puerto | Servicio | Descripción |
|--------|----------|-------------|
| 5000   | Wyze Bridge | Interfaz web principal |
| 8554   | MediaMTX | Servidor RTSP |
| 8888   | MediaMTX | WebRTC streaming |
| 8889   | MediaMTX | HLS streaming |

## 🎮 Herramientas de Gestión

### 📋 Panel de Control Completo
```bash
# Dentro del contenedor
wyze-bridge-menu
```

**Opciones disponibles:**
- Ver estado de servicios
- Iniciar/detener servicios
- Configurar credenciales
- Ver logs en tiempo real
- Instalar/actualizar FFmpeg
- Gestión completa del sistema

### 🔧 Comando Simple
```bash
# Dentro del contenedor
wyze
```

**Comandos disponibles:**
- `wyze start` - Iniciar servicio
- `wyze stop` - Detener servicio
- `wyze restart` - Reiniciar servicio
- `wyze status` - Ver estado
- `wyze logs` - Ver logs
- `wyze install-ffmpeg` - Instalar FFmpeg

## 📝 Configuración Inicial

### 1. Acceder al Contenedor
```bash
# Desde Proxmox VE
pct enter [VMID]
```

### 2. Configurar Credenciales
```bash
# Opción A: Panel completo
wyze-bridge-menu

# Opción B: Editar directamente
nano /etc/wyze-bridge/app.env
```

### 3. Configurar Wyze
Edita `/etc/wyze-bridge/app.env`:
```bash
# Credenciales de Wyze
WYZE_EMAIL=tu_email@ejemplo.com
WYZE_PASSWORD=tu_contraseña

# Configuración de cámaras (opcional)
FILTER_NAMES=Camara1,Camara2

# Configuración de streaming
RTSP_SIMPLE_SERVER=true
```

### 4. Reiniciar Servicio
```bash
systemctl restart wyze-bridge
```

## 🌐 Acceso a la Interfaz

**Interfaz Web:** `http://[IP_CONTENEDOR]:5000`
- Panel de control de Wyze Bridge
- Visualización de cámaras
- Configuración avanzada

**Streaming RTSP:** `rtsp://[IP_CONTENEDOR]:8554/[nombre_camara]`
- Compatible con VLC, OBS, etc.
- Streaming de baja latencia

## 🔍 Resolución de Problemas

### Ver Logs
```bash
# Logs del servicio principal
journalctl -u wyze-bridge -f

# Logs de MediaMTX
journalctl -u mediamtx -f
```

### Verificar Estado
```bash
# Estado de todos los servicios
wyze-bridge-menu

# Estado específico
systemctl status wyze-bridge
systemctl status mediamtx
```

### Reinstalar FFmpeg
```bash
# Si FFmpeg falló durante la instalación
wyze install-ffmpeg

# O desde el panel
wyze-bridge-menu  # Opción 6
```

## 🔧 Requisitos del Sistema

### Proxmox VE
- **Versión:** 7.x o 8.x
- **Privilegios:** Acceso root
- **Conectividad:** Internet para descarga

### Contenedor LXC
- **OS:** Ubuntu 22.04 LTS
- **RAM:** Mínimo 1GB (recomendado 2GB)
- **Storage:** Mínimo 8GB (recomendado 12GB)
- **CPU:** Mínimo 1 core (recomendado 2 cores)

## 📚 Información Adicional

### Basado en Proyectos
- **Wyze Bridge:** [mrlt8/docker-wyze-bridge](https://github.com/mrlt8/docker-wyze-bridge)
- **Instalador Nativo:** [GiZZoR/wyze-bridge-installer](https://github.com/GiZZoR/wyze-bridge-installer)
- **MediaMTX:** [bluenviron/mediamtx](https://github.com/bluenviron/mediamtx)

### Archivos de Configuración
- **Wyze Bridge:** `/etc/wyze-bridge/app.env`
- **MediaMTX:** `/srv/mediamtx/mediamtx.yml`
- **Logs:** `/var/log/wyze-bridge/`
- **Información:** `/root/wyze-bridge-info.txt`

### Servicios Systemd
- **wyze-bridge:** Servicio principal
- **mediamtx:** Servidor de streaming
- **Inicio automático:** Habilitado por defecto

## 🤝 Contribuciones

¡Las contribuciones son bienvenidas! 🇵🇷

1. Fork el repositorio
2. Crea una rama para tu feature
3. Commit tus cambios
4. Push a la rama
5. Abre un Pull Request

## 📄 Licencia

Este proyecto está bajo la Licencia MIT. Ver `LICENSE` para más detalles.

## 🙏 Agradecimientos

- **GiZZoR** por el excelente instalador nativo
- **mrlt8** por el proyecto original docker-wyze-bridge
- **Comunidad Proxmox** por el soporte y feedback

---

**Desarrollado con ❤️ por MondoBoricua** 🇵🇷  
*Para la comunidad de Proxmox y usuarios de Wyze* 