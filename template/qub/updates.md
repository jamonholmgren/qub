Line 737 is:

Open "./web/pages/" + pagename + ".html" For Input As #3

“Path not found” means the program’s current working directory does not contain:

./web/pages/

So if you launch server.bas from, say:

/home/nextcloud/Downloads/

it looks for:

/home/nextcloud/Downloads/web/pages/

not necessarily the folder beside server.bas.

Add this just before line 737 to see exactly what it is trying to open:

Print "Current dir: "; _CWD$
Print "Opening: "; "./web/pages/" + pagename + ".html"

I’d change the code to:

Dim pagefile As String
pagefile = _CWD$ + "/web/pages/" + pagename + ".html"

Print "Opening: "; pagefile

If _FileExists(pagefile) Then
    Open pagefile For Input As #3
Else
    Print "ERROR - File not found: "; pagefile
    Exit Sub
End If

One important detail: if the directory itself is missing, _FileExists will safely catch the problem rather than crashing at OPEN.

Lines 737 739 740 558 559 560 of server.bas

works in windows if you install qb64


