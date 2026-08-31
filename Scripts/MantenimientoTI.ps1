```powershell
# ============================================================
# SOPORTETI - MANTENIMIENTO TI V3
# Mantenimiento y reparacion inteligente de Windows
# ============================================================

$ErrorActionPreference = "SilentlyContinue"

Clear-Host

# ============================================================
# CONFIGURACION
# ============================================================

$Base = "C:\SoporteTI"
$Logs = "$Base\Logs"

New-Item -ItemType Directory -Path $Logs -Force | Out-Null

$FechaArchivo = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$Fecha = Get-Date -Format "dd/MM/yyyy HH:mm:ss"

$Informe = "$Logs\Mantenimiento_$FechaArchivo.txt"

$Usuario = $env:USERNAME
$Equipo = $env:COMPUTERNAME

$Acciones = @()
$Advertencias = @()
$Problemas = @()

# ============================================================
# FUNCIONES
# ============================================================

function Escribir {
    param([string]$Texto)

    Write-Host $Texto
    $Texto | Out-File -FilePath $Informe -Append -Encoding UTF8
}

function Separador {
    Escribir ""
    Escribir "============================================================"
}

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

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Red
    Write-Host "       ERROR: SE REQUIEREN PRIVILEGIOS DE ADMINISTRADOR" -ForegroundColor Red
    Write-Host "============================================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Abre PowerShell como Administrador y vuelve a ejecutar." -ForegroundColor Yellow
    Write-Host ""

    Read-Host "Presiona ENTER para salir"
    exit
}

# ============================================================
# INICIO
# ============================================================

Escribir "============================================================"
Escribir "              SOPORTETI - MANTENIMIENTO V3"
Escribir "============================================================"
Escribir "Equipo          : $Equipo"
Escribir "Usuario         : $Usuario"
Escribir "Fecha           : $Fecha"
Escribir "============================================================"
Escribir ""

# ============================================================
# ESTADO INICIAL DEL DISCO
# ============================================================

Escribir "================ ESTADO INICIAL ============================="

$DiscoAntes = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"

$LibreAntes = 0

if ($DiscoAntes) {

    $LibreAntes = [math]::Round(
        $DiscoAntes.FreeSpace / 1GB,
        2
    )

    $TotalAntes = [math]::Round(
        $DiscoAntes.Size / 1GB,
        2
    )

    $PorcentajeAntes = [math]::Round(
        ($DiscoAntes.FreeSpace / $DiscoAntes.Size) * 100,
        1
    )

    Escribir "Unidad        : C:"
    Escribir "Capacidad     : $TotalAntes GB"
    Escribir "Libre         : $LibreAntes GB"
    Escribir "Espacio libre : $PorcentajeAntes%"
}

# ============================================================
# CONFIRMACION
# ============================================================

Separador

Escribir "                 MANTENIMIENTO TI V3"
Escribir "============================================================"
Escribir ""
Escribir "Este proceso realizara mantenimiento y reparacion."
Escribir ""
Escribir "El proceso inteligente de DISM funcionara asi:"
Escribir ""
Escribir "  1. CheckHealth  - comprobacion rapida"
Escribir "  2. ScanHealth   - analisis profundo"
Escribir "  3. RestoreHealth- SOLO si se detecta corrupcion"
Escribir ""
Escribir "Tambien se ejecutaran:"
Escribir "  - Limpieza de temporales"
Escribir "  - Papelera"
Escribir "  - Cache DNS"
Escribir "  - SFC"
Escribir "  - CHKDSK"
Escribir "  - Optimizacion de unidad"
Escribir ""
Escribir "IMPORTANTE:"
Escribir "DISM /RestoreHealth puede tardar bastante."
Escribir "NO apagues el equipo durante una reparacion."
Escribir ""

$Confirmacion = Read-Host "Deseas iniciar el mantenimiento? (S/N)"

if ($Confirmacion -notmatch "^[Ss]$") {

    Escribir ""
    Escribir "Mantenimiento CANCELADO por el usuario."
    Escribir ""
    Escribir "Informe: $Informe"

    Read-Host "Presiona ENTER para salir"
    exit
}

# ============================================================
# TEMPORALES USUARIO
# ============================================================

Separador

Escribir "================ TEMPORALES DEL USUARIO ====================="

$TempUsuario = $env:TEMP

Escribir "Limpiando: $TempUsuario"

try {

    Get-ChildItem `
        -Path $TempUsuario `
        -Force `
        -ErrorAction SilentlyContinue |
        Remove-Item `
        -Recurse `
        -Force `
        -ErrorAction SilentlyContinue

    Escribir "Limpieza completada."

    $Acciones += "Temporales del usuario"

}
catch {

    Escribir "Algunos archivos no pudieron eliminarse."
    $Advertencias += "Temporales del usuario en uso."
}

# ============================================================
# TEMPORALES WINDOWS
# ============================================================

Separador

Escribir "================ TEMPORALES WINDOWS ========================="

$TempWindows = "C:\Windows\Temp"

Escribir "Limpiando: $TempWindows"

try {

    Get-ChildItem `
        -Path $TempWindows `
        -Force `
        -ErrorAction SilentlyContinue |
        Remove-Item `
        -Recurse `
        -Force `
        -ErrorAction SilentlyContinue

    Escribir "Limpieza completada."

    $Acciones += "Temporales de Windows"

}
catch {

    Escribir "Algunos archivos estaban en uso."
    $Advertencias += "Temporales de Windows en uso."
}

# ============================================================
# PAPELERA
# ============================================================

Separador

Escribir "================ PAPELERA ==================================="

try {

    Clear-RecycleBin `
        -DriveLetter C `
        -Force `
        -ErrorAction SilentlyContinue

    Escribir "Papelera procesada correctamente."

    $Acciones += "Limpieza de papelera"

}
catch {

    Escribir "No fue posible limpiar completamente la papelera."
    $Advertencias += "Papelera no limpiada completamente."
}

