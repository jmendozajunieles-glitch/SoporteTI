```powershell
# ============================================================
# SOPORTETI - OPTIMIZACION TI V3
# Analisis inteligente + optimizacion segura
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

$Problemas = New-Object System.Collections.Generic.List[string]
$Recomendaciones = New-Object System.Collections.Generic.List[string]
$Acciones = New-Object System.Collections.Generic.List[string]
$Advertencias = New-Object System.Collections.Generic.List[string]

# ============================================================
# FUNCIONES
# ============================================================

function Log {
    param([string]$Texto)

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

            return [math]::Round($CPU.Average,1)
        }
        catch {
            return 0
        }
    }
}

function Obtener-RAM {

    try {
        $OS = Get-CimInstance Win32_OperatingSystem

        $Total = [double]$OS.TotalVisibleMemorySize
        $Libre = [double]$OS.FreePhysicalMemory

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

function Obtener-EspacioGB {

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

    param([string]$Ruta)

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

        $Acciones.Add("Limpieza de $Ruta")
    }
    catch {

        Log "[ADVERTENCIA] Limpieza incompleta: $Ruta"
        $Advertencias.Add("Limpieza incompleta de $Ruta")
    }
}

# ============================================================
# ADMINISTRADOR
# ============================================================

$Principal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent()
)

$Administrador = $Principal.IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)

if (-not $Administrador) {

    Write-Host ""
    Write-Host "============================================================"
    Write-Host "      SOPORTETI NECESITA PERMISOS DE ADMINISTRADOR"
    Write-Host "============================================================"
    Write-Host ""
    Write-Host "Ejecuta PowerShell como Administrador."
    Write-Host ""

    Read-Host "Presiona ENTER para salir"
    exit
}

# ============================================================
# CABECERA
# ============================================================

Log "============================================================"
Log "             SOPORTETI - OPTIMIZACION TI V3"
Log "============================================================"
Log "Equipo : $env:COMPUTERNAME"
Log "Usuario: $env:USERNAME"
Log "Fecha  : $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')"
Log "============================================================"

# ============================================================
# INFORMACION DEL EQUIPO
# ============================================================

Linea
Log "================ INFORMACION DEL EQUIPO ===================="

$Sistema = Get-CimInstance Win32_ComputerSystem
$SO = Get-CimInstance Win32_OperatingSystem
$CPUInfo = Get-CimInstance Win32_Processor | Select-Object -First 1

$RAMGB = [math]::Round(
    $Sistema.TotalPhysicalMemory / 1GB,
    2
)

Log "Fabricante : $($Sistema.Manufacturer)"
Log "Modelo     : $($Sistema.Model)"
Log "Procesador : $($CPUInfo.Name)"
Log "Nucleos    : $($CPUInfo.NumberOfLogicalProcessors)"
Log "RAM total  : $RAMGB GB"
Log "Windows    : $($SO.Caption)"
Log "Version    : $($SO.Version)"

# ============================================================
# ANALISIS INICIAL
# ============================================================

Linea
Log "================ ANALISIS DEL EQUIPO ======================="

Log "Analizando rendimiento..."
Log ""

$CPUAntes = Obtener-CPU
$RAMAntes = Obtener-RAM
$DiscoAntes = Obtener-Disco
$EspacioAntes = Obtener-EspacioGB

Log "CPU utilizada    : $CPUAntes%"
Log "RAM utilizada    : $RAMAntes%"
Log "Disco libre      : $DiscoAntes%"
Log "Espacio libre    : $EspacioAntes GB"

# ============================================================
# ANALISIS RAM
# ============================================================

if ($RAMAntes -ge 90) {

    Log ""
    Log "[CRITICO] Uso de RAM superior al 90%."

    $Problemas.Add("Uso critico de memoria RAM")
    $Recomendaciones.Add("Reducir aplicaciones abiertas y revisar programas de inicio")

}
elseif ($RAMAntes -ge 80) {

    Log ""
    Log "[ADVERTENCIA] Uso de RAM elevado."

    $Problemas.Add("Uso elevado de memoria RAM")
    $Recomendaciones.Add("Revisar aplicaciones de inicio y procesos pesados")

}
else {

    Log ""
    Log "[OK] Uso de RAM dentro de un rango aceptable."
}

# ============================================================
# ANALISIS CPU
# ============================================================

if ($CPUAntes -ge 90) {

    Log "[CRITICO] Uso de CPU muy elevado."

    $Problemas.Add("Uso critico de CPU")
    $Recomendaciones.Add("Revisar procesos de alto consumo")

}
elseif ($CPUAntes -ge 75) {

    Log "[ADVERTENCIA] Uso de CPU elevado."

    $Problemas.Add("Uso elevado de CPU")
    $Recomendaciones.Add("Revisar procesos activos")

}
else {

    Log "[OK] Uso de CPU dentro de un rango normal."
}

# ============================================================
# ANALISIS DISCO
# ============================================================

if ($DiscoAntes -lt 15) {

    Log "[CRITICO] Menos del 15% de espacio disponible."

    $Problemas.Add("Poco espacio disponible")
    $Recomendaciones.Add("Liberar espacio del disco")

}
elseif ($DiscoAntes -lt 25) {

    Log "[ADVERTENCIA] Espacio disponible reducido."

    $Problemas.Add("Espacio disponible reducido")
    $Recomendaciones.Add("Realizar limpieza de almacenamiento")

}
else {

    Log "[OK] Espacio disponible suficiente."
}

# ============================================================
# PROCESOS PESADOS
# ============================================================

Linea
Log "================ PROCESOS DE MAYOR CONSUMO =================="

$Procesos = Get-Process |
    Where-Object {
        $_.WorkingSet64 -gt 50MB
    } |
    Sort-Object WorkingSet64 -Descending |
    Select-Object -First 10

foreach ($Proceso in $Procesos) {

    $RAMProceso = [math]::Round(
        $Proceso.WorkingSet64 / 1MB,
        2
    )

    Log "$($Proceso.ProcessName) - $RAMProceso MB"
}

# ============================================================
# APLICACIONES DE INICIO
# ============================================================

Linea
Log "================ APLICACIONES DE INICIO ===================="

try {

    $InicioApps = Get-CimInstance Win32_StartupCommand |
        Sort-Object Name

    $CantidadInicio = @($InicioApps).Count

    Log "Aplicaciones detectadas: $CantidadInicio"
    Log ""

    foreach ($App in $InicioApps) {
        Log " - $($App.Name)"
    }

    if ($CantidadInicio -gt 10) {

        $Problemas.Add("Cantidad elevada de aplicaciones de inicio")
        $Recomendaciones.Add("Revisar aplicaciones que arrancan con Windows")

        Log ""
        Log "[ADVERTENCIA] Hay muchas aplicaciones de inicio."

    }
    else {

        Log ""
        Log "[OK] Cantidad de aplicaciones de inicio razonable."
    }

}
catch {

    Log "[ADVERTENCIA] No fue posible analizar aplicaciones de inicio."
    $Advertencias.Add("Analisis de inicio")
}

# ============================================================
# DETERMINAR NIVEL
# ============================================================

Linea
Log "================ NIVEL DE OPTIMIZACION ====================="

$Nivel = "NORMAL"

if ($Problemas.Count -ge 3) {

    $Nivel = "PROFUNDO"

}
elseif ($Problemas.Count -ge 1) {

    $Nivel = "RECOMENDADO"
}

switch ($Nivel) {

    "NORMAL" {

        Log "NIVEL: NORMAL"
        Log ""
        Log "El equipo presenta un estado general bueno."
        Log "Se recomienda una limpieza preventiva."
    }

    "RECOMENDADO" {

        Log "NIVEL: RECOMENDADO"
        Log ""
        Log "Se encontraron aspectos que pueden afectar"
        Log "el rendimiento del equipo."
    }

    "PROFUNDO" {

        Log "NIVEL: PROFUNDO"
        Log ""
        Log "Se encontraron varios indicadores de bajo rendimiento."
        Log "Se recomienda realizar una optimizacion mas completa."
    }
}

Log ""

if ($Problemas.Count -gt 0) {

    Log "Problemas encontrados:"

    foreach ($Problema in $Problemas) {

        Log "[!] $Problema"
    }

}
else {

    Log "[OK] No se detectaron problemas importantes."
}

# ============================================================
# CONFIRMACION
# ============================================================

Linea
Log "================ CONFIRMACION ==============================="

Log "Nivel seleccionado: $Nivel"
Log ""
Log "La optimizacion realizara operaciones seguras."
Log ""
Log "No se desactivaran:"
Log " - Windows Defender"
Log " - Windows Update"
Log " - Servicios criticos"
Log " - Seguridad de Windows"
Log ""

$Confirmar = Read-Host "Deseas iniciar la optimizacion? (S/N)"

if ($Confirmar -notmatch "^[Ss]$") {

    Log ""
    Log "Operacion cancelada por el usuario."
    Log "Informe: $Informe"

    Read-Host "Presiona ENTER para salir"
    exit
}

# ============================================================
# LIMPIEZA TEMPORALES
# ============================================================

Linea
Log "================ LIMPIEZA DE TEMPORALES ===================="

Limpiar-Ruta $env:TEMP
Limpiar-Ruta "C:\Windows\Temp"

# ============================================================
# CACHE MINIATURAS
# ============================================================

Linea
Log "================ CACHE DE MINIATURAS ========================"

try {

    $RutaExplorer = `
        "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"

    Get-ChildItem `
        -Path $RutaExplorer `
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

    Log "[ADVERTENCIA] Cache no limpiada completamente."
    $Advertencias.Add("Cache de miniaturas")
}

