' BALLZ BALLZ
Option Explicit
Dim objShell, objFSO, strPath, strIP, strPort, strPassword, strHash, strURL, strMode, strAudio, objHTTP, objFile, strLine, objProcess, strADB, strFFmpeg, strTempDir, strIndexFile, strCSSFile, strJSFile, strLogFile, strDevices, strDevice, intChoice, objExec, strOutput, strStreamPort, strWebPort, strSocketPort

Set objShell = CreateObject("WScript.Shell")
Set objFSO = CreateObject("Scripting.FileSystemObject")
strPath = objShell.CurrentDirectory
strTempDir = strPath & "\ezcast_temp"
If Not objFSO.FolderExists(strTempDir) Then objFSO.CreateFolder(strTempDir)
strADB = "adb"
strFFmpeg = "ffmpeg"
strIP = GetIP()
strWebPort = 8080
strStreamPort = 8081
strSocketPort = 8082
strPassword = GeneratePassword(12)
strHash = GetHexHash(strPassword)
strMode = "usb"
strAudio = "yes"

If WScript.Arguments.Count > 0 Then
    If InStr(1, WScript.Arguments(0), "--wireless", 1) > 0 Then strMode = "wireless"
    If InStr(1, WScript.Arguments(0), "--no-audio", 1) > 0 Then strAudio = "no"
    If InStr(1, WScript.Arguments(0), "--port", 1) > 0 And WScript.Arguments.Count > 1 Then strWebPort = CInt(WScript.Arguments(1))
End If

strURL = "http://" & strIP & ":" & strWebPort & "/ezcast.meow"
strIndexFile = strTempDir & "\index.html"
strCSSFile = strTempDir & "\style.css"
strJSFile = strTempDir & "\script.js"
strLogFile = strTempDir & "\ezcast.log"

ColorPrint vbGreen, "EZCAST v2.0 - Remote Android Screencast"
ColorPrint vbGreen, "========================================="
ColorPrint vbYellow, "Mode: " & UCase(strMode)
ColorPrint vbYellow, "Audio: " & UCase(strAudio)
ColorPrint vbYellow, "Server IP: " & strIP
ColorPrint vbYellow, "Dashboard: " & strURL
ColorPrint vbYellow, "Password: " & strPassword
ColorPrint vbYellow, "Hash: " & strHash
ColorPrint vbGreen, "========================================="

CheckRequirements()
strDevices = GetDevices()
If strDevices = "" Then
    ColorPrint vbRed, "No device connected. For wireless, use: ezcast --wireless"
    Cleanup()
End If

If InStr(strDevices, vbCrLf) > 0 Then
    Dim arrDevices, i
    arrDevices = Split(strDevices, vbCrLf)
    ColorPrint vbCyan, "Multiple devices found:"
    For i = 0 To UBound(arrDevices)
        If Trim(arrDevices(i)) <> "" Then ColorPrint vbCyan, i+1 & ". " & arrDevices(i)
    Next
    WScript.StdOut.Write "Select device number: "
    intChoice = CInt(WScript.StdIn.ReadLine()) - 1
    strDevice = Trim(arrDevices(intChoice))
Else
    strDevice = Trim(strDevices)
End If

If strMode = "wireless" Then
    ColorPrint vbYellow, "Setting up wireless connection..."
    objShell.Run strADB & " -s " & strDevice & " tcpip 5555", 0, True
    WScript.Sleep 3000
    Dim strWirelessIP
    strWirelessIP = GetDeviceIP(strDevice)
    objShell.Run strADB & " connect " & strWirelessIP & ":5555", 0, True
    strDevice = strWirelessIP & ":5555"
    ColorPrint vbGreen, "Wireless connected: " & strDevice
End If

CreateWebFiles()
StartStreamingServer()
StartWebSocketServer()
StartWebServer()
OpenBrowser strURL
KeepAlive()

Sub CheckRequirements()
    Dim objExec, strCheck
    On Error Resume Next
    objExec = objShell.Exec("cmd /c " & strADB & " version")
    strCheck = objExec.StdOut.ReadAll()
    If InStr(strCheck, "Android Debug Bridge") = 0 Then
        ColorPrint vbRed, "ADB not found. Install Android SDK Platform Tools."
        WScript.Quit 1
    End If
    objExec = objShell.Exec("cmd /c " & strFFmpeg & " -version")
    strCheck = objExec.StdOut.ReadAll()
    If InStr(strCheck, "ffmpeg version") = 0 Then
        ColorPrint vbRed, "FFmpeg not found. Install FFmpeg and add to PATH."
        WScript.Quit 1
    End If
