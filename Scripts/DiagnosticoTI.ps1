# ============================================================
# SOPORTETI - DIAGNOSTICO V3
# ============================================================

$ErrorActionPreference = "SilentlyContinue"

$Base = "C:\SoporteTI"
$Logs = "$Base\Logs"

New-Item -ItemType Directory -Path $Logs -Force | Out-Null

$Fecha = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$Informe = "$Logs\Diagnostico_$Fecha.txt"

function Escribir {
    param([string]$Texto)

    Write-Host $Texto
    $Texto | Out-File -FilePath $Informe -Append -Encoding UTF8
}

function Separador {
    Escribir ""
    Escribir "============================================================"
}

Clear-Host

$Problemas = @()
$Advertencias = @()

Escribir "============================================================"
Escribir "              SOPORTETI - DIAGNOSTICO V3"
Escribir "============================================================"
Escribir "Fecha: $(Get-Date)"
Escribir ""

# ============================================================
# EQUIPO
# ============================================================

Escribir "================ INFORMACION DEL EQUIPO ===================="

$Equipo = Get-CimInstance Win32_ComputerSystem
$CPU = Get-CimInstance Win32_Processor | Select-Object -First 1
$Windows = Get-CimInstance Win32_OperatingSystem
$BIOS = Get-CimInstance Win32_BIOS

$RAMTotal = [math]::Round($Equipo.TotalPhysicalMemory / 1GB,2)

Escribir "Fabricante       : $($Equipo.Manufacturer)"
Escribir "Modelo           : $($Equipo.Model)"
Escribir "Procesador       : $($CPU.Name)"
Escribir "Nucleos          : $($CPU.NumberOfCores)"
Escribir "RAM total        : $RAMTotal GB"
Escribir "Windows          : $($Windows.Caption)"
Escribir "Version          : $($Windows.Version)"
Escribir "Arquitectura     : $($Windows.OSArchitecture)"
Escribir "BIOS             : $($BIOS.SMBIOSBIOSVersion)"
Escribir "Ultimo arranque  : $($Windows.LastBootUpTime)"

Separador

# ============================================================
# GPU
# ============================================================

Escribir "================ TARJETA GRAFICA ==========================="

$GPU = Get-CimInstance Win32_VideoController

foreach ($Tarjeta in $GPU) {

    $MemoriaGPU = if ($Tarjeta.AdapterRAM) {
        [math]::Round($Tarjeta.AdapterRAM / 1GB,2)
    } else {
        "No disponible"
    }

    Escribir "GPU       : $($Tarjeta.Name)"
    Escribir "Memoria   : $MemoriaGPU GB"
    Escribir "Driver    : $($Tarjeta.DriverVersion)"
    Escribir "Fecha     : $($Tarjeta.DriverDate)"
    Escribir ""
}

# ============================================================
# ALMACENAMIENTO
# ============================================================

Escribir "================ ALMACENAMIENTO ============================"

$Discos = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"

foreach ($Disco in $Discos) {

    if ($Disco.Size -gt 0) {

        $Total = [math]::Round($Disco.Size / 1GB,2)
        $Libre = [math]::Round($Disco.FreeSpace / 1GB,2)
        $PorcentajeLibre = [math]::Round(($Libre / $Total) * 100,1)

        Escribir "Unidad          : $($Disco.DeviceID)"
        Escribir "Capacidad       : $Total GB"
        Escribir "Disponible      : $Libre GB"
        Escribir "Espacio libre   : $PorcentajeLibre%"

        if ($PorcentajeLibre -lt 10) {

            Escribir "ESTADO: CRITICO - menos del 10% libre."
            $Problemas += "Espacio critico en $($Disco.DeviceID)"

        }
        elseif ($PorcentajeLibre -lt 20) {

            Escribir "ESTADO: ADVERTENCIA - menos del 20% libre."
            $Advertencias += "Poco espacio en $($Disco.DeviceID)"
        }
        else {

            Escribir "ESTADO: OK"
        }

        Escribir ""
    }
}

# ============================================================
# BATERIA
# ============================================================

Escribir "================ BATERIA ==================================="

$Bateria = Get-CimInstance Win32_Battery

if ($Bateria) {

    foreach ($Bat in $Bateria) {

        Escribir "Carga actual : $($Bat.EstimatedChargeRemaining)%"
        Escribir "Estado       : $($Bat.Status)"

        if ($Bat.EstimatedChargeRemaining -lt 15) {

            $Advertencias += "Bateria con carga inferior al 15%"
        }

        Escribir ""
    }

}
else {

    Escribir "No se detecto bateria."
}

# ============================================================
# RED
# ============================================================

Separador

Escribir "================ RED ========================================"

$Adaptadores = Get-NetAdapter

foreach ($Adaptador in $Adaptadores) {

    $IPConfig = Get-NetIPConfiguration -InterfaceIndex $Adaptador.ifIndex

    Escribir "Adaptador : $($Adaptador.Name)"
    Escribir "Tipo      : $($Adaptador.InterfaceDescription)"
    Escribir "Estado    : $($Adaptador.Status)"
    Escribir "Velocidad : $($Adaptador.LinkSpeed)"

    if ($Adaptador.Status -eq "Up") {

        $IP = $IPConfig.IPv4Address.IPAddress
        $Gateway = $IPConfig.IPv4DefaultGateway.NextHop
        $DNS = $IPConfig.DNSServer.ServerAddresses -join ", "

        Escribir "IP        : $IP"
        Escribir "Gateway   : $Gateway"
        Escribir "DNS       : $DNS"
        Escribir "Conexion  : ACTIVA"

    }
    else {

        Escribir "Conexion  : INACTIVA"
    }

    Escribir ""
}

# ============================================================
# INTERNET
# ============================================================

