# ============================================================
# SOPORTETI - DIAGNOSTICO V2
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

Clear-Host

Escribir "============================================================"
Escribir "                 SOPORTETI - DIAGNOSTICO V2"
Escribir "============================================================"
Escribir "Fecha: $(Get-Date)"
Escribir ""

$Problemas = @()

# ============================================================
# INFORMACION DEL EQUIPO
# ============================================================

Escribir "================ INFORMACION DEL EQUIPO ===================="

$Equipo = Get-CimInstance Win32_ComputerSystem
$CPU = Get-CimInstance Win32_Processor | Select-Object -First 1
$Windows = Get-CimInstance Win32_OperatingSystem
$BIOS = Get-CimInstance Win32_BIOS

Escribir "Fabricante : $($Equipo.Manufacturer)"
Escribir "Modelo     : $($Equipo.Model)"
Escribir "Procesador : $($CPU.Name)"
Escribir "Nucleos    : $($CPU.NumberOfCores)"
Escribir "RAM total  : $([math]::Round($Equipo.TotalPhysicalMemory / 1GB,2)) GB"
Escribir "Windows    : $($Windows.Caption)"
Escribir "Version    : $($Windows.Version)"
Escribir "BIOS       : $($BIOS.SMBIOSBIOSVersion)"
Escribir "Ultimo arranque: $($Windows.LastBootUpTime)"
Escribir ""

# ============================================================
# GPU
# ============================================================

Escribir "================ TARJETA GRAFICA ==========================="

$GPU = Get-CimInstance Win32_VideoController

foreach ($Tarjeta in $GPU) {

    Escribir "GPU: $($Tarjeta.Name)"
    Escribir "Memoria: $([math]::Round($Tarjeta.AdapterRAM / 1GB,2)) GB"
    Escribir "Driver: $($Tarjeta.DriverVersion)"
    Escribir ""
}

# ============================================================
# DISCO
# ============================================================

Escribir "================ ALMACENAMIENTO ============================"

$Discos = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"

foreach ($Disco in $Discos) {

    $Total = [math]::Round($Disco.Size / 1GB,2)
    $Libre = [math]::Round($Disco.FreeSpace / 1GB,2)
    $PorcentajeLibre = [math]::Round(($Libre / $Total) * 100,1)

    Escribir "Unidad: $($Disco.DeviceID)"
    Escribir "Capacidad: $Total GB"
    Escribir "Disponible: $Libre GB"
    Escribir "Espacio libre: $PorcentajeLibre%"

    if ($PorcentajeLibre -lt 15) {

        Escribir "⚠️ ADVERTENCIA: Poco espacio disponible."
        $Problemas += "Poco espacio disponible en $($Disco.DeviceID)"
    }

    Escribir ""
}

# ============================================================
# BATERIA
# ============================================================

Escribir "================ BATERIA ==================================="

$Bateria = Get-CimInstance Win32_Battery

if ($Bateria) {

    foreach ($Bat in $Bateria) {

        Escribir "Carga: $($Bat.EstimatedChargeRemaining)%"
        Escribir "Estado: $($Bat.Status)"

        if ($Bat.EstimatedChargeRemaining -lt 20) {

            $Problemas += "Bateria con carga inferior al 20%"
        }
    }

}
else {

    Escribir "No se detecto bateria."
}

Escribir ""

# ============================================================
# RED
# ============================================================

Escribir "================ RED ========================================"

$Adaptadores = Get-NetIPConfiguration

foreach ($Adaptador in $Adaptadores) {

    if ($Adaptador.InterfaceAlias) {

        Escribir "Adaptador: $($Adaptador.InterfaceAlias)"
        Escribir "IP: $($Adaptador.IPv4Address.IPAddress)"
        Escribir "Gateway: $($Adaptador.IPv4DefaultGateway.NextHop)"
        Escribir "DNS: $($Adaptador.DNSServer.ServerAddresses -join ', ')"
        Escribir ""
    }
}

# ============================================================
# PRUEBA DE INTERNET
# ============================================================

