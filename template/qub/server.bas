$Console:Only

' Variables are integers by default if they start with a-z
DefInt A-Z

' Constants
Const MAX_CLIENTS = 8
Const EXPIRY_TIME = 240 'seconds
Const MIDNIGHT_FIX_WINDOW = 60 * 60 'seconds
Const MAX_HEADER_SIZE = 4096 'bytes

' Const DEFAULT_HOST = "147.182.205.32" ' for hosting
Const DEFAULT_HOST = "localhost" ' for local
Const DEFAULT_PORT = "6464"

' Different types of web requests
Const METHOD_HEAD = 1
Const METHOD_GET = 2
Const METHOD_POST = 3

' When did the server start?
Dim Shared StartTime As String
StartTime = datetime$

' convenience consts
Dim Shared CRLF As String
Dim Shared QT As String
CRLF = Chr$(13) + Chr$(10) ' carriage return + line feed
QT = Chr$(34) ' double quote

' QB64 doesn't support variable-length strings in TYPEs, so we have to use a fixed-length string
' Important ones first
Dim client_handle(1 To MAX_CLIENTS) As Integer
Dim client_expiry(1 To MAX_CLIENTS) As Double
Dim client_request(1 To MAX_CLIENTS) As String
Dim client_uri(1 To MAX_CLIENTS) As String
Dim client_method(1 To MAX_CLIENTS) As Integer
Dim client_content_length(1 To MAX_CLIENTS) As Long
Dim client_host(1 To MAX_CLIENTS) As String
Dim client_browser(1 To MAX_CLIENTS) As String

connections = 0
port$ = DEFAULT_PORT

' check if qub.conf exists, and read in the configuration if so
If _FILEEXISTS("./qub/qub.conf") Then
    Print "Reading configuration from qub/qub.conf"
    Open "./qub/qub.conf" For Input As #1
    Do While Not EOF(1)
        Line Input #1, line$
        ' Strip any preceding whitespace from line$
        Do While Left$(line$, 1) = " "
            line$ = Mid$(line$, 2)
        Loop

        ' Read in the config options
        If Left$(line$, 5) = "port=" Then
            port$ = Mid$(line$, 6)
        End If
    Loop
    Close #1
End If

Print "Starting QB64 webserver on port " + port$

' kick off the listener
host = _OpenHost("TCP/IP:" + port$)

' main loop!
Do
    ' Process old connections
    If connections Then
        For c = 1 To MAX_CLIENTS
            ' If this connection is active
            If client_handle(c) Then
                ' Add logging to monitor connection processing
                Print "Processing connection #" + Str$(c) + " (" + Str$(ROUND((Timer(.001) - client_expiry(c)) / 1000, 1)) + "ms old)"

                ' work on the request in an effort to finish it
                If handle_request(c) Then
                    ' Ignore "captive" pings
                    If InStr(client_uri(c), "captive") < 1 Then
                        Print "Completed request for: " + client_uri(c)
                        Print " from " + _ConnectionAddress(client_handle(c))
                        Print " using " + client_browser(c)
                    End If
                    tear_down c
                    ' If the request was completed, we can reduce the number of active connections
                    connections = connections - 1
                    ' Timeout old connections
                ElseIf Timer >= client_expiry(c) And Timer < client_expiry(c) + MIDNIGHT_FIX_WINDOW Then
                    Print "TIMED OUT: request for: " + client_uri(c)
                    Print " from " + _ConnectionAddress(client_handle(c))
                    Print " using " + client_browser(c)
                    respond_text c, "HTTP/1.1 408 Request Timeout", "", "text/html"
                    tear_down c
                    ' If the request timed out, we can reduce the number of active connections
                    connections = connections - 1
                End If
            End If
        Next
    End If

    ' Accept any new connections
    If connections < MAX_CLIENTS Then
        newclient = _OpenConnection(host) ' monitor host connection
        Do While newclient
            For c = 1 To MAX_CLIENTS
                ' Find an empty client handle to handle this new connection
                If client_handle(c) = 0 Then
                    client_handle(c) = newclient
                    client_method(c) = 0
                    client_content_length(c) = -1
                    client_expiry(c) = Timer(.001) + EXPIRY_TIME
                    If client_expiry(c) >= 86400 Then client_expiry(c) = client_expiry(c) - 86400
                    Exit For
                End If
            Next
            
            connections = connections + 1

            ' If we're at the max, stop accepting new connections
            If connections >= MAX_CLIENTS Then Exit Do

            ' Get the next connection
            newclient = _OpenConnection(host) ' monitor host connection
        Loop
    End If

    ' Limit CPU usage and leave some time for stuff be sent across the network
    _Limit 100 ' default 100, range 1-1000. Higher numbers = better perf at cost of higher idle CPU usage
