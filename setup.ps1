# ==============================================================================
# Instalador automatizado de entorno de terminal
# ==============================================================================

# 1. Verificación de permisos de Administrador
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Por favor, ejecuta PowerShell como Administrador para instalar las fuentes."
    Break
}

# 2. Instalar PowerShell 7 vía winget
if (Get-Command pwsh -ErrorAction SilentlyContinue) {
    Write-Host "PowerShell 7 ya está instalado en el sistema." -ForegroundColor Green
} else {
    Write-Host "Instalando PowerShell 7..." -ForegroundColor Cyan
    winget install --id Microsoft.PowerShell --source winget --accept-package-agreements --accept-source-agreements
}

# 3. Instalar Starship y Fastfetch vía winget
if (Get-Command starship -ErrorAction SilentlyContinue) {
    Write-Host "Starship ya está instalado en el sistema." -ForegroundColor Green
} else {
    Write-Host "Instalando Starship..." -ForegroundColor Cyan
    winget install --id Starship.Starship --accept-package-agreements --accept-source-agreements
}

if (Get-Command fastfetch -ErrorAction SilentlyContinue) {
    Write-Host "Fastfetch ya está instalado en el sistema." -ForegroundColor Green
} else {
    Write-Host "Instalando Fastfetch..." -ForegroundColor Cyan
    winget install fastfetch --accept-package-agreements --accept-source-agreements
}

# 4. Instalar Fuentes Nerd Fonts
Write-Host "Validando fuentes del sistema..." -ForegroundColor Cyan
$fontsFolder = Join-Path $PSScriptRoot "fonts"
if (Test-Path $fontsFolder) {
    $shellApp = New-Object -ComObject Shell.Application
    $systemFontsFolder = $shellApp.Namespace(0x14)
    
    Get-ChildItem -Path $fontsFolder -Filter "*.ttf" | ForEach-Object {
        $fontDestPath = Join-Path "$env:windir\Fonts" $_.Name
        if (Test-Path $fontDestPath) {
            Write-Host " La fuente $($_.Name) ya está instalada." -ForegroundColor Green
        } else {
            Write-Host " Instalando: $($_.Name)" -ForegroundColor Yellow
            $systemFontsFolder.CopyHere($_.FullName, 0x10)
        }
    }
} else {
    Write-Warning "No se encontró la carpeta de fuentes en el repositorio."
}

# 5. Configurar Starship (.toml)
Write-Host "Validando configuración de Starship..." -ForegroundColor Cyan
$configDir = "$env:USERPROFILE\.config"
if (-not (Test-Path $configDir)) { 
    New-Item -ItemType Directory -Path $configDir -Force | Out-Null
}

$tomlSource = Join-Path $PSScriptRoot "config\starship.toml"
$tomlDest = Join-Path $configDir "starship.toml"

if (Test-Path $tomlSource) {
    if (Test-Path $tomlDest) {
        Write-Host " starship.toml ya existe. Actualizando con la versión del repositorio..." -ForegroundColor Yellow
    }
    Copy-Item -Path $tomlSource -Destination $tomlDest -Force
    Write-Host " starship.toml configurado exitosamente." -ForegroundColor Green
} else {
    Write-Warning " No se encontró starship.toml en el repositorio."
}

# 5.5 Configurar Fastfetch (.jsonc)
Write-Host "Validando configuración de Fastfetch..." -ForegroundColor Cyan
$ffConfigDir = "$env:USERPROFILE\.config\fastfetch"
if (-not (Test-Path $ffConfigDir)) { 
    New-Item -ItemType Directory -Path $ffConfigDir -Force | Out-Null
}

$ffSource = Join-Path $PSScriptRoot "config\fastfetch.jsonc"
$ffDest = Join-Path $ffConfigDir "config.jsonc"

if (Test-Path $ffSource) {
    if (Test-Path $ffDest) {
        Write-Host " config.jsonc (Fastfetch) ya existe. Actualizando..." -ForegroundColor Yellow
    }
    Copy-Item -Path $ffSource -Destination $ffDest -Force
    Write-Host " fastfetch.jsonc configurado exitosamente." -ForegroundColor Green
} else {
    Write-Warning " No se encontró fastfetch.jsonc en el repositorio."
}

# 6. Inyectar Starship en el perfil de PowerShell 7 SIN BOM
Write-Host "Configurando el perfil de PowerShell 7..." -ForegroundColor Cyan

$docsPath = [Environment]::GetFolderPath('MyDocuments')
$ps7ProfileDir = Join-Path $docsPath "PowerShell"
$ps7Profile = Join-Path $ps7ProfileDir "Microsoft.PowerShell_profile.ps1"

if (-not (Test-Path $ps7ProfileDir)) { New-Item -ItemType Directory -Path $ps7ProfileDir -Force | Out-Null }
if (-not (Test-Path $ps7Profile)) { New-Item -ItemType File -Path $ps7Profile -Force | Out-Null }

$initString = 'Invoke-Expression (&starship init powershell)'

