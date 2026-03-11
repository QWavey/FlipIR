# Validation Script
# Run this before building to check for common issues

Write-Host "==================================" -ForegroundColor Cyan
Write-Host "OnePlus IR Remote - Validation" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""

$hasErrors = $false

# Check Flutter installation
Write-Host "1. Checking Flutter..." -ForegroundColor Yellow
try {
    $flutterVersion = flutter --version 2>&1 | Select-String "Flutter" | Select-Object -First 1
    Write-Host "   ✓ Flutter found: $flutterVersion" -ForegroundColor Green
} catch {
    Write-Host "   ✗ Flutter not found!" -ForegroundColor Red
    $hasErrors = $true
}
Write-Host ""

# Check if pubspec.yaml exists
Write-Host "2. Checking pubspec.yaml..." -ForegroundColor Yellow
if (Test-Path "pubspec.yaml") {
    Write-Host "   ✓ pubspec.yaml found" -ForegroundColor Green
} else {
    Write-Host "   ✗ pubspec.yaml not found!" -ForegroundColor Red
    $hasErrors = $true
}
Write-Host ""

# Check required directories
Write-Host "3. Checking project structure..." -ForegroundColor Yellow
$requiredDirs = @("lib", "lib\models", "lib\services", "lib\providers", "lib\screens", "lib\widgets", "android")
foreach ($dir in $requiredDirs) {
    if (Test-Path $dir) {
        Write-Host "   ✓ $dir exists" -ForegroundColor Green
    } else {
        Write-Host "   ✗ $dir missing!" -ForegroundColor Red
        $hasErrors = $true
    }
}
Write-Host ""

# Check required files
Write-Host "4. Checking required files..." -ForegroundColor Yellow
$requiredFiles = @(
    "lib\main.dart",
    "lib\models\ir_signal.dart",
    "lib\models\ir_remote.dart",
    "lib\services\flipper_parser.dart",
    "lib\services\ir_transmitter_service.dart",
    "lib\services\storage_service.dart",
    "lib\providers\remote_provider.dart",
    "lib\screens\home_screen.dart",
    "lib\screens\remote_control_screen.dart",
    "lib\widgets\remote_button.dart",
    "android\app\src\main\kotlin\com\example\flutter_application_1\MainActivity.kt",
    "android\app\src\main\AndroidManifest.xml"
)

foreach ($file in $requiredFiles) {
    if (Test-Path $file) {
        Write-Host "   ✓ $file" -ForegroundColor Green
    } else {
        Write-Host "   ✗ $file missing!" -ForegroundColor Red
        $hasErrors = $true
    }
}
Write-Host ""

# Try to get dependencies
Write-Host "5. Testing dependency installation..." -ForegroundColor Yellow
try {
    flutter pub get 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   ✓ Dependencies installed successfully" -ForegroundColor Green
    } else {
        Write-Host "   ✗ Failed to install dependencies" -ForegroundColor Red
        $hasErrors = $true
    }
} catch {
    Write-Host "   ✗ Error running flutter pub get" -ForegroundColor Red
    $hasErrors = $true
}
Write-Host ""

# Check for connected devices
Write-Host "6. Checking for connected devices..." -ForegroundColor Yellow
try {
    $devices = flutter devices 2>&1
    if ($devices -match "No devices detected") {
        Write-Host "   ⚠ No devices detected (this is OK for building APK)" -ForegroundColor Yellow
    } else {
        Write-Host "   ✓ Device(s) detected" -ForegroundColor Green
    }
} catch {
    Write-Host "   ⚠ Could not check devices" -ForegroundColor Yellow
}
Write-Host ""

# Summary
Write-Host "==================================" -ForegroundColor Cyan
if ($hasErrors) {
    Write-Host "❌ VALIDATION FAILED" -ForegroundColor Red
    Write-Host "Please fix the errors above before building" -ForegroundColor Red
    exit 1
} else {
    Write-Host "✅ VALIDATION PASSED" -ForegroundColor Green
    Write-Host "Project is ready to build!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "1. Run: flutter run (to test on device)" -ForegroundColor White
    Write-Host "2. Run: flutter build apk --release (to build APK)" -ForegroundColor White
    Write-Host "3. Or use: .\build.ps1 (for interactive build)" -ForegroundColor White
}
Write-Host "==================================" -ForegroundColor Cyan
