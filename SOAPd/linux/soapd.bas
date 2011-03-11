'' SOAPd-lin :: SOAP Daemon for Linux platforms
''
'' Copyright 2010-2011 Eli Wenig
''
''
''  This file is part of SIBBIE.
''
''  SIBBIE is free software: you can redistribute it and/or modify
''  it under the terms of the GNU General Public License as published by
''  the Free Software Foundation, either version 3 of the License, or
''  (at your option) any later version.
''
''  SIBBIE is distributed in the hope that it will be useful,
''  but WITHOUT ANY WARRANTY; without even the implied warranty of
''  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
''  GNU General Public License for more details.
''
''  You should have received a copy of the GNU General Public License
''  along with SIBBIE.  If not, see <http://www.gnu.org/licenses/>.


#include "chisock\chisock.bi"
#include "vbcompat.bi"

Using chi
DIM soapd AS socket
DIM cmd AS string * 7 ' Maximum length of the command + 1 to avoid false positives
DIM cmdThread AS Any Ptr
DIM j AS integer
DIM ip AS string

' Prepare the command list
DIM AS integer cmdList = FREEFILE
Open "soapconfig.txt" For Input As #cmdList
Dim fileBuffer As String
Dim Shared as String vlcDir,vlcArgs,media,hosts,pid
pid = "NULL"

' Read in the commands
Do
    Line Input #cmdList, fileBuffer
Loop Until fileBuffer = "vlcarguments:"
Line Input #cmdList,vlcArgs
Do
    Line Input #cmdList, fileBuffer
Loop Until fileBuffer = "trustedhost:"
Line Input #cmdList,hosts

Close #cmdList

' Define sub so that we can initialize this as a thread later on
Sub runCommand(ByVal i As Integer)
    DIM AS integer cmdPipe = FREEFILE
    If(i = 1) Then
        Dim As String runCmd = "cvlc " & chr(34) & media & chr(34) & " " & vlcArgs & " &"
        SHELL runCmd
	runCmd = "pidof vlc | awk '{ print $NF }'"
	OPEN PIPE runCmd FOR INPUT AS FREEFILE
        Line Input #cmdPipe,pid
	Close #cmdPipe
    ElseIf (i = 2) Then
        If (pid <> "NULL") Then
           SHELL "kill " & pid
	   pid = "NULL"
	End If
    End If
End Sub

While 1
    ' Initialize the server
    ' print "Entering server initialization loop"
    if(soapd.server(7626,1) <> SOCKET_OK) then 
        print "server() call failed, exiting"
        End
    End If
    if(soapd.listen(0) <> SOCKET_OK) then
        ip = *soapd.connection_info
        ip = right(ip,len(ip)-instr(ip,": ") - 1)
        ip = left(ip,instr(ip,",")-1)
        print "Incoming connection from " + ip
        if (ip <> hosts And ip <> "127.0.0.1") then
            soapd.put_line("You have no permission to talk. Goodbye.")
            soapd.close()
            print ip + " was not an authorized host."
        Endif
    Endif
    
    Open "soapconfig.txt" For Input As #cmdList
    Do
        Line Input #cmdList, fileBuffer
    Loop Until fileBuffer = "media:"
    Line Input #cmdList,media 
    Close #cmdList
    
    ' Wait for a client to connect.
    soapd.put_line("Welcome to SOAP Interface Daemon")
    soapd.put("Enter a command: ")
    
    ' Get the command.
    cmd = soapd.get_line()
    Print ip & " said: "& chr(34) & cmd & chr(34)

    If(cmd = "start" Or cmd = "start ") Then
        soapd.put_line("Starting the media stream.")
        cmdThread = ThreadCreate(@runCommand,Cast(Any Ptr,1))
    ElseIf(cmd = "stop") Then
        soapd.put_line("Stopping the media stream.")
        runCommand(2)
    ElseIf(cmd = "quit") Then
        soapd.put_line("Exiting.")
        print("quit was called, exiting")
        runCommand(2)
        End
    Else
        soapd.put_line("Invalid command.")
    End If

    ' Close the connection
    soapd.close()
Wend

