# 🚀 Wyze Bridge Auto-Installer para Proxmox LXC

**Instalación nativa de Wyze Bridge en contenedores LXC de Proxmox VE**  
*Versión mejorada sin Docker - Usando el instalador de GiZZoR* 🇵🇷

## ⚡ Instalación Rápida (Recomendada - 100% Funcional)

```bash
# Ejecutar desde Proxmox VE (como root)
bash <(curl -s https://raw.githubusercontent.com/MondoBoricua/proxmox-wyze-bridge/main/auto-install.sh)

# Reemplaza 109 con tu VMID
pct enter 109

# Instalar Wyze Bridge
bash <(curl -s https://raw.githubusercontent.com/MondoBoricua/proxmox-wyze-bridge/main/install-wyze-only.sh)

# Configurar PATH
export PATH=/usr/local/bin:$PATH
```

**¡Listo!** Tu Wyze Bridge estará funcionando en minutos. 🎯

---

## 📋 Descripción

Este proyecto automatiza la instalación de **Wyze Bridge** en contenedores LXC de Proxmox VE utilizando un instalador nativo integrado basado en el excelente trabajo de [GiZZoR](https://github.com/GiZZoR/wyze-bridge-installer). 

**Características principales:**
- ✅ **Instalación nativa** (sin Docker)
- ✅ **Proceso en dos pasos** (contenedor + software)
- ✅ **Configuración automática** de firewall y servicios
- ✅ **Instalación completa**: Wyze Bridge + MediaMTX + FFmpeg
- ✅ **Panel de control** avanzado incluido
- ✅ **Compatible** con Proxmox VE 7.x y 8.x

## 🛠️ Opciones de Instalación

### 🎯 Instalación Completa (Proceso Manual)

**Paso 1 - Crear contenedor:**
```bash
# Ejecutar desde Proxmox VE (como root)
bash <(curl -s https://raw.githubusercontent.com/MondoBoricua/proxmox-wyze-bridge/main/auto-install.sh)
```

**Paso 2 - Entrar al contenedor:**
```bash
# Reemplaza 111 con tu VMID
pct enter 111
```

**Paso 3 - Instalar curl (Opcional):**
```bash
apt update && apt install -y curl
```

**Paso 4 - Instalar Wyze Bridge:**
```bash
bash <(curl -s https://raw.githubusercontent.com/MondoBoricua/proxmox-wyze-bridge/main/install-wyze-only.sh)
```

**Paso 5 - Configurar PATH (si es necesario):**
```bash
export PATH=/usr/local/bin:$PATH
```

**Paso 6 - Gestionar servicios:**
```bash
/usr/local/bin/wyze start
/usr/local/bin/wyze status
/usr/local/bin/wyze config
```

### 🔧 Solo Wyze Bridge (Contenedor Existente)

Si ya tienes un contenedor LXC, sigue estos pasos dentro del contenedor:

```bash
# 1. Instalar curl
apt update && apt install -y curl

# 2. Instalar Wyze Bridge
bash <(curl -s https://raw.githubusercontent.com/MondoBoricua/proxmox-wyze-bridge/main/install-wyze-only.sh)

# 3. Configurar PATH (si es necesario)
export PATH=/usr/local/bin:$PATH

# 4. Gestionar servicios
/usr/local/bin/wyze start
```

## 📦 ¿Qué se Instala?

### 🏗️ auto-install.sh
- **Crea contenedor LXC** optimizado para Wyze Bridge
- **Configuración:** 2GB RAM, 2 CPU cores, 12GB storage
- **Red:** DHCP con firewall habilitado
- **Características:** nesting=1, unprivileged
- **Opción:** Instalación automática o manual

### 📱 install-wyze-only.sh
- **Wyze Bridge** (instalador nativo integrado)
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
# Dentro del contenedor (usa ruta completa si PATH no funciona)
/usr/local/bin/wyze
```

**Comandos disponibles:**
- `/usr/local/bin/wyze start` - Iniciar servicio
- `/usr/local/bin/wyze stop` - Detener servicio
- `/usr/local/bin/wyze restart` - Reiniciar servicio
- `/usr/local/bin/wyze status` - Ver estado
- `/usr/local/bin/wyze logs` - Ver logs
- `/usr/local/bin/wyze config` - Configurar credenciales
- `/usr/local/bin/wyze install-ffmpeg` - Instalar FFmpeg

## 📝 Configuración Inicial

### 1. Acceder al Contenedor
```bash
# Desde Proxmox VE
pct enter [VMID]
```

### 2. Configurar Credenciales
```bash
# Opción A: Comando simple (usa ruta completa si PATH no funciona)
/usr/local/bin/wyze config

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
# Estado con comando simple
/usr/local/bin/wyze status

# Estado específico
systemctl status wyze-bridge
systemctl status mediamtx
```

### Reinstalar FFmpeg
```bash
# Si FFmpeg falló durante la instalación
/usr/local/bin/wyze install-ffmpeg

# O manualmente
apt update && apt install -y ffmpeg
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
- **Instalador Nativo:** [GiZZoR/wyze-bridge-installer](https://github.com/GiZZoR/wyze-bridge-installer) (integrado)
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