# ============================================================
# DNS
# ============================================================

Separador

Escribir "================ CACHE DNS =================================="

ipconfig /flushdns | ForEach-Object {
    Escribir $_
}

$Acciones += "Limpieza de cache DNS"

# ============================================================
# DISM - CHECKHEALTH
# ============================================================

Separador

Escribir "================ DISM - CHECKHEALTH ========================="

Escribir "Ejecutando comprobacion rapida..."
Escribir ""
Escribir "DISM /Online /Cleanup-Image /CheckHealth"
Escribir ""

& DISM.exe /Online /Cleanup-Image /CheckHealth

$CodigoCheck = $LASTEXITCODE

Escribir ""
Escribir "Codigo CheckHealth: $CodigoCheck"

if ($CodigoCheck -ne 0) {

    $Advertencias += "DISM CheckHealth devolvio codigo $CodigoCheck"
}

# ============================================================
# DISM - SCANHEALTH
# ============================================================

Separador

Escribir "================ DISM - SCANHEALTH =========================="

Escribir "Analizando la imagen de Windows..."
Escribir ""
Escribir "DISM /Online /Cleanup-Image /ScanHealth"
Escribir ""
Escribir "Esta comprobacion puede tardar."
Escribir ""

& DISM.exe /Online /Cleanup-Image /ScanHealth

$CodigoScan = $LASTEXITCODE

Escribir ""
Escribir "Codigo ScanHealth: $CodigoScan"

# ============================================================
# DETERMINAR SI HAY CORRUPCION
# ============================================================

$NecesitaRestore = $false

if ($CodigoScan -eq 0) {

    Escribir ""
    Escribir "ScanHealth finalizo correctamente."

}
else {

    Escribir ""
    Escribir "ScanHealth devolvio codigo: $CodigoScan"
    Escribir "Se analizara la necesidad de reparacion."

    $NecesitaRestore = $true

    $Advertencias += "DISM ScanHealth detecto una condicion que requiere revision."
}

# ============================================================
# DISM - RESTOREHEALTH
# ============================================================