# ============================================================
# DNS
# ============================================================

Linea
Log "================ CACHE DNS =================================="

try {

    ipconfig /flushdns 2>&1 |
        ForEach-Object {
            Log "$_"
        }

    Log "[OK] Cache DNS procesada."
    $Acciones.Add("Limpieza de cache DNS")

}
catch {

    Log "[ADVERTENCIA] No fue posible limpiar DNS."
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

    Log "[ADVERTENCIA] Papelera no procesada completamente."
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
        -Force |
        Out-Null

    Log "[OK] Efectos visuales configurados para rendimiento."

    $Acciones.Add("Optimizacion de efectos visuales")

}
catch {

    Log "[ADVERTENCIA] No se pudieron modificar efectos visuales."
    $Advertencias.Add("Efectos visuales")
}

# ============================================================
# DISCO
# ============================================================

Linea
Log "================ OPTIMIZACION DE DISCO ====================="

Log "Windows seleccionara automaticamente la optimizacion."
Log ""

try {

    $Salida = defrag.exe C: /O /U 2>&1
    $Codigo = $LASTEXITCODE

    foreach ($LineaDisco in $Salida) {

        Log "$LineaDisco"
    }

    Log ""
    Log "Codigo de salida: $Codigo"

    if ($Codigo -eq 0) {

        Log "[OK] Unidad C: optimizada."
        $Acciones.Add("Optimizacion de almacenamiento")

    }
    else {

        Log "[ADVERTENCIA] Codigo de salida: $Codigo"
        $Advertencias.Add("Optimizacion de disco")
    }

}
catch {

    Log "[ADVERTENCIA] No se pudo optimizar el disco."
    $Advertencias.Add("Optimizacion de disco")
}

