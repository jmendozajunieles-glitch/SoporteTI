```powershell
# ============================================================
# SOPORTETI - DIAGNOSTICO V4
# Diagnostico completo de hardware, Windows, red y seguridad
# Solo lectura - NO realiza cambios en el equipo
# ============================================================

$ErrorActionPreference = "SilentlyContinue"

# ============================================================
# CONFIGURACION
# ============================================================

$Base = "C:\SoporteTI"
$Logs = "$Base\Logs"

New-Item -ItemType Directory -Path $Logs -Force | Out-Null

$FechaArchivo = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$Fecha = Get-Date -Format "dd/MM/yyyy HH:mm:ss"

$Informe = "$Logs\Diagnostico_$FechaArchivo.txt"

$Usuario = $env:USERNAME
$EquipoNombre = $env:COMPUTERNAME

$Problemas = @()
$Advertencias = @()

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

function Agregar-Problema {
    param([string]$Texto)

    $script:Problemas += $Texto
}

function Agregar-Advertencia {
    param([string]$Texto)

    $script:Advertencias += $Texto
}

# ============================================================
# INICIO
# ============================================================

Clear-Host

Escribir "============================================================"
Escribir "                  SOPORTETI V4"
Escribir "============================================================"
Escribir "Técnico/Usuario : $Usuario"
Escribir "Equipo           : $EquipoNombre"
Escribir "Fecha            : $Fecha"
Escribir "============================================================"
Escribir ""

# ============================================================
# INFORMACION DEL EQUIPO
# ============================================================

Escribir "================ INFORMACION DEL EQUIPO ===================="

$Equipo = Get-CimInstance Win32_ComputerSystem
$CPU = Get-CimInstance Win32_Processor | Select-Object -First 1
$Windows = Get-CimInstance Win32_OperatingSystem
$BIOS = Get-CimInstance Win32_BIOS
$Placa = Get-CimInstance Win32_BaseBoard

$RAMTotalGB = [math]::Round($Equipo.TotalPhysicalMemory / 1GB, 2)

Escribir "Fabricante       : $($Equipo.Manufacturer)"
Escribir "Modelo           : $($Equipo.Model)"
Escribir "Numero de serie  : $($BIOS.SerialNumber)"
Escribir "Placa base       : $($Placa.Manufacturer) $($Placa.Product)"
Escribir "Procesador       : $($CPU.Name)"
Escribir "Nucleos          : $($CPU.NumberOfCores)"
Escribir "Hilos            : $($CPU.NumberOfLogicalProcessors)"
Escribir "RAM instalada    : $RAMTotalGB GB"
Escribir "Windows          : $($Windows.Caption)"
Escribir "Version          : $($Windows.Version)"
Escribir "Build            : $($Windows.BuildNumber)"
Escribir "Arquitectura     : $($Windows.OSArchitecture)"
Escribir "BIOS             : $($BIOS.SMBIOSBIOSVersion)"
Escribir "Ultimo arranque  : $($Windows.LastBootUpTime)"

# Tiempo desde el ultimo arranque
$UltimoArranque = $Windows.LastBootUpTime
$TiempoEncendido = (Get-Date) - $UltimoArranque

Escribir "Tiempo encendido : $([math]::Round($TiempoEncendido.TotalHours, 1)) horas"

if ($TiempoEncendido.TotalDays -ge 7) {

    Agregar-Advertencia "El equipo lleva mas de 7 dias sin reiniciarse."
}

# ============================================================
# GPU
# ============================================================

Separador

Escribir "================ TARJETA GRAFICA ==========================="

$GPU = Get-CimInstance Win32_VideoController

foreach ($Tarjeta in $GPU) {

    if ($Tarjeta.Name) {

        if ($Tarjeta.AdapterRAM) {
            $MemoriaGPU = [math]::Round($Tarjeta.AdapterRAM / 1GB, 2)
        }
        else {
            $MemoriaGPU = "No disponible"
        }

        Escribir "GPU       : $($Tarjeta.Name)"
        Escribir "Memoria   : $MemoriaGPU GB"
        Escribir "Driver    : $($Tarjeta.DriverVersion)"
        Escribir "Fecha     : $($Tarjeta.DriverDate)"
        Escribir ""
    }
}

# ============================================================
# ALMACENAMIENTO
# ============================================================

Escribir "================ ALMACENAMIENTO ============================"

$Discos = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"

foreach ($Disco in $Discos) {

    if ($Disco.Size -gt 0) {

        $Total = [math]::Round($Disco.Size / 1GB, 2)
        $Libre = [math]::Round($Disco.FreeSpace / 1GB, 2)
        $Usado = [math]::Round($Total - $Libre, 2)
        $PorcentajeLibre = [math]::Round(($Libre / $Total) * 100, 1)

        Escribir "Unidad          : $($Disco.DeviceID)"
        Escribir "Capacidad       : $Total GB"
        Escribir "Usado           : $Usado GB"
        Escribir "Disponible      : $Libre GB"
        Escribir "Espacio libre   : $PorcentajeLibre%"

        if ($PorcentajeLibre -lt 10) {

            Escribir "ESTADO: CRITICO"
            Agregar-Problema "Espacio critico en $($Disco.DeviceID): $PorcentajeLibre% libre."

        }
        elseif ($PorcentajeLibre -lt 20) {

            Escribir "ESTADO: ADVERTENCIA"
            Agregar-Advertencia "Poco espacio disponible en $($Disco.DeviceID): $PorcentajeLibre% libre."

        }
        else {

            Escribir "ESTADO: OK"
        }

        Escribir ""
    }
}

# ============================================================
# DISCOS FISICOS
# ============================================================

Escribir "================ DISCOS FISICOS ============================"

$DiscosFisicos = Get-PhysicalDisk

if ($DiscosFisicos) {

    foreach ($DiscoFisico in $DiscosFisicos) {

        Escribir "Nombre     : $($DiscoFisico.FriendlyName)"
        Escribir "Tipo       : $($DiscoFisico.MediaType)"
        Escribir "Tamaño     : $([math]::Round($DiscoFisico.Size / 1GB, 2)) GB"
        Escribir "Estado     : $($DiscoFisico.HealthStatus)"
        Escribir ""

        if ($DiscoFisico.HealthStatus -notin @("Healthy", "Unknown")) {

            Agregar-Problema "Disco fisico con estado: $($DiscoFisico.HealthStatus)"
        }
    }
}
else {

    Escribir "No fue posible consultar los discos fisicos."
}

# ============================================================
# BATERIA
# ============================================================

Escribir "================ BATERIA ==================================="

$Baterias = Get-CimInstance Win32_Battery

if ($Baterias) {

    foreach ($Bateria in $Baterias) {

        Escribir "Carga actual : $($Bateria.EstimatedChargeRemaining)%"
        Escribir "Estado       : $($Bateria.Status)"

        if ($Bateria.EstimatedChargeRemaining -lt 15) {

            Agregar-Advertencia "La bateria tiene menos del 15% de carga."
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

    Escribir "Adaptador : $($Adaptador.Name)"
    Escribir "Tipo      : $($Adaptador.InterfaceDescription)"
    Escribir "Estado    : $($Adaptador.Status)"
    Escribir "Velocidad : $($Adaptador.LinkSpeed)"

    if ($Adaptador.Status -eq "Up") {

        $IPConfig = Get-NetIPConfiguration -InterfaceIndex $Adaptador.ifIndex

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
# PRUEBA DE GATEWAY
# ============================================================

Escribir "================ CONECTIVIDAD ==============================="

$AdaptadorActivo = Get-NetIPConfiguration |
    Where-Object {
        $_.NetAdapter.Status -eq "Up" -and
        $_.IPv4DefaultGateway
    } |
    Select-Object -First 1

if ($AdaptadorActivo) {

    $GatewayPrincipal = $AdaptadorActivo.IPv4DefaultGateway.NextHop

    Escribir "Gateway detectado : $GatewayPrincipal"

    $PingGateway = Test-Connection `
        -ComputerName $GatewayPrincipal `
        -Count 2 `
        -Quiet

    if ($PingGateway) {

        Escribir "Gateway           : RESPONDE"

    }
    else {

        Escribir "Gateway           : SIN RESPUESTA"
        Agregar-Problema "El gateway principal no responde a ping."
    }
}