if ($NecesitaRestore) {

    Separador

    Escribir "================ DISM - RESTOREHEALTH ======================="

    Escribir "SE DETECTO UNA CONDICION QUE REQUIERE REPARACION."
    Escribir ""
    Escribir "Ejecutando:"
    Escribir "DISM /Online /Cleanup-Image /RestoreHealth"
    Escribir ""
    Escribir "IMPORTANTE:"
    Escribir "El porcentaje puede permanecer quieto durante varios minutos."
    Escribir "NO cierres PowerShell."
    Escribir "NO apagues el equipo."
    Escribir ""

    $InicioDISM = Get-Date

    try {

        & DISM.exe /Online /Cleanup-Image /RestoreHealth

        $CodigoRestore = $LASTEXITCODE

        $FinDISM = Get-Date

        $DuracionDISM = $FinDISM - $InicioDISM

        Escribir ""
        Escribir "Codigo RestoreHealth: $CodigoRestore"
        Escribir "Duracion: $($DuracionDISM.ToString('hh\:mm\:ss'))"

        if ($CodigoRestore -eq 0) {

            Escribir "DISM reparo correctamente la imagen de Windows."

            $Acciones += "DISM: reparacion completada"

        }
        elseif ($CodigoRestore -eq 3010) {

            Escribir "DISM termino correctamente y requiere reinicio."

            $Acciones += "DISM: reparacion completada"

            $Advertencias += "DISM requiere reiniciar el equipo."

        }
        else {

            Escribir "DISM finalizo con codigo $CodigoRestore."

            $Problemas += "DISM RestoreHealth devolvio codigo $CodigoRestore."
        }

    }
    catch {

        Escribir "ERROR ejecutando RestoreHealth."
        Escribir "Detalle: $($_.Exception.Message)"

        $Problemas += "No fue posible ejecutar DISM RestoreHealth."
    }

}
else {

    Separador

    Escribir "================ DISM ======================================="

    Escribir "No se detecto necesidad de ejecutar RestoreHealth."
    Escribir "Se ahorra la reparacion profunda."

    $Acciones += "DISM: no fue necesario reparar"
}

# ============================================================
# SFC
# ============================================================

Separador

Escribir "================ SFC ========================================"

Escribir "Comprobando archivos protegidos de Windows..."
Escribir ""
Escribir "SFC /SCANNOW"
Escribir ""
Escribir "Este proceso puede tardar."
Escribir ""

$InicioSFC = Get-Date

try {

    & sfc.exe /scannow

    $CodigoSFC = $LASTEXITCODE

    $FinSFC = Get-Date

    $DuracionSFC = $FinSFC - $InicioSFC

    Escribir ""
    Escribir "Codigo SFC: $CodigoSFC"
    Escribir "Duracion: $($DuracionSFC.ToString('hh\:mm\:ss'))"

    if ($CodigoSFC -eq 0) {

        Escribir "SFC finalizado correctamente."

        $Acciones += "SFC: comprobacion completada"

    }
    else {

        Escribir "SFC finalizo con codigo $CodigoSFC."

        $Advertencias += "SFC devolvio codigo $CodigoSFC."
    }

}
catch {

    Escribir "ERROR ejecutando SFC."
    $Problemas += "No fue posible ejecutar SFC."
}

# ============================================================
# CHKDSK
# ============================================================

Separador

Escribir "================ CHKDSK ====================================="

Escribir "Comprobando el sistema de archivos..."
Escribir ""
Escribir "CHKDSK C: /SCAN"
Escribir ""

try {

    & chkdsk.exe C: /scan

    $CodigoCHKDSK = $LASTEXITCODE

    Escribir ""
    Escribir "Codigo CHKDSK: $CodigoCHKDSK"

    if ($CodigoCHKDSK -eq 0) {

        Escribir "CHKDSK finalizado correctamente."

        $Acciones += "CHKDSK: comprobacion completada"

    }
    else {

        Escribir "CHKDSK devolvio codigo $CodigoCHKDSK."

        $Advertencias += "CHKDSK devolvio codigo $CodigoCHKDSK."
    }

}
catch {

    Escribir "ERROR ejecutando CHKDSK."
    $Problemas += "No fue posible ejecutar CHKDSK."
}

# ============================================================
# OPTIMIZACION
# ============================================================

Separador

Escribir "================ OPTIMIZACION ==============================="

Escribir "Windows determinara automaticamente la optimizacion adecuada."
Escribir ""
Escribir "Ejecutando:"
Escribir "DEFRAG C: /O /U"
Escribir ""

