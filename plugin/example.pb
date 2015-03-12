; EnableExplicit ; ###SSL-UPDATE### -> Removed to support cryptLib

XIncludeFile "..\SSL_Library.pb" ; ###SSL-UPDATE### -> 

Global Connection_ID.l = 0
Global ms_BetweenLines.i = 0
Global MaxLineLen.i = 0
Global UseSSL.i = 0 ; ###SSL-UPDATE### -> Added Global UseSSL.i 

Procedure IRCUseConnection(Connection)
  Connection_ID = Connection
EndProcedure

Procedure IRCSendText(SendTo.s, Text.s) ; ###SSL-UPDATE### -> Replaced Existing IRCSendText() with this version:
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

Procedure echoExample(Params$, ReplyTo$) ; This is the function where the actual work takes place (echoing the params back to sender in this case)
  
  IRCSendText(ReplyTo$, Params$) ; Always send text to "ReplyTo$"
  Delay(ms_BetweenLines)
  
EndProcedure ; you would want to replace the name/contents of this function, but keep the (Params$, ReplyTo$) portion the same. 

ProcedureDLL example_user_echo(Params$, ReplyTo$, Sender$, Channel$, IRC_ConnectionID.i, LineDelay.i, MaxLineLength.i, ConnectionUseSSL.i) ; this is the function, as seen by the bot.
                                                                                                                                           ; ###SSL-UPDATE### -> Added ConnectionUseSSL.i as last parameter to ALL Plug-Funcs.
  
  ; You don't need to use all parameters, usually only "Params$" and "ReplyTo$", but all are always provided, in case they are needed.
  ; DLLProc() Naming Convention: example_user_echo() = 'lib-name'_'user/oper'_'command-name'
  If IRC_ConnectionID <> 0 ; Check
    IRCUseConnection(IRC_ConnectionID) ; Must Be Set.
    ms_BetweenLines = LineDelay ; Pause Between lines from main program.
    MaxLineLen = MaxLineLength  ; Optional, used if your program might output a line longer than a max, defined in the main program.
    UseSSL = ConnectionUseSSL   ; ###SSL-UPDATE### -> Set Global UseSSL according to bot request.
    echoExample(Params$, ReplyTo$) ; Call your worker Function once all is set.
  EndIf
EndProcedure

; IDE Options = PureBasic 5.31 (Windows - x86)
; ExecutableFormat = Shared Dll
; CursorPosition = 42
; Folding = -
; EnableThread
; EnablePurifier