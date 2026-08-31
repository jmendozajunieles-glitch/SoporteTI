```powershell
# ============================================================
# SOPORTETI - MANTENIMIENTO TI V4
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
$FechaInicio = Get-Date
$Informe = "$Logs\Mantenimiento_$FechaArchivo.txt"

$Equipo = $env:COMPUTERNAME
$Usuario = $env:USERNAME

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

function Ejecutar-Comando {
    param(
        [string]$Nombre,
        [string]$Archivo,
        [string[]]$Argumentos
    )

    Escribir ""
    Escribir "Ejecutando: $Nombre"
    Escribir ""

    $Inicio = Get-Date

    & $Archivo @Argumentos 2>&1 | ForEach-Object {
        Escribir "$_"
    }

    $Codigo = $LASTEXITCODE

    $Fin = Get-Date
    $Duracion = $Fin - $Inicio

    Escribir ""
    Escribir "Codigo de salida : $Codigo"
    Escribir "Duracion         : $($Duracion.ToString('hh\:mm\:ss'))"

    return $Codigo
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
    Write-Host "       SOPORTETI REQUIERE ADMINISTRADOR" -ForegroundColor Red
    Write-Host "============================================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Abre PowerShell como Administrador y vuelve a ejecutar." -ForegroundColor Yellow
    Write-Host ""

    Read-Host "Presiona ENTER para salir"
    exit
}

# ============================================================
# CABECERA
# ============================================================

Escribir "============================================================"
Escribir "             SOPORTETI - MANTENIMIENTO V4"
Escribir "============================================================"
Escribir "Equipo     : $Equipo"
Escribir "Usuario    : $Usuario"
Escribir "Inicio     : $($FechaInicio.ToString('dd/MM/yyyy HH:mm:ss'))"
Escribir "============================================================"

# ============================================================
# INFORMACION DEL SISTEMA
# ============================================================

Separador
Escribir "================ INFORMACION DEL EQUIPO ====================="

$Sistema = Get-CimInstance Win32_ComputerSystem
$OS = Get-CimInstance Win32_OperatingSystem

Escribir "Fabricante : $($Sistema.Manufacturer)"
Escribir "Modelo     : $($Sistema.Model)"
Escribir "Windows    : $($OS.Caption)"
Escribir "Version    : $($OS.Version)"
Escribir "Arquitectura: $($OS.OSArchitecture)"

# ============================================================
# ESTADO DEL DISCO
# ============================================================

Separador
Escribir "================ ESTADO DEL DISCO ==========================="

$DiscoAntes = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"

if ($DiscoAntes) {

    $TotalAntes = [math]::Round($DiscoAntes.Size / 1GB, 2)
    $LibreAntes = [math]::Round($DiscoAntes.FreeSpace / 1GB, 2)

    $PorcentajeAntes = [math]::Round(
        ($DiscoAntes.FreeSpace / $DiscoAntes.Size) * 100,
        1
    )

    Escribir "Capacidad     : $TotalAntes GB"
    Escribir "Libre         : $LibreAntes GB"
    Escribir "Espacio libre : $PorcentajeAntes%"

}
else {

    $LibreAntes = 0
    $Advertencias += "No fue posible consultar la unidad C:"
}

# ============================================================
# CONFIRMACION
# ============================================================

Separador
Escribir "================ INICIO DEL MANTENIMIENTO =================="

Escribir ""
Escribir "Esta herramienta realizara:"
Escribir ""
Escribir " [1] Limpieza de archivos temporales"
Escribir " [2] Limpieza de papelera"
Escribir " [3] Limpieza de cache DNS"
Escribir " [4] Analisis DISM"
Escribir " [5] Reparacion DISM si es necesaria"
Escribir " [6] Comprobacion SFC"
Escribir " [7] Comprobacion CHKDSK"
Escribir " [8] Optimizacion de unidad"
Escribir ""
Escribir "DISM /RestoreHealth NO se ejecutara si no es necesario."
Escribir ""

$Confirmacion = Read-Host "Deseas continuar? (S/N)"

if ($Confirmacion -notmatch "^[Ss]$") {

    Escribir ""
    Escribir "Mantenimiento cancelado por el usuario."
    Escribir "Informe: $Informe"

    Read-Host "Presiona ENTER para salir"
    exit
}

# ============================================================
# LIMPIEZA TEMPORAL USUARIO
# ============================================================

Separador
Escribir "================ TEMPORALES DEL USUARIO ====================="

try {

    $ArchivosTemp = Get-ChildItem `
        -Path $env:TEMP `
        -Force `
        -ErrorAction SilentlyContinue

    $CantidadAntes = $ArchivosTemp.Count

    $ArchivosTemp |
        Remove-Item `
        -Recurse `
        -Force `
        -ErrorAction SilentlyContinue

    Escribir "Archivos temporales procesados: $CantidadAntes"

    $Acciones += "Temporales del usuario"

}
catch {

    Escribir "No fue posible limpiar todos los temporales."
    $Advertencias += "Algunos temporales estaban en uso."
}

# ============================================================
# TEMPORALES WINDOWS
# ============================================================

Separador
Escribir "================ TEMPORALES WINDOWS ========================="

try {

    $ArchivosTempWin = Get-ChildItem `
        -Path "C:\Windows\Temp" `
        -Force `
        -ErrorAction SilentlyContinue

    $CantidadWin = $ArchivosTempWin.Count

    $ArchivosTempWin |
        Remove-Item `
        -Recurse `
        -Force `
        -ErrorAction SilentlyContinue

    Escribir "Archivos temporales procesados: $CantidadWin"

    $Acciones += "Temporales de Windows"

}
catch {

    Escribir "No fue posible limpiar todos los temporales."
    $Advertencias += "Algunos temporales de Windows estaban en uso."
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

    $Acciones += "Papelera"

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

try {

    $DNSResultado = ipconfig /flushdns 2>&1

    foreach ($Linea in $DNSResultado) {
        Escribir $Linea
    }

    $Acciones += "Cache DNS"

}
catch {

    Escribir "No fue posible limpiar la cache DNS."
    $Advertencias += "Cache DNS no limpiada."
}

# ============================================================
# DISM CHECKHEALTH
# ============================================================

Separador
Escribir "================ DISM - CHECKHEALTH ========================="

Escribir "Realizando comprobacion rapida de la imagen de Windows."

$SalidaCheck = @()

$InicioCheck = Get-Date

$SalidaCheck = & DISM.exe /Online /Cleanup-Image /CheckHealth 2>&1

$CodigoCheck = $LASTEXITCODE

$FinCheck = Get-Date
$DuracionCheck = $FinCheck - $InicioCheck

foreach ($Linea in $SalidaCheck) {
    Escribir "$Linea"
}

Escribir ""
Escribir "Codigo : $CodigoCheck"
Escribir "Tiempo : $($DuracionCheck.ToString('hh\:mm\:ss'))"

# ============================================================
# INTERPRETACION CHECKHEALTH
# ============================================================

$TextoCheck = ($SalidaCheck -join " ").ToLower()

$CorrupcionCheck = $false
$ReparableCheck = $false

if ($TextoCheck -match "no component store corruption detected") {

    Escribir ""
    Escribir "[OK] No se detecto corrupcion en la imagen de Windows."

}
elseif ($TextoCheck -match "component store corruption detected") {

    Escribir ""
    Escribir "[ALERTA] DISM detecto corrupcion en la imagen."

    $CorrupcionCheck = $true
}
elseif ($TextoCheck -match "repairable") {

    Escribir ""
    Escribir "[ALERTA] DISM indica que la imagen puede repararse."

    $CorrupcionCheck = $true
    $ReparableCheck = $true
}
else {

    Escribir ""
    Escribir "[INFO] No fue posible interpretar completamente CheckHealth."

    $Advertencias += "DISM CheckHealth no pudo interpretarse completamente."
}

# ============================================================
# DISM SCANHEALTH
# ============================================================

Separador
Escribir "================ DISM - SCANHEALTH =========================="

Escribir "Realizando analisis profundo."
Escribir "Esta etapa puede tardar varios minutos."
Escribir ""

$SalidaScan = @()

$InicioScan = Get-Date

$SalidaScan = & DISM.exe /Online /Cleanup-Image /ScanHealth 2>&1

$CodigoScan = $LASTEXITCODE

$FinScan = Get-Date
$DuracionScan = $FinScan - $InicioScan

foreach ($Linea in $SalidaScan) {
    Escribir "$Linea"
}

Escribir ""
Escribir "Codigo : $CodigoScan"
Escribir "Tiempo : $($DuracionScan.ToString('hh\:mm\:ss'))"

$TextoScan = ($SalidaScan -join " ").ToLower()

$NecesitaRestore = $false

if ($TextoScan -match "no component store corruption detected") {

    Escribir ""
    Escribir "[OK] ScanHealth confirma que no se detecto corrupcion."

}
elseif ($TextoScan -match "component store corruption detected") {

    Escribir ""
    Escribir "[ALERTA] ScanHealth detecto corrupcion."

    $NecesitaRestore = $true

}
elseif ($TextoScan -match "repairable") {

    Escribir ""
    Escribir "[ALERTA] La imagen de Windows puede repararse."

    $NecesitaRestore = $true

}
else {

    Escribir ""
    Escribir "[INFO] No se pudo determinar automaticamente el estado."
    Escribir "Se utilizara el codigo de salida como referencia."

    if ($CodigoScan -ne 0) {
        $NecesitaRestore = $true
    }
}

# ============================================================
# DISM RESTOREHEALTH
# ============================================================

if ($NecesitaRestore) {

    Separador
    Escribir "================ DISM - RESTOREHEALTH ======================="

    Escribir "[REPARACION] Se detecto corrupcion."
    Escribir ""
    Escribir "Iniciando reparacion de la imagen de Windows."
    Escribir ""
    Escribir "IMPORTANTE:"
    Escribir "El porcentaje puede permanecer quieto durante varios minutos."
    Escribir "NO cierres PowerShell."
    Escribir "NO apagues el equipo."
    Escribir ""

    $InicioRestore = Get-Date

    $SalidaRestore = & DISM.exe /Online /Cleanup-Image /RestoreHealth 2>&1

    $CodigoRestore = $LASTEXITCODE

    $FinRestore = Get-Date
    $DuracionRestore = $FinRestore - $InicioRestore

    foreach ($Linea in $SalidaRestore) {
        Escribir "$Linea"
    }

    Escribir ""
    Escribir "Codigo : $CodigoRestore"
    Escribir "Tiempo : $($DuracionRestore.ToString('hh\:mm\:ss'))"

    if ($CodigoRestore -eq 0) {

        Escribir ""
        Escribir "[OK] DISM completo la reparacion correctamente."

        $Acciones += "DISM: imagen reparada"

    }
    elseif ($CodigoRestore -eq 3010) {

        Escribir ""
        Escribir "[OK] DISM termino correctamente."
        Escribir "[AVISO] Se requiere reiniciar Windows."

        $Acciones += "DISM: reparacion completada"

        $Advertencias += "DISM requiere reinicio."

    }
    else {

        Escribir ""
        Escribir "[ERROR] DISM termino con codigo $CodigoRestore."

        $Problemas += "DISM RestoreHealth termino con codigo $CodigoRestore."
    }

}
else {

    Separador
    Escribir "================ DISM - REPARACION ==========================="

    Escribir "[OK] RestoreHealth NO fue necesario."
    Escribir "No se realizara reparacion profunda."

    $Acciones += "DISM: reparacion no necesaria"
}

# ============================================================
# SFC
# ============================================================

Separador
Escribir "================ SFC /SCANNOW ================================"

Escribir "Comprobando archivos protegidos de Windows."
Escribir ""

$InicioSFC = Get-Date

$SalidaSFC = & sfc.exe /scannow 2>&1

$CodigoSFC = $LASTEXITCODE

$FinSFC = Get-Date
$DuracionSFC = $FinSFC - $InicioSFC

foreach ($Linea in $SalidaSFC) {
    Escribir "$Linea"
}

Escribir ""
Escribir "Codigo : $CodigoSFC"
Escribir "Tiempo : $($DuracionSFC.ToString('hh\:mm\:ss'))"

$TextoSFC = ($SalidaSFC -join " ").ToLower()

if ($TextoSFC -match "did not find any integrity violations") {

    Escribir "[OK] No se encontraron violaciones de integridad."
    $Acciones += "SFC: sistema integro"

}
elseif ($TextoSFC -match "found corrupt files and successfully repaired") {

    Escribir "[REPARADO] SFC encontro archivos dañados y los reparo."
    $Acciones += "SFC: archivos reparados"

}
elseif ($TextoSFC -match "found corrupt files but was unable to fix") {

    Escribir "[ADVERTENCIA] SFC encontro archivos dañados que no pudo reparar."

    $Problemas += "SFC encontro archivos que no pudo reparar."

}
else {

    if ($CodigoSFC -ne 0) {

        $Advertencias += "SFC termino con codigo $CodigoSFC."

    }
}

# ============================================================
# CHKDSK
# ============================================================

Separador
Escribir "================ CHKDSK ====================================="

Escribir "Comprobando el sistema de archivos de C:."
Escribir ""

$InicioCHK = Get-Date

$SalidaCHK = & chkdsk.exe C: /scan 2>&1

$CodigoCHK = $LASTEXITCODE

$FinCHK = Get-Date
$DuracionCHK = $FinCHK - $InicioCHK

foreach ($Linea in $SalidaCHK) {
    Escribir "$Linea"
}

Escribir ""
Escribir "Codigo : $CodigoCHK"
Escribir "Tiempo : $($DuracionCHK.ToString('hh\:mm\:ss'))"

if ($CodigoCHK -eq 0) {

    Escribir "[OK] CHKDSK finalizo correctamente."
    $Acciones += "CHKDSK: comprobacion completada"

}
else {

    Escribir "[ADVERTENCIA] CHKDSK devolvio codigo $CodigoCHK."
    $Advertencias += "CHKDSK devolvio codigo $CodigoCHK."
}

# ============================================================
# OPTIMIZACION
# ============================================================

Separador
Escribir "================ OPTIMIZACION ==============================="

Escribir "Windows determinara automaticamente la optimizacion adecuada."
Escribir ""

$InicioDefrag = Get-Date

$SalidaDefrag = & defrag.exe C: /O /U 2>&1

$CodigoDefrag = $LASTEXITCODE

$FinDefrag = Get-Date
$DuracionDefrag = $FinDefrag - $InicioDefrag

foreach ($Linea in $SalidaDefrag) {
    Escribir "$Linea"
}

Escribir ""
Escribir "Codigo : $CodigoDefrag"
Escribir "Tiempo : $($DuracionDefrag.ToString('hh\:mm\:ss'))"

if ($CodigoDefrag -eq 0) {

    Escribir "[OK] Optimizacion completada."
    $Acciones += "Optimizacion de C:"

}
else {

    Escribir "[ADVERTENCIA] La optimizacion devolvio codigo $CodigoDefrag."
    $Advertencias += "Optimizacion devolvio codigo $CodigoDefrag."
}

# ============================================================
# DISCO FINAL
# ============================================================

Separador
Escribir "================ RESULTADO DEL DISCO ========================"

$DiscoDespues = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"

if ($DiscoDespues) {

    $TotalDespues = [math]::Round(
        $DiscoDespues.Size / 1GB,
        2
    )

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

    Escribir "Capacidad final  : $TotalDespues GB"
    Escribir "Libre final      : $LibreDespues GB"
    Escribir "Espacio libre    : $PorcentajeDespues%"
    Escribir "Espacio liberado : $Liberado GB"
}

# ============================================================
# RESUMEN
# ============================================================

$FechaFin = Get-Date
$DuracionTotal = $FechaFin - $FechaInicio

Separador
Escribir "                  RESULTADO FINAL"
Escribir "============================================================"
Escribir ""

Escribir "Inicio       : $($FechaInicio.ToString('dd/MM/yyyy HH:mm:ss'))"
Escribir "Finalizacion : $($FechaFin.ToString('dd/MM/yyyy HH:mm:ss'))"
Escribir "Duracion     : $($DuracionTotal.ToString('hh\:mm\:ss'))"

Escribir ""
Escribir "---------------- ACCIONES ----------------"

if ($Acciones.Count -eq 0) {

    Escribir "Ninguna"

}
else {

    foreach ($Accion in $Acciones) {
        Escribir "[OK] $Accion"
    }
}

Escribir ""
Escribir "---------------- ADVERTENCIAS -------------"

if ($Advertencias.Count -eq 0) {

    Escribir "Ninguna"

}
else {

    foreach ($Advertencia in $Advertencias) {
        Escribir "[ADVERTENCIA] $Advertencia"
    }
}

Escribir ""
Escribir "---------------- PROBLEMAS ----------------"

if ($Problemas.Count -eq 0) {

    Escribir "Ninguno"

}
else {

    foreach ($Problema in $Problemas) {
        Escribir "[PROBLEMA] $Problema"
    }
}

Escribir ""
Escribir "============================================================"

if ($Problemas.Count -gt 0) {

    $Estado = "REQUIERE ATENCION"

}
elseif ($Advertencias.Count -gt 0) {

    $Estado = "COMPLETADO CON OBSERVACIONES"

}
else {

    $Estado = "MANTENIMIENTO COMPLETADO"

}

Escribir "ESTADO GENERAL: $Estado"
Escribir "============================================================"

# ============================================================
# INFORME
# ============================================================

Escribir ""
Escribir "Informe guardado en:"
Escribir $Informe

# ============================================================
# FINAL EN PANTALLA
# ============================================================

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "          SOPORTETI - MANTENIMIENTO V4" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

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
Write-Host "Duracion total : $($DuracionTotal.ToString('hh\:mm\:ss'))"
Write-Host "Informe        : $Informe"
Write-Host ""

Read-Host "Presiona ENTER para salir"
```

