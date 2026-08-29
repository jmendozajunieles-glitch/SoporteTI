```powershell
# ============================================================
# SOPORTETI - MANTENIMIENTO TI V1
# Mantenimiento preventivo de Windows
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

$Problemas = @()
$Advertencias = @()
$Acciones = @()

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

function Pausa {
    Write-Host ""
    Read-Host "Presiona ENTER para continuar"
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
    Write-Host "ERROR: SE REQUIEREN PRIVILEGIOS DE ADMINISTRADOR" -ForegroundColor Red
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
Escribir "                 SOPORTETI - MANTENIMIENTO V1"
Escribir "============================================================"
Escribir "Tecnico/Usuario : $Usuario"
Escribir "Equipo          : $Equipo"
Escribir "Fecha           : $Fecha"
Escribir "============================================================"
Escribir ""

# ============================================================
# INFORMACION DEL DISCO
# ============================================================

Escribir "================ ESTADO DEL DISCO ==========================="

$DiscoAntes = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"

if ($DiscoAntes) {

    $LibreAntes = [math]::Round(
        $DiscoAntes.FreeSpace / 1GB,
        2
    )

    $TotalAntes = [math]::Round(
        $DiscoAntes.Size / 1GB,
        2
    )

    Escribir "Unidad C:"
    Escribir "Capacidad : $TotalAntes GB"
    Escribir "Libre     : $LibreAntes GB"
}

# ============================================================
# CONFIRMACION
# ============================================================

Separador

Escribir "                    MANTENIMIENTO"
Escribir "============================================================"
Escribir ""
Escribir "Este proceso realizara tareas de mantenimiento preventivo."
Escribir ""
Escribir "Se realizaran:"
Escribir "- Limpieza de archivos temporales"
Escribir "- Limpieza de archivos temporales de Windows"
Escribir "- Limpieza de papelera"
Escribir "- Comprobacion de componentes de Windows"
Escribir "- Reparacion de componentes si es necesario"
Escribir "- Comprobacion de archivos del sistema"
Escribir "- Optimizacion de la unidad C:"
Escribir ""
Escribir "El proceso puede tardar varios minutos."
Escribir "No apagues el equipo durante el mantenimiento."
Escribir ""

$Confirmacion = Read-Host "Deseas iniciar el mantenimiento? (S/N)"

if ($Confirmacion -notmatch "^[Ss]$") {

    Escribir ""
    Escribir "Mantenimiento cancelado por el usuario."
    Escribir "Informe: $Informe"

    Read-Host "Presiona ENTER para salir"
    exit
}

# ============================================================
# LIMPIEZA TEMPORAL DEL USUARIO
# ============================================================

Separador

Escribir "================ LIMPIEZA TEMPORAL =========================="

$TempUsuario = $env:TEMP

Escribir "Limpiando archivos temporales del usuario..."
Escribir "Ubicacion: $TempUsuario"

try {

    Get-ChildItem `
        -Path $TempUsuario `
        -Force `
        -ErrorAction SilentlyContinue |
        Remove-Item `
        -Recurse `
        -Force `
        -ErrorAction SilentlyContinue

    Escribir "Limpieza temporal del usuario completada."
    $Acciones += "Limpieza de temporales del usuario"

}
catch {

    Escribir "Se encontraron archivos que no pudieron eliminarse."
    $Advertencias += "Algunos archivos temporales estaban en uso."
}

# ============================================================
# TEMPORAL DE WINDOWS
# ============================================================

Escribir ""
Escribir "Limpiando temporales de Windows..."

$TempWindows = "C:\Windows\Temp"

try {

    Get-ChildItem `
        -Path $TempWindows `
        -Force `
        -ErrorAction SilentlyContinue |
        Remove-Item `
        -Recurse `
        -Force `
        -ErrorAction SilentlyContinue

    Escribir "Limpieza de temporales de Windows completada."
    $Acciones += "Limpieza de temporales de Windows"

}
catch {

    Escribir "Algunos archivos de Windows estaban en uso."
    $Advertencias += "Algunos temporales de Windows no pudieron eliminarse."
}

# ============================================================
# PAPELERA
# ============================================================

Separador

Escribir "================ PAPELERA ==================================="

Escribir "Vaciando papelera..."

try {

    Clear-RecycleBin `
        -DriveLetter C `
        -Force `
        -ErrorAction SilentlyContinue

    Escribir "Papelera vaciada correctamente."
    $Acciones += "Limpieza de papelera"

}
catch {

    Escribir "No fue posible vaciar completamente la papelera."
    $Advertencias += "La papelera no pudo limpiarse completamente."
}

# ============================================================
# DISM
# ============================================================

Separador

Escribir "================ DISM ======================================="

Escribir "Comprobando componentes de Windows..."
Escribir ""
Escribir "Ejecutando DISM /Online /Cleanup-Image /RestoreHealth"
Escribir ""
Escribir "Este proceso puede tardar varios minutos."
Escribir ""

$DISM = Start-Process `
    -FilePath "DISM.exe" `
    -ArgumentList "/Online","/Cleanup-Image","/RestoreHealth" `
    -Wait `
    -PassThru `
    -NoNewWindow

if ($DISM.ExitCode -eq 0) {

    Escribir ""
    Escribir "DISM finalizado correctamente."
    $Acciones += "Comprobacion y reparacion DISM"

}
else {

    Escribir ""
    Escribir "DISM finalizo con codigo: $($DISM.ExitCode)"
    $Advertencias += "DISM finalizo con codigo $($DISM.ExitCode)"
}

# ============================================================
# SFC
# ============================================================

Separador

Escribir "================ SFC ========================================"

Escribir "Comprobando archivos protegidos de Windows..."
Escribir ""
Escribir "Ejecutando SFC /SCANNOW"
Escribir ""
Escribir "Este proceso puede tardar varios minutos."
Escribir ""

$SFC = Start-Process `
    -FilePath "sfc.exe" `
    -ArgumentList "/scannow" `
    -Wait `
    -PassThru `
    -NoNewWindow

