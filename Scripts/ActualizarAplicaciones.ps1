```powershell
# ============================================================
# SOPORTETI - ACTUALIZACION DE APLICACIONES V2
# Actualizacion automatica mediante WinGet
# Detecta aplicaciones, actualiza y genera informe
# NO REINICIA AUTOMATICAMENTE
# ============================================================

$ErrorActionPreference = "Continue"

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

# ============================================================
# CONTADORES
# ============================================================

$Encontradas = 0
$Actualizadas = 0
$Fallidas = 0
$Pendientes = 0

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
Log "       SOPORTETI - ACTUALIZACION DE APLICACIONES V2"
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

    Log "[ERROR] WinGet no esta disponible."

    Log ""
    Log "POSIBLE CAUSA:"
    Log "Windows Package Manager no esta instalado o no esta disponible."

    Log ""
    Log "SOLUCION:"
    Log "Actualizar Windows y comprobar que Microsoft App Installer este instalado."

    Log ""
    Log "ESTADO: NO SE PUEDE CONTINUAR"
    Log "Informe: $Informe"

    Read-Host "Presiona ENTER para salir"
    exit
}

Log "[OK] WinGet encontrado."
Log "Version: $(& winget --version)"

# ============================================================
# BUSCAR ACTUALIZACIONES
# ============================================================

Separador
Log "================ BUSQUEDA DE ACTUALIZACIONES ==============="

Log "Consultando aplicaciones..."
Log ""

$Busqueda = @(
    & winget upgrade `
        --include-unknown `
        --source winget `
        --accept-source-agreements `
        --disable-interactivity 2>&1
)

$TextoBusqueda = $Busqueda -join "`n"

# Guardar busqueda
$Busqueda |
    Out-File -FilePath $Informe -Append -Encoding UTF8

# ============================================================
# NO HAY ACTUALIZACIONES
# ============================================================

if ($TextoBusqueda -match "No upgrades available") {

    Log ""
    Log "[OK] No se encontraron actualizaciones disponibles."

    $Encontradas = 0

}
else {

    # ========================================================
    # MOSTRAR RESULTADOS
    # ========================================================

    Log ""
    Log "Aplicaciones encontradas con posible actualizacion:"
    Log ""

    foreach ($Linea in $Busqueda) {

        if (
            $Linea -match "winget" -or
            $Linea -match "Disponible" -or
            $Linea -match "Version"
        ) {

            Log $Linea
        }
    }

    # ========================================================
    # CONTAR APLICACIONES
    # ========================================================

    foreach ($Linea in $Busqueda) {

        if (
            $Linea -match "^\s*\S.+\s{2,}\S+\s{2,}\S+\s{2,}\S+.*winget\s*$"
        ) {

            $Encontradas++
        }
    }

    # Si no pudo determinar el numero, intentamos con
    # la linea de "actualizaciones disponibles".

    if ($Encontradas -eq 0) {

        if ($TextoBusqueda -match "(\d+)\s+actualizaciones?\s+disponibles?") {

            $Encontradas = [int]$Matches[1]
        }
    }

    Log ""
    Log "Actualizaciones detectadas: $Encontradas"
}

# ============================================================
# SI NO HAY NADA QUE ACTUALIZAR
# ============================================================

if ($Encontradas -eq 0 -and
    $TextoBusqueda -match "No upgrades available") {

    $Fin = Get-Date
    $Duracion = $Fin - $Inicio

    Separador
    Log "================ RESULTADO FINAL ==========================="

    Log "Aplicaciones encontradas : 0"
    Log "Actualizadas             : 0"
    Log "Fallidas                 : 0"
    Log "Pendientes               : 0"

    Log ""
    Log "ESTADO: EQUIPO ACTUALIZADO"

    Log ""
    Log "Duracion: $($Duracion.ToString('hh\:mm\:ss'))"

    Log ""
    Log "No es necesario reiniciar el equipo."

    Log ""
    Log "Informe:"
    Log $Informe

    Read-Host "Presiona ENTER para salir"
    exit
}

# ============================================================
# ACTUALIZAR
# ============================================================

Separador
Log "================ ACTUALIZANDO ==============================="

Log "Iniciando actualizacion automatica..."
Log ""

$Resultado = @(
    & winget upgrade `
        --all `
        --include-unknown `
        --silent `
        --accept-package-agreements `
        --accept-source-agreements `
        --disable-interactivity 2>&1
)

$CodigoSalida = $LASTEXITCODE

# Guardar salida
$Resultado |
    Out-File -FilePath $Informe -Append -Encoding UTF8

