option explicit
on error resume next

dim SUCCESS, ERROR, INFORMATION
SUCCESS = 0
ERROR = 1
INFORMATION = 4

dim QUERYSTRING 
dim HISTORYFILE
dim wshShell 
set wshShell = WScript.CreateObject( "WScript.Shell" )
QUERYSTRING = "https://example.com/password" 'name=computername&nouonce=0
HISTORYFILE = "C:\Support\logs.txt"

'''''''''''''''''''''''''
Function GetComputerName(byref rvalue)
GetComputerName = False
dim oWshNet 
Err.clear

Set oWshNet = CreateObject("WScript.Network") 
rvalue = ucase(oWshNet.ComputerName)
If (Err.Number = SUCCESS) Then
	GetComputerName = True
End If
End Function

'''''''''''''''''''''''''
Function GetLocalAdminUser(byVal strComputer, byref rvalue)
'Determine the name of the local administrator via SID
GetLocalAdminUser = False
dim oWMI, account, strQry
Err.clear
rvalue = ""
set oWMI = GetObject("winmgmts:{impersonationLevel=impersonate}!//" & strComputer )
strQry = "SELECT * FROM Win32_Account where Domain = '" & strComputer & "'"

For Each account in oWMI.ExecQuery(strQry)
	If (Left(account.sid, 6) = "S-1-5-" And Right(account.sid,4) = "-500") Then
		rvalue = account.name
		Exit For
	End If	
Next

If "" = rvalue Then
	Exit Function
End If 

If (Err.Number = SUCCESS) Then
	GetLocalAdminUser = True
End If
End Function

'''''''''''''''''''''''''
Function HTTPReq(strUser, byref rvalue)
Dim oHTTPRequest
Dim strHttpResponse

HTTPReq = False
Err.Clear

Set oHTTPRequest = CreateObject("WinHttp.WinHttpRequest.5.1")
strHttpResponse = "NIL"
oHTTPRequest.Option(0) = Cstr(WScript.ScriptName)
oHTTPRequest.Option(6) = True 'Allow redirect 
oHTTPRequest.Open "GET", strUser, False
oHTTPRequest.SetAutoLogonPolicy 1 
	oHTTPRequest.Send
	strHttpResponse = oHTTPRequest.ResponseText
	Set oHTTPRequest = Nothing 
rvalue = strHttpResponse 
If (Err.Number = SUCCESS) Then
	HTTPReq = True
End If
End Function

'''''''''''''''''''''''''
Function RemoveTags(strHTML, byref rvalue)
dim objRegEx
dim colMatch
dim match

RemoveTags = False
Err.Clear

Set objRegEx = new regexp
objRegEx.pattern = "<html><body>(.*)</body></html>"
set colMatch = objRegEx.Execute(strHTML)
set match = colMatch.item(0)
rvalue = cstr(match.SubMatches.item(0))

If (Err.Number = SUCCESS) Then
	RemoveTags = True
End If
End Function

'''''''''''''''''''''''''
Function Decode64(strB64, byref rvalue)
'cheat and use MSXML to base64 decode
dim strXML
dim oXMLDoc
dim bytes
dim strtmp
dim i

Decode64 = False
Err.Clear

 strXML = "<B64DECODE xmlns:dt=" & Chr(34) & _
        "urn:schemas-microsoft-com:datatypes" & Chr(34) & " " & _
        "dt:dt=" & Chr(34) & "bin.base64" & Chr(34) & ">" & _
        strB64 & "</B64DECODE>"
 Set oXMLDoc = CreateObject("MSXML2.DOMDocument.3.0")
 oXMLDoc.LoadXML(strXML)
 bytes = oXMLDoc.selectsinglenode("B64DECODE").nodeTypedValue
 for i = lbound(bytes) to ubound(bytes)
	strTmp = strTmp & Chr(AscB(MidB(bytes, i + 1, 1)))
 next 
 set oXMLDoc = nothing
 rvalue = strtmp
If (Err.Number = SUCCESS) Then
	Decode64 = True
End If
End Function


