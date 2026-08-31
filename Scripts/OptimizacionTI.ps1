```powershell
# ============================================================
# SOPORTETI - OPTIMIZACION TI V2
# Optimizacion segura y diagnostico de rendimiento
# ============================================================

$ErrorActionPreference = "SilentlyContinue"

Clear-Host

# ============================================================
# CONFIGURACION
# ============================================================

$Base = "C:\SoporteTI"
$Logs = "$Base\Logs"

New-Item -ItemType Directory -Path $Logs -Force | Out-Null

$Fecha = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$Inicio = Get-Date

$Informe = "$Logs\Optimizacion_$Fecha.txt"

$Acciones = New-Object System.Collections.Generic.List[string]
$Advertencias = New-Object System.Collections.Generic.List[string]

# ============================================================
# FUNCIONES
# ============================================================

function Log {
    param(
        [string]$Texto
    )

    Write-Host $Texto
    $Texto | Out-File -FilePath $Informe -Append -Encoding UTF8
}

function Linea {
    Log ""
    Log "============================================================"
}

function Obtener-CPU {

    try {

        $Resultado = Get-Counter `
            '\Processor(_Total)\% Processor Time' `
            -SampleInterval 1 `
            -MaxSamples 1 `
            -ErrorAction Stop

        return [math]::Round(
            $Resultado.CounterSamples[0].CookedValue,
            1
        )

    }
    catch {

        try {

            $CPU = Get-CimInstance Win32_Processor |
                Measure-Object LoadPercentage -Average

            return [math]::Round(
                $CPU.Average,
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

        if ($Total -gt 0) {

            return [math]::Round(
                (($Total - $Libre) / $Total) * 100,
                1
            )
        }

        return 0
    }
    catch {

        return 0
    }
}

function Obtener-Disco {

    try {

        $Disco = Get-CimInstance Win32_LogicalDisk `
            -Filter "DeviceID='C:'"

        if ($Disco.Size -gt 0) {

            return [math]::Round(
                ($Disco.FreeSpace / $Disco.Size) * 100,
                1
            )
        }

        return 0
    }
    catch {

        return 0
    }
}

function Obtener-EspacioLibreGB {

    try {

        $Disco = Get-CimInstance Win32_LogicalDisk `
            -Filter "DeviceID='C:'"

        return [math]::Round(
            $Disco.FreeSpace / 1GB,
            2
        )
    }
    catch {

        return 0
    }
}

function Limpiar-Ruta {

    param(
        [string]$Ruta
    )

    if (-not (Test-Path $Ruta)) {

        return
    }

    try {

        $Elementos = Get-ChildItem `
            -Path $Ruta `
            -Force `
            -ErrorAction SilentlyContinue

        $Cantidad = $Elementos.Count

        foreach ($Elemento in $Elementos) {

            Remove-Item `
                -Path $Elemento.FullName `
                -Recurse `
                -Force `
                -ErrorAction SilentlyContinue
        }

        Log "[OK] Procesado: $Ruta"
        Log "     Elementos encontrados: $Cantidad"

        $Acciones.Add("Limpieza: $Ruta")

    }
    catch {

        Log "[ADVERTENCIA] No se pudo limpiar completamente: $Ruta"
        $Advertencias.Add("Limpieza incompleta: $Ruta")
    }
}

# ============================================================
# ADMINISTRADOR
# ============================================================

$Principal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent()
)

$EsAdministrador = $Principal.IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)

