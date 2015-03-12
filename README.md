# afk-operator
AFK Operator v0.55.1218 Alpha

IRC Bot - Coded in PureBasic

Thanks to the following for some of afk-operator's supporting code:
 - a reference of the irc basics (in pb): DarkDragon @ purebasic forums
 - cryptlib wrapper (For the last-minute SSL support add-on) : http://www.coastrd.com/smtps/cryptlib
 - TrayIcon.pbc: luis @ purebasic forums
 - Whoever wrote the winhttp wrapper.

Basic / Quick Startup Guide:

1. Compile afk.pb
2. place any plugin dll's in /plugin/ folder (/plugin/ must be a sub-folder of the folder afk is running from).  Also, be sure cl32.dll is with your exe for (limited) SSL support.
3. when prompted, enter YOUR nickname (as the bot master/1st oper), and create a password.
4. fill in the form, and click connect.
5. refer to the function 'ProcessCommand(*Text)' within afk.pb for the basic controls / documentation, or use the main window to manipulate the connection.
6. early Alpha release, so expect bugs aplenty and very little documentation
7. if you feel adventurous, in the /plugin/ folder, there are a couple example plugin.dll source files, to create plugins for the bot.