'''''''''''''''''''''''''
Function ReadHistory(byref rvalues)
Dim fso, fo, ts
Set fso = CreateObject("Scripting.FileSystemObject")

Err.Clear
ReadHistory = False
If (fso.FileExists(HISTORYFILE)) Then
	set fo = fso.GetFile(HISTORYFILE)
	set ts = fo.OpenAsTextStream(1,0)
	rvalues(0) = ts.ReadLine
	rvalues(1) = ts.ReadLine
Else
	rvalues(0) = "1900-01-01 00:00:00"
	rvalues(1) = "0"	
End IF

If (Err.Number = SUCCESS) Then
	ReadHistory = True
End If 
End Function


''''''''''''''''''''''''''
Function WriteHistory(byref values)
dim fso, fo, ts
set fso = CreateObject("Scripting.FileSystemObject")

Err.Clear
WriteHistory = False
If (fso.FileExists(HISTORYFILE)) Then
	fso.DeleteFile(HISTORYFILE)
End If
If (SUCCESS <> Err.Number) Then
	Exit Function
End If
set ts = fso.CreateTextFile(HISTORYFILE, True)
ts.WriteLine(cstr(values(0)))
ts.WriteLine(cstr(values(1)))
ts.close()

If (SUCCESS = Err.Number) Then
	WriteHistory = True
End If
End Function

''''''''''''''''''''''''''
Function ChangePassword(user, computerName, password)
dim oUser
ChangePassword = False
Err.Clear
Set oUser = GetObject("WinNT://" & computerName & "/" & user)
 
' Set the password 
oUser.SetPassword password
oUser.Setinfo 
If (Err.Number = SUCCESS ) Then
	ChangePassword = True
End If
End Function 


''''''''''''''''''''''''''
'MAIN
''''''''''''''''''''''''''
dim ch_history(1)
dim strname, struser, response
dim info
If (false = ReadHistory(ch_history)) Then
	wshShell.LogEvent ERROR, "SetAdminPass: Change history could not be read"
	wscript.quit 1
End If

If (0 > datediff("h", cdate(ch_history(0)), now)) Then 
	'Its not time yet back to sleep
	wscript.quit 
End If

wshShell.LogEvent INFORMATION, "SetAdminPass: Change time reached attempting password change"

If (false = GetComputerName(strname)) Then
	wshShell.LogEvent ERROR, "SetAdminPass: Failed to determine system name"
	wscript.quit 1
End If

If (false = GetLocalAdminUser(strname, struser)) Then
	wshShell.LogEvent ERROR, "SetAdminPass: Could not determine name of local Administrator account"
	wscript.quit 1
End If

If (False = HTTPReq(QUERYSTRING & "name=" & strname & "&nouonce=" & ch_history(1), response)) Then
	wshShell.LogEvent ERROR, "SetAdminPass: HTTPS Request Failed"
	wscript.quit 1
End If

If (False = RemoveTags(response, response)) Then
	wshShell.LogEvent ERROR, "SetAdminPass: Server response invalid 1"
	wscript.quit 1
End If

info = split(response, ",")
If (3 <> Ubound(info)) Then
	wshShell.LogEvent ERROR, "SetAdminPass: Server response invalid 2"
	wscript.quit 1
End If

If ("true" <> info(0)) Then 
	wshShell.LogEvent ERROR, "SetAdminPass: Server refused password change"
	wscript.quit 1
End If

If (False = Decode64(info(1), response)) Then
	wshShell.LogEvent ERROR, "SetAdminPass: decode of password failed" 
	wscript.quit 1
End If

If (False = ChangePassword(struser, strname, response)) Then
	wshShell.LogEvent ERROR, "SetAdminPass: Change password failed!" 
	'The server already thinks the pwd is changed try again at the next interval
	info(3) = "1900-01-01 00:00:00"
End If

wshShell.LogEvent INFORMATION, "SetAdminPass: Administrator password changed!" 
ch_history(0) = info(3)
ch_history(1) = info(2)

if (False = WriteHistory(ch_history)) Then
	wscript.quit 1
End If

wscript.quit
