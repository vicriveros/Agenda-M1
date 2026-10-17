# Servidor Local de Persistencia para Mi Planificador Academico
param([int]$Port = 8080)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

$htmlCandidates = @(
    (Join-Path $scriptDir "index.html"),
    (Join-Path $scriptDir "Mi Planificador App.html")
)
$htmlFile = $null
foreach ($cand in $htmlCandidates) {
    if (Test-Path $cand) {
        $htmlFile = $cand
        break
    }
}

if (-not $htmlFile) {
    Write-Host "[ERROR] No se encontro el archivo HTML de la aplicacion." -ForegroundColor Red
    pause
    exit 1
}

$jsonFile = Join-Path $scriptDir "datos_planificador.json"
$csvFile = Join-Path $scriptDir "notas.csv"

# Buscar puerto disponible
$listener = $null
$boundPort = $Port
for ($p = $Port; $p -le ($Port + 10); $p++) {
    try {
        $tempListener = New-Object System.Net.HttpListener
        $tempListener.Prefixes.Add("http://localhost:$p/")
        $tempListener.Start()
        $listener = $tempListener
        $boundPort = $p
        break
    } catch {
        if ($tempListener) { $tempListener.Close() }
    }
}

if (-not $listener) {
    Write-Host "[ERROR] No se pudo vincular ningun puerto HTTP entre $Port y $($Port + 10)." -ForegroundColor Red
    pause
    exit 1
}

# Obtener IP local para acceso desde el telefono / red Wi-Fi
$localIp = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" } | Select-Object -First 1).IPAddress

Clear-Host
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "     AGENDA M1 - SERVIDOR LOCAL & ACCESO EN DISPOSITIVOS         " -ForegroundColor White
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  [OK] En tu Computador: " -NoNewline -ForegroundColor Green
Write-Host "http://localhost:$boundPort/" -ForegroundColor Yellow
if ($localIp) {
    Write-Host "  [OK] En tu Telefono (misma red Wi-Fi): " -NoNewline -ForegroundColor Green
    Write-Host "http://${localIp}:$boundPort/" -ForegroundColor Cyan
}
Write-Host "  [OK] Guardado en disco habilitado:" -ForegroundColor Green
Write-Host "       * JSON: $jsonFile" -ForegroundColor Gray
Write-Host "       * CSV:  $csvFile" -ForegroundColor Gray
Write-Host "-----------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "  Todos los cambios que hagas en el navegador se guardan de" -ForegroundColor White
Write-Host "  forma automatica y permanente en estos archivos." -ForegroundColor White
Write-Host "  Para salir, puedes cerrar esta ventana o presionar Ctrl + C." -ForegroundColor Gray
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ""

# Abrir el navegador automaticamente
Start-Process "http://localhost:$boundPort/"

try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response
        $rawPath = $request.Url.AbsolutePath

        if ($rawPath -eq "/" -or $rawPath -like "*index.html*" -or $rawPath -like "*Mi%20Planificador*") {
            $bytes = [System.IO.File]::ReadAllBytes($htmlFile)
            $response.ContentType = "text/html; charset=utf-8"
            $response.ContentLength64 = $bytes.Length
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
        }
        elseif ($rawPath -eq "/api/load" -and $request.HttpMethod -eq "GET") {
            if (Test-Path $jsonFile) {
                $bytes = [System.IO.File]::ReadAllBytes($jsonFile)
            } else {
                $bytes = [System.Text.Encoding]::UTF8.GetBytes("null")
            }
            $response.ContentType = "application/json; charset=utf-8"
            $response.ContentLength64 = $bytes.Length
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
        }
        elseif ($rawPath -eq "/api/save" -and $request.HttpMethod -eq "POST") {
            $reader = New-Object System.IO.StreamReader($request.InputStream, [System.Text.Encoding]::UTF8)
            $body = $reader.ReadToEnd()
            $reader.Close()

            try {
                $data = $body | ConvertFrom-Json
                if ($data.courses) {
                    $jsonString = $data.courses | ConvertTo-Json -Depth 10
                    [System.IO.File]::WriteAllText($jsonFile, $jsonString, [System.Text.Encoding]::UTF8)
                }
                if ($data.csv) {
                    [System.IO.File]::WriteAllText($csvFile, $data.csv, [System.Text.Encoding]::UTF8)
                }
                
                $time = (Get-Date).ToString("HH:mm:ss")
                Write-Host "  [$time] [GUARDADO] Cambios guardados en datos_planificador.json y notas.csv" -ForegroundColor Green

                $respStr = '{"status":"ok","message":"Guardado en disco exitosamente"}'
                $bytes = [System.Text.Encoding]::UTF8.GetBytes($respStr)
                $response.ContentType = "application/json; charset=utf-8"
                $response.ContentLength64 = $bytes.Length
                $response.OutputStream.Write($bytes, 0, $bytes.Length)
            } catch {
                $errMsg = $_.Exception.Message
                Write-Host "  [ERROR] al procesar guardado: $errMsg" -ForegroundColor Red
                $response.StatusCode = 500
            }
        }
        else {
            $response.StatusCode = 404
        }

        $response.Close()
    }
}
finally {
    if ($listener) {
        $listener.Stop()
        $listener.Close()
    }
}

