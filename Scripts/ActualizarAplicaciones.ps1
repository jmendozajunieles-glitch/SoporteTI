```powershell
# ============================================================
# SOPORTETI - ACTUALIZADOR DE APLICACIONES V3
# ============================================================

$ErrorActionPreference = "SilentlyContinue"

Clear-Host

$Base = "C:\SoporteTI"
$LogDir = "$Base\Logs"
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null

$Fecha = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$Log = "$LogDir\ActualizarAplicaciones_$Fecha.txt"

function Escribir {
    param([string]$Texto)

    Write-Host $Texto
    $Texto | Out-File $Log -Append -Encoding UTF8
}

function Separador {
    Escribir ""
    Escribir "============================================================"
}

Escribir "============================================================"
Escribir "       SOPORTETI - ACTUALIZADOR DE APLICACIONES V3"
Escribir "============================================================"
Escribir "Equipo : $env:COMPUTERNAME"
Escribir "Fecha  : $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')"
Escribir "============================================================"

# ============================================================
# 1. WINGET
# ============================================================

Separador
Escribir "BUSCANDO ACTUALIZACIONES CON WINGET..."
Escribir ""

$Winget = Get-Command winget -ErrorAction SilentlyContinue

if ($Winget) {

    $ResultadoWinget = @(
        winget upgrade `
        --all `
        --include-unknown `
        --silent `
        --accept-package-agreements `
        --accept-source-agreements `
        --disable-interactivity 2>&1
    )

    $ResultadoWinget | Out-File $Log -Append -Encoding UTF8

    foreach ($Linea in $ResultadoWinget) {
        Write-Host $Linea
    }

    if ($LASTEXITCODE -eq 0) {
        Escribir ""
        Escribir "[OK] Proceso WinGet finalizado."
    }
    else {
        Escribir ""
        Escribir "[INFO] WinGet finalizo con observaciones."
    }

}
else {

    Escribir "[INFO] WinGet no esta disponible."
}

# ============================================================
# 2. MICROSOFT STORE
# ============================================================

Separador
Escribir "ACTUALIZANDO APLICACIONES DE MICROSOFT STORE..."
Escribir ""

try {

    $Store = Get-Command winget -ErrorAction Stop

    $ResultadoStore = @(
        winget upgrade `
        --source msstore `
        --all `
        --silent `
        --accept-package-agreements `
        --accept-source-agreements `
        --disable-interactivity 2>&1
    )

    $ResultadoStore | Out-File $Log -Append -Encoding UTF8

    foreach ($Linea in $ResultadoStore) {
        Write-Host $Linea
    }

    Escribir ""
    Escribir "[OK] Comprobacion de Microsoft Store finalizada."

}
catch {

    Escribir "[INFO] No fue posible utilizar Microsoft Store mediante WinGet."
}

# ============================================================
# 3. PROGRAMAS INSTALADOS
# ============================================================

Separador
Escribir "ANALIZANDO PROGRAMAS INSTALADOS..."
Escribir ""

$Programas = @()

$Rutas = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

foreach ($Ruta in $Rutas) {

    $Datos = Get-ItemProperty $Ruta -ErrorAction SilentlyContinue

    foreach ($Programa in $Datos) {

        if (
            $Programa.DisplayName -and
            $Programa.DisplayVersion
        ) {

            $Programas += [PSCustomObject]@{
                Nombre = $Programa.DisplayName
                Version = $Programa.DisplayVersion
                Fabricante = $Programa.Publisher
            }
        }
    }
}

$Programas = $Programas |
    Sort-Object Nombre, Version -Unique

Escribir "Aplicaciones instaladas detectadas: $($Programas.Count)"

# ============================================================
# 4. COMPARACION CON WINGET
# ============================================================

Separador
Escribir "COMPROBANDO APLICACIONES NO DETECTADAS POR WINGET..."
Escribir ""

$ListaWinget = @()

if ($Winget) {

    $ListaWinget = @(
        winget list --source winget `
        --accept-source-agreements `
        --disable-interactivity 2>&1
    )
}

$NoDetectadas = 0

foreach ($Programa in $Programas) {

    $Encontrado = $false

    foreach ($Linea in $ListaWinget) {

        if (
            $Linea -match [regex]::Escape($Programa.Nombre)
        ) {

            $Encontrado = $true
            break
        }
    }

    if (-not $Encontrado) {

        $NoDetectadas++

        Escribir "[INFO] No administrada por WinGet:"
        Escribir "       $($Programa.Nombre)"
        Escribir "       Version: $($Programa.Version)"
        Escribir ""
    }
}

# ============================================================
# 5. RESULTADO
# ============================================================

Separador
Escribir "================ RESULTADO ================================"
Escribir ""

Escribir "Aplicaciones instaladas detectadas : $($Programas.Count)"
Escribir "No administradas por WinGet        : $NoDetectadas"

Escribir ""
Escribir "WinGet:"
Escribir "Se ejecuto la actualizacion automatica."

Escribir ""
Escribir "IMPORTANTE:"
Escribir "Las aplicaciones que no aparecen en WinGet"
Escribir "requieren su propio mecanismo de actualizacion"
Escribir "o una actualizacion manual."

# ============================================================
# 6. DURACION
# ============================================================

Escribir ""

$Fin = Get-Date

Escribir "============================================================"
Escribir "ESTADO: COMPLETADO"
Escribir "============================================================"
Escribir ""
Escribir "No se realizara ningun reinicio automatico."
Escribir ""
Escribir "Informe:"
Escribir $Log
Escribir ""

Read-Host "Presiona ENTER para salir"
```
