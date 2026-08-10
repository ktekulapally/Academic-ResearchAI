@echo off
title Academic Research AI - MCP Server
echo ===================================================
echo   Academic Research AI - Exposing MCP Server Tools
echo ===================================================
echo.
echo [1/2] Changing directory to backend...
cd /d "%~dp0\backend"

echo [2/2] Launching FastMCP Server...
echo (The server communicates via stdio transport. Do not type commands here; connect an MCP client to interface with it.)
echo.
"..\\.venv\\Scripts\\python.exe" -m app.mcp_server
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] The MCP server terminated with code %errorlevel%.
    pause
)
