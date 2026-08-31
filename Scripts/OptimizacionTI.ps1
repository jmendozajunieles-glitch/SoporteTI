```powershell
# ============================================================
# SOPORTETI - OPTIMIZACION TI V1
# Optimizacion segura de rendimiento de Windows
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

$Informe = "$Logs\Optimizacion_$FechaArchivo.txt"

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

function Obtener-CPU {

    try {

        $CPU = Get-Counter '\Processor(_Total)\% Processor Time' `
            -ErrorAction Stop

        return [math]::Round(
            $CPU.CounterSamples[0].CookedValue,
            1
        )

    }
    catch {

        try {

            $Procesador = Get-CimInstance Win32_Processor

            return [math]::Round(
                $Procesador.LoadPercentage,
                1
            )

        }
        catch {

            return 0
        }
    }
}

function Obtener-RAM {

    try {

        $OS = Get-CimInstance Win32_OperatingSystem

        $Total = $OS.TotalVisibleMemorySize
        $Libre = $OS.FreePhysicalMemory

        $Usada = $Total - $Libre

        return [math]::Round(
            ($Usada / $Total) * 100,
            1
        )

    }
    catch {

        return 0
    }
}

function Obtener-Disco {

    try {

        $Disco = Get-CimInstance Win32_LogicalDisk `
            -Filter "DeviceID='C:'"

        return [math]::Round(
            ($Disco.FreeSpace / $Disco.Size) * 100,
            1
        )

    }
    catch {

        return 0
    }
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
    Write-Host "Abre PowerShell como Administrador." -ForegroundColor Yellow
    Write-Host ""

    Read-Host "Presiona ENTER para salir"
    exit
}

# ============================================================
# CABECERA
# ============================================================

Escribir "============================================================"
Escribir "              SOPORTETI - OPTIMIZACION V1"
Escribir "============================================================"
Escribir "Equipo     : $Equipo"
Escribir "Usuario    : $Usuario"
Escribir "Inicio     : $($FechaInicio.ToString('dd/MM/yyyy HH:mm:ss'))"
Escribir "============================================================"

# ============================================================
# MEDICION INICIAL
# ============================================================

Separador
Escribir "================ ESTADO INICIAL ============================="

$CPUAntes = Obtener-CPU
$RAMAntes = Obtener-RAM
$DiscoAntes = Obtener-Disco

Escribir "CPU utilizada       : $CPUAntes%"
Escribir "RAM utilizada       : $RAMAntes%"
Escribir "Espacio libre C:    : $DiscoAntes%"

# ============================================================
# CONFIRMACION
# ============================================================

Separador

Escribir "Este proceso realizara optimizaciones seguras:"
Escribir ""
Escribir "[1] Limpieza de temporales"
Escribir "[2] Limpieza de cachés seguras"
Escribir "[3] Limpieza de DNS"
Escribir "[4] Revision de aplicaciones de inicio"
Escribir "[5] Optimizacion de efectos visuales"
Escribir "[6] Optimizacion de unidad C:"
Escribir "[7] Revision del plan de energia"
Escribir "[8] Limpieza de componentes antiguos de Windows"
Escribir ""
Escribir "No se desactivaran servicios criticos."
Escribir "No se desactivara Windows Update."
Escribir "No se desactivara Windows Defender."
Escribir ""

$Confirmacion = Read-Host "Deseas iniciar la optimizacion? (S/N)"

if ($Confirmacion -notmatch "^[Ss]$") {

    Escribir ""
    Escribir "Optimizacion cancelada por el usuario."
    Escribir "Informe: $Informe"

    Read-Host "Presiona ENTER para salir"
    exit
}

# ============================================================
# TEMPORALES DEL USUARIO
# ============================================================

Separador
Escribir "================ TEMPORALES ================================"

try {

    $Temp = Get-ChildItem `
        -Path $env:TEMP `
        -Force `
        -ErrorAction SilentlyContinue

    $Cantidad = $Temp.Count

    $Temp |
        Remove-Item `
        -Recurse `
        -Force `
        -ErrorAction SilentlyContinue

    Escribir "[OK] Temporales procesados: $Cantidad"

    $Acciones += "Limpieza de temporales"

}
catch {

    Escribir "[ADVERTENCIA] Algunos temporales estaban en uso."
    $Advertencias += "Temporales no eliminados completamente."
}

# ============================================================
# TEMPORALES WINDOWS
# ============================================================

Separador
Escribir "================ TEMPORALES WINDOWS ========================="

try {

    $TempWindows = Get-ChildItem `
        -Path "C:\Windows\Temp" `
        -Force `
        -ErrorAction SilentlyContinue

    $CantidadWindows = $TempWindows.Count

    $TempWindows |
        Remove-Item `
        -Recurse `
        -Force `
        -ErrorAction SilentlyContinue

    Escribir "[OK] Temporales Windows procesados: $CantidadWindows"

    $Acciones += "Limpieza de temporales Windows"

}
catch {

    Escribir "[ADVERTENCIA] Algunos archivos estaban en uso."
    $Advertencias += "Temporales Windows no eliminados completamente."
}

# ============================================================
# CACHE DNS
# ============================================================

Separador
Escribir "================ CACHE DNS =================================="

try {

    ipconfig /flushdns 2>&1 |
        ForEach-Object {
            Escribir "$_"
        }

    Escribir "[OK] Cache DNS procesada."

    $Acciones += "Limpieza de cache DNS"

}
catch {

    $Advertencias += "No fue posible limpiar completamente la cache DNS."
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

    Escribir "[OK] Papelera procesada."

    $Acciones += "Limpieza de papelera"

}
catch {

    $Advertencias += "No fue posible limpiar completamente la papelera."
}

# ============================================================
# APLICACIONES DE INICIO
# ============================================================

Separador
Escribir "================ APLICACIONES DE INICIO ====================="

Escribir "Programas registrados para iniciar con Windows:"
Escribir ""

try {

    $Inicio = Get-CimInstance Win32_StartupCommand |
        Sort-Object Name

    if ($Inicio) {

        foreach ($Programa in $Inicio) {

            Escribir " - $($Programa.Name)"
        }

        Escribir ""
        Escribir "No se deshabilitaron programas automaticamente."
        Escribir "La lista queda registrada para revision."

    }
    else {

        Escribir "No se encontraron programas registrados."
    }

}
catch {

    Escribir "No fue posible obtener la lista de inicio."
    $Advertencias += "No fue posible revisar aplicaciones de inicio."
}

# ============================================================
# EFECTOS VISUALES
# ============================================================

Separador
Escribir "================ EFECTOS VISUALES ==========================="

try {

    $Ruta = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"

    New-ItemProperty `
        -Path $Ruta `
        -Name "VisualFXSetting" `
        -PropertyType DWORD `
        -Value 2 `
        -Force | Out-Null

    Escribir "[OK] Windows configurado para priorizar rendimiento visual."

    $Acciones += "Optimizacion de efectos visuales"

}
catch {

    Escribir "[ADVERTENCIA] No se pudieron modificar los efectos visuales."
    $Advertencias += "Efectos visuales sin modificar."
}

# ============================================================
# PLAN DE ENERGIA
# ============================================================

Separador
Escribir "================ ENERGIA ===================================="

try {

    $Planes = powercfg /list 2>&1

    foreach ($Linea in $Planes) {

        Escribir "$Linea"
    }

    Escribir ""
    Escribir "Plan de energia actual:"

    $Activo = powercfg /getactivescheme 2>&1

    foreach ($Linea in $Activo) {

        Escribir "$Linea"
    }

    $Acciones += "Revision del plan de energia"

}
catch {

    $Advertencias += "No fue posible consultar el plan de energia."
}

# ============================================================
# OPTIMIZACION DE DISCO
# ============================================================

Separador
Escribir "================ OPTIMIZACION DE DISCO ======================"

Escribir "Windows determinara automaticamente el tipo de optimizacion."
Escribir ""
Escribir "DEFRAG C: /O"

$InicioDefrag = Get-Date

$SalidaDefrag = defrag.exe C: /O /U 2>&1

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

    Escribir "[OK] Unidad C: optimizada."
    $Acciones += "Optimizacion de unidad C:"

}
else {

    Escribir "[ADVERTENCIA] La optimizacion devolvio codigo $CodigoDefrag."
    $Advertencias += "Optimizacion de C: con codigo $CodigoDefrag."
}

