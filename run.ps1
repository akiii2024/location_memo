# run.ps1 - Flutter App Execution Script
param(
    [string]$Mode = "debug",
    [string]$Device = ""
)

Write-Host "=== Location Memo App Execution Script ===" -ForegroundColor Green

# Load environment variables from .env file
if (Test-Path ".env") {
    Get-Content ".env" | ForEach-Object {
        if ($_ -match "^([^=]+)=(.*)$") {
            $name = $matches[1]
            $value = $matches[2]
            [Environment]::SetEnvironmentVariable($name, $value, "Process")
            Write-Host "✓ Environment variable set: $name" -ForegroundColor Cyan
        }
    }
} else {
    Write-Host "⚠ Warning: .env file not found" -ForegroundColor Yellow
    Write-Host "   Create .env file and set API key" -ForegroundColor Yellow
    Write-Host "   Example: GEMINI_API_KEY=your_actual_api_key_here" -ForegroundColor Yellow
}

# Check if environment variable is set
if ($env:GEMINI_API_KEY -and $env:GEMINI_API_KEY -ne "your_actual_api_key_here") {
    Write-Host "✓ API key is configured" -ForegroundColor Green
} else {
    Write-Host "⚠ API key not configured (AI features will not work)" -ForegroundColor Yellow
}

# Execute Flutter app
Write-Host "`n🚀 Starting Flutter app..." -ForegroundColor Green

$flutterArgs = @()

# Set arguments based on mode
switch ($Mode.ToLower()) {
    "debug" { 
        $flutterArgs += "--debug"
        Write-Host "Mode: Debug" -ForegroundColor Blue
    }
    "release" { 
        $flutterArgs += "--release"
        Write-Host "Mode: Release" -ForegroundColor Blue
    }
    "profile" { 
        $flutterArgs += "--profile"
        Write-Host "Mode: Profile" -ForegroundColor Blue
    }
    "v" {
        $flutterArgs += "--verbose"
        Write-Host "Mode: Verbose" -ForegroundColor Blue
    }
    default { 
        Write-Host "Mode: Default" -ForegroundColor Blue
    }
}

# If device is specified
if ($Device) {
    $flutterArgs += "-d"
    $flutterArgs += $Device
    Write-Host "Device: $Device" -ForegroundColor Blue
}

# Execute Flutter command
try {
    & flutter run @flutterArgs
} catch {
    Write-Host "❌ Failed to start Flutter app: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} 