Loop Until InKey$ = Chr$(27) ' escape quits

' After a keypress, close all connections and quit
Close #host
System ' Quits to system

StaticFileError:
    Print "File error: " + Error$
    Resume Next

' This tears down a connection, empties memory, and resets the client handle to 0
Sub tear_down (c As Integer)
    ' Import the shared arrays
    Shared client_handle() As Integer
    Shared client_uri() As String
    Shared client_host() As String
    Shared client_browser() As String
    Shared client_request() As String

    ' Close the connection
    Close #client_handle(c)

    'set handle to 0 so we know it's unused
    client_handle(c) = 0
    'set strings to empty to save memory
    client_uri(c) = ""
    client_host(c) = ""
    client_browser(c) = ""
    client_request(c) = ""
End Sub

' Attempt to complete a request
Function handle_request% (c As Integer)
    ' Import the shared arrays
    Shared client_handle() As Integer
    Shared client_uri() As String
    Shared client_host() As String
    Shared client_browser() As String
    Shared client_content_length() As Long
    Shared client_request() As String
    Shared client_method() As Integer

    ' Start timer
    Dim start_timer As Single
    start_timer = Timer(.001)

    ' Apparently QB64 doesn't support this yet
    ' ON LOCAL ERROR GOTO runtime_internal_error

    ' Allocate space for the current line we're reading
    Dim cur_line As String

    ' Read the first line of the request and store in s$
    Get #client_handle(c), , s$

    ' Empty requests are just dumped
    If Len(s$) = 0 Then Exit Function

    'client_request is used to collect the client's request
    'when all the headers have arrived, they are stripped away from client_request
    client_request(c) = client_request(c) + s$

    ' If we haven't parsed out the client method yet, let's do that
    If client_method(c) = 0 Then
        ' The end of the headers is the first blank line, which is two CRLFs in a row
        header_end = InStr(client_request(c), CRLF + CRLF)
        ' If it's immediately at the start of the request, we have no headers
        If header_end = 0 Then
            ' Too large of a request...can't handle it
            If Len(client_request(c)) > MAX_HEADER_SIZE Then GoTo large_request
            ' Either way, we're out
            Exit Function
        End If

        ' HTTP permits the use of multiple spaces/tabs and in some cases newlines
        ' to separate words. So we collapse them.
        headers$ = shrinkspace(Left$(client_request(c), header_end + 1))
        client_request(c) = Mid$(client_request(c), header_end + 4)

        'This loop processes all the header lines
        first_line = 1
        Do
            ' If there's a CRLF, we have another line
            linebreak = InStr(headers$, CRLF)
            If linebreak = 0 Then Exit Do

            ' Get the current line minus the CRLF
            cur_line = Left$(headers$, linebreak - 1)

            ' Remove the current line from the rest of the headers, since we're processing it now
            headers$ = Mid$(headers$, linebreak + 2)

            ' If this is the first line, it's the request line
            If first_line Then
                'First line looks something like
                'GET /index.html HTTP/1.1
                
                ' Not the first line anymore, after this
                first_line = 0

                ' First space separates the method from the uri
                methodSpace = InStr(cur_line, " ")
                If methodSpace = 0 Then GoTo bad_request
                method$ = Left$(cur_line, methodSpace - 1)

                ' Second space separates the uri from the protocol
                uriSpace = InStr(methodSpace + 1, cur_line, " ")
                If uriSpace = 0 Then GoTo bad_request
                client_uri(c) = Mid$(cur_line, methodSpace + 1, uriSpace - (methodSpace + 1))
                If Len(client_uri(c)) = 0 Then GoTo bad_request

                ' The rest is the protocol
                version$ = Mid$(cur_line, uriSpace + 1)

                ' Grab the method, first
                Select Case method$
                    Case "GET"
                        client_method(c) = METHOD_GET
                    Case "HEAD"
                        client_method(c) = METHOD_HEAD
                    Case "POST"
                        client_method(c) = METHOD_POST
                    Case Else
                        GoTo unimplemented
                End Select

                ' We only support HTTP/1.1 and 1.0
                Select Case version$
                    Case "HTTP/1.1"
                    Case "HTTP/1.0"
                    Case Else
                        GoTo bad_request
                End Select
            Else
                ' The rest of the headers look like "Name: Value", e.g.
                ' Host: www.qb64.net
                colon = InStr(cur_line, ": ")
                If colon = 0 Then GoTo bad_request

                header$ = LCase$(Left$(cur_line, colon - 1))
                value$ = Mid$(cur_line, colon + 2)

                ' Here are the headers we recognize. We don't care about most of them.
                Select Case header$
                    Case "cache-control"
                    Case "connection"
                    Case "date"
                    Case "pragma"
                    Case "trailer"
                    Case "transfer-encoding"
                        GoTo unimplemented
                    Case "upgrade"
                    Case "via"
                    Case "warning"

                    Case "accept"
                    Case "accept-charset"
                    Case "accept-encoding"
                    Case "accept-language"
                    Case "authorization"
                    Case "expect"
                    Case "from"
                    Case "host"
                        client_host(c) = value$
                    Case "if-match"
                    Case "if-modified-since"
                    Case "if-none-match"
                    Case "if-range"
                    Case "if-unmodified-Since"
                    Case "max-forwards"
                    Case "proxy-authorization"
                    Case "range"
                    Case "referer"
                        ' Could add this later, referer is sometimes useful
                    Case "te"
                    Case "user-agent"
                        client_browser(c) = value$
                    Case "allow"
                    Case "content-encoding"
                        If LCase$(value$) <> "identity" Then GoTo unimplemented
                    Case "content-language"
                    Case "content-length"
                        If Len(value$) <= 6 Then
                            client_content_length(c) = Val(value$)
                        Else
                            GoTo large_request
                        End If
                    Case "content-location"
                    Case "content-md5"
                    Case "content-range"
                    Case "content-type"
                    Case "expires"
                    Case "last-modified"
                    Case Else
                        ' Ignore
                End Select
            End If
        Loop

        'All modern clients send a hostname, so this is mainly to prevent
        'ancient clients and bad requests from tripping us up
        If Len(client_host(c)) = 0 Then client_host(c) = DEFAULT_HOST
    End If

    ' assume the request can be completed; set to 0 if it can't.
    handle_request = 1
    code$ = "200 OK"
    content_type$ = "text/html"

    Select Case client_method(c)
        Case METHOD_HEAD
            respond_text c, "HTTP/1.1 200 OK", "", "text/html"
        Case METHOD_GET
            uri$ = client_uri(c)
            l$ = Left$(uri$, InStr(uri$, ".") - 1)
            ext$ = Right$(uri$, Len(uri$) - Len(l$))
            filename$ = Mid$(uri$, InStr(uri$, "/static/") + 8)
            pagename$ = "404" ' 404 by default

            ' Router!
            Select Case 1
                Case Len(uri$) ' hack .. length of 1 is just "/" so we capture home page
                    pagename$ = "home"
                Case InStr(uri$, "/favicon.ico")
                    ' html$ = favicon(c)
                    GoTo not_found
                Case InStr(uri$, "/robots.txt")
                    ' html$ = robots_txt()
                    GoTo not_found
                Case StaticExists(filename$)
                    format$ = "binary" ' "binary" or "text"

                    Select Case ext$
                        Case ".css"
                            content_type$ = "text/css"
                            format$ = "text"
                        Case ".js"
                            content_type$ = "text/javascript"
                            format$ = "text"
                        Case ".jpg"
                            content_type$ = "image/jpeg"
                        Case ".png"
                            content_type$ = "image/png"
                        Case ".ico"
                            content_type$ = "image/x-icon"
                        Case ".svg"
                            content_type$ = "image/svg+xml"
                        Case ".woff"
                            content_type$ = "font/woff"
                        Case ".woff2"
                            content_type$ = "font/woff2"
                        Case ".ttf"
                            content_type$ = "font/ttf"
                        Case ".eot"
                            content_type$ = "application/vnd.ms-fontobject"
                        Case ".otf"
                            content_type$ = "font/otf"
                        Case ".txt"
                            content_type$ = "text/plain"
                            format$ = "text"
                        Case ".pdf"
                            content_type$ = "application/pdf"
                        Case ".zip"
                            content_type$ = "application/zip"
                        Case ".gz"
                            content_type$ = "application/gzip"
                        Case ".mp4"
                            content_type$ = "video/mp4"
                        Case ".mp3"
                            content_type$ = "audio/mpeg"
                        Case ".webm"
                            content_type$ = "video/webm"
                        Case ".ogg"
                            content_type$ = "audio/ogg"
                        Case ".ogv"
                            content_type$ = "video/ogg"
                        Case ".webp"
                            content_type$ = "image/webp"
                        Case ".json"
                            content_type$ = "application/json"
                            format$ = "text"
                        Case ".xml"
                            content_type$ = "application/xml"
                            format$ = "text"
                        Case ".csv"
                            content_type$ = "text/csv"
                            format$ = "text"
                        Case ".html"
                            content_type$ = "text/html"
                            format$ = "text"
                        Case ".htm"
                            content_type$ = "text/html"
                            format$ = "text"
                        Case Else
                            content_type$ = "text/plain"
                            format$ = "text"
                    End Select

                    If format$ = "binary" Then
                        respond_binary c, "HTTP/1.1 " + code$, filename$, content_type$
                    Else
                        respond_static c, "HTTP/1.1 " + code$, filename$, content_type$
                    End If

                    Exit Function
                Case PageExists(uri$)
                    pagename$ = uri$

                    ' does pagename$ start with a slash?
                    If Left$(pagename$, 1) = "/" Then
                        ' remove the slash
                        pagename$ = Mid$(pagename$, 2)
                    End If
                Case Else
                    pagename$ = "404"
                    code$ = "404 Not Found"
            End Select

            respond_page c, "HTTP/1.1 " + code$, pagename$, content_type$
            
        Case METHOD_POST
            GoTo unimplemented
        Case Else
            'This shouldn't happen because we would have EXITed FUNCTION earlier
            Print "ERROR: Unknown method. This should never happen."
    End Select

    ' Done with all the normal stuff. Everything past this point is just helper "functions" (actually gotos)
    Dim total_time As Single
    total_time = Timer(.001) - start_timer
    Print "Request handled in " + Str$(total_time) + " seconds."

    Exit Function

