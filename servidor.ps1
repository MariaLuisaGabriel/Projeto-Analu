# Servidor local do Cronograma SES-DF 2027.
# Escuta só em 127.0.0.1 e grava o progresso em dados\cronograma.json.
param(
    [switch]$SemNavegador,
    [int]$Porta = 8765,
    [string]$Arquivo
)

$ErrorActionPreference = 'Stop'
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
} catch {}

$root = $PSScriptRoot
$port = $Porta
$prefix = "http://127.0.0.1:$port/"
if ([string]::IsNullOrWhiteSpace($Arquivo)) {
    $dataDir = Join-Path $root 'dados'
    $dataFile = Join-Path $dataDir 'cronograma.json'
} else {
    $dataFile = $Arquivo
    $dataDir = Split-Path -Parent $dataFile
}
$htmlFile = Join-Path $root 'cronograma_ses_df_2027.html'
$script:lastWriteMs = [int64]0
$script:emptyState = '{"revisions":{},"classesText":{},"classesDone":{},"shifts":{}}'
$maxBytes = 2MB

Add-Type -AssemblyName System.Web.Extensions
$script:json = New-Object System.Web.Script.Serialization.JavaScriptSerializer
$script:json.MaxJsonLength = $maxBytes

function Send-Response {
    param(
        $Response,
        [int]$Status,
        $Body,
        [string]$ContentType = 'application/json; charset=utf-8'
    )
    $Response.StatusCode = $Status
    $Response.Headers.Add('Access-Control-Allow-Origin', '*')
    $Response.Headers.Add('Access-Control-Allow-Methods', 'GET, PUT, OPTIONS')
    $Response.Headers.Add('Access-Control-Allow-Headers', 'Content-Type, X-Save-Time')
    $Response.Headers.Add('Access-Control-Allow-Private-Network', 'true')
    $Response.Headers.Add('Cache-Control', 'no-store')
    if ($null -eq $Body) {
        $Response.ContentLength64 = 0
    } else {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes([string]$Body)
        $Response.ContentType = $ContentType
        $Response.ContentLength64 = $bytes.Length
        $Response.OutputStream.Write($bytes, 0, $bytes.Length)
    }
    $Response.Close()
}

function Send-Error {
    param($Response, [int]$Status, [string]$Message)
    $payload = $script:json.Serialize(@{ erro = $Message })
    Send-Response $Response $Status $payload
}

function Read-RequestBody {
    param($Request)
    if ($Request.ContentLength64 -gt $maxBytes) {
        throw 'Os dados passaram do tamanho permitido.'
    }
    $reader = New-Object System.IO.StreamReader($Request.InputStream, [System.Text.Encoding]::UTF8)
    try {
        $text = $reader.ReadToEnd()
    } finally {
        $reader.Dispose()
    }
    if ([System.Text.Encoding]::UTF8.GetByteCount($text) -gt $maxBytes) {
        throw 'Os dados passaram do tamanho permitido.'
    }
    return $text
}

function Assert-Map {
    param($Value, [string]$Kind)
    if ($null -eq $Value -or -not ($Value -is [System.Collections.IDictionary])) {
        throw 'Cada parte do cronograma precisa ser um objeto.'
    }
    foreach ($key in @($Value.Keys)) {
        if ($key -notmatch '^\d+-\d+$') {
            throw 'Há uma chave de semana inválida.'
        }
        $item = $Value[$key]
        if ($Kind -eq 'bool' -and $item -isnot [bool]) {
            throw 'Uma marcação veio com valor inválido.'
        }
        if ($Kind -eq 'text') {
            if ($item -isnot [string]) { throw 'O nome de uma aula veio com valor inválido.' }
            if ($item.Length -gt 2000) { throw 'O nome de uma aula está longo demais.' }
        }
    }
}

function Test-CronogramaJson {
    param([string]$Body)
    try {
        $raw = $script:json.DeserializeObject($Body)
    } catch {
        throw 'O cronograma não está em JSON válido.'
    }
    if ($null -eq $raw -or -not ($raw -is [System.Collections.IDictionary])) {
        throw 'O cronograma precisa ser um objeto.'
    }
    foreach ($name in @('revisions', 'classesText', 'classesDone', 'shifts')) {
        if (-not $raw.ContainsKey($name)) {
            throw "Falta o campo $name."
        }
    }
    Assert-Map $raw['revisions'] 'bool'
    Assert-Map $raw['classesDone'] 'bool'
    Assert-Map $raw['shifts'] 'bool'
    Assert-Map $raw['classesText'] 'text'
}

function Save-StateAtomic {
    param([string]$Json)
    if (-not (Test-Path -LiteralPath $dataDir)) {
        New-Item -ItemType Directory -Path $dataDir | Out-Null
    }
    $id = [guid]::NewGuid().ToString('N')
    $tmp = Join-Path $dataDir "cronograma.$id.tmp"
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($tmp, $Json, $utf8)
    try {
        if (Test-Path -LiteralPath $dataFile) {
            $backup = Join-Path $dataDir "cronograma.$id.bak"
            [System.IO.File]::Replace($tmp, $dataFile, $backup, $true)
            if (Test-Path -LiteralPath $backup) {
                Remove-Item -LiteralPath $backup -Force
            }
        } else {
            [System.IO.File]::Move($tmp, $dataFile)
        }
    } catch {
        if (Test-Path -LiteralPath $tmp) {
            Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        }
        throw
    }
}

