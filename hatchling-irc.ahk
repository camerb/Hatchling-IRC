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

;TODO only show the tail of the scrollback, delete the rest
;TODO figure out why Hatchling stops responding to pings
;TODO rename occurances of nick to myNick

;TODO load from config files
configFile=hatchling_config.json
channel=#ahk-bots-n-such
nick=hatch_%rand%_%A_ComputerName%
enableAutoAwaySuffix:=false
awaySuffix=^afk
server=irc.freenode.net
port=6667
nick:="camerb__" ;only for testing it in the main IRC
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
Gui, Color, , 000020
Gui, Font, cCCCCEE,
;TODO change font to Consolas Normal 10 (by default)
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
Gui, Show, h155 w480, %win%
;Gui, Show, h155 w500, %win%
;TODO do better math here for screen coordinates so that everything is shown in a pretty format
AppendToScrollback("Connecting to " . server  . " as " . nick())

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
   wc=(.+)
   ns=([^ ]+)
   haystack=\:%wc%\!%wc%\@%ns% %ns% (\#[^ ]+)? ?%wc%?
   ;haystack=\:(.+)\!(.+)\@([^ ]+) ([^ ]+) (\#[^ ]+)? (.+)?
   RegExMatch(data, haystack, match)
   nick:=match1
   nickReg:=match2
   location:=match3
   command:=match4
   channel:=match5
   if match6
      RegExMatch(match6, "\:(.*)$", message)
   message:=message1
   all=%nick%\\%nickreg%\\%location%\\\%command%\\\%channel%\\\\%message%

   addtotrace(data) ;for testing
   addtotrace(all) ;for testing

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
         ;TODO need to support `tACTION ... (/me)
      if (command = "JOIN")
         appendToScrollback(nick . " has joined.")
      if (command = "PART") ;note that this is for one channel only
         appendToScrollback(nick . " has left.")
      if (command = "QUIT") ;note that this is for all channels
         appendToScrollback(nick . " has left.")
   }

   ;parsing
   StringTrimRight, data, data, 2
   if InStr(data,"`r`n")
   {
      StringReplace, data, data, `r`n`r`n, `r`n
      Loop, %data%, `n, `r
         dataprocess(socket, A_LoopField)
      return
   }

   ;parsing
   StringSplit, param, data, %A_Space%
   name := SubStr(data, 2, InStr(data,"!")-2 )
   AppendToCsv(param1, param2, param3, data)

   ;respond to a ping, let them know we are here
   if(param1 == "PING")
   {
      sendData("PONG " . param2)
      ;appendToScrollback("PONG!!!")
      ;addToTrace("PONG!!!") ;for testing
      checkIfAfk()
   }
   ;that nick is taken, let's use a different one
   else if(instr(data,"* " . nick() . " :Nickname is already in use."))
   {
      if(differentnick = 0)
      {
         Random, rand, 11111, 99999
         changenick(nick() . rand)
         differentnick := 1
      }
      SetTimer, nick, -60000
   }
}

appendToScrollback(textToAppend)
{
   global chatScrollback
   textToAppend := CurrentTimestamp() . " " . TextToAppend
   if chatScrollback
      chatScrollback .= "`n"
   chatScrollback .= textToAppend
   chatScrollback := SubStr(chatScrollback, -3000)
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

AppendToCsv(t1, t2, t3, t4)
{
   text="%t1%","%t2%","%t3%","%t4%"`r`n
   FileAppend, %text%, C:\Dropbox\Public\logs\irc.csv
}