not_found:
    respond_text c, "HTTP/1.1 404 Not Found", "404 Not Found", "text/html"
    Exit Function

large_request:
    respond_text c, "HTTP/1.1 413 Request Entity Too Large", "", "text/html"
    handle_request = 1
    Exit Function

bad_request:
    respond_text c, "HTTP/1.1 400 Bad Request", "", "text/html"
    handle_request = 1
    Exit Function
    unimplemented:
    respond_text c, "HTTP/1.1 501 Not Implemented", "", "text/html"
    handle_request = 1
    Exit Function

runtime_internal_error:
    Print "RUNTIME ERROR: Error code"; Err; ", Line"; _ErrorLine
    Resume internal_error
    
internal_error:
    respond_text c, "HTTP/1.1 500 Internal Server Error", "", "text/html"
    handle_request = 1
    Exit Function
End Function

Function PageExists(filename$)
    PageExists = _FILEEXISTS("./web/pages" + filename$ + ".html") * -1
End Function

Function StaticExists(filename$)
    StaticExists = _FILEEXISTS("./web/static/" + filename$) * -1
End Function

' Respond with headers

Sub respond_headers (c As Integer, header As String, content_type As String)
    ' Output ... build with a header first, then an empty line, then the payload
    send c, header

    send c, "Date: " + datetime$
    send c, "Server: Qub"
    send c, "Last-Modified: " + StartTime
    send c, "Cache-Control: public, max-age=86400, s-maxage=86400"
    send c, "Connection: close"
    
    send c, "Content-Type: " + content_type + "; charset=UTF-8"
    ' We probably should have a Content-Length header, but since we'd rather read a line
    ' at a time and don't know ahead of time what the length will be, let's skip it
    ' send c, "Content-Length:" + Str$(Len(payload))

    ' extra newline to signify end of header
    send c, ""
