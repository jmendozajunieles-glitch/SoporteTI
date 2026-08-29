```powershell
# ============================================================
# SOPORTETI - ACTUALIZAR DRIVERS V1
# Actualizacion de controladores mediante Microsoft Update
# ============================================================

$ErrorActionPreference = "SilentlyContinue"

Clear-Host

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "             SOPORTETI - ACTUALIZAR DRIVERS" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# COMPROBAR ADMINISTRADOR
# ============================================================

$Principal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent()
)

$Administrador = $Principal.IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)

if (-not $Administrador) {

    Write-Host "ERROR: Este script debe ejecutarse como Administrador." -ForegroundColor Red
    Write-Host ""
    Write-Host "Abre PowerShell como Administrador y vuelve a ejecutar el comando." -ForegroundColor Yellow
    Read-Host "Presiona ENTER para salir"
    exit
}

Write-Host "OK - PowerShell ejecutado como Administrador." -ForegroundColor Green
Write-Host ""

# ============================================================
# INFORMACION DEL EQUIPO
# ============================================================

$Equipo = Get-CimInstance Win32_ComputerSystem
$Modelo = $Equipo.Model
$Fabricante = $Equipo.Manufacturer

Write-Host "Equipo     : $Fabricante $Modelo" -ForegroundColor White
Write-Host "Usuario    : $env:USERNAME" -ForegroundColor White
Write-Host "Fecha      : $(Get-Date)" -ForegroundColor White
Write-Host ""

# ============================================================
# CREAR CARPETA DE SOPORTE
# ============================================================

$Base = "C:\SoporteTI"
$Logs = "$Base\Logs"

New-Item -ItemType Directory -Path $Logs -Force | Out-Null

$FechaArchivo = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$Informe = "$Logs\Drivers_$FechaArchivo.txt"

# ============================================================
# FUNCION PARA ESCRIBIR EN PANTALLA Y LOG
# ============================================================

function Escribir {
    param([string]$Texto)

    Write-Host $Texto
    $Texto | Out-File -FilePath $Informe -Append -Encoding UTF8
}

Escribir "============================================================"
Escribir "             SOPORTETI - ACTUALIZACION DE DRIVERS"
Escribir "============================================================"
Escribir "Equipo : $Fabricante $Modelo"
Escribir "Usuario: $env:USERNAME"
Escribir "Fecha  : $(Get-Date)"
Escribir ""

# ============================================================
# COMPROBAR SERVICIO WINDOWS UPDATE
# ============================================================

Escribir "================ WINDOWS UPDATE ============================="

$ServicioWU = Get-Service -Name wuauserv

if ($ServicioWU.Status -ne "Running") {

    Escribir "Windows Update no esta ejecutandose."
    Escribir "Intentando iniciar el servicio..."

    Start-Service -Name wuauserv

    Start-Sleep -Seconds 3

    $ServicioWU = Get-Service -Name wuauserv
}

if ($ServicioWU.Status -eq "Running") {

    Escribir "Windows Update: ACTIVO"

}
else {

    Escribir "ERROR: No fue posible iniciar Windows Update."
    Escribir ""
    Escribir "El proceso no puede continuar."
    Escribir "Informe: $Informe"

    Read-Host "Presiona ENTER para salir"
    exit
}

Escribir ""

# ============================================================
# INSTALAR MODULO PSWINDOWSUPDATE
# ============================================================

Escribir "================ MICROSOFT UPDATE ==========================="

$Modulo = Get-Module -ListAvailable -Name PSWindowsUpdate

if (-not $Modulo) {

    Escribir "Modulo PSWindowsUpdate no encontrado."
    Escribir "Instalando modulo..."

    try {

        Install-PackageProvider `
            -Name NuGet `
            -MinimumVersion 2.8.5.201 `
            -Force

        Set-PSRepository `
            -Name PSGallery `
            -InstallationPolicy Trusted

        Install-Module `
            -Name PSWindowsUpdate `
            -Force `
            -AllowClobber

        Escribir "Modulo instalado correctamente."

    }
    catch {

        Escribir "ERROR: No fue posible instalar PSWindowsUpdate."
        Escribir "Detalle: $($_.Exception.Message)"

        Read-Host "Presiona ENTER para salir"
        exit
    }

}
else {

    Escribir "Modulo PSWindowsUpdate: INSTALADO"
}

Import-Module PSWindowsUpdate -Force

Escribir ""

# ============================================================
# BUSCAR ACTUALIZACIONES
# ============================================================

Escribir "================ BUSCANDO ACTUALIZACIONES ==================="

Escribir "Buscando actualizaciones disponibles..."
Escribir "Esto puede tardar varios minutos."
Escribir ""

try {

    $Actualizaciones = Get-WindowsUpdate `
        -MicrosoftUpdate `
        -Category "Drivers" `
        -IgnoreReboot

}
catch {

    Escribir "No fue posible consultar la categoria de drivers."
    Escribir "Intentando consulta general de Microsoft Update..."

    $Actualizaciones = Get-WindowsUpdate `
        -MicrosoftUpdate `
        -IgnoreReboot
}

