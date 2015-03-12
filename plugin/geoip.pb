IncludeFile "..\WinHTTP.pbi"
XIncludeFile "..\SSL_Library.pb"
IncludeFile "..\irc_special_chars.pbi"
Global Connection_ID.l = 0
Global ms_BetweenLines.i = 0
Global MaxLineLen.i = 0
Global UseSSL.i = 0

Procedure IRCUseConnection(Connection)
  Connection_ID = Connection
EndProcedure

Procedure IRCSendText(SendTo.s, Text.s)
  If Connection_ID <> 0
    Select UseSSL
      Case 0
        SendNetworkString(Connection_ID,"PRIVMSG "+SendTo+" :"+Text+Chr(13)+Chr(10))
      Case 1  
        SSL_Client_SendString(Connection_ID,"PRIVMSG "+SendTo+" :"+Text+Chr(13)+Chr(10))
    EndSelect  
  Else
    ; Do Nothing
  EndIf
EndProcedure

Procedure GeoIPLookup(Params$, ReplyTo$) 
  Protected PageSource$ = ReceiveHTTPString("http://freegeoip.net/csv/"+URLEncoder(Params$))
  If Params$ = "" : Params$ = "This Bot" : EndIf
  Protected IPAddr$ = ""
  IPAddr$ = StringField(PageSource$, 1, ",")
  Protected CountryCode$ = ""
  CountryCode$ = StringField(PageSource$, 2, ",")
  Protected CountryName$ = ""
  CountryName$ = StringField(PageSource$, 3, ",")
  Protected RegionCode$ = ""
  RegionCode$ = StringField(PageSource$, 4, ",")
  Protected RegionName$ = ""
  RegionName$ = StringField(PageSource$, 5, ",")
  Protected CityName$ = ""
  CityName$ = StringField(PageSource$, 6, ",")
  Protected ZipCode$ = ""
  ZipCode$ = StringField(PageSource$, 7, ",")
  Protected TimeZone$ = ""
  TimeZone$ = StringField(PageSource$, 8, ",")
  Protected Lat$ = StringField(PageSource$, 9, ",")
  Protected Lon$ = StringField(PageSource$, 10, ",")
  Protected Met$ = StringField(PageSource$, 11, ",")
  PageSource$ = ""
  IRCSendText(ReplyTo$, Params$ + " -> " + "[IP]:"+#IRC_COLOR_TEXT+"3 "+IPAddr$ + #IRC_COLOR_TEXT + "  [Country]:"+#IRC_COLOR_TEXT+"3 " + CountryCode$ + "("+CountryName$+")  "+#IRC_COLOR_TEXT+"[Region]:"+#IRC_COLOR_TEXT+"3 " + RegionCode$ + " ("+RegionName$+")  "+#IRC_COLOR_TEXT+"[City]:"+#IRC_COLOR_TEXT+"3 " + CityName$ + "  "+#IRC_COLOR_TEXT+"[ZIP]:"+#IRC_COLOR_TEXT+"3 " + ZipCode$ + "  "+#IRC_COLOR_TEXT+"[Lat./Lon.]:"+#IRC_COLOR_TEXT+"3 " + Lat$ + "/" + Lon$)
  Delay(ms_BetweenLines)
EndProcedure

ProcedureDLL geoip_user_ip(Params$, ReplyTo$, Sender$, Channel$, IRC_ConnectionID.i, LineDelay.i, MaxLineLength.i, ConnectionUseSSL.i) ; this is the function, as seen by the bot.
  ; You don't need to use all parameters, usually only "Params$" and "ReplyTo$", but all are always provided, in case they are needed.
  ; DLLProc() Naming Convention: example_user_echo() = 'lib-name'_'user/oper'_'command-name'
  If IRC_ConnectionID <> 0 ; Check
    IRCUseConnection(IRC_ConnectionID) ; Must Be Set.
    ms_BetweenLines = LineDelay ; Pause Between lines from main program.
    MaxLineLen = MaxLineLength  ; Optional, used if your program might output a line longer than a max, defined in the main program.
    UseSSL = ConnectionUseSSL
    GeoIPLookup(Params$, ReplyTo$) ; Call your worker Function once all is set.
  EndIf
EndProcedure
; IDE Options = PureBasic 5.31 (Windows - x86)
; ExecutableFormat = Shared Dll
; CursorPosition = 5
; Folding = 1
; EnableThread
; Executable = geoip.dll
; EnablePurifier
; IDE Options = PureBasic 5.31 (Windows - x86)
; ExecutableFormat = Shared Dll
; CursorPosition = 49
; FirstLine = 20
; Folding = -
; EnableThread
; Executable = ..\bin\plugin\geoip.dll
; EnablePurifier