if ($SFC.ExitCode -eq 0) {

    Escribir ""
    Escribir "SFC finalizado correctamente."
    $Acciones += "Comprobacion SFC"

}
else {

    Escribir ""
    Escribir "SFC finalizo con codigo: $($SFC.ExitCode)"
    $Advertencias += "SFC finalizo con codigo $($SFC.ExitCode)"
}

# ============================================================
# COMPROBACION DEL SISTEMA DE ARCHIVOS
# ============================================================

Separador

Escribir "================ SISTEMA DE ARCHIVOS ========================"

Escribir "Comprobando unidad C:"

$CHKDSK = Start-Process `
    -FilePath "chkdsk.exe" `
    -ArgumentList "C:","/scan" `
    -Wait `
    -PassThru `
    -NoNewWindow

if ($CHKDSK.ExitCode -eq 0) {

    Escribir ""
    Escribir "CHKDSK finalizado correctamente."
    $Acciones += "Comprobacion CHKDSK"

}
else {

    Escribir ""
    Escribir "CHKDSK finalizo con codigo: $($CHKDSK.ExitCode)"
    $Advertencias += "CHKDSK finalizo con codigo $($CHKDSK.ExitCode)"
}

# ============================================================
# OPTIMIZACION DE DISCO
# ============================================================

Separador

Escribir "================ OPTIMIZACION ==============================="

Escribir "Analizando unidad C:..."
Escribir ""

$Optimize = Start-Process `
    -FilePath "defrag.exe" `
    -ArgumentList "C:","/O","/U","/V" `
    -Wait `
    -PassThru `
    -NoNewWindow

if ($Optimize.ExitCode -eq 0) {

    Escribir ""
    Escribir "Optimizacion finalizada correctamente."
    $Acciones += "Optimizacion de unidad C:"

}
else {

    Escribir ""
    Escribir "La optimizacion finalizo con codigo: $($Optimize.ExitCode)"
    $Advertencias += "La optimizacion de C: devolvio codigo $($Optimize.ExitCode)"
}

# ============================================================
# WINDOWS UPDATE - ESTADO
# ============================================================

Separador

Escribir "================ WINDOWS UPDATE ============================="

$WU = Get-Service -Name wuauserv

if ($WU) {

    Escribir "Servicio Windows Update: $($WU.Status)"

    if ($WU.Status -ne "Running") {

        Escribir "Windows Update no esta ejecutandose."
        $Advertencias += "El servicio Windows Update no esta activo."
    }
    else {

        Escribir "Windows Update: ACTIVO"
    }
}

# ============================================================
# DISCO DESPUES DEL MANTENIMIENTO
# ============================================================

Separador

Escribir "================ RESULTADO DEL DISCO ========================"

$DiscoDespues = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"

if ($DiscoDespues) {

    $LibreDespues = [math]::Round(
        $DiscoDespues.FreeSpace / 1GB,
        2
    )

    $TotalDespues = [math]::Round(
        $DiscoDespues.Size / 1GB,
        2
    )

    $Diferencia = [math]::Round(
        $LibreDespues - $LibreAntes,
        2
    )

    Escribir "Capacidad : $TotalDespues GB"
    Escribir "Libre ANTES     : $LibreAntes GB"
    Escribir "Libre DESPUES   : $LibreDespues GB"
    Escribir "Espacio liberado: $Diferencia GB"

    if ($Diferencia -gt 0) {

        $Acciones += "Se liberaron aproximadamente $Diferencia GB"
    }
}

# ============================================================
# RESUMEN
# ============================================================

Separador

Escribir "                    RESUMEN"
Escribir "============================================================"

Escribir ""
Escribir "ACCIONES REALIZADAS: $($Acciones.Count)"

foreach ($Accion in $Acciones) {

    Escribir "[OK] $Accion"
}

Escribir ""

if ($Advertencias.Count -gt 0) {

    Escribir "ADVERTENCIAS: $($Advertencias.Count)"
    Escribir ""

    foreach ($Advertencia in $Advertencias) {

        Escribir "[ADVERTENCIA] $Advertencia"
    }

}
else {

    Escribir "ADVERTENCIAS: 0"
}

Escribir ""

if ($Problemas.Count -gt 0) {

    Escribir "PROBLEMAS: $($Problemas.Count)"

    foreach ($Problema in $Problemas) {

        Escribir "[PROBLEMA] $Problema"
    }

}
else {

    Escribir "PROBLEMAS: 0"
}

Escribir ""

if ($Advertencias.Count -eq 0 -and $Problemas.Count -eq 0) {

    Escribir "ESTADO GENERAL: MANTENIMIENTO COMPLETADO"

}
else {

    Escribir "ESTADO GENERAL: COMPLETADO CON OBSERVACIONES"
}

Separador

Escribir "Informe guardado en:"
Escribir $Informe

# ============================================================
# PANTALLA FINAL
# ============================================================

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "          SOPORTETI - MANTENIMIENTO FINALIZADO" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

if ($Advertencias.Count -eq 0 -and $Problemas.Count -eq 0) {

    Write-Host "MANTENIMIENTO COMPLETADO CORRECTAMENTE" -ForegroundColor Green

}
else {

    Write-Host "MANTENIMIENTO COMPLETADO CON OBSERVACIONES" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Informe:" -ForegroundColor Green
Write-Host $Informe -ForegroundColor Yellow
Write-Host ""

Read-Host "Presiona ENTER para salir"
```