End Sub

' Respond with a text payload
Sub respond_text (c As Integer, header As String, payload As String, content_type As String)
    ' Put the headers to the handle
    respond_headers c, header, content_type

    ' Put the payload to the handle
    send c, payload

    ' Done!
End Sub

Sub respond_page (c As Integer, header As String, pagename As String, content_type As String)
    ' Put the headers to the handle
    respond_headers c, header, content_type

    title$ = ""
    read_metadata pagename, title$

    ' Load the layout & page and put those to the handle
    Open "./web/layout.html" For Input As #1
    Do While Not EOF(1)
        Line Input #1, line$

        ' Replace all dynamic variables
        line$ = replace(line$, "<!--$TITLE-->", title$)
        line$ = replace(line$, "<!--$YEAR-->", Mid$(datetime$, 13, 4))
        line$ = replace(line$, "<!--$SLUG-->", slugify$(pagename))

        ' If line includes <!--$BODY-->, then load the page body
        If InStr(line$, "<!--$BODY-->") Then        
            ' Output everything up to the <!--$BODY--> line
            send c, Left$(line$, InStr(line$, "<!--$BODY-->") - 1)

            ' Load the page body
            Print "loading page: " + pagename
            Open "./web/pages/" + pagename + ".html" For Input As #2
            Do While Not EOF(2)
                Line Input #2, page_line$

                ' Replace all dynamic variables
                page_line$ = replace(page_line$, "<!--$TITLE-->", title$)
                page_line$ = replace(page_line$, "<!--$YEAR-->", Mid$(datetime$, 13, 4))
                page_line$ = replace(page_line$, "<!--$SLUG-->", slugify$(pagename))
                
                ' Push the current line to the client
                send c, page_line$
            Loop
            Close #2

            ' Output everything after the <!--$BODY--> line
            send c, Mid$(line$, InStr(line$, "<!--$BODY-->") + 12)
        Else
            ' Not a <!--$BODY--> line, so just push the full thing to the client
            send c, line$
        End If
    Loop
    Close #1

    ' Done!
