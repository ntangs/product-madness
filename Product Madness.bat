@echo off
set EDGE="C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
if not exist %EDGE% set EDGE="C:\Program Files\Microsoft\Edge\Application\msedge.exe"
start "" %EDGE% --app="file:///C:/Users/ntangs/Documents/Product-Madness/Product Madness v1.html" --window-size=430,720