# ============================================================
# PRUEBA DE INTERNET
# ============================================================

$Internet = Test-Connection `
    -ComputerName 8.8.8.8 `
    -Count 2 `
    -Quiet

if ($Internet) {

    Escribir "Internet          : CONECTADO"

}
else {

    Escribir "Internet          : SIN RESPUESTA"
    Agregar-Problema "No se obtuvo respuesta de Internet."
}

# ============================================================
# DNS
# ============================================================

$DNSPrueba = Resolve-DnsName `
    -Name "www.microsoft.com" `
    -ErrorAction SilentlyContinue

if ($DNSPrueba) {

    Escribir "Resolucion DNS    : OK"

}
else {

    Escribir "Resolucion DNS    : ERROR"
    Agregar-Problema "La resolucion DNS presenta problemas."
}

# ============================================================
# DISPOSITIVOS CON ERRORES
# ============================================================

Separador

Escribir "================ DISPOSITIVOS ==============================="

$DispositivosError = Get-PnpDevice | Where-Object {
    $_.Status -eq "Error"
}

if ($DispositivosError) {

    foreach ($Dispositivo in $DispositivosError) {

        Escribir "ESTADO: ERROR"
        Escribir "Nombre : $($Dispositivo.FriendlyName)"
        Escribir "Clase  : $($Dispositivo.Class)"
        Escribir "ID     : $($Dispositivo.InstanceId)"
        Escribir ""

        Agregar-Problema "Dispositivo con error: $($Dispositivo.FriendlyName)"
    }

}
else {

    Escribir "ESTADO: OK"
    Escribir "No se encontraron dispositivos con estado ERROR."
}

# ============================================================
# DRIVERS PRINCIPALES
# ============================================================

Escribir "================ DRIVERS PRINCIPALES ========================"

$Drivers = Get-CimInstance Win32_PnPSignedDriver |
    Where-Object {
        $_.DeviceName -and
        $_.DriverVersion
    }

$DriversImportantes = $Drivers |
    Where-Object {
        $_.DeviceName -match "AMD|Radeon|Realtek|MediaTek|Intel|NVIDIA|Qualcomm|Bluetooth|Wi-Fi|Wireless|Ethernet"
    } |
    Sort-Object DeviceName -Unique

foreach ($Driver in $DriversImportantes) {

    Escribir "Dispositivo : $($Driver.DeviceName)"
    Escribir "Fabricante  : $($Driver.Manufacturer)"
    Escribir "Version     : $($Driver.DriverVersion)"
    Escribir "Fecha       : $($Driver.DriverDate)"
    Escribir ""
}

# ============================================================
# SEGURIDAD / ANTIVIRUS
# ============================================================

Separador

Escribir "================ SEGURIDAD ================================="

$Defender = Get-MpComputerStatus

if ($Defender) {

    Escribir "Microsoft Defender"
    Escribir "Antivirus activo       : $($Defender.AntivirusEnabled)"
    Escribir "Proteccion tiempo real : $($Defender.RealTimeProtectionEnabled)"
    Escribir ""
}

$Antivirus = Get-CimInstance `
    -Namespace "root\SecurityCenter2" `
    -ClassName AntiVirusProduct

if ($Antivirus) {

    Escribir "Antivirus registrados:"

    foreach ($AV in $Antivirus) {

        Escribir "Proveedor : $($AV.displayName)"
        Escribir "Estado    : $($AV.productState)"
        Escribir ""
    }

}
else {

    Escribir "No se encontraron antivirus registrados."
    Agregar-Problema "No se detecto un antivirus registrado."
}

# ============================================================
# FIREWALL
# ============================================================

Escribir "================ FIREWALL ==================================="

$Firewall = Get-NetFirewallProfile

foreach ($Perfil in $Firewall) {

    if ($Perfil.Enabled) {

        Escribir "$($Perfil.Name): ACTIVO"

    }
    else {

        Escribir "$($Perfil.Name): DESACTIVADO"

        Agregar-Advertencia "Firewall $($Perfil.Name) desactivado."
    }
}

# ============================================================
# WINDOWS UPDATE
# ============================================================

Separador

Escribir "================ WINDOWS UPDATE ============================="

$Updates = Get-HotFix |
    Sort-Object InstalledOn -Descending |
    Select-Object -First 10

if ($Updates) {

    Escribir "Ultimas actualizaciones instaladas:"
    Escribir ""

    foreach ($Update in $Updates) {

        Escribir "$($Update.HotFixID) - $($Update.InstalledOn)"
    }
}
else {

    Escribir "No fue posible consultar actualizaciones."
}

# ============================================================
# MEMORIA RAM
# ============================================================

Separador

Escribir "================ MEMORIA RAM ================================"

$RAMLibreGB = [math]::Round($Windows.FreePhysicalMemory / 1MB, 2)
$RAMUsadaGB = [math]::Round($RAMTotalGB - $RAMLibreGB, 2)

$PorcentajeRAM = [math]::Round(
    ($RAMUsadaGB / $RAMTotalGB) * 100,
    1
)

Escribir "RAM instalada    : $RAMTotalGB GB"
Escribir "RAM usada        : $RAMUsadaGB GB"
Escribir "RAM disponible   : $RAMLibreGB GB"
Escribir "Uso de RAM       : $PorcentajeRAM%"

if ($PorcentajeRAM -ge 95) {

    Escribir "ESTADO: CRITICO"
    Agregar-Advertencia "Uso de RAM muy elevado: $PorcentajeRAM%."

}
elseif ($PorcentajeRAM -ge 85) {

    Escribir "ESTADO: ALTO"
    Agregar-Advertencia "Uso de RAM elevado: $PorcentajeRAM%."

}
elseif ($PorcentajeRAM -ge 70) {

    Escribir "ESTADO: MODERADO"

}
else {

    Escribir "ESTADO: NORMAL"
}

# ============================================================
# PROCESOS
# ============================================================

Escribir ""
Escribir "================ PROCESOS ==================================="

$Procesos = Get-Process |
    Sort-Object WorkingSet64 -Descending |
    Select-Object -First 10

Escribir "Procesos con mayor consumo de memoria:"
Escribir ""

foreach ($Proceso in $Procesos) {

    $Memoria = [math]::Round(
        $Proceso.WorkingSet64 / 1MB,
        2
    )

    Escribir "$($Proceso.ProcessName) - $Memoria MB"
}

# ============================================================
# SERVICIOS IMPORTANTES
# ============================================================

Separador

Escribir "================ SERVICIOS =================================="

$ServiciosImportantes = @(
    "wuauserv",
    "WinDefend",
    "MpsSvc",
    "BITS",
    "Dhcp",
    "Dnscache"
)

foreach ($NombreServicio in $ServiciosImportantes) {

    $Servicio = Get-Service -Name $NombreServicio

    if ($Servicio) {

        Escribir "$($Servicio.DisplayName): $($Servicio.Status)"
    }
}

# ============================================================
# RESULTADO FINAL
# ============================================================

Separador

Escribir "                  RESUMEN TECNICO"
Escribir "============================================================"

Escribir ""

if ($Problemas.Count -eq 0) {

    Escribir "✓ PROBLEMAS CRITICOS: 0"

}
else {

    Escribir "X PROBLEMAS CRITICOS: $($Problemas.Count)"
}

if ($Advertencias.Count -eq 0) {

    Escribir "✓ ADVERTENCIAS: 0"

}
else {

    Escribir "⚠ ADVERTENCIAS: $($Advertencias.Count)"
}

Escribir ""

# ------------------------------------------------------------
# PROBLEMAS
# ------------------------------------------------------------

if ($Problemas.Count -gt 0) {

    Escribir "PROBLEMAS ENCONTRADOS:"
    Escribir ""

    foreach ($Problema in $Problemas) {

        Escribir "[PROBLEMA] $Problema"
    }

    Escribir ""
}

# ------------------------------------------------------------
# ADVERTENCIAS
# ------------------------------------------------------------

if ($Advertencias.Count -gt 0) {

    Escribir "ADVERTENCIAS:"
    Escribir ""

    foreach ($Advertencia in $Advertencias) {

        Escribir "[ADVERTENCIA] $Advertencia"
    }

    Escribir ""
}

# ------------------------------------------------------------
# ESTADO GENERAL
# ------------------------------------------------------------

if ($Problemas.Count -gt 0) {

    Escribir "ESTADO GENERAL: REQUIERE ATENCION"

}
elseif ($Advertencias.Count -gt 0) {

    Escribir "ESTADO GENERAL: REQUIERE REVISION"

}
else {

    Escribir "ESTADO GENERAL: OK"
}

Separador

Escribir "Diagnostico finalizado."
Escribir "Informe guardado en:"
Escribir $Informe

# ============================================================
# PANTALLA FINAL
# ============================================================

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "              SOPORTETI V4 FINALIZADO" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

if ($Problemas.Count -gt 0) {

    Write-Host "PROBLEMAS CRITICOS: $($Problemas.Count)" -ForegroundColor Red

}
else {

    Write-Host "PROBLEMAS CRITICOS: 0" -ForegroundColor Green
}

if ($Advertencias.Count -gt 0) {

    Write-Host "ADVERTENCIAS: $($Advertencias.Count)" -ForegroundColor Yellow

}
else {

    Write-Host "ADVERTENCIAS: 0" -ForegroundColor Green
}

Write-Host ""
Write-Host "Informe:" -ForegroundColor Green
Write-Host $Informe -ForegroundColor Yellow
Write-Host ""

Read-Host "Presiona ENTER para salir"
```
