param()

$failed = 0
$total = 0
$failedTests = @()

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Running Base-Defense Test Suites (lua55)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Get-ChildItem -Path Testing -Filter "test_*.lua" | ForEach-Object {
    $total++
    Write-Host "Running $($_.Name)..." -NoNewline
    
    # Run the test and capture output
    $output = lua55 $_.FullName 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        $failed++
        $failedTests += $_.Name
        Write-Host " [FAILED]" -ForegroundColor Red
        Write-Host "----------------------------------------" -ForegroundColor Yellow
        Write-Host $output
        Write-Host "----------------------------------------" -ForegroundColor Yellow
    } else {
        Write-Host " [PASS]" -ForegroundColor Green
    }
}

Write-Host "`nTest Run Summary:" -ForegroundColor Cyan
Write-Host "Total Suites: $total"
Write-Host "Passed:       $($total - $failed)" -ForegroundColor Green

if ($failed -gt 0) {
    Write-Host "Failed:       $failed" -ForegroundColor Red
    Write-Host "`nFailing Suites:" -ForegroundColor Red
    foreach ($test in $failedTests) {
        Write-Host "  - $test" -ForegroundColor Red
    }
    exit 1
} else {
    Write-Host "Failed:       0" -ForegroundColor Green
    Write-Host "`nAll test suites passed successfully!" -ForegroundColor Green
    exit 0
}