try {

    & defrag.exe C: /O /U

    $CodigoDefrag = $LASTEXITCODE

    Escribir ""
    Escribir "Codigo optimizacion: $CodigoDefrag"

    if ($CodigoDefrag -eq 0) {

        Escribir "Optimizacion completada."

        $Acciones += "Optimizacion de C:"

    }
    else {

        Escribir "La optimizacion devolvio codigo $CodigoDefrag."

        $Advertencias += "La optimizacion devolvio codigo $CodigoDefrag."
    }

}
catch {

    Escribir "ERROR durante la optimizacion."
    $Problemas += "No fue posible optimizar C:"
}

# ============================================================
# WINDOWS UPDATE
# ============================================================

Separador

Escribir "================ WINDOWS UPDATE ============================="

$WU = Get-Service -Name wuauserv

if ($WU) {

    Escribir "Estado del servicio: $($WU.Status)"

    if ($WU.Status -eq "Running") {

        Escribir "Windows Update: ACTIVO"

    }
    else {

        Escribir "Windows Update: INACTIVO"

        $Advertencias += "Windows Update no esta activo."
    }

}
else {

    Escribir "No fue posible consultar Windows Update."

    $Advertencias += "No fue posible consultar Windows Update."
}

# ============================================================
# DISCO FINAL
# ============================================================

Separador

Escribir "================ RESULTADO DEL DISCO ========================"

$DiscoDespues = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"

if ($DiscoDespues) {

    $LibreDespues = [math]::Round(
        $DiscoDespues.FreeSpace / 1GB,
        2
    )

    $PorcentajeDespues = [math]::Round(
        ($DiscoDespues.FreeSpace / $DiscoDespues.Size) * 100,
        1
    )

    $Liberado = [math]::Round(
        $LibreDespues - $LibreAntes,
        2
    )

    Escribir "Libre antes      : $LibreAntes GB"
    Escribir "Libre despues    : $LibreDespues GB"
    Escribir "Espacio libre    : $PorcentajeDespues%"
    Escribir "Espacio liberado : $Liberado GB"
}

# ============================================================
# RESUMEN FINAL
# ============================================================

Separador

Escribir "                  RESULTADO FINAL"
Escribir "============================================================"
Escribir ""

Escribir "ACCIONES REALIZADAS: $($Acciones.Count)"
Escribir ""

foreach ($Accion in $Acciones) {

    Escribir "[OK] $Accion"
}

Escribir ""

Escribir "ADVERTENCIAS: $($Advertencias.Count)"

foreach ($Advertencia in $Advertencias) {

    Escribir "[ADVERTENCIA] $Advertencia"
}

Escribir ""

Escribir "PROBLEMAS: $($Problemas.Count)"

foreach ($Problema in $Problemas) {

    Escribir "[PROBLEMA] $Problema"
}

Escribir ""

if ($Problemas.Count -gt 0) {

    Escribir "ESTADO GENERAL: REQUIERE ATENCION"

}
elseif ($Advertencias.Count -gt 0) {

    Escribir "ESTADO GENERAL: COMPLETADO CON OBSERVACIONES"

}
else {

    Escribir "ESTADO GENERAL: MANTENIMIENTO COMPLETADO"

}

# ============================================================
# INFORME
# ============================================================

Separador

Escribir "Mantenimiento finalizado."
Escribir ""
Escribir "Informe guardado en:"
Escribir $Informe

# ============================================================
# FINAL
# ============================================================

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "          SOPORTETI - MANTENIMIENTO V3 FINALIZADO" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

if ($Problemas.Count -gt 0) {

    Write-Host "ESTADO: REQUIERE ATENCION" -ForegroundColor Red

}
elseif ($Advertencias.Count -gt 0) {

    Write-Host "ESTADO: COMPLETADO CON OBSERVACIONES" -ForegroundColor Yellow

}
else {

    Write-Host "ESTADO: MANTENIMIENTO COMPLETADO" -ForegroundColor Green
}

Write-Host ""
Write-Host "Acciones realizadas : $($Acciones.Count)"
Write-Host "Advertencias        : $($Advertencias.Count)"
Write-Host "Problemas           : $($Problemas.Count)"
Write-Host ""
Write-Host "Informe:" -ForegroundColor Green
Write-Host $Informe -ForegroundColor Yellow
Write-Host ""

Read-Host "Presiona ENTER para salir"
```