# ============================================================
# RESULTADO DE BUSQUEDA
# ============================================================

if (-not $Actualizaciones) {

    Escribir ""
    Escribir "============================================================"
    Escribir "NO SE ENCONTRARON ACTUALIZACIONES PENDIENTES."
    Escribir "============================================================"
    Escribir ""
    Escribir "Los controladores disponibles mediante Microsoft Update"
    Escribir "parecen estar actualizados."

}
else {

    Escribir ""
    Escribir "ACTUALIZACIONES ENCONTRADAS:"
    Escribir ""

    foreach ($Update in $Actualizaciones) {

        Escribir "Titulo : $($Update.Title)"
        Escribir "KB     : $($Update.KB)"
        Escribir "Tamano : $($Update.Size)"
        Escribir ""
    }

    # ========================================================
    # INSTALAR ACTUALIZACIONES
    # ========================================================

    Escribir "============================================================"
    Escribir "INICIANDO INSTALACION"
    Escribir "============================================================"
    Escribir ""

    try {

        Install-WindowsUpdate `
            -MicrosoftUpdate `
            -Category "Drivers" `
            -AcceptAll `
            -IgnoreReboot `
            -Verbose

        Escribir ""
        Escribir "Proceso de instalacion finalizado."

    }
    catch {

        Escribir ""
        Escribir "ERROR DURANTE LA INSTALACION."
        Escribir "Detalle: $($_.Exception.Message)"
    }
}

# ============================================================
# COMPROBAR DISPOSITIVOS
# ============================================================

Escribir ""
Escribir "================ COMPROBACION FINAL ========================="

$Errores = Get-PnpDevice |
    Where-Object {
        $_.Status -eq "Error"
    }

if ($Errores) {

    Escribir "ADVERTENCIA: Se encontraron dispositivos con errores."

    foreach ($ErrorDispositivo in $Errores) {

        Escribir "Dispositivo: $($ErrorDispositivo.FriendlyName)"
        Escribir "Estado     : $($ErrorDispositivo.Status)"
        Escribir ""
    }

}
else {

    Escribir "OK - No se encontraron dispositivos con estado ERROR."
}

# ============================================================
# FINAL
# ============================================================

Escribir ""
Escribir "============================================================"
Escribir "             ACTUALIZACION FINALIZADA"
Escribir "============================================================"
Escribir ""
Escribir "Informe guardado en:"
Escribir $Informe
Escribir ""

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "          SOPORTETI - DRIVERS FINALIZADO" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Informe:" -ForegroundColor Green
Write-Host $Informe -ForegroundColor Yellow
Write-Host ""

Read-Host "Presiona ENTER para salir"
```
