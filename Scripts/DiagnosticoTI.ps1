# ============================================
# DIAGNOSTICO TI
# ============================================

$ErrorActionPreference = "SilentlyContinue"

$Ruta = "C:\SoporteTI\Logs"

New-Item -ItemType Directory -Path $Ruta -Force | Out-Null

$Fecha = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$Informe = "$Ruta\Diagnostico_$Fecha.txt"

function Escribir {
    param($Texto)

    Write-Host $Texto
    $Texto | Out-File $Informe -Append -Encoding UTF8
}

Clear-Host

Escribir "============================================"
Escribir "           DIAGNOSTICO TI"
Escribir "============================================"
Escribir "Fecha: $(Get-Date)"
Escribir ""

# EQUIPO
Escribir "============= EQUIPO ======================="

$Equipo = Get-CimInstance Win32_ComputerSystem
$CPU = Get-CimInstance Win32_Processor | Select-Object -First 1
$Windows = Get-CimInstance Win32_OperatingSystem
$BIOS = Get-CimInstance Win32_BIOS

Escribir "Fabricante: $($Equipo.Manufacturer)"
Escribir "Modelo: $($Equipo.Model)"
Escribir "Procesador: $($CPU.Name)"
Escribir "Nucleos: $($CPU.NumberOfCores)"
Escribir "RAM: $([math]::Round($Equipo.TotalPhysicalMemory / 1GB,2)) GB"
Escribir "Windows: $($Windows.Caption)"
Escribir "Version: $($Windows.Version)"
Escribir "BIOS: $($BIOS.SMBIOSBIOSVersion)"
Escribir ""

# DISCO
Escribir "============= DISCO ========================"

$Discos = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"

foreach ($Disco in $Discos) {

    $Total = [math]::Round($Disco.Size / 1GB,2)
    $Libre = [math]::Round($Disco.FreeSpace / 1GB,2)

    Escribir "Unidad: $($Disco.DeviceID)"
    Escribir "Capacidad: $Total GB"
    Escribir "Libre: $Libre GB"
    Escribir ""
}

# RED
Escribir "============= RED =========================="

$Red = Get-NetIPConfiguration

foreach ($Adaptador in $Red) {

    if ($Adaptador.InterfaceAlias) {

        Escribir "Adaptador: $($Adaptador.InterfaceAlias)"
        Escribir "IP: $($Adaptador.IPv4Address.IPAddress)"
        Escribir "Gateway: $($Adaptador.IPv4DefaultGateway.NextHop)"
        Escribir ""
    }
}

# DISPOSITIVOS
Escribir "============= DISPOSITIVOS ================="

$Problemas = Get-PnpDevice | Where-Object {
    $_.Status -ne "OK"
}

if ($Problemas) {

    Escribir "Se encontraron dispositivos con problemas:"
    Escribir ""

    foreach ($Problema in $Problemas) {

        Escribir "Nombre: $($Problema.FriendlyName)"
        Escribir "Estado: $($Problema.Status)"
        Escribir ""
    }

}
else {

    Escribir "No se encontraron dispositivos con problemas."
}

# BATERIA
Escribir "============= BATERIA ======================"

$Bateria = Get-CimInstance Win32_Battery

if ($Bateria) {

    Escribir "Carga: $($Bateria.EstimatedChargeRemaining)%"
    Escribir "Estado: $($Bateria.Status)"

}
else {

    Escribir "No se detecto bateria."
}

Escribir ""

# FINAL
Escribir "============================================"
Escribir "       DIAGNOSTICO FINALIZADO"
Escribir "============================================"
Escribir ""
Escribir "Informe guardado en:"
Escribir $Informe

Write-Host ""
Write-Host "Diagnostico terminado." -ForegroundColor Green
Write-Host "Informe: $Informe" -ForegroundColor Cyan
