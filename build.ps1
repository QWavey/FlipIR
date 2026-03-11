# Build Script for OnePlus IR Remote App
# Run this in PowerShell

Write-Host "==================================" -ForegroundColor Cyan
Write-Host "OnePlus IR Remote - Build Script" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""

# Check if Flutter is installed
Write-Host "Checking Flutter installation..." -ForegroundColor Yellow
$flutterCheck = flutter --version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Flutter is not installed or not in PATH!" -ForegroundColor Red
    Write-Host "Please install Flutter from: https://docs.flutter.dev/get-started/install" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Flutter found" -ForegroundColor Green
Write-Host ""

# Check if device is connected
Write-Host "Checking connected devices..." -ForegroundColor Yellow
$devices = flutter devices 2>&1
if ($devices -match "No devices detected") {
    Write-Host "WARNING: No Android device detected!" -ForegroundColor Yellow
    Write-Host "Please connect your OnePlus 15 via USB and enable USB Debugging" -ForegroundColor Yellow
    Write-Host ""
    $continue = Read-Host "Continue anyway? (y/n)"
    if ($continue -ne "y") {
        exit 0
    }
} else {
    Write-Host "✓ Device detected" -ForegroundColor Green
}
Write-Host ""

# Clean previous builds
Write-Host "Cleaning previous builds..." -ForegroundColor Yellow
flutter clean
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Clean failed!" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Clean completed" -ForegroundColor Green
Write-Host ""

# Get dependencies
Write-Host "Getting dependencies..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to get dependencies!" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Dependencies installed" -ForegroundColor Green
Write-Host ""

# Show build options
Write-Host "Build Options:" -ForegroundColor Cyan
Write-Host "1. Debug APK (for testing with debugging)" -ForegroundColor White
Write-Host "2. Release APK (optimized, for distribution)" -ForegroundColor White
Write-Host "3. Run on connected device (debug mode)" -ForegroundColor White
Write-Host "4. Cancel" -ForegroundColor White
Write-Host ""

$choice = Read-Host "Select option (1-4)"

switch ($choice) {
    "1" {
        Write-Host ""
        Write-Host "Building Debug APK..." -ForegroundColor Yellow
        flutter build apk --debug
        if ($LASTEXITCODE -eq 0) {
            Write-Host ""
            Write-Host "==================================" -ForegroundColor Green
            Write-Host "✓ Debug APK built successfully!" -ForegroundColor Green
            Write-Host "==================================" -ForegroundColor Green
            Write-Host ""
            Write-Host "Location:" -ForegroundColor Cyan
            Write-Host "android\app\build\outputs\flutter-apk\app-debug.apk" -ForegroundColor White
        } else {
            Write-Host "ERROR: Build failed!" -ForegroundColor Red
            exit 1
        }
    }
    "2" {
        Write-Host ""
        Write-Host "Building Release APK..." -ForegroundColor Yellow
        flutter build apk --release
        if ($LASTEXITCODE -eq 0) {
            Write-Host ""
            Write-Host "==================================" -ForegroundColor Green
            Write-Host "✓ Release APK built successfully!" -ForegroundColor Green
            Write-Host "==================================" -ForegroundColor Green
            Write-Host ""
            Write-Host "Location:" -ForegroundColor Cyan
            Write-Host "android\app\build\outputs\flutter-apk\app-release.apk" -ForegroundColor White
            Write-Host ""
            Write-Host "You can now:" -ForegroundColor Yellow
            Write-Host "1. Transfer this APK to your phone" -ForegroundColor White
            Write-Host "2. Install it manually" -ForegroundColor White
            Write-Host "3. Share it with others" -ForegroundColor White
        } else {
            Write-Host "ERROR: Build failed!" -ForegroundColor Red
            exit 1
        }
    }
    "3" {
        Write-Host ""
        Write-Host "Running on device..." -ForegroundColor Yellow
        flutter run
    }
    "4" {
        Write-Host "Build cancelled." -ForegroundColor Yellow
        exit 0
    }
    default {
        Write-Host "Invalid option!" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "Done!" -ForegroundColor Green