Escribir "================ CONECTIVIDAD ==============================="

$Conexion = Test-Connection -ComputerName 8.8.8.8 -Count 2 -Quiet

if ($Conexion) {

    Escribir "Internet: CONECTADO"

}
else {

    Escribir "Internet: SIN RESPUESTA"
    $Problemas += "No se obtuvo respuesta de Internet"
}

Escribir ""

# ============================================================
# DISPOSITIVOS CON ERRORES REALES
# ============================================================

Escribir "================ DISPOSITIVOS ==============================="

$DispositivosError = Get-PnpDevice | Where-Object {
    $_.Status -eq "Error"
}

if ($DispositivosError) {

    foreach ($Dispositivo in $DispositivosError) {

        $Problemas += "Dispositivo con error: $($Dispositivo.FriendlyName)"

        Escribir "⚠️ DISPOSITIVO CON ERROR"
        Escribir "Nombre: $($Dispositivo.FriendlyName)"
        Escribir "Estado: $($Dispositivo.Status)"
        Escribir "Clase: $($Dispositivo.Class)"
        Escribir "ID: $($Dispositivo.InstanceId)"
        Escribir ""
    }

}
else {

    Escribir "OK - No se encontraron dispositivos con estado ERROR."
}

# ============================================================
# WINDOWS DEFENDER
# ============================================================

Escribir "================ WINDOWS DEFENDER ==========================="

$Defender = Get-MpComputerStatus

if ($Defender) {

    Escribir "Antivirus activo: $($Defender.AntivirusEnabled)"
    Escribir "Proteccion tiempo real: $($Defender.RealTimeProtectionEnabled)"

    if (-not $Defender.AntivirusEnabled) {

        $Problemas += "Windows Defender no esta activo"
    }

}
else {

    Escribir "No fue posible consultar Windows Defender."
}

Escribir ""

# ============================================================
# FIREWALL
# ============================================================

Escribir "================ FIREWALL ==================================="

$Firewall = Get-NetFirewallProfile

foreach ($Perfil in $Firewall) {

    Escribir "$($Perfil.Name): $($Perfil.Enabled)"

}

Escribir ""

# ============================================================
# ACTUALIZACIONES
# ============================================================

Escribir "================ WINDOWS UPDATE ============================="

$Updates = Get-HotFix |
    Sort-Object InstalledOn -Descending |
    Select-Object -First 5

foreach ($Update in $Updates) {

    Escribir "$($Update.HotFixID) - $($Update.InstalledOn)"
}

Escribir ""

# ============================================================
# PROCESOS
# ============================================================

Escribir "================ PROCESOS ==================================="

$Procesos = Get-Process |
    Sort-Object WorkingSet64 -Descending |
    Select-Object -First 10

foreach ($Proceso in $Procesos) {

    $Memoria = [math]::Round($Proceso.WorkingSet64 / 1MB,2)

    Escribir "$($Proceso.ProcessName) - $Memoria MB"
}

Escribir ""

# ============================================================
# RESULTADO
# ============================================================

Escribir "============================================================"
Escribir "                 RESULTADO DEL DIAGNOSTICO"
Escribir "============================================================"

if ($Problemas.Count -eq 0) {

    Escribir ""
    Escribir "ESTADO GENERAL: OK"
    Escribir ""
    Escribir "No se encontraron problemas criticos."

}
else {

    Escribir ""
    Escribir "ESTADO GENERAL: REQUIERE REVISION"
    Escribir ""
    Escribir "Problemas encontrados:"

    foreach ($Problema in $Problemas) {

        Escribir "- $Problema"
    }
}

Escribir ""
Escribir "============================================================"
Escribir "Diagnostico finalizado."
Escribir "Informe: $Informe"
Escribir "============================================================"

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "       DIAGNOSTICO V2 FINALIZADO" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Informe guardado en:" -ForegroundColor Green
Write-Host $Informe -ForegroundColor Yellow
Write-Host ""

Read-Host "Presiona ENTER para salir"
