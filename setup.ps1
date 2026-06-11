# ==============================================================================
# Instalador automatizado de entorno de terminal
# ==============================================================================

# 1. Verificación de permisos de Administrador (Necesario para instalar fuentes)
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Por favor, ejecuta PowerShell como Administrador para instalar las fuentes."
    Break
}

# 2. Instalar PowerShell 7 vía winget
Write-Host "Instalando PowerShell 7..." -ForegroundColor Cyan
winget install --id Microsoft.PowerShell --source winget --accept-package-agreements --accept-source-agreements

# 3. Instalar Starship vía winget
Write-Host "Instalando Starship..." -ForegroundColor Cyan
winget install --id Starship.Starship --accept-package-agreements --accept-source-agreements

# 4. Instalar Fuentes Nerd Fonts
Write-Host "Instalando fuentes..." -ForegroundColor Cyan
$fontsFolder = Join-Path $PSScriptRoot "fonts"
if (Test-Path $fontsFolder) {
    $shellApp = New-Object -ComObject Shell.Application
    $systemFontsFolder = $shellApp.Namespace(0x14) # 0x14 es la carpeta de fuentes de Windows
    
    Get-ChildItem -Path $fontsFolder -Filter "*.ttf" | ForEach-Object {
        Write-Host " Instalando: $($_.Name)"
        $systemFontsFolder.CopyHere($_.FullName, 0x10) # 0x10 evita el prompt de "Yes to all"
    }
} else {
    Write-Warning "No se encontró la carpeta de fuentes."
}

# 5. Configurar Starship (.toml)
Write-Host "Configurando Starship..." -ForegroundColor Cyan
$configDir = "$env:USERPROFILE\.config"
if (-not (Test-Path $configDir)) { 
    New-Item -ItemType Directory -Path $configDir -Force | Out-Null
}
$tomlSource = Join-Path $PSScriptRoot "config\starship.toml"
if (Test-Path $tomlSource) {
    Copy-Item -Path $tomlSource -Destination "$configDir\starship.toml" -Force
    Write-Host " starship.toml copiado exitosamente."
}

# 6. Inyectar Starship en el perfil de PowerShell 7
$ps7ProfileDir = "$env:USERPROFILE\Documents\PowerShell"
$ps7Profile = "$ps7ProfileDir\Microsoft.PowerShell_profile.ps1"

if (-not (Test-Path $ps7ProfileDir)) { New-Item -ItemType Directory -Path $ps7ProfileDir -Force | Out-Null }
if (-not (Test-Path $ps7Profile)) { New-Item -ItemType File -Path $ps7Profile -Force | Out-Null }

$initString = 'Invoke-Expression (&starship init powershell)'
$profileContent = Get-Content $ps7Profile -Raw -ErrorAction SilentlyContinue
if ($profileContent -notmatch [regex]::Escape($initString)) {
    Add-Content -Path $ps7Profile -Value "`n$initString"
    Write-Host " Starship añadido al perfil de PowerShell 7."
}

# 7. Modificar settings.json de Windows Terminal para agregar Y activar el tema
Write-Host "Inyectando y activando tema One Dark Pro en Windows Terminal..." -ForegroundColor Cyan
$wtSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

if (Test-Path $wtSettingsPath) {
    # Leer el JSON de la terminal
    $wtSettings = Get-Content $wtSettingsPath | ConvertFrom-Json -Depth 10

    # Leer tema desde el repo (o puedes incrustar el JSON directamente en el script si prefieres)
    $themeSource = Join-Path $PSScriptRoot "theme\One-Dark-Pro.json"
    $newTheme = Get-Content $themeSource | ConvertFrom-Json

    # 7.1 Agregar a la lista de esquemas (equivalente a pegar en "schemes")
    $themeExists = $false
    foreach ($scheme in $wtSettings.schemes) {
        if ($scheme.name -eq $newTheme.name) {
            $themeExists = $true
            break
        }
    }

    if (-not $themeExists) {
        $wtSettings.schemes += $newTheme
        Write-Host " Esquema One Dark Pro añadido al archivo."
    } else {
        Write-Host " El esquema ya existía en la configuración."
    }

   # 7.2 Activar configuraciones modulares desde terminal-defaults.json
    $defaultsSource = Join-Path $PSScriptRoot "theme\terminal-defaults.json"
    
    if (Test-Path $defaultsSource) {
        $repoDefaults = Get-Content $defaultsSource | ConvertFrom-Json
        
        # Asegurar que el objeto 'defaults' exista en el archivo local
        if ($null -eq $wtSettings.profiles.defaults) {
            $wtSettings.profiles | Add-Member -NotePropertyName defaults -NotePropertyValue (New-Object PSObject)
        }

        # Iterar dinámicamente sobre cada propiedad del JSON modular e inyectarla
        $repoDefaults.psobject.properties | ForEach-Object {
            $propName = $_.Name
            $propValue = $_.Value
            
            # Si la propiedad ya existe, se actualiza. Si no, se crea.
            if ($null -ne $wtSettings.profiles.defaults.$propName) {
                $wtSettings.profiles.defaults.$propName = $propValue
            } else {
                $wtSettings.profiles.defaults | Add-Member -NotePropertyName $propName -NotePropertyValue $propValue -Force
            }
        }
        Write-Host " Configuraciones por defecto modulares aplicadas exitosamente."
    } else {
        Write-Warning " No se encontró el archivo terminal-defaults.json en el repositorio."
    }

    # Guardar todo de vuelta al archivo settings.json original
    $wtSettings | ConvertTo-Json -Depth 10 | Set-Content $wtSettingsPath
    Write-Host " Archivo settings.json de Windows Terminal actualizado."
}
Write-Host "¡Automatización completada! Reinicia tu terminal para ver los cambios." -ForegroundColor Green