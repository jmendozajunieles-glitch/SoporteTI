# ============================================================
# SOPORTETI - ACTUALIZADOR DE APLICACIONES V1
# Actualiza aplicaciones mediante Windows Package Manager
# NO REINICIA EL EQUIPO AUTOMATICAMENTE
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
$Informe = "$Logs\ActualizacionApps_$Fecha.txt"

$Inicio = Get-Date

# Contadores
$Encontradas = 0
$Actualizadas = 0
$Fallidas = 0
$SinActualizar = 0

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

function Separador {

    Log ""
    Log "============================================================"
}

# ============================================================
# CABECERA
# ============================================================

Log "============================================================"
Log "       SOPORTETI - ACTUALIZACION DE APLICACIONES V1"
Log "============================================================"
Log "Equipo : $env:COMPUTERNAME"
Log "Usuario: $env:USERNAME"
Log "Fecha  : $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')"
Log "============================================================"

# ============================================================
# COMPROBAR WINGET
# ============================================================

Separador
Log "================ COMPROBANDO WINGET ========================"

$Winget = Get-Command winget -ErrorAction SilentlyContinue

if (-not $Winget) {

    Log "[ERROR] Winget no esta disponible en este equipo."
    Log ""
    Log "POSIBLE CAUSA:"
    Log "Windows Package Manager no esta instalado o no esta disponible para este usuario."
    Log ""
    Log "SOLUCION:"
    Log "Actualizar Windows y comprobar que App Installer este instalado desde Microsoft Store."
    Log ""
    Log "El proceso no puede continuar."

    Log ""
    Log "Informe:"
    Log $Informe

    Read-Host "Presiona ENTER para salir"
    exit
}

Log "[OK] Winget encontrado."
Log "Version: $(& winget --version)"

# ============================================================
# BUSCAR ACTUALIZACIONES
# ============================================================

Separador
Log "================ BUSCANDO ACTUALIZACIONES ================="

Log "Esto puede tardar unos segundos..."
Log ""

$ListaActualizaciones = & winget upgrade --accept-source-agreements 2>&1

if ($LASTEXITCODE -ne 0 -and
    ($ListaActualizaciones -join "`n") -notmatch "No upgrades available") {

    Log "[ADVERTENCIA] Winget devolvio un resultado inesperado."
}

# Guardar resultado de busqueda
$ListaActualizaciones |
    Out-File -FilePath $Informe -Append -Encoding UTF8

# ============================================================
# COMPROBAR SI EXISTEN ACTUALIZACIONES
# ============================================================

if (($ListaActualizaciones -join "`n") -match "No upgrades available") {

    Log ""
    Log "[OK] No se encontraron aplicaciones pendientes de actualizacion."

    $SinActualizar = 1

}
else {

    Log ""
    Log "Se encontraron posibles actualizaciones."
}

# ============================================================
# ACTUALIZAR APLICACIONES
# ============================================================

Separador
Log "================ ACTUALIZANDO APLICACIONES ================="

Log "Iniciando proceso..."
Log ""

# Obtener lista estructurada
$Aplicaciones = & winget upgrade `
    --source winget `
    --accept-source-agreements `
    --disable-interactivity 2>$null

if ($Aplicaciones) {

    # Mostrar lista encontrada
    foreach ($Linea in $Aplicaciones) {

        if ($Linea -match "^\s*(.+?)\s{2,}(\S+)\s{2,}(\S+)\s{2,}(\S+)") {

            Log $Linea
        }
    }
}

Log ""
Log "Ejecutando actualizacion automatica..."
Log ""

# ============================================================
# ACTUALIZACION GENERAL
# ============================================================

$ResultadoActualizacion = & winget upgrade `
    --all `
    --silent `
    --accept-package-agreements `
    --accept-source-agreements `
    --disable-interactivity 2>&1

$CodigoSalida = $LASTEXITCODE

# Guardar salida completa
$ResultadoActualizacion |
    Out-File -FilePath $Informe -Append -Encoding UTF8

# Mostrar salida
foreach ($Linea in $ResultadoActualizacion) {

    if ($Linea -match "Successfully installed|Successfully updated|Successfully") {

        Write-Host "[OK] $Linea"
    }
    elseif ($Linea -match "Failed|Error|error|failed") {

        Write-Host "[ERROR] $Linea"
    }
    else {

        Write-Host $Linea
    }
}

# ============================================================
# INTERPRETAR RESULTADO
# ============================================================

Separador
Log "================ RESULTADO DE ACTUALIZACION ================"

$TextoResultado = $ResultadoActualizacion -join "`n"

if ($TextoResultado -match "No applicable upgrade found|No upgrades available") {

    Log "[OK] No habia actualizaciones pendientes."

    $SinActualizar = 1

}
elseif ($CodigoSalida -eq 0) {

    Log "[OK] El proceso de actualizacion finalizo correctamente."

    # Intentar determinar aplicaciones actualizadas
    $LineasExito = @(
        $ResultadoActualizacion |
        Where-Object {
            $_ -match "Successfully|Successfully installed|Successfully updated"
        }
    )

    if ($LineasExito.Count -gt 0) {

        $Actualizadas = $LineasExito.Count

    }
    else {

        Log "[INFO] Winget finalizo correctamente, pero no fue posible determinar el numero exacto de aplicaciones."
    }

}
else {

    Log "[ADVERTENCIA] Algunas aplicaciones pueden no haberse actualizado."

    $Fallidas = 1
}

# ============================================================
# COMPROBACION FINAL
# ============================================================

Separador
Log "================ COMPROBACION FINAL ======================="

Log "Volviendo a consultar actualizaciones..."

$PendientesFinales = & winget upgrade `
    --accept-source-agreements `
    --disable-interactivity 2>&1

$TextoPendientes = $PendientesFinales -join "`n"

$PendientesFinales |
    Out-File -FilePath $Informe -Append -Encoding UTF8

if ($TextoPendientes -match "No upgrades available") {

    Log "[OK] No quedan actualizaciones pendientes."

}
else {

    Log "[ADVERTENCIA] Todavia existen aplicaciones que pueden tener actualizaciones pendientes."

    Log ""
    Log "Esto puede ocurrir porque:"
    Log "- La aplicacion necesita permisos adicionales."
    Log "- La aplicacion utiliza su propio actualizador."
    Log "- El paquete no pudo instalarse silenciosamente."
    Log "- La version instalada no coincide con el repositorio."
}

# ============================================================
# RESUMEN
# ============================================================

$Fin = Get-Date
$Duracion = $Fin - $Inicio

Separador
Log "================ RESUMEN FINAL ============================="

Log "Aplicaciones actualizadas : $Actualizadas"
Log "Procesos con observaciones: $Fallidas"
Log "Duracion                  : $($Duracion.ToString('hh\:mm\:ss'))"

Log ""

if ($CodigoSalida -eq 0) {

    Log "ESTADO GENERAL: COMPLETADO"

}
else {

    Log "ESTADO GENERAL: COMPLETADO CON OBSERVACIONES"
}

Log ""
Log "No se realizara ningun reinicio automatico."
Log ""
Log "Informe guardado en:"
Log $Informe

# ============================================================
# FINAL
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host "       SOPORTETI - ACTUALIZACION FINALIZADA"
Write-Host "============================================================"
Write-Host ""

if ($CodigoSalida -eq 0) {

    Write-Host "ESTADO: COMPLETADO"

}
else {

    Write-Host "ESTADO: COMPLETADO CON OBSERVACIONES"
}

Write-Host ""
Write-Host "Informe:"
Write-Host $Informe
Write-Host ""

Read-Host "Presiona ENTER para salir"
```

