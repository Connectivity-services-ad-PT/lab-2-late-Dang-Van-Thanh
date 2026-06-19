$ErrorActionPreference = "Stop"

$BaseUrl = if ($env:BASE_URL) { $env:BASE_URL } else { "http://127.0.0.1:4010" }
$AuthHeader = "Authorization: Bearer test_token"

Write-Host "[Lab02] Chay test tu dong Prism Mock Server - Cap 03 & Cap 10" -ForegroundColor Cyan
Write-Host ""


Write-Host "[1/5] Happy path: GET /access/logs/recent (Lay nhat ky quet the)" -ForegroundColor Green
curl.exe -i "$BaseUrl/access/logs/recent?limit=5" -H $AuthHeader
Write-Host "`n---"

Write-Host "[2/5] Happy path: POST /access/check (ALLOW Scenario)" -ForegroundColor Green
$payloadAllow = '{\"cardId\": \"RFID88776655\", \"gateId\": \"5ebb8022-f33e-f71a-7a06-cab650c82a13\", \"timestamp\": \"2026-05-28T16:36:00Z\"}'
curl.exe -i -X POST "$BaseUrl/access/check" -H $AuthHeader -H "X-Correlation-ID: check-in-cntt-17-11-allow" -H "Content-Type: application/json" -d $payloadAllow
Write-Host "`n---"

Write-Host "[3/5] Happy path: GET /gates/{gateId}/status (Kiem tra trang thai cong)" -ForegroundColor Green
curl.exe -i "$BaseUrl/gates/5ebb8022-f33e-f71a-7a06-cab650c82a13/status" -H $AuthHeader
Write-Host "`n---"


Write-Host "[4/5] Error case: GET /access/logs/recent WITHOUT TOKEN (Loi thieu Token)" -ForegroundColor Red
curl.exe -i "$BaseUrl/access/logs/recent?limit=5"
Write-Host "`n---"

Write-Host "[5/5] Error case: GET /cards/SAI_DINH_DANG_THE (Loi Validate dinh dang the 422)" -ForegroundColor Red
curl.exe -i "$BaseUrl/cards/SAI_DINH_DANG_THE" -H $AuthHeader
Write-Host ""