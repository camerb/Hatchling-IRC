#include *i thirdParty\winsock2.ahk
#include *i thirdParty\Functions.ahk
#include *i thirdParty\json.ahk
#include *i thirdParty\ini.ahk
#include *i thirdParty\FcnLib-Rewrites.ahk
#include *i thirdParty\FcnLib--.ahk
;#include *i thirdParty\FcnLib.ahk
;#include *i winsock2.ahk
;#include *i Functions.ahk
;#include *i json.ahk
;#include *i FcnLib-Rewrites.ahk
#singleinstance force
#persistent
setbatchlines -1
onexit exithandler

random,rand,10,99

;TODO load from config files
configFile=hatchling_config.json
channel=#ahk-bots-n-such
nick=hatch_%rand%_%A_ComputerName%
;changeNick(nick)
enableAutoAwaySuffix:=false
awaySuffix=^afk
server=irc.freenode.net
port=6667
defaultConfig=
(
{
   "simple": {
      "server": "%server%",
      "port": "%port%",
      "channel": "%channel%",
      "nick": "%nick%",
      "password": "%password%",
      "font_color": "%font_color%",
      "background_color": "%background_color%",
      "lastItem": "lastItem"
   }
}
)

if NOT FileExist(configFile)
   FileAppend, %defaultConfig%, %configFile%
   ;FileAppend, , %configFile%

if FileExist(configFile)
{
   FileRead, config, %configFile%
   server := json(config, "simple.server")
   port := json(config, "simple.port")
   channel := json(config, "simple.channel")
   ;nick := json(config, "simple.nick")
   ;password := json(config, "simple.password")
   ;enableAutoAwaySuffix := json(config, "autoAway.enabled")
   ;awaySuffix := json(config, "autoAway.suffix")
   ;TODO quit message
   ;; := json(config, "")
;;server port
}

;if TODOchoseTogenerateConfigWithWizard
;{
;config=
;(
;{
   ;simple: {
      ;server: "%server%",
      ;port: "%port%",
      ;channel: "%channel%",
      ;nick: "%nick%"
   ;}
;}
;)
;FileCreate(config, configFile)
;}

;make connection
ws2_cleanup()
;msgbox, % server . port
socket:=ws2_connect(server . ":" . port)
ws2_asyncselect(socket,"dataprocess")

;choose nick
changenick(nick())
sendData("USER " . nick() . " * * :the Hatchling IRC client, made by camerb")
sendData("JOIN " . channel())

Gui, +LastFound +ToolWindow
;Gui, +LastFound -Caption +ToolWindow
Gui, Color, , 000022
Gui, Font, cCCCCEE,
;WinSet, TransColor, %CustomColor% 150
Gui, Add, Edit, x-3 y-3 w500 r10 gEditedReadOnly vOut
Gui, Add, Edit, x-3 y134 w500 vInputText
;Gui, Add, Edit, w500 r10 gEditedReadOnly vOut
;Gui, Add, Edit, w500 vInputText
Gui, Add, Button, y500 Default, Send
Gui, Add, Button, , X
Gui, Add, Button, , Bottom
Gui, Add, Button, , Reload

win:=WindowTitle()
Gui, Show, h155 w300, %win%
;TODO do better math here for screen coordinates so that everything is shown in a pretty format
AppendToScrollback("Connecting to " . server)

;here's where we should do periodic checks, like if we should set the status to "away"
SetTimer, checkEverySecond, 1000
SetTimer, checkEveryTenSeconds, % 1000 * 10
SetTimer, checkEveryMinute, % 1000 * 60
return

EditedReadOnly:
GuiControl, Text, Edit1, %chatScrollback%
return

ButtonBottom:
ScrollToBottom()
return

ButtonReload:
Reload

ButtonX:
ExitApp

ButtonSend:
Gui, Submit, NoHide

if (InputText = "/QUIT")
   GoSub, exithandler
if (InputText = "/EXIT")
   GoSub, exithandler

msg:="PRIVMSG " . channel() . " :" . InputText
;debug(msg)
sendData(msg)
appendToScrollback(nick() . ": " . InputText)
;GuiControl, Text, Edit1, %chatScrollback%
GuiControl, Text, Edit2,
return

;TODO identify
;TODO ipc gui?
;TODO multi-channel
;TODO config files

