# Weekly updater for the Deck Decoder. Run it through download_images.bat.
#  1. Downloads the latest card list (cards.json)
#  2. Creates cards.js, which index.html loads by itself
#  3. Downloads only the card images that are missing into images\<CardDefId>.webp

Set-Location -Path $PSScriptRoot
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = "SilentlyContinue"   # much faster downloads in Windows PowerShell 5.1

$cardsUrl = "https://marvelsnapzone.com/getinfo/?searchtype=cards&searchcardstype=true"
$ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Safari/537.36"

function Read-Cards($path) {
    $d = Get-Content -Raw -Encoding UTF8 $path | ConvertFrom-Json
    if ($d.success.cards) { return $d.success.cards }
    elseif ($d.success)   { return $d.success }
    elseif ($d.cards)     { return $d.cards }
    else                  { return $d }
}

# 1. Latest card list
$cards = $null
Write-Host "Downloading the latest card list..."
try {
    Invoke-WebRequest -Uri $cardsUrl -OutFile "cards.new.json" -UseBasicParsing -UserAgent $ua -TimeoutSec 60
    $cards = Read-Cards "cards.new.json"
    if (@($cards).Count -lt 1) { throw "empty list" }
    Move-Item -Force "cards.new.json" "cards.json"
    Write-Host "cards.json updated ($(@($cards).Count) cards)." -ForegroundColor Green
} catch {
    Write-Host "Could not download the card list: $($_.Exception.Message)" -ForegroundColor Yellow
    if (Test-Path "cards.new.json") { Remove-Item "cards.new.json" -Force }
    if (Test-Path "cards.json") {
        Write-Host "Using the existing cards.json instead."
        $cards = Read-Cards "cards.json"
    } else {
        Write-Host "No cards.json available. Save it manually from the link in the page and run again." -ForegroundColor Red
        exit 1
    }
}

# 2. cards.js (small file the page reads even when opened straight from the folder)
$slim = @()
foreach ($c in $cards) {
    $key = if ($c.carddefid) { $c.carddefid } elseif ($c.key) { $c.key } else { $c.name }
    if (-not $c.name -or -not $key) { continue }
    $slim += [pscustomobject]@{ name = $c.name; carddefid = $key; cost = $c.cost; power = $c.power; art = $c.art }
}
$json = ConvertTo-Json -InputObject @($slim) -Compress
[IO.File]::WriteAllText((Join-Path $PSScriptRoot "cards.js"), "window.CARDS_DATA = $json;", (New-Object Text.UTF8Encoding $false))
Write-Host "cards.js created." -ForegroundColor Green

# 3. Missing images only
New-Item -ItemType Directory -Force -Path "images" | Out-Null
$total = @($cards).Count
$i = 0; $done = 0; $skipped = 0; $failed = 0
foreach ($c in $cards) {
    $i++
    $key = if ($c.carddefid) { $c.carddefid } elseif ($c.key) { $c.key } else { $c.name }
    $art = $c.art
    if (-not $key -or -not $art) { continue }
    $dest = Join-Path "images" ($key + ".webp")
    if ((Test-Path $dest) -and ((Get-Item $dest).Length -gt 0)) { $skipped++; continue }
    try {
        Invoke-WebRequest -Uri $art -OutFile $dest -UseBasicParsing -UserAgent $ua -TimeoutSec 30
        $done++
        Write-Host "[$i/$total] new: $key"
    } catch {
        $failed++
        if (Test-Path $dest) { Remove-Item $dest -Force }
        Write-Host "[$i/$total] FAILED $key : $($_.Exception.Message)" -ForegroundColor Yellow
    }
    Start-Sleep -Milliseconds 100
}

Write-Host ""
Write-Host "Done. New images: $done, already there: $skipped, failed: $failed." -ForegroundColor Green
