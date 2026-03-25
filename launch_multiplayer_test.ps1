# Launch two instances of the app for multiplayer testing
Write-Host "Launching Player 1..."
Start-Process "flutter" -ArgumentList "run -d windows"
Start-Sleep -Seconds 5
Write-Host "Launching Player 2..."
Start-Process "flutter" -ArgumentList "run -d windows"
