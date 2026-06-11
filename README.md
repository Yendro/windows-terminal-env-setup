# Windows Terminal Dotfiles

Un script de automatización en PowerShell para configurar desde cero un entorno de terminal moderno en Windows. Este proyecto instala PowerShell 7, el prompt de Starship, fuentes Nerd Font, e inyecta automáticamente el tema **One Dark Pro** junto con configuraciones visuales (Acrylic, opacidad, tamaño de fuente) en Windows Terminal.

## ✨ Características

- **Instalación de paquetes:** Descarga e instala PowerShell 7 y Starship automáticamente usando `winget`.
- **Fuentes automatizadas:** Instala todas las variantes `.ttf` de la fuente CaskaydiaCove Nerd Font Mono directamente en el sistema.
- **Configuración de Starship:** Copia y aplica el archivo `starship.toml` personalizado.
- **Inyección de Perfil:** Añade el comando de inicialización de Starship al perfil nativo de PowerShell 7.
- **Windows Terminal Modular:** Inyecta de forma dinámica el esquema de color (One Dark Pro) y las configuraciones por defecto desde archivos JSON modulares directamente al `settings.json` de Windows Terminal, sin sobrescribir tus perfiles existentes.

## 🛠️ Requisitos Previos

- Windows 10 o Windows 11.

- Windows Terminal instalado.

- `winget` habilitado en el sistema (incluido por defecto en versiones recientes de Windows).

## 💻 Instalación y Uso

- Clona este repositorio o descarga los archivos.

- Abre una ventana de PowerShell como Administrador (requerido para la instalación de las fuentes).

- Navega hasta el directorio del proyecto.

- Ejecuta el script de configuración habilitando temporalmente la ejecución de scripts:

```PowerShell
Set-ExecutionPolicy Bypass -Scope Process -Force; .\setup.ps1
```

Cierra la terminal y vuelve a abrirla para que todos los cambios surtan efecto.