# ============================================================
# LIMPIEZA COMPONENTES WINDOWS
# ============================================================

Separador
Escribir "================ COMPONENTES WINDOWS ========================"

Escribir "Ejecutando limpieza controlada del almacén de componentes."
Escribir ""
Escribir "DISM /Online /Cleanup-Image /StartComponentCleanup"
Escribir ""

$InicioCleanup = Get-Date

$SalidaCleanup = DISM.exe `
    /Online `
    /Cleanup-Image `
    /StartComponentCleanup 2>&1

$CodigoCleanup = $LASTEXITCODE

$FinCleanup = Get-Date

$DuracionCleanup = $FinCleanup - $InicioCleanup

foreach ($Linea in $SalidaCleanup) {

    Escribir "$Linea"
}

Escribir ""
Escribir "Codigo : $CodigoCleanup"
Escribir "Tiempo : $($DuracionCleanup.ToString('hh\:mm\:ss'))"

if ($CodigoCleanup -eq 0) {

    Escribir "[OK] Limpieza de componentes completada."

    $Acciones += "Limpieza de componentes Windows"

}
else {

    Escribir "[ADVERTENCIA] DISM devolvio codigo $CodigoCleanup."

    $Advertencias += "Limpieza de componentes devolvio codigo $CodigoCleanup."
}

# ============================================================
# MEDICION FINAL
# ============================================================

Separador
Escribir "================ ESTADO FINAL ==============================="

Start-Sleep -Seconds 3

$CPUDespues = Obtener-CPU
$RAMDespues = Obtener-RAM
$DiscoDespues = Obtener-Disco

Escribir "CPU utilizada       : $CPUDespues%"
Escribir "RAM utilizada       : $RAMDespues%"
Escribir "Espacio libre C:    : $DiscoDespues%"

# ============================================================
# COMPARACION
# ============================================================

Separador
Escribir "================ COMPARACION ================================"

$CambioCPU = [math]::Round(
    $CPUAntes - $CPUDespues,
    1
)

$CambioRAM = [math]::Round(
    $RAMAntes - $RAMDespues,
    1
)

$CambioDisco = [math]::Round(
    $DiscoDespues - $DiscoAntes,
    1
)

Escribir "CPU antes           : $CPUAntes%"
Escribir "CPU despues         : $CPUDespues%"
Escribir "Cambio CPU          : $CambioCPU puntos"

Escribir ""

Escribir "RAM antes           : $RAMAntes%"
Escribir "RAM despues         : $RAMDespues%"
Escribir "Cambio RAM          : $CambioRAM puntos"

Escribir ""

Escribir "Espacio libre antes : $DiscoAntes%"
Escribir "Espacio libre ahora : $DiscoDespues%"
Escribir "Cambio espacio      : $CambioDisco puntos"

# ============================================================
# RESULTADO
# ============================================================

Separador
Escribir "                  RESULTADO FINAL"
Escribir "============================================================"

Escribir ""
Escribir "ACCIONES REALIZADAS: $($Acciones.Count)"

foreach ($Accion in $Acciones) {

    Escribir "[OK] $Accion"
}

Escribir ""
Escribir "ADVERTENCIAS: $($Advertencias.Count)"

foreach ($Advertencia in $Advertencias) {

    Escribir "[ADVERTENCIA] $Advertencia"
}

Escribir ""

if ($Advertencias.Count -eq 0) {

    Escribir "ESTADO GENERAL: OPTIMIZACION COMPLETADA"

}
else {

    Escribir "ESTADO GENERAL: COMPLETADA CON OBSERVACIONES"
}

# ============================================================
# FINAL
# ============================================================

$FechaFin = Get-Date

$DuracionTotal = $FechaFin - $FechaInicio

Separador

Escribir "Fecha final : $($FechaFin.ToString('dd/MM/yyyy HH:mm:ss'))"
Escribir "Duracion    : $($DuracionTotal.ToString('hh\:mm\:ss'))"

Escribir ""
Escribir "Informe guardado en:"
Escribir $Informe

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "        SOPORTETI - OPTIMIZACION V1 FINALIZADA" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

if ($Advertencias.Count -eq 0) {

    Write-Host "ESTADO: OPTIMIZACION COMPLETADA" -ForegroundColor Green

}
else {

    Write-Host "ESTADO: COMPLETADA CON OBSERVACIONES" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Informe:" -ForegroundColor Green
Write-Host $Informe -ForegroundColor Yellow
Write-Host ""

Read-Host "Presiona ENTER para salir"
```
