# clear-env.ps1 - Clear Environment Variables for Current Session
Write-Host "=== Clear Environment Variables ===" -ForegroundColor Green

# Clear specific environment variables
$env:GEMINI_API_KEY = $null

Write-Host "✓ Environment variables cleared" -ForegroundColor Green
Write-Host "  - GEMINI_API_KEY: Cleared" -ForegroundColor Gray

Write-Host "`n⚠ Note: This only affects the current PowerShell session" -ForegroundColor Yellow
Write-Host "   Other sessions or permanent environment variables are not affected" -ForegroundColor Yellow 