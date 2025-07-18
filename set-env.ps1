# set-env.ps1 - Set Environment Variables for Current Session
param(
    [string]$ApiKey = ""
)

Write-Host "=== Environment Variable Setup for Current Session ===" -ForegroundColor Green

# If API key is provided as parameter, use it
if ($ApiKey) {
    $env:GEMINI_API_KEY = $ApiKey
    Write-Host "✓ API key set from parameter" -ForegroundColor Green
} else {
    # Try to load from .env file first
    if (Test-Path ".env") {
        Get-Content ".env" | ForEach-Object {
            if ($_ -match "^([^=]+)=(.*)$") {
                $name = $matches[1]
                $value = $matches[2]
                Set-Variable -Name "env:$name" -Value $value -Scope Global
                Write-Host "✓ Environment variable loaded from .env: $name" -ForegroundColor Cyan
            }
        }
    } else {
        # Prompt user to enter API key
        Write-Host "⚠ .env file not found" -ForegroundColor Yellow
        Write-Host "Enter your Gemini API key (or press Enter to skip):" -ForegroundColor Yellow
        $userApiKey = Read-Host
        
        if ($userApiKey) {
            $env:GEMINI_API_KEY = $userApiKey
            Write-Host "✓ API key set from user input" -ForegroundColor Green
        } else {
            Write-Host "⚠ No API key provided" -ForegroundColor Yellow
        }
    }
}

# Check current status
Write-Host "`n=== Current Environment Status ===" -ForegroundColor Blue

if ($env:GEMINI_API_KEY -and $env:GEMINI_API_KEY -ne "your_actual_api_key_here") {
    Write-Host "✓ GEMINI_API_KEY: Configured" -ForegroundColor Green
    Write-Host "  Key: $($env:GEMINI_API_KEY.Substring(0, [Math]::Min(10, $env:GEMINI_API_KEY.Length)))..." -ForegroundColor Gray
} else {
    Write-Host "⚠ GEMINI_API_KEY: Not configured" -ForegroundColor Yellow
}

Write-Host "`n=== Usage Examples ===" -ForegroundColor Blue
Write-Host "Now you can run Flutter commands:" -ForegroundColor White
Write-Host "  flutter run" -ForegroundColor Gray
Write-Host "  flutter run --debug" -ForegroundColor Gray
Write-Host "  flutter run --release" -ForegroundColor Gray
Write-Host "  flutter run -d windows" -ForegroundColor Gray

Write-Host "`n⚠ Note: These environment variables are only valid for this PowerShell session" -ForegroundColor Yellow
Write-Host "   Close this window to clear them" -ForegroundColor Yellow 