@echo off
setlocal
cd /d "%~dp0"
where node >nul 2>nul
if errorlevel 1 (
  echo Node.js 22+ manquant. Installer https://nodejs.org puis relancer.
  pause
  exit /b 1
)
if not exist ".env" (
  node setup.mjs || (pause & exit /b 1)
)
if not exist "node_modules\ws" (
  call npm install --no-audit --no-fund || (pause & exit /b 1)
)
echo.
echo CHK GODOT DIRECT MCP - SERVEUR INDEPENDANT
echo Adresse locale: http://127.0.0.1:8791/health
echo Pour ChatGPT, activer un HTTPS PUBLIC et ajouter /mcp/ avec le jeton ChatGPT.
echo Pour Godot, ouvrir le dock CHK Direct et saisir le serveur HTTPS et le jeton Editeur.
echo Ne partagez pas les secrets du fichier .env.
echo.
node server.mjs
if errorlevel 1 pause