function Get-SaveTime {
    param($Request)
    $header = $Request.Headers['X-Save-Time']
    if ([string]::IsNullOrWhiteSpace($header)) {
        return [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    }
    try {
        return [int64]$header
    } catch {
        return [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    }
}

function Read-StateText {
    if (-not (Test-Path -LiteralPath $dataFile)) {
        return $script:emptyState
    }
    $text = [System.IO.File]::ReadAllText($dataFile, [System.Text.Encoding]::UTF8)
    if ([string]::IsNullOrWhiteSpace($text)) {
        return $script:emptyState
    }
    Test-CronogramaJson $text
    return $text
}

function Handle-Request {
    param($Context)
    $request = $Context.Request
    $method = $request.HttpMethod.ToUpperInvariant()
    $path = $request.Url.AbsolutePath

    if ($method -eq 'OPTIONS') {
        Send-Response $Context.Response 204 $null
        return
    }

    if ($method -eq 'GET' -and ($path -eq '/' -or $path -eq '/cronograma_ses_df_2027.html')) {
        if (-not (Test-Path -LiteralPath $htmlFile)) {
            Send-Error $Context.Response 500 'Não encontrei a tela do cronograma.'
            return
        }
        $html = [System.IO.File]::ReadAllText($htmlFile, [System.Text.Encoding]::UTF8)
        Send-Response $Context.Response 200 $html 'text/html; charset=utf-8'
        return
    }

    if ($path -eq '/api/estado' -and $method -eq 'GET') {
        try {
            $text = Read-StateText
        } catch {
            Send-Error $Context.Response 500 'O arquivo dados/cronograma.json está ilegível.'
            return
        }
        Send-Response $Context.Response 200 $text
        return
    }

    if ($path -eq '/api/estado' -and $method -eq 'PUT') {
        $saveTime = Get-SaveTime $request
        if ($saveTime -lt $script:lastWriteMs) {
            Send-Error $Context.Response 409 'Esta gravação chegou atrasada.'
            return
        }
        try {
            $body = Read-RequestBody $request
            Test-CronogramaJson $body
        } catch {
            $status = 400
            if ($_.Exception.Message -eq 'Os dados passaram do tamanho permitido.') { $status = 413 }
            Send-Error $Context.Response $status $_.Exception.Message
            return
        }
        Save-StateAtomic $body
        $script:lastWriteMs = $saveTime
        $hora = Get-Date -Format 'HH:mm:ss'
        Write-Host "Salvo às $hora"
        Send-Response $Context.Response 200 '{"ok":true}'
        return
    }

    Send-Error $Context.Response 404 'Não encontrei este endereço.'
}

if (-not (Test-Path -LiteralPath $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir | Out-Null
}
if (-not (Test-Path -LiteralPath $dataFile)) {
    Save-StateAtomic $script:emptyState
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($prefix)
try {
    $listener.Start()
} catch {
    $listener.Close()
    Write-Host ''
    Write-Host "Não consegui abrir o cronograma na porta $port."
    Write-Host ''
    Write-Host 'Se você deu dois cliques de novo, o cronograma já está aberto.'
    Write-Host 'Feche ESTA janela e use a janela preta que já estava aberta.'
    Write-Host ''
    Write-Host "Se não houver outra janela do cronograma, outro programa está usando a porta $port."
    Write-Host 'Feche esse programa e dê dois cliques em Iniciar.bat outra vez.'
    Write-Host ''
    Write-Host "Detalhe técnico: $($_.Exception.Message)"
    exit 1
}

try { $host.UI.RawUI.WindowTitle = 'Cronograma SES-DF 2027' } catch {}
Write-Host 'Cronograma SES-DF 2027'
Write-Host 'Não feche esta janela enquanto estiver estudando.'
Write-Host 'Se fechá-la, o navegador deixa de gravar no arquivo.'
Write-Host ''
Write-Host "Aberto em $prefix"
Write-Host 'Dados em dados\cronograma.json'
Write-Host ''
Write-Host 'Para encerrar, feche esta janela.'
Write-Host ''

if (-not $SemNavegador) {
    Start-Process $prefix
}

try {
    while ($listener.IsListening) {
        $asyncResult = $listener.BeginGetContext($null, $null)
        while (-not $asyncResult.AsyncWaitHandle.WaitOne(400)) { }
        try {
            $context = $listener.EndGetContext($asyncResult)
        } catch {
            break
        }
        try {
            Handle-Request $context
        } catch {
            Write-Host "Erro: $($_.Exception.Message)"
            try {
                Send-Error $context.Response 500 'Falha interna ao gravar.'
            } catch {}
        }
    }
} finally {
    if ($listener.IsListening) { $listener.Stop() }
    $listener.Close()
}