Escribir "================ CONECTIVIDAD ==============================="

$Conexion = Test-Connection -ComputerName 8.8.8.8 -Count 2 -Quiet

if ($Conexion) {

    Escribir "Internet : CONECTADO"

}
else {

    Escribir "Internet : SIN RESPUESTA"
    $Problemas += "No hay conectividad con Internet"
}

# ============================================================
# DISPOSITIVOS
# ============================================================

Separador

Escribir "================ DISPOSITIVOS ==============================="

$DispositivosError = Get-PnpDevice | Where-Object {
    $_.Status -eq "Error"
}

if ($DispositivosError) {

    foreach ($Dispositivo in $DispositivosError) {

        $Problemas += "Dispositivo con error: $($Dispositivo.FriendlyName)"

        Escribir "ESTADO: ERROR"
        Escribir "Nombre : $($Dispositivo.FriendlyName)"
        Escribir "Clase  : $($Dispositivo.Class)"
        Escribir "ID     : $($Dispositivo.InstanceId)"
        Escribir ""
    }

}
else {

    Escribir "ESTADO: OK"
    Escribir "No se encontraron dispositivos con estado ERROR."
}

# ============================================================
# ANTIVIRUS
# ============================================================

Separador

Escribir "================ SEGURIDAD ================================"

$Defender = Get-MpComputerStatus

if ($Defender) {

    Escribir "Microsoft Defender"
    Escribir "Antivirus activo       : $($Defender.AntivirusEnabled)"
    Escribir "Proteccion tiempo real : $($Defender.RealTimeProtectionEnabled)"
    Escribir ""

}

# Buscar productos antivirus registrados en Windows
$Antivirus = Get-CimInstance -Namespace "root\SecurityCenter2" `
    -ClassName AntiVirusProduct

if ($Antivirus) {

    Escribir "Antivirus detectados:"

    foreach ($AV in $Antivirus) {

        $Estado = $AV.productState

        Escribir "Proveedor : $($AV.displayName)"
        Escribir "Estado    : $Estado"
        Escribir ""
    }

}
else {

    Escribir "No se encontraron productos antivirus registrados."
    $Problemas += "No se detecto un antivirus registrado en Windows."
}

# ============================================================
# FIREWALL
# ============================================================

Escribir "================ FIREWALL ==================================="

$Firewall = Get-NetFirewallProfile

foreach ($Perfil in $Firewall) {

    $EstadoFirewall = if ($Perfil.Enabled) {
        "ACTIVO"
    }
    else {
        "DESACTIVADO"
    }

    Escribir "$($Perfil.Name): $EstadoFirewall"

    if (-not $Perfil.Enabled) {

        $Advertencias += "Firewall $($Perfil.Name) desactivado"
    }
}

# ============================================================
# WINDOWS UPDATE
# ============================================================

Separador

Escribir "================ WINDOWS UPDATE ============================="

$Updates = Get-HotFix |
    Sort-Object InstalledOn -Descending |
    Select-Object -First 5

Escribir "Ultimas actualizaciones instaladas:"
Escribir ""

foreach ($Update in $Updates) {

    Escribir "$($Update.HotFixID) - $($Update.InstalledOn)"
}

# ============================================================
# MEMORIA
# ============================================================

Separador

Escribir "================ MEMORIA ===================================="

$MemoriaLibre = [math]::Round($Windows.FreePhysicalMemory / 1MB,2)
$MemoriaUsada = [math]::Round($RAMTotal - $MemoriaLibre,2)

$PorcentajeRAM = [math]::Round(($MemoriaUsada / $RAMTotal) * 100,1)

Escribir "RAM total       : $RAMTotal GB"
Escribir "RAM usada       : $MemoriaUsada GB"
Escribir "RAM disponible  : $MemoriaLibre GB"
Escribir "Uso de RAM      : $PorcentajeRAM%"

if ($PorcentajeRAM -gt 90) {

    $Advertencias += "Uso de RAM superior al 90%"
}

# ============================================================
# PROCESOS
# ============================================================

Escribir ""
Escribir "================ PROCESOS ==================================="

$Procesos = Get-Process |
    Sort-Object WorkingSet64 -Descending |
    Select-Object -First 10

foreach ($Proceso in $Procesos) {

    $Memoria = [math]::Round($Proceso.WorkingSet64 / 1MB,2)

    Escribir "$($Proceso.ProcessName) - $Memoria MB"
}

# ============================================================
# RESULTADO
# ============================================================

Separador

Escribir "                 RESULTADO DEL DIAGNOSTICO"
Escribir "============================================================"

if ($Problemas.Count -eq 0 -and $Advertencias.Count -eq 0) {

    Escribir ""
    Escribir "ESTADO GENERAL: OK"
    Escribir "No se encontraron problemas ni advertencias."
}

else {

    if ($Problemas.Count -gt 0) {

        Escribir ""
        Escribir "PROBLEMAS ENCONTRADOS:"

        foreach ($Problema in $Problemas) {

            Escribir "[PROBLEMA] $Problema"
        }
    }

    if ($Advertencias.Count -gt 0) {

        Escribir ""
        Escribir "ADVERTENCIAS:"

        foreach ($Advertencia in $Advertencias) {

            Escribir "[ADVERTENCIA] $Advertencia"
        }
    }

    Escribir ""
    Escribir "ESTADO GENERAL: REQUIERE REVISION"
}

Separador

Escribir "Diagnostico finalizado."
Escribir "Informe guardado en:"
Escribir $Informe

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "       DIAGNOSTICO V3 FINALIZADO" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Informe:" -ForegroundColor Green
Write-Host $Informe -ForegroundColor Yellow
Write-Host ""

Read-Host "Presiona ENTER para salir"