# ============================================================
# DISM
# ============================================================

Linea
Log "================ LIMPIEZA WINDOWS ==========================="

if ($Nivel -eq "PROFUNDO") {

    Log "El equipo requiere optimizacion profunda."
    Log ""
    Log "DISM puede tardar varios minutos."
    Log "No cierres PowerShell durante el proceso."
    Log ""

    $RespuestaDISM = Read-Host "Deseas ejecutar la limpieza DISM? (S/N)"

    if ($RespuestaDISM -match "^[Ss]$") {

        Log ""
        Log "Iniciando limpieza de componentes..."

        $InicioDISM = Get-Date

        try {

            $SalidaDISM = DISM.exe `
                /Online `
                /Cleanup-Image `
                /StartComponentCleanup 2>&1

            $CodigoDISM = $LASTEXITCODE

            foreach ($LineaDISM in $SalidaDISM) {

                Log "$LineaDISM"
            }

            $FinDISM = Get-Date
            $TiempoDISM = $FinDISM - $InicioDISM

            Log ""
            Log "Codigo DISM : $CodigoDISM"
            Log "Tiempo      : $($TiempoDISM.ToString('hh\:mm\:ss'))"

            if ($CodigoDISM -eq 0) {

                Log "[OK] Limpieza DISM completada."
                $Acciones.Add("Limpieza DISM")

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

        Log "DISM omitido por el usuario."
    }

}
else {

    Log "[INFO] DISM no es necesario para este nivel."
}

# ============================================================
# PLAN DE ENERGIA
# ============================================================

Linea
Log "================ PLAN DE ENERGIA ============================"

try {

    $Plan = powercfg /getactivescheme 2>&1

    foreach ($LineaPower in $Plan) {

        Log "$LineaPower"
    }

    Log ""
    Log "[OK] Plan de energia revisado."

}
catch {

    Log "[ADVERTENCIA] No fue posible consultar energia."
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
$EspacioDespues = Obtener-EspacioGB

Log "CPU utilizada    : $CPUDespues%"
Log "RAM utilizada    : $RAMDespues%"
Log "Disco libre      : $DiscoDespues%"
Log "Espacio libre    : $EspacioDespues GB"

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

Log "CPU"
Log "Antes   : $CPUAntes%"
Log "Despues : $CPUDespues%"
Log "Cambio  : $CambioCPU puntos"

Log ""

Log "RAM"
Log "Antes   : $RAMAntes%"
Log "Despues : $RAMDespues%"
Log "Cambio  : $CambioRAM puntos"

Log ""

Log "ALMACENAMIENTO"
Log "Antes   : $EspacioAntes GB libres"
Log "Despues : $EspacioDespues GB libres"
Log "Cambio  : $EspacioLiberado GB"

# ============================================================
# RESULTADO
# ============================================================

Linea
Log "================ RESULTADO FINAL ============================"

Log ""
Log "Nivel aplicado: $Nivel"
Log ""

Log "ACCIONES REALIZADAS: $($Acciones.Count)"

foreach ($Accion in $Acciones) {

    Log "[OK] $Accion"
}

Log ""
Log "ADVERTENCIAS: $($Advertencias.Count)"

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
Write-Host "============================================================"
Write-Host "       SOPORTETI - OPTIMIZACION V3 FINALIZADA"
Write-Host "============================================================"
Write-Host ""

if ($Advertencias.Count -eq 0) {

    Write-Host "ESTADO: OPTIMIZACION COMPLETADA"

}
else {

    Write-Host "ESTADO: COMPLETADA CON OBSERVACIONES"
}

Write-Host ""
Write-Host "Informe:"
Write-Host $Informe
Write-Host ""

Read-Host "Presiona ENTER para salir"
```

Read-Host "Presiona ENTER para salir"
```