;TODO ip lookup
;TODO nick lookup
;TODO window to look at recent pastebin
;TODO button to run recent pastebin

dataprocess(socket,data){
   static differentnick = 0
   ;msgbox % data ;for testing
   ;appendToScrollback(data)
   ;addtotrace(data) ;for testing
   wc=(.+)
   haystack=\:%wc%\!\~%wc%\@%wc% %wc% \#([^ ]+) ?%wc%?
   ;haystack=\:(.+)\!\~(.+)\@(.+) (.+) \#([^ ]+) ?(.+)?
   RegExMatch(data, haystack, match)
   nick:=match1
   nickReg:=match2
   location:=match3
   command:=match4
   channel:="#" . match5
   ;message:=match6
   if match6
      RegExMatch(match6, "\:(.*)$", message)
   message:=message1
   ;myNick:=Nick()
   all=%nick%\\%nickreg%\\%location%\\\%command%\\\%channel%\\\\%message%

   if (nick = nick())
   {
      ;Things from me
      if (command = "JOIN")
         appendToScrollback("Joined Channel: " . channel)
   }
   else
   {
      ;Things from others
      if (channel = channel())
         appendToScrollback(nick . ": " . message)
      ;if (command = "QUIT")
         ;appendToScrollback(all)
      ;if (command = "PART")
         ;appendToScrollback(all)
      ;if InStr(data, "PART")
         ;appendToScrollback(data)
   }
   ;addtotrace(all)
   ;if InStr(data, "camerb")
      ;appendToScrollback(nick . ": " . data)

   ;appendToScrollback(command)

   ;parsing
   stringtrimright,data,data,2
   if(instr(data,"`r`n"))
   {
      stringreplace,data,data,`r`n`r`n,`r`n
      loop,%data%,`n,`r
         dataprocess(socket,a_loopfield)
      return
   }

   ;parsing
   stringsplit,param,data,%a_space%
   name:=substr(data,2,instr(data,"!")-2)

   ;respond to a ping, let them know we are here
   if(param1 == "PING")
   {
      sendData("PONG " param2)
      checkIfAfk()
   }
   ;that nick is taken, let's use a different one
   else if(instr(data,"* " . nick() . " :Nickname is already in use."))
   {
      if(differentnick = 0)
      {
         random,rand,11111,99999
         changenick(nick() . rand)
         differentnick := 1
      }
      settimer, nick, -60000
   }
}

appendToScrollback(textToAppend)
{
   global chatScrollback
   textToAppend := CurrentTimestamp() . " " . TextToAppend
   if chatScrollback
      chatScrollback .= "`n"
   chatScrollback .= textToAppend
   GuiControl, Text, Edit1, %chatScrollback%
   ScrollToBottom()
}

sendData(data){
   global socket
   ws2_senddata(socket,data "`r`n")
}

exithandler:
sendData("PART " . channel() . WindowTitle())
sendData("QUIT")
ws2_cleanup()
exitapp

nick:
changeNick(nick())
return

checkEverySecond:
;ScrollToBottom()
return

checkEveryTenSeconds:
;debug()
checkIfAfk()
return

checkEveryMinute:
return

nick()
{
   global
   nick:=substr(nick, 1, 16)
   return nick ;"cam_irc"
}

awaynick()
{
   global
   return nick() . awaySuffix
}

channel()
{
   global
   return channel ;"#ahk-bots-n-such"
}

checkIfAfk()
{
   if enableAutoAwaySuffix
   {
      if (A_TimeIdlePhysical > 1000 * 60 * 8)
         changeNick(awaynick())
      else
         changeNick(nick())
   }
}

changeNick(newNick)
{
   global currentNick
   ;newNick:=substr(newNick, 1, 16)
   if (newNick != currentNick)
   {
      cmd=NICK %newNick%
      sendData(cmd)
      currentNick := newNick
   }
}

ScrollToBottom()
{
   win:=WindowTitle()
   ;TODO switch to use my hwnd or my pid
   PostMessage, 0xB1, -2, -1, Edit1, %win%
   PostMessage, 0xB7, , , Edit1, %win%
}

WindowTitle()
{
   return "The Hatchling IRC Client"
}

CurrentTimestamp()
{
   FormatTime, returned, , [hh:mm]
   return returned
}