End Sub

' static text files
Sub respond_static (c As Integer, header As String, filename as String, content_type As String)
    Print "Serving static file: " + filename

    send c, header
    send c, "Date: " + datetime$
    send c, "Server: QweB64"
    send c, "Last-Modified: " + StartTime
    ' 604800 seconds = 1 week
    ' 86400 seconds = 1 day
    send c, "Cache-Control: public, max-age=86400, s-maxage=86400"
    send c, "Connection: close"
    send c, "Content-Type: " + content_type + "; charset=UTF-8"
    send c, ""

    ' Read the file and write it to the handle
    ON ERROR GOTO StaticFileError
    Open "./web/static/" + filename For Input As #1
    ON ERROR GOTO 0

    Do While Not EOF(1)
       Line Input #1, line$
       send c, line$
    Loop

    Close #1

    ' Done!
End Sub

Sub respond_binary (c As Integer, header As String, filename as String, content_type As String)
    ' Headers first
    respond_headers c, header, content_type

    ' Read the file and write it to the handle
    ON ERROR GOTO StaticFileError
    Open "./web/static/" + filename For Binary As #1
    ON ERROR GOTO 0

    ' Define a buffer size, e.g., 1 KB chunks
    Const bufferSize = 1024
    Dim buffer As String * bufferSize

    Dim fileLength As Long
    fileLength = LOF(1) ' Length of file

    While fileLength > 0
        ' Determine the size of the next chunk to read
        If fileLength < bufferSize Then
            ' Resize buffer for the last piece of the file
            buffer = Space$(fileLength)
        End If
        
        ' Read a chunk of the file
        Get #1, , buffer
        
        ' Send the chunk to the client
        send c, buffer  ' Send the entire buffer
        
        ' Reduce the remaining file length by the size of the chunk just read
        fileLength = fileLength - Len(buffer)
    Wend

    Close #1

    ' Done!
End Sub

