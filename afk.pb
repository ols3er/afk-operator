IncludeFile "WinHTTP.pbi"
IncludeFile "TrayIcon.pbc"
IncludeFile "irc_special_chars.pbi"
XIncludeFile "SSL_Library.pb"

; Configurable / Variables =============================================================
Global IRCVersion$ = "0."+Str(#PB_Editor_BuildCount)+"."+Str(#PB_Editor_CompileCount) + " Alpha"

; Connection Options (User-Configurable)
Global NetworkName$ = "irc.somenetwork.net"
Global NetworkHandle$ = ""
Global Port.i = 6667
Global Desired_Nick$ = "cgtest"
Global Password$ = ""
Global UseSSL.i = 0

; ZNC Options (User-Configurable)
Global UseZNC.i = 0 ; Enable if Port.i is really a ZNC, and set user/pass
Global ZNCUser.s= ""
Global ZNCPass.s= ""

; Misc Options (User-Configurable)
Global CommandIDChar$ = "!" 
Global Master.s = ""
Global MasterPass$ = ""
Global Debug_User$ = Master
Global InviteAccept.i = 1 
Global MaxLineLen.i = 306 
Global PINGTimeout = 5000 
Global PINGInterval=31000 
Global IdleTimeout=120000
Global ms_BetweenLines.i = 1500
Global Log_Write_Interval.i = 5000
Global PingOn = 0 ; Ping Debug
Global logHandle.l
Global PM_All_Replies = 0
Global LogMaxLines.i = 2000

; TBD By Server (Do Not Edit)
Global Host.s = ""
Global Nick.s = ""

; My Network Info (Do Not Edit)
Global Hostname$ = "" 
Global DomainName$ = "localdomain" 
Global FQDN$ = ""

; Misc (Do Not Edit)
Global ConnectionID.l = 0
Global Connected = 0
Global CurrentLogFile$ = "afk.log"
Global TriggerWordsFile$ = "trigger.words"
Global CurrentCMDThread.l = 0
Global CommandProcessorID.i = 0
Global LoggerThread.l = 0
Global EXIT = 0
Global RESTART = 0
Global LastPing = 0
Global IdleTime = 0
Global MainLoopThread = 0
Global Busy.i = 0
Global Null.i = 0
Global UseWordScan.i = 1
Global BufferSizeRecv.i = 16384

; Lists
Global NewList RecText.s()
;Global NewList Logs.s()
Global NewList CurrentUser.s()
Global NewList CommandStack.s()
Global NewList CommandStackRun.s()
Global NewList IgnoreList.s()
Global NewList TriggerWords.s()

Structure Bot_Operator
  OperNick$
  OperHost$
  OperPass$
  LoggedIn.i
  Enabled.i
  FailedLogins.i
EndStructure

Global NewList OperListItem.Bot_Operator()

Structure PlugCommand
  LibPath$
  CMDString$
  FuncAddr.l
  DisabledChans$
  OperOnly.i
  Enabled.i
EndStructure

Structure IRC_Channel
  ChannelName$
  ChannelModes$
  ChannelTopic$
  ScanURLS.i
  List Users.s()
EndStructure

Global NewList PluginFuncs.PlugCommand()

Global NewList ChannelsJoined.IRC_Channel()

; Array of Icon Frames for Tray Animations
Global Dim hAnim(3)

; Command is PM or Public/Channel
Enumeration
  #CG_COMMAND_PRIVATE
  #CG_COMMAND_PUBLIC
EndEnumeration

Enumeration
  #AFK_CONF_TRIGGERWORDS
  #AFK_CURRENT_LOG
  #AFK_SEEN_DB
EndEnumeration

; The GUI Parts
Enumeration 
  #WINDOW_MAIN
  #ShortcutKey
  #DEBUG_MAIN
  #BUTTON_INFO
  #BUTTON_CLOSE
  #BUTTON_CLEAR
  #BUTTON_START
  #BUTTON_HIDE
  #BUTTON_CHANSND
  #BUTTON_USERSND
  #BUTTON_QUIT
  #BUTTON_SAY
  #EDIT_SAY
  #EDIT_HOST
  #EDIT_CHAN
  #EDIT_PORT
  #EDIT_NICK
  #LIST_CHANS
  #LIST_USERS
  #MNU_TRAY
  #GADGET_TITLE
  #BUTTON_RUNC
  #FONT_COUR
  #CHECK_ZNC
  #CHECK_SSL
  #EDIT_ZNCUSR
  #EDIT_ZNCPASS
  #EDIT_NSPASS
  #PLUGIN_FOLDER
  #TEXT_HOST
  #TEXT_PORT
  #TEXT_BOT_NICK
  #TEXT_NS_PASS
EndEnumeration

Global hWnd.l = 0 ; Main Window Handle

Global ToolTipText$
Global BalloonTitle$
Global BalloonTexts$

Global objTray.TrayIcon

#FLAGS = #PB_Window_ScreenCentered | #PB_Window_SystemMenu ;| #PB_Window_BorderLess ; | #PB_Window_Tool
#WM_USER_TRAYICON = #WM_USER

; =======================================================================================

Procedure SetBusy(BusyStatus.i)
  Select BusyStatus
    Case 0
      Busy = BusyStatus
      objTray\StopAnimation()
    Case 1
      Busy = BusyStatus
      objTray\SetAnimationFrames(4)
      objTray\SetAnimationDelay(100)
      objTray\LoadFrameIcon(0, ImageID(hAnim(0)))
      objTray\LoadFrameIcon(1, ImageID(hAnim(1)))
      objTray\LoadFrameIcon(2, ImageID(hAnim(2)))
      objTray\LoadFrameIcon(3, ImageID(hAnim(3)))
      objTray\StartAnimation(-1) 
  EndSelect
EndProcedure

Procedure TimeZoneOffset()
  Protected result,mode
 Protected TZ.TIME_ZONE_INFORMATION
 mode=GetTimeZoneInformation_(@TZ)
 If mode=1
  result-TZ\Bias
 ElseIf mode=2
  result-TZ\Bias-TZ\DaylightBias
 EndIf
 ProcedureReturn result*60
EndProcedure

Procedure.s StringBetween(SourceString$, String1$, String2$, OccurenceNumber.i=0, StartPos.i=0)
  Protected Start1.i = StartPos
  Protected End1.i = 0
  Protected I.i = 0
  If OccurenceNumber <> 0
    For I = 0 To OccurenceNumber
      Select I
        Case 0
          Start1 = FindString(SourceString$, String1$, Start1) + Len(String1$)
        Default
          Start1 = FindString(SourceString$, String1$, Start1) + Len(String1$)
      EndSelect
    Next
  Else
    Start1 = FindString(SourceString$, String1$, 0) + Len(String1$)
  EndIf
  End1 = FindString(SourceString$, String2$, Start1)
  End1 - Start1
  If End1 = 0 : End1 = Len(SourceString$) : EndIf
  ProcedureReturn Mid(SourceString$, Start1, End1)
EndProcedure

Procedure.s RandHex(strLen.i)
*Key = AllocateMemory(strLen)
  If OpenCryptRandom() And *Key
    CryptRandomData(*Key, strLen)
    For i = 0 To strLen-1
      Text$ + RSet(Hex(PeekB(*Key+i), #PB_Byte), 1, "0")
    Next i     
    CloseCryptRandom()
    ProcedureReturn Text$
  Else
    ;yoig
  EndIf
EndProcedure

Procedure.i CountLinesInTextFile(TextFile.s)
  Protected Count.i = 0
  If ReadFile(0, TextFile)
  ReadStringFormat(0)
  While Not Eof(0)
    If ReadString(0)
      count + 1
    EndIf
  Wend
  CloseFile(0)
  ProcedureReturn count
EndIf
ProcedureReturn 0
EndProcedure

Procedure.s ReadSpecificLineOfTextFile(TextFile.s, LineNumber) ; Clean Up - Not only for quotes.
  Protected Count.i = 0
  Protected tmp$ = ""
  If LineNumber > CountLinesInTextFile(TextFile) : ProcedureReturn "Quote Does Not Exist" : EndIf
  If ReadFile(0, TextFile)
    ReadStringFormat(0)
    While Not Eof(0)
      tmp$ = ReadString(0)
      If tmp$ <> ""
        count + 1
        If count = LineNumber
          ProcedureReturn tmp$
        EndIf
      EndIf
    Wend
  EndIf
  ProcedureReturn ""
EndProcedure

Procedure AppendTextFile(TextFile.s, LineToAdd.s)
  Define Handle.l
  If FileSize(TextFile) = -1
    Handle = CreateFile(#PB_Any, TextFile)
    FileSeek(Handle, Lof(Handle))
    WriteStringN(Handle, LineToAdd)
  Else
    Handle = OpenFile(#PB_Any, TextFile)
    FileSeek(Handle, Lof(Handle))
    WriteStringN(Handle, LineToAdd)
  EndIf
  CloseFile(Handle)
EndProcedure

Procedure.i Conf_Read_TriggerWords()
  If ReadFile(#AFK_CONF_TRIGGERWORDS, TriggerWordsFile$)
    ClearList(TriggerWords())
    While Eof(#AFK_CONF_TRIGGERWORDS) = 0
      AddElement(TriggerWords())
      TriggerWords() = ReadString(#AFK_CONF_TRIGGERWORDS)
    Wend
    CloseFile(#AFK_CONF_TRIGGERWORDS)
    ProcedureReturn #True
  EndIf 
  ProcedureReturn #False
EndProcedure

Procedure.i Conf_Write_TriggerWords()
  If CreateFile(#AFK_CONF_TRIGGERWORDS, TriggerWordsFile$)
    ResetList(TriggerWords())
    While NextElement(TriggerWords())
      WriteStringN(#AFK_CONF_TRIGGERWORDS, TriggerWords())
    Wend
    CloseFile(#AFK_CONF_TRIGGERWORDS)
    ProcedureReturn #True
  EndIf
  ProcedureReturn #False
EndProcedure

Procedure LogText(LogOutput.s)
  If IsGadget(#DEBUG_MAIN) And (Not FindString(LogOutput, ")PONG :")) And (Not FindString(LogOutput, ")PING :")) And (Not FindString(LogOutput, " 372 "+ Nick + " :"))
    AddGadgetItem(#DEBUG_MAIN, -1, LogOutput)
    If CurrentLogFile$ <> "afk.log"
      OpenFile(#AFK_CURRENT_LOG, CurrentLogFile$)
      FileSeek(#AFK_CURRENT_LOG, Lof(#AFK_CURRENT_LOG))
      WriteStringN(#AFK_CURRENT_LOG, LogOutput)
      CloseFile(#AFK_CURRENT_LOG)
    EndIf 
    If CountGadgetItems(#DEBUG_MAIN) > LogMaxLines
      ClearGadgetItems(#DEBUG_MAIN)
    EndIf
    SetGadgetState(#DEBUG_MAIN, CountGadgetItems(#DEBUG_MAIN)- 1)                                   ;/ ListView
    SendMessage_(GadgetID(#DEBUG_MAIN), #LVM_ENSUREVISIBLE, CountGadgetItems(#DEBUG_MAIN)- 1, #True)  ;/ ListIcon
    SendMessage_(GadgetID(#DEBUG_MAIN), #EM_SCROLLCARET, #False, #False)    
  EndIf
EndProcedure

Procedure IRCConnect(Server.s, Port.l)
Select UseSSL
  Case 0
    Protected Connection = OpenNetworkConnection(Server, Port)
    If Connection <> 0
      ConnectionID = Connection
    EndIf
    ProcedureReturn Connection
  Case 1
    Connection = SSL_Client_OpenConnection(Server, Port)
    If Connection <> 0
      ConnectionID = Connection
    EndIf
    ProcedureReturn Connection 
EndSelect
EndProcedure

Procedure IRCUseConnection(Connection)
  ConnectionID = Connection
EndProcedure

Procedure RawText(Text$)
  If ConnectionID <> 0  
    LogText(FormatDate("[%yyyy/%mm/%dd-%hh:%ii:%ss]",Date())+"(->)"+Text$)
    Select UseSSL
      Case 0
        SendNetworkString(ConnectionID, Text$ + Chr(13)+Chr(10))
      Case 1
        SSL_Client_SendString(ConnectionID, Text$ + Chr(13)+Chr(10))
    EndSelect
  EndIf
EndProcedure

Procedure IRCLogin(Server.s, Name.s)
  If ConnectionID <> 0
    If UseZNC = 1
      RawText("PASS "+ZNCUser+":"+ZNCPass)
    EndIf
    RawText("USER "+ReplaceString(Name, " ", "_")+" "+Hostname$+" "+Server+" www.cyberghetto.net")
    RawText("NICK "+ReplaceString(Name, " ", "_"))
  Else
    ; Do Nothing
  EndIf
EndProcedure

Procedure IRCChangeNick(Name.s)
  If ConnectionID <> 0
    RawText("NICK "+ReplaceString(Name, " ", "_"))
    Delay(ms_BetweenLines)
    Protected LastNick$ = Nick 
    Nick = Name
  Else
    ; Do Nothing
  EndIf
EndProcedure

Procedure IRCJoin(Channel.s)
  If ConnectionID <> 0
    RawText("JOIN " + Channel)
  Else
    ; Do Nothing
  EndIf
EndProcedure

Procedure IRCLeave(Channel.s)
  If ConnectionID <> 0
    RawText("PART " + Channel)
  Else
    ;Do Nothing
  EndIf
EndProcedure

Procedure IRCJoinList(ChanList.s)
  Protected Params$ = ChanList
  If Params$ <> ""
    If FindString(Params$, " ")
      Protected JoinCount.i = CountString(Params$, " ") + 1
      Protected StartCount.i= 0
      For StartCount = 1 To JoinCount
        Debug StringField(Params$, StartCount, " ")
        IRCJoin(StringField(Params$, StartCount, " "))
      Next
    Else
      IRCJoin(Params$)
    EndIf
  Else
    ;
  EndIf
EndProcedure

Procedure IRCPartList(ChanList.s)
  Protected Params$ = ChanList
  If Params$ <> ""
    If FindString(Params$, " ")
      Protected JoinCount.i = CountString(Params$, " ") + 1
      Protected StartCount.i= 0
      For StartCount = 1 To JoinCount
        IRCLeave(StringField(Params$, StartCount, " "))
      Next
    Else
      IRCLeave(Params$)
    EndIf
  Else
    ;
  EndIf
EndProcedure

Procedure IRCLeaveAllChans(Cycle.i=#False)
  Protected ChanList$ = ""
  ForEach ChannelsJoined()
    Channel$ = ChannelsJoined()\ChannelName$
    ChanList$ = ChanList$ + Channel$ + " "
  Next
  IRCPartList(ChanList$)
  If Cycle 
    Delay(ms_BetweenLines)
    IRCJoinList(ChanList$)
  EndIf
EndProcedure

Procedure IRCSendText(SendTo.s, Text.s)
  If ConnectionID <> 0
    RawText("PRIVMSG " + SendTo + " :" + Text)
  Else
    ; Do Nothing
  EndIf
EndProcedure

Procedure.s IRCGetFrom(Str.s) 
  If StringBetween(Str.s, ":", "!") <> "" And Not FindString((StringBetween(Str.s, ":", "!")), " ")
    ProcedureReturn StringBetween(Str.s, ":", "!")
  Else
    ProcedureReturn StringBetween(Str.s, ":", " ")
  EndIf
EndProcedure

Procedure.s IRCGetTo(Str.s) 
  If Not FindString(Str.s, "PRIVMSG ")
    ProcedureReturn StringField(Str.s, 3, " ")
  EndIf
  Protected Result$ = StringBetween(Str.s, "PRIVMSG ", " :")
  If Result$ <> ""
    ProcedureReturn Result$
  Else
    ; Nothing
  EndIf
EndProcedure 

Procedure.s IRCGetText(STR.s)
  Protected Start = FindString(STR.s, ":", FindString(STR.s, "PRIVMSG", 2)+Len("PRIVMSG"))
  If Start = 0
    Start = FindString(STR.s, IRCGetTo(STR.s) + " ", FindString(STR.s, "PRIVMSG", 2)+Len("PRIVMSG")) + Len(IRCGetTo(STR.s)) 
  EndIf
  ProcedureReturn Right(STR, Len(STR)-Start)
EndProcedure

Procedure.s IRCGetHost(LineString$)
  ProcedureReturn StringBetween(LineString$, "@", " ")
EndProcedure

Procedure.s IRCGetPingMsg(STR.s)
  Protected Start = FindString(STR.s, ":", 0)+1
  Protected Stop = Len(STR.s)+1
  ProcedureReturn Mid(STR.s, Start, Stop-Start)
EndProcedure

Procedure.s IRCGetID(Line.s)
  ProcedureReturn StringField(Line, 2, " ")
EndProcedure

Procedure.s IRCGetP1(Line.s)
  ProcedureReturn StringField(Line, 3, " ")
EndProcedure

Procedure.s IRCGetP2(Line.s)
  ProcedureReturn StringField(Line, 4, " ")
EndProcedure

Procedure.s IRCGetP3(Line.s)
  ProcedureReturn StringField(Line, 5, " ")
EndProcedure

Procedure IRCEnumNames(InChannel.s)
  ForEach ChannelsJoined()
    If ChannelsJoined()\ChannelName$ = InChannel
      ;ChannelsJoined()\UsersInChannel$ = ""
    EndIf
  Next
  If ConnectionID <> 0
    RawText("NAMES " + InChannel)
  EndIf
EndProcedure 

Procedure.s IRCLocate(NickName$)
  Protected ResultString$ = ""
  ForEach ChannelsJoined()
    ForEach ChannelsJoined()\Users()
      If Trim(UCase(ChannelsJoined()\Users())) = Trim(UCase(NickName$))
        ResultString$ = ResultString$ + ChannelsJoined()\ChannelName$ + " "
      EndIf
    Next
  Next
  ResultString$ = Trim(ResultString$)
  ProcedureReturn ResultString$
EndProcedure

Procedure.s IRCGetLine()
  Protected K.i = 0
  Protected Line.s = ""
  If ConnectionID <> 0 And Connected = 1
    Select UseSSL
      Case 0
        If NetworkClientEvent(ConnectionID) = 2
          LastElement(RecText())
          Protected *Buffer = AllocateMemory(BufferSizeRecv)
          ReceiveNetworkData(ConnectionID, *Buffer, BufferSizeRecv)
          Protected txt.s = PeekS(*Buffer)
          FreeMemory(*Buffer)
          ReplaceString(txt, Chr(13), Chr(10))
          ReplaceString(txt, Chr(10)+Chr(10), Chr(10))
          For K=1 To CountString(txt, Chr(10))
            Line.s = RemoveString(RemoveString(StringField(txt, k, Chr(10)), Chr(10)), Chr(13))
            If Line <> ""
              If FindString(Line, "PING :", 0) Or FindString(Line, "VERSION", 0)
                RawText(ReplaceString(Line,"PING :", "PONG :",0))
              Else
                AddElement(RecText())
                RecText() = Line.s
              EndIf
            EndIf
          Next
        EndIf
      Case 1
        If SSL_Client_Event(ConnectionID) = #SSLEvent_Data
          LastElement(RecText())
          *Buffer = AllocateMemory(BufferSizeRecv)
          SSL_Client_ReceiveData(ConnectionID, *Buffer, BufferSizeRecv)
          txt.s = PeekS(*Buffer)
          FreeMemory(*Buffer)
          ReplaceString(txt, Chr(13), Chr(10))
          ReplaceString(txt, Chr(10)+Chr(10), Chr(10))
          For K=1 To CountString(txt, Chr(10))
            Line.s = RemoveString(RemoveString(StringField(txt, k, Chr(10)), Chr(10)), Chr(13))
            If Line <> ""
              If FindString(Line, "PING :", 0)  Or FindString(Line, "VERSION", 0) 
                RawText(ReplaceString(Line,"PING :", "PONG :",0))
              Else
                AddElement(RecText())
                RecText() = Line.s
              EndIf
            EndIf
          Next
        EndIf
    EndSelect
    If ListSize(RecText()) > 0
      FirstElement(RecText())
      txt.s = RecText()
      DeleteElement(RecText())
      ProcedureReturn txt
    EndIf
  EndIf
EndProcedure

Procedure.f IRCPing(Server.s, Timeout)
If ConnectionID <> 0
  Protected *Buffer = AllocateMemory(BufferSizeRecv)
  RawText("PING :" + Server)
  Protected Time = ElapsedMilliseconds()
  Select UseSSL
    Case 0
      While NetworkClientEvent(ConnectionID) <> 2 
        Delay(1) 
        If ElapsedMilliseconds()-Time > Timeout 
          Break 
        EndIf 
      Wend
    Case 1
      While SSL_Client_Event(ConnectionID) <> 2 
        Delay(1) 
        If ElapsedMilliseconds()-Time > Timeout 
          Break 
        EndIf 
      Wend
  EndSelect
  If ElapsedMilliseconds()-Time <= Timeout
    Protected T = ElapsedMilliseconds()-Time
    Select UseSSL
      Case 0
        ReceiveNetworkData(ConnectionID, *Buffer, BufferSizeRecv)
      Case 1
        SSL_Client_ReceiveData(ConnectionID, *Buffer, BufferSizeRecv)
    EndSelect
    FreeMemory(*Buffer)
    ProcedureReturn T
  Else
    ProcedureReturn -1
  EndIf
Else
  ; Do Nothing
EndIf 
EndProcedure

Procedure IRCDisconnect(Msg.s)
  If ConnectionID <> 0
    Select UseSSL
      Case 0
        RawText("QUIT " + Msg.s)
        CloseNetworkConnection(ConnectionID)
        ConnectionID = 0
      Case 1
        RawText("QUIT " + Msg.s)
        SSL_Client_CloseConnection(ConnectionID)
        ConnectionID = 0
    EndSelect
  Else
    ; 
  EndIf 
  ;Delay(ms_BetweenLines)
EndProcedure

Procedure.s NativeGetVersion()
    Protected Dim tOSVw.l($54)
    Protected lib = LoadLibrary_("ntdll.dll")
    Protected proc = GetProcAddress_(lib, "RtlGetVersion")
    tOSVw(0) = $54 * $4
    CallFunctionFast(proc, @tOSVw())
    FreeLibrary_(lib)
    ProcedureReturn Str(tOSVw(4)) + "." + Str(tOSVw(1)) + "." + Str(tOSVw(2))
EndProcedure

Procedure.s VersionToName(sVersion.s)
    Select sVersion
        Case "1.0.0":     ProcedureReturn "Windows 95"
        Case "1.1.0":     ProcedureReturn "Windows 98"
        Case "1.9.0":     ProcedureReturn "Windows Millenium"
        Case "2.3.0":     ProcedureReturn "Windows NT 3.51"
        Case "2.4.0":     ProcedureReturn "Windows NT 4.0"
        Case "2.5.0":     ProcedureReturn "Windows 2000"
        Case "2.5.1":     ProcedureReturn "Windows XP"
        Case "2.5.3":     ProcedureReturn "Windows 2003 (SERVER)"
        Case "2.6.0":     ProcedureReturn "Windows Vista"
        Case "2.6.1":     ProcedureReturn "Windows 7"
        Case "2.6.2":     ProcedureReturn "Windows 8"
        Case "2.6.3":     ProcedureReturn "Windows 8.1"
        Default:          ProcedureReturn "Undefined (I Was Compiled Q1 2015)"
    EndSelect
EndProcedure  

Procedure ToggleShowPing(ReplyTo$)
  Select PingOn
    Case 0  
      IRCSendText(ReplyTo$, "[*] Enabling Channel Latency Reporting.")
      PingOn = 1
      Debug_User$ = ReplyTo$
    Case 1
      IRCSendText(ReplyTo$, "[*] Disabling Channel Latency Reporting.")
      PingOn = 0
  EndSelect
EndProcedure

Procedure ToggleWordScan(ReplyTo$)
  Select UseWordScan
    Case 0
      IRCSendText(ReplyTo$, "[*] Enabling Word Scan.")
      UseWordScan = 1
    Case 1
      IRCSendText(ReplyTo$, "[*] Disabling Word Scan.")
      UseWordScan = 0
  EndSelect
EndProcedure

Procedure TogglePrivateMode(ReplyTo$)
  Select PM_All_Replies
    Case 0
      IRCSendText(ReplyTo$, "[*] Enabling Private/Quiet Mode")
      PM_All_Replies = 1
    Case 1
      IRCSendText(ReplyTo$, "[*] Disabling Private/Quiet Mode")
      PM_All_Replies = 0
  EndSelect
EndProcedure

Procedure.s TrimUserSymbols(NickName$)
  NickName$ = RemoveString(NickName$, "@")
  NickName$ = RemoveString(NickName$, "~")
  NickName$ = RemoveString(NickName$, "&")
  NickName$ = RemoveString(NickName$, "%")
  NickName$ = RemoveString(NickName$, "+")
  ProcedureReturn NickName$
EndProcedure  
  
Procedure SetLineDelay(NewValue.i, ReplyTo$="")
  If NewValue > 0 
    ms_BetweenLines = NewValue
    If ReplyTo$ <> ""
      IRCSendText(ReplyTo$, "[*] Line-Delay="+Str(ms_BetweenLines)+"ms")
    EndIf 
  Else
    If ReplyTo$ <> ""
      IRCSendText(ReplyTo$, "[*] Line-Delay="+Str(ms_BetweenLines)+"ms")
    EndIf 
  EndIf     
EndProcedure

Procedure CGInfo(ReplyTo$)
  Protected UName$ = Space(255)
  Protected i = Len(UName$)
  GetUserNameEx_(12, UName$, @i)
  If Trim(UName$) = ""
    UName$ = ComputerName()+"\"+UserName()
  EndIf
  If DomainName$ = "" : DomainName$ = "localdomain" : EndIf
  If Hostname$ = "" : Hostname$ = ComputerName() : EndIf
  IRCSendText(ReplyTo$, "[*] [AFK Operator v"+IRCVersion$+"] - [Host]: (" + Hostname$ + "." + DomainName$ + ") | [User]: " + Trim(UName$) + " ("+UserName()+") | " + "[Stamp]: ["  + FormatDate("%yyyy/%mm/%dd]:[%hh:%ii:%ss]", Date()) + " | " + "[PID]: " + Str(GetCurrentProcessId_()) +" | " + "[OS]: " + VersionToName(NativeGetVersion()) + " ("+NativeGetVersion()+")")
EndProcedure

Procedure ShutdownBot(Params$, ComType.i, ReplyTo$) 
  Params$ = Trim(Params$)
  If ComType = #CG_COMMAND_PRIVATE
    IRCSendText(ReplyTo$, "[*] Quitting... Received ['cg-quit'] Command")
    objTray\Destroy()
    IRCDisconnect("['cg-quit']")
    End
  Else
    If Params$ = "all" Or Params$ = Nick Or Params$ = Desired_Nick$
      IRCSendText(ReplyTo$, "[*] Quitting... Received ['cg-quit'] (public) Command")
      IRCDisconnect("['cg-quit'] (public)")
      End
    Else
      IRCSendText(ReplyTo$, #IRC_BOLD_TEXT + "[*] Only Accepted VIA PM or when 'all' is specified.")
    EndIf
  EndIf
EndProcedure

Procedure UnloadPlugin(LibName$, ReplyTo$)
  LibName$ = Trim(LibName$)
  ForEach PluginFuncs()
    If GetFilePart(PluginFuncs()\LibPath$) = LibName$
      IRCSendText(ReplyTo$, "[*] "+GetFilePart(PluginFuncs()\LibPath$)+" Un-Loaded. ( "+ CommandIDChar$ + PluginFuncs()\CMDString$ + " )")
      DeleteElement(PluginFuncs())
    EndIf
  Next
  If LibName$ = "all"
    ClearList(PluginFuncs())
    IRCSendText(ReplyTo$, "[*] ALL Plugins Un-Loaded.")
  EndIf
EndProcedure

Procedure DisablePlugCommand(Command$, ReplyTo$)
  Command$ = Trim(Command$)
  If Left(Command$, 1) = CommandIDChar$
    Command$ = Right(Command$, Len(Command$)-1)
  EndIf
  ForEach PluginFuncs()
    If PluginFuncs()\CMDString$ = Command$
      PluginFuncs()\Enabled = #False
      IRCSendText(ReplyTo$, "[*] " + CommandIDChar$ + PluginFuncs()\CMDString$ + " is now disabled globally.")
    EndIf
  Next
EndProcedure

Procedure EnablePlugCommand(Command$, ReplyTo$)
  Command$ = Trim(Command$)
  If Left(Command$, 1) = CommandIDChar$
    Command$ = Right(Command$, Len(Command$)-1)
  EndIf
  ForEach PluginFuncs()
    If PluginFuncs()\CMDString$ = Command$
      PluginFuncs()\Enabled = #True
      IRCSendText(ReplyTo$, "[*] " + CommandIDChar$ + PluginFuncs()\CMDString$ + " is now enabled globally.")
    EndIf
  Next
EndProcedure

Procedure ListLoadedPlugins(ReplyTo$)
  ForEach PluginFuncs()
    Protected EnabledStatus$ = ""
    Select PluginFuncs()\Enabled
      Case #True
        EnabledStatus$ = "Enabled"
      Case #False
        EnabledStatus$ = "Disabled"
    EndSelect
    IRCSendText(ReplyTo$,  "[*] " + CommandIDChar$ + PluginFuncs()\CMDString$ + " ( " + GetFilePart(PluginFuncs()\LibPath$) + " ) - ["+EnabledStatus$+"]")
    Delay(ms_BetweenLines)
  Next
EndProcedure

Procedure UpdateChanListView()
  ClearGadgetItems(#LIST_CHANS)
  ForEach ChannelsJoined()
    AddGadgetItem(#LIST_CHANS, -1, ChannelsJoined()\ChannelName$)
  Next
EndProcedure

Procedure ListConnectedChannels(ReplyTo$)
  ForEach ChannelsJoined()
    IRCSendText(ReplyTo$, "[*] " + ChannelsJoined()\ChannelName$)
    Delay(ms_BetweenLines)
  Next
  UpdateChanListView()
EndProcedure

Procedure UpdateUsersInChan(Channel$, UserList$)
  UserList$ = Trim(UserList$) + " "
  ForEach ChannelsJoined()
    If ChannelsJoined()\ChannelName$ = Channel$
      If Trim(UserList$) <> ""
        Protected NameCountCurrent.i = CountString(UserList$, " ")
        For X = 1 To NameCountCurrent
          AddElement(ChannelsJoined()\Users())
          ChannelsJoined()\Users() = StringField(UserList$, X, " ")
        Next
        SortList(ChannelsJoined()\Users(), #PB_Sort_Ascending | #PB_Sort_NoCase)
        Protected Current$ = "@@@@@"
        ForEach ChannelsJoined()\Users()
          If ChannelsJoined()\Users() <> Current$
            Current$ = ChannelsJoined()\Users()
          Else
            DeleteElement(ChannelsJoined()\Users())
          EndIf
        Next
        Debug "Current List:" ; ***
        ForEach ChannelsJoined()\Users() ; ***
          Debug ChannelsJoined()\Users() ; ***
        Next ; ***
      EndIf
    EndIf
  Next
EndProcedure

Procedure SearchUsers(Params$, ReplyTo$)
  Params$ = Trim(Params$)
  FoundChannels$ = IRCLocate(Params$)
  If FoundChannels$ <> ""
    IRCSendText(ReplyTo$, "[*] '" + Params$ + "' seen in: " + FoundChannels$)
    Delay(ms_BetweenLines)
  Else
    IRCSendText(ReplyTo$, "[*] User: " + Params$ + " not currently seen.")
  EndIf
EndProcedure

Procedure.i IsChannel(Channel$)
  ForEach ChannelsJoined()
    If ChannelsJoined()\ChannelName$ = Trim(Channel$)
      ProcedureReturn #True
    EndIf
  Next
  ProcedureReturn #False
EndProcedure

Procedure ShowChannelUsers(Channel$, ReplyTo$)
  Channel$ = Trim(Channel$)
  If IsChannel(Channel$)
    ForEach ChannelsJoined()
      If ChannelsJoined()\ChannelName$ = Channel$
        Protected SendString$ = ""
        ForEach ChannelsJoined()\Users()
          SendString$ = SendString$ + ChannelsJoined()\Users() + ", "
        Next
        IRCSendText(ReplyTo$, SendString$)
      EndIf 
    Next
  Else
    IRCSendText(ReplyTo$, "[*] I'm not in '"+Channel$+"'")
  EndIf
EndProcedure

Procedure.i UpdateChanList(TheChannel$)
  ForEach ChannelsJoined()
    If ChannelsJoined()\ChannelName$ = TheChannel$
      ProcedureReturn #False
    EndIf
  Next
  AddElement(ChannelsJoined())
  ChannelsJoined()\ChannelName$ = TheChannel$
  ChannelsJoined()\ScanURLS = 0
  UpdateChanListView()
  ProcedureReturn #True
EndProcedure

Procedure.i RemoveChanList(TheChannel$)
  Protected Result.i = #False
  ForEach ChannelsJoined()
    If ChannelsJoined()\ChannelName$ = TheChannel$
      DeleteElement(ChannelsJoined())
      Result = #True
    EndIf
  Next
  UpdateChanListView()
  ProcedureReturn Result
EndProcedure

Procedure.i UserQuit(NickName$)
  Protected Result.i = #False
  ForEach ChannelsJoined()
    ForEach ChannelsJoined()\Users()
      If ChannelsJoined()\Users() = NickName$
        Debug "Removing " + ChannelsJoined()\Users() + " from " + ChannelsJoined()\ChannelName$ ; ***
        DeleteElement(ChannelsJoined()\Users())
        Result = #True
      EndIf
    Next
  Next
  ProcedureReturn Result
EndProcedure

Procedure.i UserNick(OldNick$, NewNick$)
  Protected Result.i = #False
  ForEach ChannelsJoined()
    ForEach ChannelsJoined()\Users()
      If ChannelsJoined()\Users() = OldNick$
        ChannelsJoined()\Users() = NewNick$
        Result = #True
      EndIf
    Next
  Next
  ProcedureReturn #False
EndProcedure

Procedure ScanPlugins(ReplyTo$, Mask$="*.dll")
  ForEach PluginFuncs()
    If GetFilePart(PluginFuncs()\LibPath$) = Mask$
      DeleteElement(PluginFuncs())
    EndIf
  Next
  If Mask$ = "*.dll" : ClearList(PluginFuncs()) : EndIf
  Protected PlugPath$ = GetPathPart(ProgramFilename())
  PlugPath$ + "plugin\"
  If ExamineDirectory(#PLUGIN_FOLDER, PlugPath$, Mask$)
    While NextDirectoryEntry(#PLUGIN_FOLDER)
      If DirectoryEntryType(#PLUGIN_FOLDER) = #PB_DirectoryEntry_File
        Protected lHandle = OpenLibrary(#PB_Any, PlugPath$ + DirectoryEntryName(#PLUGIN_FOLDER))
        If lHandle
          If ExamineLibraryFunctions(lHandle)
            Protected CommandList$ = " -> "
            While NextLibraryFunction()
              If (Trim(StringField(LibraryFunctionName(), 3, "_")) <> "") And (StringField(LibraryFunctionName(), 1, "_") = Left(DirectoryEntryName(#PLUGIN_FOLDER), Len(DirectoryEntryName(#PLUGIN_FOLDER))-4))
                AddElement(PluginFuncs())
                PluginFuncs()\LibPath$ = PlugPath$ + DirectoryEntryName(#PLUGIN_FOLDER)
                PluginFuncs()\CMDString$ = StringField(LibraryFunctionName(), 3, "_")
                PluginFuncs()\FuncAddr = LibraryFunctionAddress()
                PluginFuncs()\Enabled = #True
                Select StringField(LibraryFunctionName(), 2, "_")
                  Case "oper"
                    PluginFuncs()\OperOnly = 1
                  Case "user"
                    PluginFuncs()\OperOnly = 0
                EndSelect
                CommandList$ = CommandList$ + CommandIDChar$ + StringField(LibraryFunctionName(), 3, "_") + ", "
              EndIf
            Wend
            If CommandList$ <> " -> "
              CommandList$ = Left(CommandList$, Len(CommandList$)-2)
            EndIf
            IRCSendText(ReplyTo$, "[*] "+ DirectoryEntryName(#PLUGIN_FOLDER) + " Loaded. Plugin Provides: " + CommandList$)
            Delay(ms_BetweenLines)
          EndIf
        EndIf
        CloseLibrary(lHandle)
      EndIf
    Wend
  EndIf
EndProcedure

Procedure.i IsIgnored(Person$)
  ForEach IgnoreList()
    If IgnoreList() = Person$
      ProcedureReturn #True
    EndIf
  Next
  ProcedureReturn #False
EndProcedure

Procedure Ignore(Person$, Mode.i, ReplyTo$)
  Select Mode
    Case 0
      If IsIgnored(Person$)
        ForEach IgnoreList()
          If IgnoreList() = Person$
            DeleteElement(IgnoreList())
            IRCSendText(ReplyTo$, "[*] " + Person$ + " was removed from the IgnoreList().")
          EndIf
        Next
      Else
        IRCSendText(ReplyTo$, "[*] " + Person$ + " is not in the IgnoreList().")
      EndIf 
    Case 1
      If Not IsIgnored(Person$)
        AddElement(IgnoreList())
        IgnoreList() = Person$
        IRCSendText(ReplyTo$, "[*] " + Person$ + " was added to the IgnoreList().")
      Else
        IRCSendText(ReplyTo$, "[*] " + Person$ + " is already in the IgnoreList().")
      EndIf
  EndSelect
EndProcedure

Procedure ShowIgnoreList(ReplyTo$) ; Clean Up
  ForEach IgnoreList()
    IRCSendText(ReplyTo$, IgnoreList())
    Delay(ms_BetweenLines)
  Next
EndProcedure

Procedure ChanBlockCmd(Params$, ReplyTo$, Status.i)
  Protected Command$ = StringField(Params$, 1, " ")
  Protected InChannel$ = StringField(Params$, 2, " ")
  If Command$ <> "" And InChannel$ <> ""
    If Left(Command$, 1) = CommandIDChar$
      Command$ = Right(Command$, Len(Command$)-1)
    EndIf
    ForEach PluginFuncs()
      If PluginFuncs()\CMDString$ = Command$
        Select Status
          Case 0
            PluginFuncs()\DisabledChans$ = RemoveString(PluginFuncs()\DisabledChans$, Trim(InChannel$))
            IRCSendText(ReplyTo$, "[*] Removed '" + InChannel$ + "' From '" + CommandIDChar$ + Command$ + "' Channel-Ignore-List")
          Case 1
            PluginFuncs()\DisabledChans$+ InChannel$ + " "
            IRCSendText(ReplyTo$, "[*] Added '" + InChannel$ + "' To '" + CommandIDChar$ + Command$ + "' Channel-Ignore-List")
        EndSelect
      EndIf
    Next
  Else
    IRCSendText(ReplyTo$, "[*] Use: "+CommandIDChar$+"chanblock+/- <command> <#channel>")
  EndIf
EndProcedure

Procedure.i AuthorizeCMD(CommandName$, InChannel$, UserName$)
  Protected AuthResult.i = #False
  ForEach PluginFuncs()
    If CommandName$ = PluginFuncs()\CMDString$
      If (PluginFuncs()\Enabled = #True) And (Not FindString(PluginFuncs()\DisabledChans$, InChannel$)) And (Not IsIgnored(UserName$))
        ProcedureReturn #True
      EndIf
    EndIf
  Next
  ProcedureReturn AuthResult
EndProcedure

Procedure.l GetPluginFuncAddr(plugHandle.l, CmdName$)
  If ExamineLibraryFunctions(plugHandle)
    While NextLibraryFunction()
      If StringField(LibraryFunctionName(), 3, "_") = CmdName$
        ProcedureReturn LibraryFunctionAddress()
      EndIf
    Wend
  EndIf
  ProcedureReturn 0
EndProcedure

Procedure.i URLChannel(ChanName$)
  ForEach ChannelsJoined()
    If ChannelsJoined()\ChannelName$ = ChanName$
      Select ChannelsJoined()\ScanURLS
        Case 0
          ProcedureReturn #False
        Case 1
          ProcedureReturn #True
        Default
          ProcedureReturn #False
      EndSelect
    EndIf
  Next
EndProcedure

Procedure SetURLChannel(ChanName$, ReplyTo$, Enabled.i)
  ForEach ChannelsJoined()
    If ChannelsJoined()\ChannelName$ = ChanName$
      ChannelsJoined()\ScanURLS = Enabled
      IRCSendText(ReplyTo$, "[*] Modified URL Scan Settings For " + ChanName$)
    EndIf
  Next
EndProcedure

Procedure.s GetChannel(TextLine$); charybdis - now works.
  Protected Total.i = CountString(TextLine$, " ")
  Protected I.i = 0
  Protected Temp$ = ""
  Select IRCGetID(TextLine$)
    Case "JOIN"
      If Not FindString(IRCGetText(TextLine$), " ") And IRCGetText(TextLine$) <> ""
        ProcedureReturn IRCGetText(TextLine$)
      Else
        ProcedureReturn IRCgetP1(TextLine$)
      EndIf
    Case "PART"
      If Not FindString(IRCGetText(TextLine$), " ") And IRCGetText(TextLine$) <> ""
        ProcedureReturn StringField(TextLine$, 3, " ")
      Else
        ProcedureReturn IRCGetP1(TextLine$)
      EndIf 
    Default
      For I = 1 To Total
        Temp$ = StringField(TextLine$, I, " ")
        If Left(Temp$, 1) = "#"
          If Not FindString(Trim(Temp$ , ":"), " ")
            ProcedureReturn Trim(Temp$, ":")
          Else
            ProcedureReturn "#" + StringBetween(TextLine$, "#", " ")
          EndIf 
        EndIf
      Next
  EndSelect
EndProcedure

Procedure ListWords(ReplyTo$)
  Protected ReplyString$ = ""
  ForEach TriggerWords()
    ReplyString$ = ReplyString$ + StringField(TriggerWords(), 1, "[*]") + ", "
  Next
  ReplyString$ = RTrim(ReplyString$, " ")
  ReplyString$ = RTrim(ReplyString$, ",")
  IRCSendText(ReplyTo$, ReplyString$)
EndProcedure

Procedure.i Oper_Auth(NickName$, UserHost$)
  ForEach OperListItem()
    If OperListItem()\OperNick$ = NickName$
      If OperListItem()\Enabled = #True
        If OperListItem()\LoggedIn = #True
          If OperListItem()\OperHost$ = UserHost$
            ProcedureReturn #True
          EndIf
          Debug "Oper Host Mismatch"
        EndIf
        Debug "Oper Not Logged In."
      EndIf
      Debug "Oper Account Disabled."
    EndIf
    Debug "Not An Oper."
  Next
  ProcedureReturn #False
EndProcedure

Procedure.i Oper_Create(NickName$)
  ForEach OperListItem()
    If OperListItem()\OperNick$ = NickName$
      ProcedureReturn #False
    EndIf
  Next
  AddElement(OperListItem())
  OperListItem()\OperNick$ = NickName$
  OperListItem()\Enabled = #True
  OperListItem()\FailedLogins = 0
  OperListItem()\OperHost$ = ""
  OperListItem()\OperPass$ = ""
  ProcedureReturn #True
EndProcedure

Procedure.i Oper_Delete(NickName$)
  ForEach OperListItem()
    If OperListItem()\OperNick$ = NickName$ And NickName$ <> Master
      DeleteElement(OperListItem())
      ProcedureReturn #True
    EndIf
  Next
  ProcedureReturn #False
EndProcedure

Procedure.i Oper_SetPass(NickName$, NewPassword$)
  ForEach OperListItem()
    If OperListItem()\OperNick$ = NickName$
      OperListItem()\OperPass$ = NewPassword$
      ProcedureReturn #True
    EndIf
  Next
  ProcedureReturn #False
EndProcedure

Procedure.i Oper_Exist(NickName$)
  ForEach OperListItem()
    If OperListItem()\OperNick$ = NickName$
      ProcedureReturn #True
    EndIf
  Next
  ProcedureReturn #False
EndProcedure

Procedure.i Oper_Login(NickName$, UserHost$, Password$)
  ForEach OperListItem()
    If OperListItem()\OperNick$ = NickName$
      If OperListItem()\OperPass$ = Password$
        OperListItem()\OperHost$ = UserHost$
        OperListItem()\LoggedIn = #True
        ProcedureReturn #True
      Else
        OperListItem()\FailedLogins + 1
      EndIf 
    EndIf
    If OperListItem()\FailedLogins > 2
      OperListItem()\Enabled = #False
      OperListItem()\FailedLogins = 0
      ;CreateThread(@Oper_Lockout(), @NickName$)
    EndIf 
  Next
  ProcedureReturn #False
EndProcedure

Procedure.i Oper_Enable(NickName$, EnabledStatus.i)
  Protected Result.i = #False
  ForEach OperListItem()
    If OperListItem()\OperNick$ = NickName$
      OperListItem()\Enabled = EnabledStatus
      Result = #True
    EndIf
  Next
  ProcedureReturn Result
EndProcedure

Procedure.i Oper_LogOut(NickName$)
  ForEach OperListItem()
    If OperListItem()\OperNick$ = NickName$
      OperListItem()\LoggedIn = #False
      OperListItem()\OperHost$ = ""
      ProcedureReturn #True
    EndIf
  Next
  ProcedureReturn #False
EndProcedure

Procedure BotOp_Login(NickName$, Password$, UserHost$, CommandType.i)
  Select CommandType
    Case #CG_COMMAND_PRIVATE
      If Oper_Login(NickName$, UserHost$, Password$)
        IRCSendText(NickName$, "[*] Logged In As: '" + NickName$ + "' Using Host: '" + UserHost$ + "'")
      Else
        IRCSendText(NickName$, "[*] Bad Username or Password")
      EndIf
    Case #CG_COMMAND_PUBLIC
      IRCSendText(NickName$, "[*] You Have Posted Your Password In A Public Channel.  Congrats, Your Account Is Now Deleted.  Use Private Messaging Next Time.")
      Oper_Delete(NickName$)
  EndSelect
EndProcedure

Procedure BotOp_Logout(NickName$)
  If Oper_LogOut(NickName$)
    IRCSendText(NickName$, "[*] You Are Now Logged Out.")
  Else
    IRCSendText(NickName$, "[*] Error. You Are Either Already Logged Out, Or Not In The Oper Access List.")
  EndIf 
EndProcedure

Procedure BotOp_Register(NickName$, Caller$)
  If Oper_Create(NickName$)
    IRCSendText(Caller$, "[*] Operator Account Created For " + NickName$)
    Delay(ms_BetweenLines/2)
    IRCSendText(NickName$,"[*] Operator Account Created For " + NickName$)
    Delay(ms_BetweenLines/2)
    Protected TempPass$ = RandHex(16)
    If Oper_SetPass(NickName$, TempPass$)
      IRCSendText(Caller$, "[*] Username: '" + NickName$ + "' Password: '"+TempPass$+"'")
      Delay(ms_BetweenLines/2)
      IRCSendText(Caller$, "[*] To Login (VIA PM) -> '/msg "+Nick+ " "+CommandIDChar$+"login <your-password>'")
      Delay(ms_BetweenLines/2)
      If Trim(IRCLocate(NickName$)) <> ""
        IRCSendText(NickName$, "[*] Username: '" + NickName$ + "' Password: '"+TempPass$+"'")
        Delay(ms_BetweenLines/2)
        IRCSendText(NickName$, "[*] To Login (VIA PM): -> '/msg "+Nick+ " "+CommandIDChar$+"login <your-password>'")
        Delay(ms_BetweenLines/2)
        IRCSendText(NickName$, "[*] When Logged In, To Change Password: -> '/msg " + Nick + " " + CommandIDChar$ + "setpass <new-password>'")
        Delay(ms_BetweenLines/2)
        IRCSendText(NickName$, "[*] To Logout: -> '"+CommandIDChar$+"logout'")
        Delay(ms_BetweenLines/2)
        IRCSendText(NickName$, "[*] NOTE: Logging In OR Setting Password Publicly (In A Channel) Will Cause Your Account To Be Deleted.")
      Else
        IRCSendText(Caller$, "[*] I Do Not See " + NickName$ + " In Any Of The Channels I Am In. Not Sending Login Info.")
      EndIf
    Else
      IRCSendText(Caller$, "[*] Could Not Set Operator Password After Account Creation.")
    EndIf
  Else
    IRCSendText(Caller$, "[*] Could Not Create Operator Account. Account Already Exists.")
  EndIf
EndProcedure

Procedure BotOp_DeleteOp(NickName$, ReplyTo$)
  If Oper_Delete(NickName$)
    IRCSendText(ReplyTo$, "[*] Operator Deleted: "+NickName$)
  Else
    IRCSendText(ReplyTo$, "[*] Couldn't Delete Operator: "+NickName$)
  EndIf
EndProcedure

Procedure BotOp_NewPass(NewPass$, ReplyTo$)
  If Oper_SetPass(ReplyTo$, NewPass$)
    IRCSendText(ReplyTo$, "[*] Password Successfully Updated.")
  Else
    IRCSendText(ReplyTo$, "[*] Could Not Set Password For: '" + ReplyTo$ +"'")
  EndIf
EndProcedure

Procedure AddTriggerWord(ReplyTo$, Params$)
  Protected Word$ = StringField(Params$, 1, " ")
  Protected Def$ = StringBetween(Params$, #DQUOTE$, #DQUOTE$)
  If Word$ <> "" And Def$ <> ""
    Debug Word$
    Debug Def$
    AppendTextFile("trigger.words", Word$+"[*]"+Def$)
    Conf_Read_TriggerWords()
    IRCSendText(ReplyTo$, "[*] Created Auto Response For '"+Word$+"' [->] '"+Def$+"'")
  Else
    IRCSendText(ReplyTo$, "[*] Error: "+CommandIDChar$+"addword <word> "+#DQUOTE$+"<the automatic response string>"+#DQUOTE$)
  EndIf
  ;IRCSendText(ReplyTo$, 
EndProcedure

Procedure DisplayUsersIn(SelectedChannel$, UserListGadget.i)
  SelectedChannel$ = Trim(SelectedChannel$)
  ClearGadgetItems(UserListGadget)
  ForEach ChannelsJoined()
    If ChannelsJoined()\ChannelName$ = SelectedChannel$
      ForEach ChannelsJoined()\Users()
        AddGadgetItem(UserListGadget, -1, ChannelsJoined()\Users())
      Next
    EndIf
  Next
EndProcedure

Procedure RemTriggerWord(ReplyTo$, Params$)
  ForEach TriggerWords()
    If StringField(TriggerWords(), 1, "[*]") = Params$
      DeleteElement(TriggerWords())
      Conf_Write_TriggerWords()
      IRCSendText(ReplyTo$, "[*] Removed Response For Word: "+Params$)
      ProcedureReturn
    EndIf
  Next
  IRCSendText(ReplyTo$, "[*] Word: "+Params$ + " Not Found.")
  ProcedureReturn
EndProcedure

Procedure TriggerWords_Check(Text$ , From$, SentTo$)
  If From$ <> Nick And From$ <> Host And From$ <> NetworkName$
    Protected ReplyTo$ = ""
    If SentTo$ = Nick : ReplyTo$ = From$ : Else : ReplyTo$ = SentTo$ : EndIf
    ForEach TriggerWords()
      If FindString(Text$, StringField(TriggerWords(), 1, "[*]"))
        IRCSendText(ReplyTo$, StringField(TriggerWords(), 2, "[*]"))
      EndIf
    Next
  EndIf
EndProcedure

Procedure.s GenerateSeenString(Date$, IRCLine$, NickName$)
  Protected Action$ = ""
  Protected WithinChannel$ = GetChannel(IRCLine$)
  If WithinChannel$ = "" Or FindString(WithinChannel$, " ")
    WithinChannel$ = IRCGetTo(IRCLine$)
  EndIf 
  Select IRCGetID(IRCLine$)
    Case "JOIN"
      Action$ = " joining "
    Case "PART"
      Action$ = " leaving "
    Case "QUIT"
      Action$ = " quitting ("
      WithinChannel$ = IRCGetText(IRCLine$) + ")"
    Case "PRIVMSG"
      Action$ = " messaging "
    Case "NOTICE"
      Action$ = " sending [NOTICE] : '"
      WithinChannel$ = IRCGetText(IRCLine$)+"'"
    Case "NICK"
      Action$ = " changing [NICK] to "
      WithinChannel$ = IRCGetText(IRCLine$)
    Case "MODE"
      Action$ = " changing MODE for "
      WithinChannel$ = IRCGetP1(IRCLine$) + " '" + IRCGetP2(IRCLine$) + " " + IRCGetP3(IRCLine$) + "'"
  EndSelect
  ProcedureReturn "[*] '" + NickName$ + "' was last seen" + Action$ + WithinChannel$ + " on " + ReplaceString(Date$, "-", " at ") + "."
EndProcedure

Procedure SeenInfo(Params$, ReplyTo$)
  Params$ = Trim(Params$)
  Protected NewList SearchLog.s()
  If CurrentLogFile$ <> "afk.log" And ReadFile(#AFK_CURRENT_LOG, CurrentLogFile$)
    Protected LogLength.i = Lof(#AFK_CURRENT_LOG)
    Protected *LogMem = AllocateMemory(LogLength)
    If *LogMem
      Protected Bytes = ReadData(#AFK_CURRENT_LOG, *LogMem, LogLength)
      If Bytes <> 0
        Protected LogDataStr$ = PeekS(*LogMem, LogLength)
        FreeMemory(*LogMem)
        Debug LogDataStr$
        Protected LogLineCount.i = CountString(LogDataStr$, #CR$)
        Debug LogLineCount
        For I = LogLineCount To 1 Step -1
          TempLine$ = StringField(LogDataStr$, I, #CR$)
          StartSearch.i = FindString(TempLine$, ")", 0)+1
          Protected ActualLine$ = Mid(TempLine$,StartSearch, Len(TempLine$)-StartSearch+1)
          Debug ActualLine$
          If UCase(IRCGetFrom(ActualLine$)) = UCase(Params$)
            IRCSendText(ReplyTo$, GenerateSeenString(StringBetween(TempLine$, "[", "]"), ActualLine$,Params$))
            If IRCLocate(Params$) <> ""
              IRCSendText(ReplyTo$, "[*] '"+Params$+ "' is currently in: "+ IRCLocate(Params$))
              ProcedureReturn
            EndIf 
            ProcedureReturn
          EndIf
        Next
      EndIf
    EndIf
    CloseFile(#AFK_CURRENT_LOG)
  EndIf 
  IRCSendText(ReplyTo$, "[*] I have no records of previously seeing '" + Params$ + "'.")
    If IRCLocate(Params$) <> ""
    IRCSendText(ReplyTo$, "[*] '"+Params$+ "' is currently in: "+ IRCLocate(Params$))
    ProcedureReturn
  EndIf 
EndProcedure

Procedure ProcessCommand(*Text)
  Protected ThisLine$ = PeekS(*Text)
  Protected Output_To$, FromUser$, SourceChannel$, FullCommand$, IRCTo$, Command$, Params$, Type.i, pdHandle.l
  SetBusy(1) : IdleTime = ElapsedMilliseconds() : LastPing = ElapsedMilliseconds()
  FromUser$ = IRCGetFrom(ThisLine$) : FullCommand$ = IRCGetText(ThisLine$) : IRCTo$ = IRCGetTo(ThisLine$) : FromUserHost$ = IRCGetHost(ThisLine$)
  If IRCTo$ <> Nick And IRCTo$ <> Desired_Nick$
    Type = #CG_COMMAND_PUBLIC : Output_To$ = IRCTo$ : SourceChannel$ = GetChannel(ThisLine$)
    If PM_All_Replies <> 0 : Output_To$ = FromUser$ : EndIf 
  Else
    Type = #CG_COMMAND_PRIVATE : Output_To$ = FromUser$
  EndIf
  If Left(FullCommand$,1) = CommandIDChar$
    Protected Start = FindString(FullCommand$, CommandIDChar$) + 1
    Protected Finish= FindString(FullCommand$, " ")
    If Finish = 0
      Finish=Len(FullCommand$) : Command$ = Mid(FullCommand$, Start, Finish)
    Else 
      Finish = Finish - 1 : Command$ = RTrim(Mid(FullCommand$, Start, Finish))
    EndIf
      Start = Finish + 1 : Finish= Len(FullCommand$) : Params$ = LTrim(Mid(FullCommand$, Start, Finish))
      Debug "Host: " + IRCGetHost(ThisLine$)
      Select Command$ ; Public Commands, Available to anyone (Includes applicable plugin commands, within "Default" case)
        Case "cg-info"; !cg-info  |  Displays the bot's host and time information.
          CGInfo(Output_To$) : IdleTime = ElapsedMilliseconds() : SetBusy(0) : ProcedureReturn     
        Case "login" ; !login <password>  |  Log In as your nick, using your password.
          BotOp_Login(FromUser$, Params$, FromUserHost$, Type) : IdleTime = ElapsedMilliseconds() : SetBusy(0) : ProcedureReturn     
        Case "seen"; !seen <nick>  |  Reverse-Log-Search to find the most recent activity of a nick.
          SeenInfo(Params$, Output_To$) : IdleTime = ElapsedMilliseconds() : SetBusy(0) : ProcedureReturn
        Case "see" ; !see <nick>  |  Check if the bot can currently see <nick> in any of the channels it is in.
          If Params$ <> "" : SearchUsers(Params$, Output_To$) : EndIf : IdleTime = ElapsedMilliseconds() : SetBusy(0) : ProcedureReturn
        Default ; check loaded plugins for a matching cmd string.
          ForEach PluginFuncs()
            If Command$ = PluginFuncs()\CMDString$ And PluginFuncs()\OperOnly = 0 And AuthorizeCMD(Command$, SourceChannel$, FromUser$)
              pdHandle = OpenLibrary(#PB_Any, PluginFuncs()\LibPath$)
              If pdHandle
                PluginFuncs()\FuncAddr = GetPluginFuncAddr(pdHandle, Command$)
                If PluginFuncs()\FuncAddr <> 0
                  CallFunctionFast(PluginFuncs()\FuncAddr, @Params$, @Output_To$, @FromUser$, @SourceChannel$, ConnectionID, ms_BetweenLines, MaxLineLen, UseSSL) : CloseLibrary(pdHandle)
                Else
                  IRCSendText(Output_To$, "[*] "+PluginFuncs()\LibPath$+" Missing... Re-Hashing...")
                  Delay(ms_BetweenLines)
                  CloseLibrary(pdHandle) : ScanPlugins(Output_To$)
                EndIf 
                IdleTime = ElapsedMilliseconds() : SetBusy(0) : ProcedureReturn
              Else
                IRCSendText(Output_To$, "[*] "+PluginFuncs()\LibPath$+" Missing... Re-Hashing...")
                Delay(ms_BetweenLines)
                CloseLibrary(pdHandle) : ScanPlugins(Output_To$)
              EndIf
            EndIf
          Next
          IdleTime = ElapsedMilliseconds()
      EndSelect
      If Oper_Auth(FromUser$, FromUserHost$)
        Debug "From Oper " + FromUser$ ; Must Be Logged In To Access These
        Select Command$ ; Core Commands, Bot-Ops Only (Includes Applicable Plugin Commands, within "Default" case)
          Case "logout" ; !logout  |  used to log out (if logged in as an oper)
            BotOp_Logout(FromUser$) : IdleTime = ElapsedMilliseconds() : SetBusy(0) : ProcedureReturn     
          Case "oper+" ; !oper+ <nick>  |  used to register a new oper (auto-generates a password, sends to you and the new oper)
            BotOp_Register(Params$, FromUser$) : IdleTime = ElapsedMilliseconds() : SetBusy(0) : ProcedureReturn
          Case "oper-" ; !oper- <nick>  |  used to delete an oper account
            BotOp_DeleteOp(Params$, FromUser$) : IdleTime = ElapsedMilliseconds() : SetBusy(0) : ProcedureReturn
          Case "setpass"; !setpass <newpass>  |  used to change your current password
            BotOp_NewPass(Params$, FromUser$) : IdleTime = ElapsedMilliseconds() : SetBusy(0) : ProcedureReturn
          Case "cg-quit"; !cg-quit [all/bot-nick]  |  used to quit the bot.  if delivered in a channel rather than via PM, the param 'all' or '<bot-nick>' is specified.
            ShutdownBot(Params$, Type, Output_To$) : IdleTime = ElapsedMilliseconds() : SetBusy(0) : ProcedureReturn           
          Case "chan+"; !chan+ <#chan1> <#chan2> <#chan3> ...  |  join a space-separated list of channels.
            IRCJoinList(Params$) : IdleTime = ElapsedMilliseconds() : SetBusy(0) : ProcedureReturn
          Case "chan-"; !chan- <#chan1> <#chan2> <#chan3> ...  |  part/leave a space-separated list of channels.
            IRCPartList(Params$) : IdleTime = ElapsedMilliseconds() : SetBusy(0) : ProcedureReturn
          Case "part-all"; !part-all  |  part/leave all joined channels
            IRCLeaveAllChans() : IdleTime = ElapsedMilliseconds() : SetBusy(0) : ProcedureReturn
          Case "cycle-all"; !cycle-all  |  cycle all joined channels
            IRCLeaveAllChans(#True) : IdleTime = ElapsedMilliseconds() : SetBusy(0) : ProcedureReturn
          Case "nick"; !nick <newnick>  |  change the bot's nick to <newnick>
            If Params$ <> "" : IRCChangeNick(Params$) : EndIf : IdleTime = ElapsedMilliseconds() : SetBusy(0) : ProcedureReturn
          Case "echo"; !echo <some text>  |  make the bot echo text back to you (used mostly for debug, testing, and "marco-polo" type situations with the bot)
            If Params$ <> "" : IRCSendText(Output_To$, Params$) : EndIf : IdleTime = ElapsedMilliseconds() : SetBusy(0) : ProcedureReturn
          Case "reconnect"; !reconnect  |  disconnect, and then reconnect in 10-20 seconds.  ***no guarantees at this point, not much testing done***
            IRCDisconnect("Please Allow At Least 10 Seconds for Reconnect.") : RESTART = 99 : Connected = 0 : ConnectionID = 0 : IdleTime = ElapsedMilliseconds() : SetBusy(0) : ProcedureReturn
          Case "dropplug"; !dropplug <plugin.dll>  |  remove a *.dll plugin, and all of its associated commands from memory
            UnloadPlugin(Params$, Output_To$) : IdleTime = ElapsedMilliseconds() : SetBusy(0) : ProcedureReturn
          Case "cmd+"; !cmd+ <plug-cmd>  |  used in Enabling / Disabling a particular plugin command (but not the entire plugin) globally.
            EnablePlugCommand(Params$, Output_To$) : IdleTime = ElapsedMilliseconds() : SetBusy(0) : ProcedureReturn
          Case "cmd-"; !cmd- <plug-cmd>  |  used in Enabling / Disabling a particular plugin command (but not the entire plugin) globally.
            DisablePlugCommand(Params$, Output_To$) : IdleTime = ElapsedMilliseconds() : SetBusy(0) : ProcedureReturn
          Case "urltitle+"; !urltitle+ <#channel>  |  enable url-title reporting in a joined channel.
            SetURLChannel(Params$, Output_To$, 1) : IdleTime = ElapsedMilliseconds() : SetBusy(0) : ProcedureReturn
          Case "urltitle-"; !urltitle- <#channel>  |  disable url-title reporting in a joined channel.
            SetURLChannel(Params$, Output_To$, 0) : IdleTime = ElapsedMilliseconds() : SetBusy(0) : ProcedureReturn
          Case "ignore+"; !ignore+ <nick>  |  causes the bot to ignore all input from <nick>
            Ignore(Params$, 1, Output_To$) : IdleTime = ElapsedMilliseconds() : SetBusy(0) : ProcedureReturn
          Case "ignore-"; !ignore- <nick>  |  'un-bans' a previously ignored <nick>
            Ignore(Params$, 0, Output_To$) : IdleTime = ElapsedMilliseconds() : SetBusy(0) : ProcedureReturn
          Case "listignore"; !listignore  |  show a list of the currently ignored users
            ShowIgnoreList(Output_To$) : IdleTime = ElapsedMilliseconds() : SetBusy(0) : ProcedureReturn
          Case "chanblock+"; !chanblock <plug-cmd> <#channel>  |  Disable Plugin Command <plug-cmd>, within channel <#channel>
            ChanBlockCmd(Params$, Output_To$, 1) : IdleTime = ElapsedMilliseconds() : SetBusy(0) : ProcedureReturn
          Case "chanblock-"; !chanblock <plug-cmd> <#channel>  |  Re-Enable Plugin Command <plug-cmd>, within channel <#channel>
            ChanBlockCmd(Params$, Output_To$, 0) : IdleTime = ElapsedMilliseconds() : SetBusy(0) : ProcedureReturn
          Case "listchans"; !listchans  |  list currently joined channels
            ListConnectedChannels(Output_To$) : IdleTime = ElapsedMilliseconds() : SetBusy(0) : ProcedureReturn
          Case "listusers"; !listusers <#channel>  |  show a list of the nicks currently in <#channel>
            ShowChannelUsers(Params$, Output_To$) : IdleTime = ElapsedMilliseconds() : SetBusy(0) : ProcedureReturn
          Case "hashplug"; !hashplug <plugin.dll (optional)>  |  re-hashes the plugin dll files in the plugin folder.  you can specify 1 dll filename to rehash it's contents, or no parameters to re-scan all
            ScanPlugins(Output_To$, Params$) : IdleTime = ElapsedMilliseconds() : SetBusy(0) : ProcedureReturn
          Case "listplug"; !listplug  |  list loaded plugins from !hashplug
            ListLoadedPlugins(Output_To$) : IdleTime = ElapsedMilliseconds() : SetBusy(0) : ProcedureReturn
          Case "lat"; !lat  |  toggle latency reporting (debug only)
            ToggleShowPing(Output_To$) : IdleTime = ElapsedMilliseconds() : SetBusy(0) : ProcedureReturn
          Case "addword"; !addword <myword> "my automatic response"  |  used to create an auto-response when the bot sees <myword> in text.
            AddTriggerWord(Output_To$, Params$) : IdleTime = ElapsedMilliseconds() : SetBusy(0) : ProcedureReturn     
          Case "delword"; !delword <myword>  |  deletes a previously created auto-response for a word
            RemTriggerWord(Output_To$, Params$) : IdleTime = ElapsedMilliseconds() : SetBusy(0) : ProcedureReturn     
          Case "bot-filename"; !bot-filename  |  reveals the bot's running exe location (debug only)
            IRCSendText(Output_To$, "[*] " + "My Executable Location: ["+ProgramFilename()+"]") : IdleTime = ElapsedMilliseconds() : SetBusy(0) : ProcedureReturn
          Case "linedelay"; !linedelay <milliseconds>  |  how many ms between output lines (to avoid floods)  default is 2000 (2 seconds)
            SetLineDelay(Val(Params$), Output_To$) : IdleTime = ElapsedMilliseconds() : SetBusy(0) : ProcedureReturn
          Case "cmdchar"; !cmdchar <x>  |  change the command-id character to <x>, instead of the default "!"
            If Params$ <> "" And Len(Params$) = 1 : CommandIDChar$ = Params$ : EndIf : IRCSendText(Output_To$, "Command ID Character is: " + CommandIDChar$) : IdleTime = ElapsedMilliseconds() : SetBusy(0) : ProcedureReturn
          Case "raw"; !raw <raw-text>  |  send raw network text to server.  ex.: '!raw PRIVMSG someuser :hi'
            RawText(Params$) : IdleTime = ElapsedMilliseconds() : SetBusy(0) : ProcedureReturn
          Case "togglewords"; !togglewords  |  enable/disable auto-responses 
            ToggleWordScan(Output_To$) : IdleTime = ElapsedMilliseconds() : SetBusy(0) : ProcedureReturn
          Case "togglepub"; !togglepub  |  toggle output mode.  when enabled, most if not all output is PM'd back to the sender rather than output in a channel.
            TogglePrivateMode(Output_To$) : IdleTime = ElapsedMilliseconds() : SetBusy(0) : ProcedureReturn
          Case "listwords"; !listwords  |  list the currently added words for auto-responses.
            ListWords(Output_To$) : IdleTime = ElapsedMilliseconds() : SetBusy(0) : ProcedureReturn
          Default ; check loaded plugins for a matching cmd string
            ForEach PluginFuncs()
              If Command$ = PluginFuncs()\CMDString$ And PluginFuncs()\OperOnly = 1
                pdHandle = OpenLibrary(#PB_Any, PluginFuncs()\LibPath$)
                If pdHandle
                  PluginFuncs()\FuncAddr = GetPluginFuncAddr(pdHandle, Command$)
                  If PluginFuncs()\FuncAddr <> 0
                    CallFunctionFast(PluginFuncs()\FuncAddr, @Params$, @Output_To$, @FromUser$, @SourceChannel$, ConnectionID, ms_BetweenLines, MaxLineLen, UseSSL) : CloseLibrary(pdHandle)
                  Else
                    IRCSendText(Output_To$, "[*] "+PluginFuncs()\LibPath$+" Missing... Re-Hashing...")
                    Delay(ms_BetweenLines)
                    CloseLibrary(pdHandle) : ScanPlugins(Output_To$)
                  EndIf 
                  IdleTime = ElapsedMilliseconds() : SetBusy(0) : ProcedureReturn
                Else
                  IRCSendText(Output_To$, "[*] "+PluginFuncs()\LibPath$+" Missing... Re-Hashing...")
                  Delay(ms_BetweenLines)
                  CloseLibrary(pdHandle) : ScanPlugins(Output_To$)
                EndIf
              EndIf
            Next
            IdleTime = ElapsedMilliseconds() : SetBusy(0) : ProcedureReturn
        EndSelect
      EndIf
    EndIf
    IdleTime = ElapsedMilliseconds() : If Busy : SetBusy(0) : EndIf : ProcedureReturn
EndProcedure

Procedure ScanText(*Text)
  Protected TheText$ = PeekS(*Text)
  Select IRCGetTo(TheText$)
    Case Nick
      If IRCGetFrom(TheText$) <> Host And IRCGetFrom(TheText$) <> Nick
        objTray\ShowBalloon("<"+IRCGetFrom(TheText$)+">",IRCGetText(TheText$))
      EndIf
  EndSelect
  Select IRCGetID(TheText$)
    Case "NICK"
      UserNick(IRCGetFrom(TheText$), IRCGetText(TheText$))
    Case "JOIN"
      If IRCGetFrom(TheText$) = Nick
        UpdateChanList(GetChannel(TheText$))
      Else
        ;IRCEnumNames(GetChannel(TheText$))
        UpdateUsersInChan(GetChannel(TheText$), IRCGetFrom(TheText$))
      EndIf
    Case "PART"
      If IRCGetFrom(TheText$) = Nick
        RemoveChanList(GetChannel(TheText$))
      Else
        IRCEnumNames(GetChannel(TheText$))
      EndIf
    Case "QUIT"
      If IRCGetFrom(TheText$) <> Nick
        Delay(ms_BetweenLines/2)
        UserQuit(IRCGetFrom(TheText$))
      EndIf
    Case "INVITE"
      If InviteAccept <> 0
        IRCJoin(IRCGetText(TheText$))
      EndIf
    Case "NOTICE"
      If FindString(IRCGetText(TheText$), "IDENTIFY")
        If Password$ <> ""
          Debug "LOGGING IN"
          Select UseSSL
            Case 0
              SendNetworkString(ConnectionID,"PRIVMSG NickServ IDENTIFY "+Password$+Chr(13)+Chr(10))
            Case 1
              SSL_Client_SendString(ConnectionID,"PRIVMSG NickServ IDENTIFY "+Password$+Chr(13)+Chr(10))
          EndSelect
        EndIf
      EndIf 
    Case "001"
      Protected StartString$ = "Welcome to the "
      Protected EndString1$ = " IRC Network"
      Protected EndString2$ = " Internet Relay Chat"
      If FindString(TheText$, EndString1$)
        NetworkHandle$ = StringBetween(TheText$, StartString$, EndString1$)
      Else
        NetworkHandle$ = StringBetween(TheText$, StartString$, EndString2$)
      EndIf
      If NetworkHandle$ <> ""
        CurrentLogFile$ = NetworkHandle$ + ".log"
        ;Log_Read_LogText()
      EndIf
    Case "004"
      Protected TempServer$ = StringField(TheText$, 4, " ")
      If TempServer$ <> NetworkName$
        Host = TempServer$
      Else
        Host = TempServer$
      EndIf
      objTray\SetToolTip("AFK Operator v" + IRCVersion$ + " Connected To ["+Host+"]")
      ;IRCJoinList(AutoChannel)
    Case "353"
      UpdateUsersInChan(GetChannel(TheText$), TrimUserSymbols(IRCGetText(TheText$)))
    Case "376"
      ; End of MOTD
    Case "438"
      ; Too Many Nick Changes
    Case "432", "433", "436"
      OpenCryptRandom()
      Nick = Nick + "-" + Str(CryptRandom(999))
      CloseCryptRandom()
      IRCChangeNick(Nick)
  EndSelect
  ;===============================================URL SCAN========================================
  If FindString(IRCGetText(TheText$), "http") And IRCGetFrom(TheText$) <> Host And (URLChannel(GetChannel(TheText$)))
    Protected URLStart.i = FindString(TheText$, "http")
    Protected UrlEnd.i = FindString(TheText$, " ", URLStart)
    If URLEnd = 0
      URLEnd = Len(TheText$) - URLStart
    Else
      URLEnd - URLStart
    EndIf  
    Protected URL$ = Mid(TheText$, URLStart, URLEnd+1)
    If URL$ = ""
      URL$ = IRCGetText(TheText$)
    EndIf
    If Right(URL$, 1) <> "/"
      URL$ = URL$ + "/"
    EndIf
    Debug URL$
    If URL$ <> ""
      Protected Temp1$ = ReceiveHTTPString(URL$)
    EndIf
    Temp1$ = ReplaceString(Temp1$, Chr(10), "")
    Temp1$ = ReplaceString(Temp1$, Chr(13), "")
    Temp1$ = ReplaceString(Temp1$, "  ", "")
    Temp1$ = ReplaceString(Temp1$, "&quot;", "'")
    ;Debug Temp1$
    Protected Ttl$ = StringBetween(Temp1$, "<title>", "</title>") : Debug Ttl$
    If Trim(Ttl$) <> "" And Len(Trim(Ttl$)) < MaxLineLen 
      IRCSendText(GetChannel(TheText$), "[*] <"+IRCGetFrom(TheText$)+"> URL Title: " + #IRC_BOLD_TEXT + Trim(Ttl$))
    EndIf
  EndIf
  ;===============================================/URL SCAN========================================
  If UseWordScan <> 0
    TriggerWords_Check(IRCGetText(TheText$), IRCGetFrom(TheText$), IRCGetTo(TheText$))
  EndIf 
  ;================================================Logging=========================================
  ;
EndProcedure

Procedure CommandQueue(*nill)
  Repeat
    While Busy <> 0
      Delay(1)
    Wend
    If ListSize(CommandStack()) > 0
      ClearList(CommandStackRun())
      CopyList(CommandStack(), CommandStackRun())
      ClearList(CommandStack())
      ForEach CommandStackRun()
        While Busy <> 0
          Delay(1)
        Wend
        Protected RunNext$ = CommandStackRun() 
        CurrentCMDThread = CreateThread(@ProcessCommand(), @RunNext$)
        If WaitThread(CurrentCMDThread, 60000) = 0
          KillThread(CurrentCMDThread)
          SetBusy(0)
        EndIf
      Next
    EndIf
    Delay(1)
  ForEver
EndProcedure  

Procedure InitBot()
  Select UseSSL
    Case 0
      InitNetwork()
    Case 1
      cryptInit()
  EndSelect
  Oper_Create(Master)
  Oper_SetPass(Master, MasterPass$)
  If UseWordScan <> 0
    Conf_Read_TriggerWords()
  EndIf
  CommandProcessorID = CreateThread(@CommandQueue(), @Null) 
  Protected BufferSize.I
  If GetNetworkParams_(0, @BufferSize) = #ERROR_BUFFER_OVERFLOW
    Protected *Buffer = AllocateMemory(BufferSize)
    If *Buffer
      Protected Result = GetNetworkParams_(*Buffer, @BufferSize)
      If Result = #ERROR_SUCCESS
        Hostname$ = PeekS(*Buffer)
        DomainName$ = PeekS(*Buffer + 132)
        FQDN$ = PeekS(*Buffer) + "." + PeekS(*Buffer+132)
      EndIf
      FreeMemory(*Buffer)
    EndIf
  EndIf
  Nick = Desired_Nick$
EndProcedure 

Procedure MainLoop(*null)
  Repeat
    InitBot()
    IRCConnect(NetworkName$, Port)
    If ConnectionID <> 0
      IdleTime = ElapsedMilliseconds()
      LastPing = ElapsedMilliseconds()
      If ConnectionID <> 0 : Connected = 1 : EndIf
      IRCLogin(NetworkName$, Nick)
      Repeat
        Protected Line.s = IRCGetLine()
        If Line <> "" And Not IsIgnored(IRCGetFrom(Line))
          LogText(FormatDate("[%yyyy/%mm/%dd-%hh:%ii:%ss]",Date())+"(<-)"+Line)
          If IRCGetFrom(Line) <> ""
            If StringField(IRCGetText(Line), 2, " ") = ">>" ; MINECRAFT EXCEPTION =============================
              Protected MCLine$ = IRCGetText(Line)
              Protected RealFrom$ = IRCGetFrom(Line)
              If Not Oper_Exist(StringField(MCLine$, 1, " ")) : RealFrom$ = StringField(MCLine$, 1, " ") : EndIf
              MCLine$ = Right(MCLine$, Len(MCLine$)-(FindString(MCLine$, ">>")+2))
              Debug "Minecraft -> " + MCLine$
              Debug "Real From -> " + RealFrom$
              Line = ReplaceString(Line, IRCGetText(Line), MCLine$)
              Line = ReplaceString(Line, IRCGetFrom(Line), RealFrom$)
              Debug "Converted ->" + Line
            EndIf ; END MINECRAFT EXCEPTION ===================================================================
            If Left(IRCGetText(Line), 1) = CommandIDChar$
              If Busy = 0
                CurrentCMDThread = CreateThread(@ProcessCommand(), @Line)
              Else
                AddElement(CommandStack())
                CommandStack() = Line
              EndIf
              If Not IsThread(CommandProcessorID)
                CommandProcessorID = CreateThread(@CommandQueue(), @Null)
              EndIf
            EndIf
            CreateThread(@ScanText(), @Line) : IdleTime = ElapsedMilliseconds()
          EndIf
        EndIf
        If (ElapsedMilliseconds()-LastPing > PINGInterval) 
          If (ElapsedMilliseconds()-IdleTime > IdleTimeout)
            SetBusy(1)
            Protected Ping.f = IRCPing(Host, PINGTimeout) 
            If PingOn = 1 And Debug_User$ <> ""
              IRCSendText(Debug_User$, "Reply from "+Host+": "+ Str(Ping) + "ms")
            EndIf
            LastPing = ElapsedMilliseconds() 
            If Ping > PINGTimeout Or Ping < 0
              IRCDisconnect("Connection Timeout... Restarting Connection.")
              RESTART = 99
              Connected = 0
            EndIf
            SetBusy(0)
          EndIf
          LastPing = ElapsedMilliseconds()
        EndIf
        If ConnectionID = 0
          Connected = 0
          RESTART = 99
        EndIf
        If Connected <> 0
          SetWindowTitle(#WINDOW_MAIN, "AFK Operator - v"+IRCVersion$+ " - Connected To [" + Host + "] - Ping: "+Str(Ping) + "ms" + " - " + "Idle Time: "+ FormatDate("%hh:%ii:%ss", (ElapsedMilliseconds()-IdleTime)/1000))
          ToolTipText$ = "AFK Operator - Connected To [" + Host + "]"
          ;objTray\SetToolTip(ToolTipText$)
        EndIf
        Delay(10)
      Until RESTART = 99 Or Connected = 0
    EndIf
    RESTART = 0
    ConnectionID = 0
    Sleep_(10000)
  Until EXIT = 99
EndProcedure

Procedure WinMainCallback(hWnd, iMessage, wParam, lParam)
Protected iResult = #PB_ProcessPureBasicEvents
  Select iMessage  
    Case #WM_USER_TRAYICON 
      Select lParam
        Case #WM_LBUTTONDOWN
          ;
        Case #WM_LBUTTONDBLCLK
          HideWindow(#WINDOW_MAIN, #False)
        Case #WM_RBUTTONDOWN
          HideWindow(#WINDOW_MAIN, #False)  
      EndSelect
  EndSelect
ProcedureReturn iResult 
EndProcedure

Procedure ProcessEnterKey()
  Select GetActiveGadget()
    Case #EDIT_HOST, #EDIT_CHAN, #EDIT_PORT, #EDIT_NICK, #EDIT_NSPASS, #EDIT_ZNCPASS, #EDIT_ZNCUSR, #CHECK_SSL, #CHECK_ZNC
      SetActiveGadget(#BUTTON_START)
      keybd_event_(#VK_SPACE, 1, 0, 0)
      keybd_event_(#VK_SPACE, 1, #KEYEVENTF_KEYUP, 0)
    Case #EDIT_SAY
      Protected Raw$ = GetGadgetText(#EDIT_SAY)
      If Raw$ <> ""
        RawText(Raw$)
        SetGadgetText(#EDIT_SAY, "")
        SetActiveGadget(#EDIT_SAY)
      EndIf
  EndSelect
EndProcedure

Procedure Main()
  hWnd = OpenWindow(#WINDOW_MAIN, 0, 0, 1024, 680, "AFK Operator - v"+IRCVersion$, #FLAGS)
  If hWnd
    Master = InputRequester("Please Enter The NICK Of The MASTER USER", "Nickname:", "botmaster")
    MasterPass$ = InputRequester("Please Create A Password For " + Master, "To Login: (As "+Master+") /msg <bot-nick> !login <pass>", "", #PB_InputRequester_Password)
    Protected nIcon1 = CatchImage(#PB_Any, ?icon1)
    
    hAnim(0) = CatchImage(#PB_Any, ?anim1)
    hAnim(1) = CatchImage(#PB_Any, ?anim2)
    hAnim(2) = CatchImage(#PB_Any, ?anim3)
    hAnim(3) = CatchImage(#PB_Any, ?anim4)
    
    objTray = TrayIcon_Create(WindowID(#WINDOW_MAIN), ImageID(nIcon1), #WM_USER_TRAYICON, 0)
    objTray\SetToolTip("AFK Operator v" + IRCVersion$ + " [Offline]")
    If UseGadgetList(WindowID(#WINDOW_MAIN))
      
      AddKeyboardShortcut(#WINDOW_MAIN, #PB_Shortcut_Return, #ShortcutKey)
      
      TextGadget(#TEXT_HOST, 10, 14, 50, 20, "Host/Net:")
      StringGadget(#EDIT_HOST, 60, 10, 150, 20, NetworkName$)
      
      TextGadget(#TEXT_PORT, 220, 14, 50, 20, "Port:")
      StringGadget(#EDIT_PORT, 245, 10, 50, 20, Str(Port))
      
      TextGadget(#TEXT_BOT_NICK, 305, 14, 50, 20, "Nick:")
      StringGadget(#EDIT_NICK, 333, 10, 100, 20, Desired_Nick$)
      
      TextGadget(#TEXT_NS_PASS, 440, 14, 50, 20, "NS Pass:")
      StringGadget(#EDIT_NSPASS, 487, 10, 100, 20, "", #PB_String_Password)
      
      CheckBoxGadget(#CHECK_SSL, 600, 10, 50, 20, "SSL?")
      
      CheckBoxGadget(#CHECK_ZNC, 655, 10, 60, 20, "ZNC ->")
      
      StringGadget(#EDIT_ZNCUSR, 714, 10, 90, 20, "zncuser")
      StringGadget(#EDIT_ZNCPASS,814, 10, 90, 20, "", #PB_String_Password)
      
      ButtonGadget(#BUTTON_START, 914, 10, 100, 20, "Connect", #PB_Button_Toggle)
      ButtonGadget(#BUTTON_HIDE, 914, 40, 100, 20, "Minimize To Tray")
      
      
      ListViewGadget(#LIST_CHANS, 914, 70, 100, 160)
      ButtonGadget(#BUTTON_CHANSND, 914, 240, 100, 20, "Send To Chan")
      
      ListViewGadget(#LIST_USERS, 914, 270, 100, 338)
      ButtonGadget(#BUTTON_USERSND, 914, 618, 100, 20, "Send To Nick")
      
      DisableGadget(#EDIT_ZNCPASS, #True)
      DisableGadget(#EDIT_ZNCUSR, #True)
      
      ButtonGadget(#BUTTON_CLEAR, 804, 650, 100, 20, "Clear Log")
      
      ListViewGadget(#DEBUG_MAIN, 10, 70, 894, 568)

      ButtonGadget(#BUTTON_SAY, 10, 650, 100, 20, " RawInput >")
      StringGadget(#EDIT_SAY, 120, 650, 674, 20, "")
      ButtonGadget(#BUTTON_CLOSE, 914, 650, 100, 20, "Shut Down Bot")
      
      SetGadgetColor(#LIST_CHANS, #PB_Gadget_BackColor, RGB(50,50,50))
      SetGadgetColor(#LIST_CHANS, #PB_Gadget_FrontColor, RGB(50,180,50))
      SetGadgetColor(#LIST_USERS, #PB_Gadget_BackColor, RGB(50,50,50))
      SetGadgetColor(#LIST_USERS, #PB_Gadget_FrontColor, RGB(50,180,50))
      SetGadgetColor(#DEBUG_MAIN, #PB_Gadget_BackColor, RGB(50,50,50))
      SetGadgetColor(#DEBUG_MAIN, #PB_Gadget_FrontColor, RGB(50,180,50))
      SetGadgetColor(#EDIT_SAY, #PB_Gadget_BackColor, RGB(50,50,50))
      SetGadgetColor(#EDIT_SAY, #PB_Gadget_FrontColor, RGB(50,180,50))
      SetGadgetColor(#EDIT_HOST, #PB_Gadget_BackColor, RGB(50,50,50))
      SetGadgetColor(#EDIT_HOST, #PB_Gadget_FrontColor, RGB(50,180,50))
      SetGadgetColor(#EDIT_PORT, #PB_Gadget_BackColor, RGB(50,50,50))
      SetGadgetColor(#EDIT_PORT, #PB_Gadget_FrontColor, RGB(50,180,50))
      SetGadgetColor(#EDIT_NICK, #PB_Gadget_BackColor, RGB(50,50,50))
      SetGadgetColor(#EDIT_NICK, #PB_Gadget_FrontColor, RGB(50,180,50))
      SetGadgetColor(#EDIT_NSPASS, #PB_Gadget_BackColor, RGB(50,50,50))
      SetGadgetColor(#EDIT_NSPASS, #PB_Gadget_FrontColor, RGB(50,180,50))
      SetGadgetColor(#EDIT_ZNCPASS, #PB_Gadget_BackColor, RGB(50,50,50))
      SetGadgetColor(#EDIT_ZNCPASS, #PB_Gadget_FrontColor, RGB(50,180,50))
      SetGadgetColor(#EDIT_ZNCUSR, #PB_Gadget_BackColor, RGB(50,50,50))
      SetGadgetColor(#EDIT_ZNCUSR, #PB_Gadget_FrontColor, RGB(50,180,50))
      If LoadFont(101, "Courier New", 8)
        SetGadgetFont(#DEBUG_MAIN, FontID(101))
        SetGadgetFont(#LIST_CHANS, FontID(101))
        SetGadgetFont(#EDIT_SAY, FontID(101))
        SetGadgetFont(#EDIT_HOST, FontID(101))
        SetGadgetFont(#EDIT_PORT, FontID(101))
        SetGadgetFont(#EDIT_NICK, FontID(101))
        SetGadgetFont(#EDIT_NSPASS, FontID(101))
        SetGadgetFont(#LIST_USERS, FontID(101))
      EndIf
      SetWindowCallback(@WinMainCallback(), #WINDOW_MAIN)
      Repeat
        Define Event.l = WaitWindowEvent()
        Select Event
          Case #PB_Event_Menu
            If EventMenu() = #ShortcutKey
              ProcessEnterKey()
            EndIf  
          Case #PB_Event_Gadget
            If EventType() = #PB_EventType_Focus And GadgetType(EventGadget())=#PB_GadgetType_String
              SendMessage_(GadgetID(EventGadget()),#EM_SETSEL,0,-1)
            EndIf
            Select EventGadget()
              Case #BUTTON_CLOSE, #BUTTON_QUIT
                If Connected = 1
                  ShutdownBot(Nick,#CG_COMMAND_PRIVATE,Master)
                Else
                  RESTART = 99
                  EXIT = 99
                EndIf
                While ConnectionID <> 0
                  Delay(1)
                Wend
              Case #LIST_CHANS
                SelectedChannel$ = GetGadgetText(#LIST_CHANS)
                DisplayUsersIn(SelectedChannel$, #LIST_USERS)
              Case #BUTTON_SAY
                Define WhatToSay$ = GetGadgetText(#EDIT_SAY)
                If WhatToSay$ <> ""
                  RawText(WhatToSay$)
                  SetGadgetText(#EDIT_SAY, "")
                EndIf
              Case #BUTTON_CLEAR
                ClearGadgetItems(#DEBUG_MAIN)
              Case #BUTTON_CHANSND                
                Protected ChanToSendTo$ = GetGadgetText(#LIST_CHANS)
                Protected MessageToSend$ = InputRequester("Send Message To: " + ChanToSendTo$, "Enter Your Message:", "")
                If MessageToSend$ <> "" And ChanToSendTo$ <> ""
                  IRCSendText(ChanToSendTo$, MessageToSend$)
                EndIf
              Case #BUTTON_USERSND
                Protected UserToSendTo$ = GetGadgetText(#LIST_USERS)
                Protected PMToSend$ = InputRequester("Send Message To: " + UserToSendTo$, "Enter Your Message:", "")
                If PMToSend$ <> "" And UserToSendTo$ <> ""
                  IRCSendText(UserToSendTo$, PMToSend$)
                EndIf 
              Case #CHECK_SSL
                Select GetGadgetState(#CHECK_SSL)
                  Case #PB_Checkbox_Checked
                    UseSSL = 1
                    DisableGadget(#CHECK_ZNC, #True)
                  Case #PB_Checkbox_Unchecked
                    UseSSL = 0
                    DisableGadget(#CHECK_ZNC, #False)
                EndSelect
              Case #CHECK_ZNC
                Select GetGadgetState(#CHECK_ZNC)
                  Case #PB_Checkbox_Checked
                    UseZNC = 1
                    DisableGadget(#EDIT_ZNCPASS, #False)
                    DisableGadget(#EDIT_ZNCUSR, #False)
                    SetGadgetState(#CHECK_SSL, #PB_Checkbox_Unchecked)
                    If UseSSL = 1 : UseSSL = 0 : EndIf
                    DisableGadget(#CHECK_SSL, #True)
                  Case #PB_Checkbox_Unchecked
                    UseZNC = 0
                    DisableGadget(#EDIT_ZNCPASS, #True)
                    DisableGadget(#EDIT_ZNCUSR, #True)
                    DisableGadget(#CHECK_SSL, #False)
                EndSelect
              Case #BUTTON_START
                If Not IsThread(MainLoopThread)
                  SetGadgetText(#BUTTON_START, "Disconnect")
                  DisableGadget(#EDIT_HOST, 1)
                  NetworkName$ = GetGadgetText(#EDIT_HOST)
                  DisableGadget(#EDIT_PORT, 1)
                  Port = Val(GetGadgetText(#EDIT_PORT))
                  DisableGadget(#EDIT_NICK, 1)
                  DisableGadget(#CHECK_SSL, 1)
                  DisableGadget(#EDIT_NICK, 1)
                  DisableGadget(#CHECK_ZNC, 1)
                  DisableGadget(#EDIT_NSPASS, 1)
                  DisableGadget(#EDIT_ZNCUSR, 1)
                  DisableGadget(#EDIT_ZNCPASS, 1)
                  Desired_Nick$ = GetGadgetText(#EDIT_NICK)
                  Password$ = GetGadgetText(#EDIT_NSPASS)
                  ZNCUser = GetGadgetText(#EDIT_ZNCUSR)
                  ZNCPass = GetGadgetText(#EDIT_ZNCPASS)
                  MainLoopThread = CreateThread(@MainLoop(), @MainLoopThread)
                  ;Log_Read_LogText()
                  ;LoggerThread = CreateThread(@KeepLogging(), @Log_Write_Interval)
                Else
                  DisableGadget(#EDIT_HOST, 0)
                  DisableGadget(#EDIT_PORT, 0)
                  
                  DisableGadget(#EDIT_NICK, 0)
                  DisableGadget(#CHECK_SSL, 0)
                  DisableGadget(#CHECK_ZNC, 0)
                  DisableGadget(#EDIT_NSPASS, 0)
                  If IsThread(MainLoopThread)
                    KillThread(MainLoopThread)
                  EndIf
                  If IsThread(LoggerThread)
                    KillThread(LoggerThread)
                  EndIf
                  ;Log_Write_LogText()
                  CurrentLogFile$ = ""
                  ;ClearList(Logs())
                  ClearList(ChannelsJoined())
                  ClearList(OperListItem())
                  ClearList(PluginFuncs())
                  IRCDisconnect("[Bot Control Panel]")
                  If ConnectionID <> 0
                    CloseNetworkConnection(ConnectionID)
                  EndIf
                  Connected = 0
                  ConnectionID = 0
                  SetGadgetText(#BUTTON_START, "Connect")
                  ClearGadgetItems(#LIST_CHANS)
                  objTray\SetToolTip("AFK Operator v" + IRCVersion$ + " [Offline]")
                EndIf
              Case #BUTTON_HIDE
                BalloonTitle$ = "AFK Operator:"
                BalloonTexts$ = "Now Running In System Tray"
                objTray\ShowBalloon(BalloonTitle$,BalloonTexts$)
                HideWindow(#WINDOW_MAIN, #True)
            EndSelect
        EndSelect
        If Event = #WM_LBUTTONDOWN
          SendMessage_(hWnd,#WM_NCLBUTTONDOWN, #HTCAPTION,0)
        EndIf
      Until Event = #PB_Event_CloseWindow Or EXIT = 99
    EndIf
  EndIf

;LogText(FormatDate("%hh:%ii:%ss ", Date()) + "QUITTING!!!")
objTray\Destroy()
EndProcedure

Main()

DataSection
  icon1: 
  IncludeBinary "i1.ico"
  anim1: 
  IncludeBinary "spin_1.ico"
  anim2: 
  IncludeBinary "spin_2.ico"
  anim3: 
  IncludeBinary "spin_3.ico"
  anim4: 
  IncludeBinary "spin_4.ico"
EndDataSection

; IDE Options = PureBasic 5.31 (Windows - x86)
; CursorPosition = 1465
; FirstLine = 1196
; Folding = ----------PAAg9--
; EnableThread
; EnableXP
; Executable = bin\afk.exe
; Debugger = Standalone
; EnableCompileCount = 1276
; EnableBuildCount = 70
; IncludeVersionInfo
; VersionField0 = %BUILDCOUNT
; VersionField1 = %COMPILECOUNT
; VersionField2 = CyberGhetto Associates (A BG-Technology Services Subsidiary)
; VersionField3 = AFK Operator IRC Bot
; VersionField4 = 0
; VersionField5 = 0.%BUILDCOUNT.%COMPILERCOUNT.0
; VersionField6 = Modular IRC Bot Framework - Core
; VersionField7 = AFK Operator
; VersionField8 = afk.exe
; VersionField15 = VOS_NT_WINDOWS32
; VersionField16 = VFT_APP