End Sub

Function GetIP()
    Dim objExec, strOutput, strIPLine, arrParts
    objExec = objShell.Exec("cmd /c ipconfig")
    strOutput = objExec.StdOut.ReadAll()
    Dim arrLines, line
    arrLines = Split(strOutput, vbCrLf)
    For Each line In arrLines
        If InStr(line, "IPv4 Address") > 0 Then
            strIPLine = Trim(Split(line, ":")(1))
            If strIPLine <> "127.0.0.1" Then
                GetIP = strIPLine
                Exit Function
            End If
        End If
    Next
    GetIP = "127.0.0.1"
End Function

Function GeneratePassword(intLen)
    Dim strChars, i, strPass
    strChars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%"
    Randomize
    strPass = ""
    For i = 1 To intLen
        strPass = strPass & Mid(strChars, Int((Len(strChars) * Rnd) + 1), 1)
    Next
    GeneratePassword = strPass
End Function

Function GetHexHash(strInput)
    Dim objExec, strCmd, strHash
    strCmd = "cmd /c echo " & strInput & "| certutil -hashfile stdin MD5"
    objExec = objShell.Exec(strCmd)
    strHash = objExec.StdOut.ReadAll()
    GetHexHash = Trim(Split(strHash, vbCrLf)(1))
End Function

Function GetDevices()
    Dim objExec, strOutput, arrLines, strDevices, line
    objExec = objShell.Exec("cmd /c " & strADB & " devices")
    strOutput = objExec.StdOut.ReadAll()
    arrLines = Split(strOutput, vbCrLf)
    strDevices = ""
    For Each line In arrLines
        If InStr(line, Chr(9) & "device") > 0 Then
            strDevices = strDevices & Trim(Split(line, Chr(9))(0)) & vbCrLf
        End If
    Next
    GetDevices = strDevices
End Function

Function GetDeviceIP(strDeviceID)
    Dim objExec, strOutput
    objExec = objShell.Exec("cmd /c " & strADB & " -s " & strDeviceID & " shell ip route")
    strOutput = objExec.StdOut.ReadAll()
    Dim arrParts
    arrParts = Split(strOutput, "src ")
    If UBound(arrParts) >= 1 Then
        GetDeviceIP = Trim(Split(arrParts(1), " ")(0))
    Else
        GetDeviceIP = "192.168.1.100"
    End If
End Function