if (-not $EsAdministrador) {

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Red
    Write-Host "      SOPORTETI NECESITA PERMISOS DE ADMINISTRADOR" -ForegroundColor Red
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

Log "============================================================"
Log "              SOPORTETI - OPTIMIZACION V2"
Log "============================================================"
Log "Equipo       : $env:COMPUTERNAME"
Log "Usuario      : $env:USERNAME"
Log "Fecha inicio : $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')"
Log "============================================================"

# ============================================================
# INFORMACION DEL EQUIPO
# ============================================================

Linea
Log "================ INFORMACION DEL EQUIPO ===================="

$Sistema = Get-CimInstance Win32_ComputerSystem
$SO = Get-CimInstance Win32_OperatingSystem
$CPUInfo = Get-CimInstance Win32_Processor | Select-Object -First 1

Log "Fabricante : $($Sistema.Manufacturer)"
Log "Modelo     : $($Sistema.Model)"
Log "Procesador : $($CPUInfo.Name)"
Log "Nucleos    : $($CPUInfo.NumberOfLogicalProcessors)"
Log "RAM total  : $([math]::Round($Sistema.TotalPhysicalMemory / 1GB,2)) GB"
Log "Windows    : $($SO.Caption)"
Log "Version    : $($SO.Version)"

# ============================================================
# ESTADO INICIAL
# ============================================================

Linea
Log "================ ESTADO INICIAL ============================"

$CPUAntes = Obtener-CPU
$RAMAntes = Obtener-RAM
$DiscoAntes = Obtener-Disco
$EspacioAntes = Obtener-EspacioLibreGB

Log "CPU utilizada    : $CPUAntes%"
Log "RAM utilizada    : $RAMAntes%"
Log "Espacio libre C: : $EspacioAntes GB"
Log "Libre en disco   : $DiscoAntes%"

# ============================================================
# PROCESOS CON MAYOR CONSUMO
# ============================================================

Linea
Log "================ PROCESOS PESADOS =========================="

$Procesos = Get-Process |
    Where-Object { $_.WorkingSet64 -gt 50MB } |
    Sort-Object WorkingSet64 -Descending |
    Select-Object -First 10

foreach ($Proceso in $Procesos) {

    $RAM = [math]::Round(
        $Proceso.WorkingSet64 / 1MB,
        2
    )

    Log "$($Proceso.ProcessName) - $RAM MB"
}

# ============================================================
# APLICACIONES DE INICIO
# ============================================================

Linea
Log "================ APLICACIONES DE INICIO ===================="

try {

    $InicioApps = Get-CimInstance Win32_StartupCommand |
        Sort-Object Name

    if ($InicioApps) {

        foreach ($App in $InicioApps) {

            Log " - $($App.Name)"
        }

        Log ""
        Log "[INFO] No se deshabilitaron automaticamente."
        Log "[INFO] Se registran para revision."

    }
    else {

        Log "No se encontraron aplicaciones de inicio."
    }

}
catch {

    Log "[ADVERTENCIA] No se pudo obtener la lista de inicio."
    $Advertencias.Add("No se pudo revisar inicio.")
}

# ============================================================
# LIMPIEZA TEMPORALES
# ============================================================

Linea
Log "================ LIMPIEZA DE TEMPORALES ===================="

Limpiar-Ruta $env:TEMP
Limpiar-Ruta "C:\Windows\Temp"

# ============================================================
# CACHE DE MINIATURAS
# ============================================================

Linea
Log "================ CACHE DE MINIATURAS ========================"

try {

    $ExplorerCache = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"

    Get-ChildItem `
        -Path $ExplorerCache `
        -Filter "thumbcache*" `
        -Force `
        -ErrorAction SilentlyContinue |
        Remove-Item `
        -Force `
        -ErrorAction SilentlyContinue

    Log "[OK] Cache de miniaturas procesada."

    $Acciones.Add("Limpieza de cache de miniaturas")

}
catch {

    Log "[ADVERTENCIA] No se pudo limpiar completamente la cache."
    $Advertencias.Add("Cache de miniaturas")
}

# ============================================================
# DNS
# ============================================================

Linea
Log "================ LIMPIEZA DNS ==============================="

try {

    $DNS = ipconfig /flushdns 2>&1

    foreach ($LineaDNS in $DNS) {

        Log "$LineaDNS"
    }

    Log "[OK] Cache DNS procesada."

    $Acciones.Add("Limpieza de cache DNS")

}
catch {

    Log "[ADVERTENCIA] No se pudo limpiar la cache DNS."
    $Advertencias.Add("Cache DNS")
}

# ============================================================
# PAPELERA
# ============================================================

Linea
Log "================ PAPELERA ==================================="

try {

    Clear-RecycleBin `
        -DriveLetter C `
        -Force `
        -ErrorAction SilentlyContinue

    Log "[OK] Papelera procesada."

    $Acciones.Add("Limpieza de papelera")

}
catch {

    Log "[ADVERTENCIA] No se pudo procesar completamente la papelera."
    $Advertencias.Add("Papelera")
}

# ============================================================
# EFECTOS VISUALES
# ============================================================

Linea
Log "================ EFECTOS VISUALES ==========================="

try {

    $RutaVisual = `
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"

    New-ItemProperty `
        -Path $RutaVisual `
        -Name "VisualFXSetting" `
        -PropertyType DWORD `
        -Value 2 `
        -Force `
        | Out-Null

    Log "[OK] Configuracion de efectos visuales aplicada."

    $Acciones.Add("Optimizacion de efectos visuales")

}
catch {

    Log "[ADVERTENCIA] No se pudo aplicar la configuracion visual."
    $Advertencias.Add("Efectos visuales")
}

# ============================================================
# PLAN DE ENERGIA
# ============================================================

Linea
Log "================ PLAN DE ENERGIA ============================"

try {

    $Activo = powercfg /getactivescheme 2>&1

    foreach ($LineaPower in $Activo) {

        Log "$LineaPower"
    }

    Log ""
    Log "[INFO] No se modifico el plan de energia automaticamente."

}
catch {

    Log "[ADVERTENCIA] No se pudo consultar energia."
    $Advertencias.Add("Plan de energia")
}

# ============================================================
# OPTIMIZACION DEL DISCO
# ============================================================

Linea
Log "================ OPTIMIZACION DEL DISCO ===================="

Log "[INFO] Windows determinara automaticamente la optimizacion."
Log "[INFO] No se realizara una desfragmentacion forzada."
Log ""

$InicioDisco = Get-Date

try {

    $SalidaDisco = defrag.exe C: /O /U 2>&1

    foreach ($LineaDisco in $SalidaDisco) {

        Log "$LineaDisco"
    }

    $CodigoDisco = $LASTEXITCODE

    $FinDisco = Get-Date
    $TiempoDisco = $FinDisco - $InicioDisco

    Log ""
    Log "Codigo de salida : $CodigoDisco"
    Log "Tiempo           : $($TiempoDisco.ToString('hh\:mm\:ss'))"

    if ($CodigoDisco -eq 0) {

        Log "[OK] Unidad C: optimizada."
        $Acciones.Add("Optimizacion de unidad C:")

    }
    else {

        Log "[ADVERTENCIA] La unidad devolvio codigo $CodigoDisco."
        $Advertencias.Add("Optimizacion de disco")
    }

}
catch {

    Log "[ADVERTENCIA] No se pudo ejecutar la optimizacion."
    $Advertencias.Add("Optimizacion de disco")
}

# ============================================================
# COMPONENTES WINDOWS
# ============================================================

Linea
Log "================ COMPONENTES WINDOWS ========================"

Log "[INFO] Limpieza de componentes antiguos."
Log ""
Log "Esta operacion puede tardar varios minutos."
Log "No cierres PowerShell mientras este ejecutandose."
Log ""

$RespuestaDISM = Read-Host "Deseas ejecutar la limpieza DISM? (S/N)"

if ($RespuestaDISM -match "^[Ss]$") {

    $InicioDISM = Get-Date

    try {

        $SalidaDISM = DISM.exe `
            /Online `
            /Cleanup-Image `
            /StartComponentCleanup 2>&1

        foreach ($LineaDISM in $SalidaDISM) {

            Log "$LineaDISM"
        }

        $CodigoDISM = $LASTEXITCODE

        $FinDISM = Get-Date
        $TiempoDISM = $FinDISM - $InicioDISM

        Log ""
        Log "Codigo de salida : $CodigoDISM"
        Log "Tiempo           : $($TiempoDISM.ToString('hh\:mm\:ss'))"

        if ($CodigoDISM -eq 0) {

            Log "[OK] Limpieza DISM completada."
            $Acciones.Add("Limpieza de componentes DISM")

        }
        else {

            Log "[ADVERTENCIA] DISM devolvio codigo $CodigoDISM."
            $Advertencias.Add("DISM codigo $CodigoDISM")
        }

    }
    catch {

        Log "[ADVERTENCIA] Error ejecutando DISM."
        $Advertencias.Add("DISM")
    }

}
else {

    Log "[INFO] Limpieza DISM omitida por el usuario."
}

# ============================================================
# WINDOWS UPDATE - SOLO REVISION
# ============================================================

Linea
Log "================ WINDOWS UPDATE ============================="

try {

    $Updates = Get-HotFix |
        Sort-Object InstalledOn -Descending |
        Select-Object -First 5

    foreach ($Update in $Updates) {

        Log "$($Update.HotFixID) - $($Update.InstalledOn)"
    }

    Log ""
    Log "[INFO] No se instalaron actualizaciones automaticamente."

}
catch {

    Log "[ADVERTENCIA] No se pudo consultar Windows Update."
}

# ============================================================
# MEDICION FINAL
# ============================================================

Linea
Log "================ ESTADO FINAL ==============================="

Start-Sleep -Seconds 3

$CPUDespues = Obtener-CPU
$RAMDespues = Obtener-RAM
$DiscoDespues = Obtener-Disco
$EspacioDespues = Obtener-EspacioLibreGB

Log "CPU utilizada    : $CPUDespues%"
Log "RAM utilizada    : $RAMDespues%"
Log "Espacio libre C: : $EspacioDespues GB"
Log "Libre en disco   : $DiscoDespues%"

# ============================================================
# COMPARACION
# ============================================================

Linea
Log "================ COMPARACION ================================"

$CambioCPU = [math]::Round(
    $CPUAntes - $CPUDespues,
    1
)

$CambioRAM = [math]::Round(
    $RAMAntes - $RAMDespues,
    1
)

$EspacioLiberado = [math]::Round(
    $EspacioDespues - $EspacioAntes,
    2
)

Log "CPU antes        : $CPUAntes%"
Log "CPU despues      : $CPUDespues%"
Log "Cambio CPU       : $CambioCPU puntos"

Log ""

Log "RAM antes        : $RAMAntes%"
Log "RAM despues      : $RAMDespues%"
Log "Cambio RAM       : $CambioRAM puntos"

Log ""

Log "Disco antes      : $EspacioAntes GB libres"
Log "Disco despues    : $EspacioDespues GB libres"
Log "Espacio liberado : $EspacioLiberado GB"

# ============================================================
# EVALUACION
# ============================================================

Linea
Log "================ EVALUACION ================================"

if ($RAMDespues -ge 90) {

    Log "[ADVERTENCIA] El uso de RAM continua superior al 90%."
    $Advertencias.Add("RAM superior al 90%")

}
elseif ($RAMDespues -ge 80) {

    Log "[AVISO] El uso de RAM continua elevado."

}

if ($DiscoDespues -lt 15) {

    Log "[ADVERTENCIA] Poco espacio libre en C:."
    $Advertencias.Add("Poco espacio libre")

}
else {

    Log "[OK] Espacio disponible suficiente."
}

# ============================================================
# RESULTADO FINAL
# ============================================================

Linea
Log "                 RESULTADO FINAL"
Log "============================================================"

Log ""
Log "Acciones realizadas : $($Acciones.Count)"

foreach ($Accion in $Acciones) {

    Log "[OK] $Accion"
}

Log ""
Log "Advertencias        : $($Advertencias.Count)"

foreach ($Advertencia in $Advertencias) {

    Log "[ADVERTENCIA] $Advertencia"
}

Log ""

if ($Advertencias.Count -eq 0) {

    Log "ESTADO GENERAL: OPTIMIZACION COMPLETADA"

}
else {

    Log "ESTADO GENERAL: COMPLETADA CON OBSERVACIONES"
}

# ============================================================
# FINAL
# ============================================================

$Fin = Get-Date
$Duracion = $Fin - $Inicio

Linea
Log "Fecha final : $($Fin.ToString('dd/MM/yyyy HH:mm:ss'))"
Log "Duracion    : $($Duracion.ToString('hh\:mm\:ss'))"

Log ""
Log "Informe guardado en:"
Log $Informe

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "       SOPORTETI - OPTIMIZACION V2 FINALIZADA" -ForegroundColor Cyan
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