# 1. Leer el archivo crudo
$rawContent = Get-Content $ps7Profile -Raw -Encoding UTF8 -ErrorAction SilentlyContinue

# 2. Limpiar la marca BOM de forma totalmente segura (evitando el error $null)
$profileContent = ""
if ($null -ne $rawContent) {
    $profileContent = $rawContent.Replace([string][char]0xFEFF, "")
}

# 3. Evaluar el contenido ya limpio
if ($profileContent -notmatch [regex]::Escape($initString)) {
    # SOLUCIÓN BOM: Usar .NET para escribir UTF-8 puro y evitar el \x1b[0m en VS Code
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    
    # 4. Concatenar asegurando un salto de línea (`r`n) si el archivo ya tenía texto
    $newContent = if ([string]::IsNullOrWhiteSpace($profileContent)) { $initString } else { $profileContent + "`r`n" + $initString }
    
    [System.IO.File]::WriteAllText($ps7Profile, $newContent, $utf8NoBom)
    Write-Host " Starship añadido al perfil de PowerShell 7." -ForegroundColor Green
} else {
    Write-Host " Starship ya estaba inyectado en el perfil de PowerShell 7." -ForegroundColor Green
}

# 7. Modificar settings.json de Windows Terminal
Write-Host "Validando configuración en Windows Terminal..." -ForegroundColor Cyan
$wtSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

if (Test-Path $wtSettingsPath) {
    $wtSettings = Get-Content $wtSettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json

    # 7.1 Inyectar Tema
    $themeSource = Join-Path $PSScriptRoot "theme\One-Dark-Pro.json"
    if (Test-Path $themeSource) {
        $newTheme = Get-Content $themeSource -Raw -Encoding UTF8 | ConvertFrom-Json
        $themeExists = $false
        if ($null -eq $wtSettings.schemes) { $wtSettings | Add-Member -NotePropertyName schemes -NotePropertyValue @() }

        foreach ($scheme in $wtSettings.schemes) {
            if ($scheme.name -eq $newTheme.name) { $themeExists = $true; break }
        }
        if (-not $themeExists) {
            $wtSettings.schemes += $newTheme
            Write-Host " Esquema One Dark Pro inyectado." -ForegroundColor Green
        } else {
            Write-Host " El esquema One Dark Pro ya existía." -ForegroundColor Green
        }
    }

   # 7.2 Activar configuraciones modulares (defaults)
    $defaultsSource = Join-Path $PSScriptRoot "theme\terminal-defaults.json"
    if (Test-Path $defaultsSource) {
        $repoDefaults = Get-Content $defaultsSource -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($null -eq $wtSettings.profiles) { $wtSettings | Add-Member -NotePropertyName profiles -NotePropertyValue (New-Object PSObject) }
        if ($null -eq $wtSettings.profiles.defaults) { $wtSettings.profiles | Add-Member -NotePropertyName defaults -NotePropertyValue (New-Object PSObject) }

        $repoDefaults.psobject.properties | ForEach-Object {
            $propName = $_.Name
            $propValue = $_.Value
            if ($null -ne $wtSettings.profiles.defaults.$propName) {
                $wtSettings.profiles.defaults.$propName = $propValue
            } else {
                $wtSettings.profiles.defaults | Add-Member -NotePropertyName $propName -NotePropertyValue $propValue -Force
            }
        }
        Write-Host " Configuraciones modulares por defecto actualizadas." -ForegroundColor Green
    }

    # 7.3 Inyectar PowerShell 7 a la fuerza y hacerlo el predeterminado
    if ($null -eq $wtSettings.profiles.list) { $wtSettings.profiles | Add-Member -NotePropertyName list -NotePropertyValue @() }
    
    $ps7Exists = $false
    foreach ($p in $wtSettings.profiles.list) {
        if ($p.source -eq "Windows.Terminal.PowershellCore" -or $p.name -eq "PowerShell 7") { $ps7Exists = $true; break }
    }

    $ps7Guid = "{574e775e-4f2a-5b96-ac1e-a2962a402336}"
    if (-not $ps7Exists) {
        $ps7Obj = ConvertFrom-Json "{ `"guid`": `"$ps7Guid`", `"hidden`": false, `"name`": `"PowerShell 7`", `"source`": `"Windows.Terminal.PowershellCore`" }"
        $wtSettings.profiles.list += $ps7Obj
        Write-Host " Perfil de PowerShell 7 agregado a Windows Terminal." -ForegroundColor Green
    }
    
    # Hacerlo el perfil por defecto
    $wtSettings.defaultProfile = $ps7Guid
    Write-Host " PowerShell 7 configurado como terminal predeterminada." -ForegroundColor Green

    # Guardar todo
    $wtSettings | ConvertTo-Json -Depth 10 | Set-Content $wtSettingsPath -Encoding UTF8
    Write-Host " Archivo settings.json de Windows Terminal guardado exitosamente." -ForegroundColor Green
} else {
    Write-Warning " No se encontró el archivo settings.json de Windows Terminal."
}

Write-Host "`n¡Automatización completada exitosamente! Reinicia tu terminal para ver los cambios." -ForegroundColor Cyan