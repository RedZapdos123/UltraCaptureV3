# UltraCaptureV3 Start Script.
# This script starts both the backend and frontend servers with proper error handling.

Write-Host "  UltraCaptureV3 Start Script" -ForegroundColor Cyan
Write-Host ""

# Get the script directory for absolute paths.
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$backendDir = Join-Path $scriptDir "backend"
$frontendDir = Join-Path $scriptDir "frontend"
$pythonExe = Join-Path $backendDir "ultracapturev3\Scripts\python.exe"
$appPy = Join-Path $backendDir "app.py"

# Check if backend virtual environment exists.
if (-not (Test-Path $pythonExe)) {
    Write-Host "[ERROR] Backend virtual environment not found." -ForegroundColor Red
    Write-Host "  Expected path: $pythonExe" -ForegroundColor Yellow
    Write-Host "  Please run '.\setup.ps1' first to set up the application." -ForegroundColor Yellow
    exit 1
}

# Check if app.py exists.
if (-not (Test-Path $appPy)) {
    Write-Host "[ERROR] Backend app.py not found." -ForegroundColor Red
    Write-Host "  Expected path: $appPy" -ForegroundColor Yellow
    exit 1
}

# Check if frontend node_modules exists.
if (-not (Test-Path (Join-Path $frontendDir "node_modules"))) {
    Write-Host "[ERROR] Frontend dependencies not found." -ForegroundColor Red
    Write-Host "  Please run '.\setup.ps1' first to set up the application." -ForegroundColor Yellow
    exit 1
}

Write-Host "Starting UltraCaptureV3..." -ForegroundColor Green
Write-Host ""

# Start backend server in a new window using the venv Python directly.
Write-Host "Starting backend server (CPU-based ONNX inference)..." -ForegroundColor Yellow
Write-Host "  Backend directory: $backendDir" -ForegroundColor Gray
Write-Host "  Python executable: $pythonExe" -ForegroundColor Gray

$backendProcess = Start-Process -FilePath $pythonExe `
    -ArgumentList $appPy `
    -WorkingDirectory $backendDir `
    -PassThru

if ($null -eq $backendProcess) {
    Write-Host "[ERROR] Failed to start backend server." -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Backend server process started (PID: $($backendProcess.Id))" -ForegroundColor Green

# Wait for backend to initialize and become accessible.
Write-Host "Waiting for backend to initialize..." -ForegroundColor Yellow
$backendReady = $false
$maxAttempts = 15
$attempt = 0

while (-not $backendReady -and $attempt -lt $maxAttempts) {
    Start-Sleep -Seconds 1
    $attempt++

    try {
        $response = Invoke-WebRequest -Uri "http://localhost:5000/api/health" `
            -TimeoutSec 2 `
            -ErrorAction Stop

        if ($response.StatusCode -eq 200) {
            $backendReady = $true
            Write-Host "[OK] Backend server is ready and responding to health checks." -ForegroundColor Green
        }
    } catch {
        # Backend not ready yet, continue waiting
        Write-Host "  Attempt $attempt/$($maxAttempts): Backend not ready yet..." -ForegroundColor Gray
    }
}

if (-not $backendReady) {
    Write-Host "[WARNING] Backend server started but did not respond to health checks within timeout." -ForegroundColor Yellow
    Write-Host "  The server may still be initializing. Check the backend window for errors." -ForegroundColor Yellow
}

# Start frontend server in a new window.
Write-Host ""
Write-Host "Starting frontend server..." -ForegroundColor Yellow
Write-Host "  Frontend directory: $frontendDir" -ForegroundColor Gray

$frontendProcess = Start-Process -FilePath "powershell" `
    -ArgumentList "-NoExit", "-Command", "cd '$frontendDir'; npm run dev" `
    -PassThru

if ($null -eq $frontendProcess) {
    Write-Host "[ERROR] Failed to start frontend server." -ForegroundColor Red
    # Kill backend if frontend fails
    Stop-Process -Id $backendProcess.Id -ErrorAction SilentlyContinue
    exit 1
}

Write-Host "[OK] Frontend server process started (PID: $($frontendProcess.Id))" -ForegroundColor Green

# Wait for frontend to initialize.
Write-Host "Waiting for frontend to initialize..." -ForegroundColor Yellow
$frontendReady = $false
$maxAttempts = 15
$attempt = 0

while (-not $frontendReady -and $attempt -lt $maxAttempts) {
    Start-Sleep -Seconds 1
    $attempt++

    try {
        $response = Invoke-WebRequest -Uri "http://localhost:5173" `
            -TimeoutSec 2 `
            -ErrorAction Stop

        if ($response.StatusCode -eq 200) {
            $frontendReady = $true
            Write-Host "[OK] Frontend server is ready and responding." -ForegroundColor Green
        }
    } catch {
        # Frontend not ready yet, continue waiting
        Write-Host "  Attempt $attempt/$($maxAttempts): Frontend not ready yet..." -ForegroundColor Gray
    }
}

if (-not $frontendReady) {
    Write-Host "[WARNING] Frontend server started but did not respond within timeout." -ForegroundColor Yellow
    Write-Host "  The server may still be initializing. Check the frontend window for errors." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  Application Started!" -ForegroundColor Cyan
Write-Host ""
Write-Host "Access the application at:" -ForegroundColor Green
Write-Host "  Frontend: http://localhost:5173" -ForegroundColor White
Write-Host "  Backend API: http://localhost:5000" -ForegroundColor White
Write-Host "  Backend Health: http://localhost:5000/api/health" -ForegroundColor White
Write-Host ""
Write-Host "To stop the servers:" -ForegroundColor Yellow
Write-Host "  1. Close the backend PowerShell window (or press Ctrl+C)" -ForegroundColor White
Write-Host "  2. Close the frontend PowerShell window (or press Ctrl+C)" -ForegroundColor White
Write-Host ""
Write-Host "For usage instructions, see Usage.md" -ForegroundColor Green
Write-Host ""