# Mostrar salida
foreach ($Linea in $Resultado) {

    if (
        $Linea -match "Instalado correctamente" -or
        $Linea -match "Successfully installed" -or
        $Linea -match "Successfully updated" -or
        $Linea -match "Successfully"
    ) {

        Write-Host "[OK] $Linea"

    }
    elseif (
        $Linea -match "Error" -or
        $Linea -match "Failed" -or
        $Linea -match "failed"
    ) {

        Write-Host "[ERROR] $Linea"

    }
    else {

        Write-Host $Linea
    }
}

# ============================================================
# DETERMINAR ACTUALIZACIONES EXITOSAS
# ============================================================

$TextoResultado = $Resultado -join "`n"

$Exitos = @(
    $Resultado |
    Where-Object {
        $_ -match "Instalado correctamente" -or
        $_ -match "Successfully installed" -or
        $_ -match "Successfully updated"
    }
)

if ($Exitos.Count -gt 0) {

    $Actualizadas = $Exitos.Count
}

# ============================================================
# DETECTAR ERRORES
# ============================================================

$Errores = @(
    $Resultado |
    Where-Object {
        $_ -match "Error" -or
        $_ -match "Failed" -or
        $_ -match "failed"
    }
)

if ($Errores.Count -gt 0) {

    $Fallidas = $Errores.Count
}

# ============================================================
# COMPROBACION FINAL
# ============================================================

Separador
Log "================ COMPROBACION FINAL ======================="

Log "Consultando nuevamente WinGet..."
Log ""

$Final = @(
    & winget upgrade `
        --include-unknown `
        --source winget `
        --accept-source-agreements `
        --disable-interactivity 2>&1
)

$TextoFinal = $Final -join "`n"

$Final |
    Out-File -FilePath $Informe -Append -Encoding UTF8

if ($TextoFinal -match "No upgrades available") {

    $Pendientes = 0

    Log "[OK] No quedan actualizaciones pendientes."

}
else {

    # Intentar obtener cantidad pendiente
    if (
        $TextoFinal -match
        "(\d+)\s+actualizaciones?\s+disponibles?"
    ) {

        $Pendientes = [int]$Matches[1]

    }
    else {

        $Pendientes = 1
    }

    Log "[ADVERTENCIA] Todavia existen actualizaciones pendientes: $Pendientes"
}

# ============================================================
# RESULTADO
# ============================================================

$Fin = Get-Date
$Duracion = $Fin - $Inicio

Separador
Log "================ RESULTADO FINAL ==========================="

Log ""
Log "Aplicaciones encontradas : $Encontradas"
Log "Aplicaciones actualizadas: $Actualizadas"
Log "Actualizaciones fallidas : $Fallidas"
Log "Actualizaciones pendientes: $Pendientes"

Log ""

if (
    $Fallidas -eq 0 -and
    $Pendientes -eq 0
) {

    Log "ESTADO GENERAL: COMPLETADO CORRECTAMENTE"

}
elseif (
    $Actualizadas -gt 0 -and
    $Pendientes -gt 0
) {

    Log "ESTADO GENERAL: COMPLETADO CON PENDIENTES"

}
elseif ($Fallidas -gt 0) {

    Log "ESTADO GENERAL: REQUIERE REVISION"

}
else {

    Log "ESTADO GENERAL: COMPLETADO CON OBSERVACIONES"
}

Log ""
Log "Duracion: $($Duracion.ToString('hh\:mm\:ss'))"

Log ""
Log "REINICIO:"
Log "No se realizara ningun reinicio automatico."

Log ""
Log "Informe guardado en:"
Log $Informe

# ============================================================
# PANTALLA FINAL
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host "       SOPORTETI - ACTUALIZACION FINALIZADA"
Write-Host "============================================================"
Write-Host ""

if (
    $Fallidas -eq 0 -and
    $Pendientes -eq 0
) {

    Write-Host "ESTADO: COMPLETADO CORRECTAMENTE"

}
elseif ($Fallidas -gt 0) {

    Write-Host "ESTADO: REQUIERE REVISION"

}
else {

    Write-Host "ESTADO: COMPLETADO CON PENDIENTES"
}

Write-Host ""
Write-Host "Encontradas : $Encontradas"
Write-Host "Actualizadas: $Actualizadas"
Write-Host "Fallidas    : $Fallidas"
Write-Host "Pendientes  : $Pendientes"
Write-Host ""
Write-Host "Informe:"
Write-Host $Informe
Write-Host ""

Read-Host "Presiona ENTER para salir"
```


Read-Host "Presiona ENTER para salir"
```