Sub CreateWebFiles()
    Dim strHTML, strCSS, strJS
    strHTML = "<!DOCTYPE html><html><head><title>EZCast Dashboard</title><link rel='stylesheet' href='style.css'></head><body>" & _
              "<div class='container'><h1>EZCast Dashboard</h1><div class='status'><span class='dot green'></span> Connected</div>" & _
              "<div class='info'><p>Device: " & strDevice & "</p><p>Mode: " & UCase(strMode) & "</p><p>Audio: " & UCase(strAudio) & "</p>" & _
              "<p>URL: " & strURL & "</p><p>Password: " & strPassword & "</p></div>" & _
              "<div class='stream-container'><canvas id='screenCanvas'></canvas></div>" & _
              "<div class='controls'><button onclick='toggleFullscreen()'>Fullscreen</button>" & _
              "<button onclick='toggleAudio()'>Toggle Audio</button><button onclick='screenshot()'>Screenshot</button>" & _
              "<button onclick='recordToggle()'>Record</button><button onclick='restartStream()'>Restart</button></div>" & _
              "<div class='qrcode' id='qrcode'></div></div><script src='script.js'></script></body></html>"
    
    strCSS = "*{margin:0;padding:0;box-sizing:border-box}body{font-family:monospace;background:#0a0a0a;color:#00ff00;overflow:hidden}" & _
             ".container{max-width:1200px;margin:0 auto;padding:20px}h1{text-align:center;color:#00ff00;text-shadow:0 0 10px #00ff00}" & _
             ".status{text-align:center;margin:10px 0}.dot{height:12px;width:12px;border-radius:50%;display:inline-block}" & _
             ".green{background:#00ff00;box-shadow:0 0 10px #00ff00}.info{background:#111;padding:15px;border:1px solid #00ff00;margin:15px 0}" & _
             ".info p{margin:5px 0}.stream-container{border:2px solid #00ff00;margin:15px 0;background:#000}" & _
             "#screenCanvas{width:100%;height:auto}.controls{text-align:center;margin:15px 0}" & _
             "button{background:#111;color:#00ff00;border:1px solid #00ff00;padding:10px 20px;margin:5px;cursor:pointer}" & _
             "button:hover{background:#00ff00;color:#000}.qrcode{text-align:center;margin:15px 0}"

    strJS = "var ws = new WebSocket('ws://" & strIP & ":" & strSocketPort & "');" & _
            "var canvas = document.getElementById('screenCanvas');" & _
            "var ctx = canvas.getContext('2d');" & _
            "var img = new Image();" & _
            "ws.onmessage = function(event) {" & _
            "img.onload = function() {" & _
            "canvas.width = img.width;" & _
            "canvas.height = img.height;" & _
            "ctx.drawImage(img, 0, 0);" & _
            "};" & _
            "img.src = URL.createObjectURL(event.data);" & _
            "};" & _
            "function toggleFullscreen() {" & _
            "if (!document.fullscreenElement) {" & _
            "document.documentElement.requestFullscreen();" & _
            "} else {" & _
            "document.exitFullscreen();" & _
            "}" & _
            "}" & _
            "function toggleAudio() {" & _
            "ws.send('toggle_audio');" & _
            "}" & _
            "function screenshot() {" & _
            "var link = document.createElement('a');" & _
            "link.download = 'screenshot.png';" & _
            "link.href = canvas.toDataURL();" & _
            "link.click();" & _
            "}" & _
            "var recording = false;" & _
            "function recordToggle() {" & _
            "recording = !recording;" & _
            "ws.send(recording ? 'start_record' : 'stop_record');" & _
            "}" & _
            "function restartStream() {" & _
            "ws.send('restart');" & _
            "}" & _
            "window.onload = function() {" & _
            "var qr = document.getElementById('qrcode');" & _
            "qr.innerHTML = '<img src=\"https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=" & Replace(strURL, "&", "%26") & "\">';" & _
            "};"

    objFSO.CreateTextFile(strCSSFile, True).Write strCSS
    objFSO.CreateTextFile(strJSFile, True).Write strJS
    objFSO.CreateTextFile(strIndexFile, True).Write strHTML
End Sub

Sub StartStreamingServer()
    Dim strCmd
    If strAudio = "yes" Then
        strCmd = strFFmpeg & " -f gdigrab -framerate 30 -i desktop -f mjpeg -q:v 5 -"
    Else
        strCmd = strFFmpeg & " -f gdigrab -framerate 30 -i desktop -an -f mjpeg -q:v 5 -"
    End If
    objShell.Run "cmd /c " & strCmd & " | " & strFFmpeg & " -f mjpeg -i - -c:v mjpeg -f mjpeg tcp://0.0.0.0:" & strStreamPort & "?listen", 0, False
    ColorPrint vbGreen, "Stream started on port " & strStreamPort
End Sub

Sub StartWebSocketServer()
    Dim strWSCmd
    strWSCmd = "cmd /c echo Starting WebSocket server... & node -e ""var WebSocket=require('ws');var wss=new WebSocket.Server({port:" & strSocketPort & "});wss.on('connection',function(ws){ws.on('message',function(msg){console.log(msg)})})"""
    objShell.Run strWSCmd, 0, False
    ColorPrint vbGreen, "WebSocket server started on port " & strSocketPort
End Sub

Sub StartWebServer()
    Dim strWebCmd
    strWebCmd = "cmd /c cd /d " & strTempDir & " && python -m http.server " & strWebPort
    objShell.Run strWebCmd, 0, False
    ColorPrint vbGreen, "Web server started on port " & strWebPort
End Sub

Sub OpenBrowser(strURL)
    objShell.Run "cmd /c start " & strURL, 0, False
End Sub

Sub KeepAlive()
    ColorPrint vbGreen, "EZCast is running. Press Ctrl+C to stop."
    ColorPrint vbGreen, "Dashboard available at: " & strURL
    Do
        WScript.Sleep 1000
    Loop
End Sub

Sub ColorPrint(intColor, strText)
    WScript.StdOut.WriteLine strText
End Sub

Sub Cleanup()
    If objFSO.FolderExists(strTempDir) Then objFSO.DeleteFolder(strTempDir, True)
    WScript.Quit 1
End Sub