' This returns a string of the current date and time in the format required by HTTP
Function datetime$ ()
    Static init As Integer
    Static day() As String, month() As String, monthtbl() As Integer
    If init = 0 Then
        init = 1
        ReDim day(0 To 6) As String
        ReDim month(0 To 11) As String
        ReDim monthtbl(0 To 11) As Integer
        day(0) = "Sun": day(1) = "Mon": day(2) = "Tue"
        day(3) = "Wed": day(4) = "Thu": day(5) = "Fri"
        day(6) = "Sat"
        month(0) = "Jan": month(1) = "Feb": month(2) = "Mar"
        month(3) = "Apr": month(4) = "May": month(5) = "Jun"
        month(6) = "Jul": month(7) = "Aug": month(8) = "Sep"
        month(9) = "Oct": month(10) = "Nov": month(11) = "Dec"
        'Source: Wikipedia
        monthtbl(0) = 0: monthtbl(1) = 3: monthtbl(2) = 3
        monthtbl(3) = 6: monthtbl(4) = 1: monthtbl(5) = 4
        monthtbl(6) = 6: monthtbl(7) = 2: monthtbl(8) = 5
        monthtbl(9) = 0: monthtbl(10) = 3: monthtbl(11) = 5
    End If
    temp$ = Date$ + " " + Time$
    m = Val(Left$(temp$, 2))
    d = Val(Mid$(temp$, 4, 2))
    y = Val(Mid$(temp$, 7, 4))
    c = 2 * (3 - (y \ 100) Mod 4)
    y2 = y Mod 100
    y2 = y2 + y2 \ 4
    m2 = monthtbl(m - 1)
    weekday = c + y2 + m2 + d

    'leap year and Jan/Feb
    If ((y Mod 4 = 0) And (y Mod 100 <> 0) Or (y Mod 400 = 0)) And m <= 2 Then weekday = weekday - 1

    weekday = weekday Mod 7

    datetime$ = day(weekday) + ", " + Left$(temp$, 2) + " " + month(m - 1) + " " + Mid$(temp$, 7) + " GMT"
End Function

' removes extra spaces from a string, I guess?
Function shrinkspace$ (str1 As String)
    Do
        i = InStr(str1, Chr$(9))
        If i = 0 Then Exit Do
        Mid$(str1, i, 1) = " "
    Loop
    Do
        i = InStr(str1, CRLF + " ")
        If i = 0 Then Exit Do
        str1 = Left$(str1, i - 1) + Mid$(str1, i + 2)
    Loop
    Do
        i = InStr(str1, "  ")
        If i = 0 Then Exit Do
        str1 = Left$(str1, i - 1) + Mid$(str1, i + 1)
    Loop
    shrinkspace = str1
End Function

' slugifies a url path string, assuming no foreign characters
Function slugify$ (urlpath As string)
    str1$ = LCase$(urlpath)
    str1$ = replace$(str1$, " ", "-")
    str1$ = replace$(str1$, "/", "-")
    str1$ = replace$(str1$, "\", "-")
    str1$ = replace$(str1$, ":", "-")
    str1$ = replace$(str1$, "*", "-")
    str1$ = replace$(str1$, "?", "-")
    slugify$ = str1$
End Function

' replaces various template variables with their values
Function replace$ (str1 As String, template_var As String, template_value As String)
    Do
        i = InStr(str1, template_var)
        If i = 0 Then Exit Do
        str1 = Left$(str1, i - 1) + template_value + Mid$(str1, i + Len(template_var))
    Loop
    replace = str1
End Function

' Passing in variables by reference (such as title) so we can add more later
Sub read_metadata (pagename As String, title As String)
    ' Open the page file so we can read its metadata
    Open "./web/pages/" + pagename + ".html" For Input As #3

    If Not EOF(3) Then
        Line Input #3, page_line$
        ' Metadata is like this:
        ' <!--META
        ' TITLE: My Page Title
        ' -->
        If Left$(page_line$, 8) = "<!--META" Then
            ' Read all lines until we hit the end of the metadata
            Do While Not EOF(3)
                Line Input #3, page_line$
                If page_line$ = "-->" Then Exit Do

                ' Parse the metadata
                If Left$(page_line$, 6) = "TITLE:" Then
                    Print "Found title: " + Mid$(page_line$, 7)
                    title = Mid$(page_line$, 7)
                    ' Strip any left whitespace
                    Do While Left$(title, 1) = " "
                        title = Mid$(title, 2)
                    Loop
                End If
            Loop
        End If
    End If

    Close #3
End Sub

Sub send (c as Integer, s as String)
    Shared client_handle() As Integer

    ' add trailing CRLF
    s = s + CRLF

    Put #client_handle(c), , s
End Sub
