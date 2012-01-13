;{{{ Includes and initial settings
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
;TODO see how this behaves if we remove setbatchlines -1
onexit exithandler
random,rand,10,99
;}}}

;{{{ Creating the GUI, initial connection, + other one-time tasks
;load from config
config := LoadConfig()

;move variable contents from config var to individual vars
server:=json(newConfig, "servers[0].server")
port:=json(newConfig, "servers[0].port")
channel:=json(newConfig, "servers[0].channels[0].name")
nick:=json(newConfig, "servers[0].nick")
password:=json(newConfig, "servers[0].password")
enableAutoAwaySuffix:=json(newConfig, "autoAwaySuffixChange.enable")
autoAwayTimeout:=json(newConfig, "autoAwaySuffixChange.timeout")
awaySuffix:=json(newConfig, "autoAwaySuffixChange.suffix")
;nick:="camerb__" ;only for testing it in the main IRC

;make connection to server
ws2_cleanup()
socket:=ws2_connect(server . ":" . port)
ws2_asyncselect(socket,"dataprocess")

;choose nick
changenick(nick())
sendData("USER " . nick() . " * * :the Hatchling IRC client, made by camerb")
sendData("JOIN " . channel())

Gui, +LastFound
;Gui, -Caption

font_color := json(config, "appearance.font_color")
background_color := json(config, "appearance.background_color")
Gui, Color, , %background_color%
Gui, Font, c%font_color%,
;TODO change font to Consolas Normal 10 (by default) ;NO!!!!! choose a non-fixed width font
;TODO font size in config
;TODO font face in config
;WinSet, TransColor, %CustomColor% 150
Gui, Add, Edit, x-3 y-3 w500 r10 gEditedReadOnly vOut
Gui, Add, Edit, x-3 y134 w482 vInputText
;Gui, Add, Edit, w500 r10 gEditedReadOnly vOut
;Gui, Add, Edit, w500 vInputText
Gui, Add, Button, y500 Default, Send
Gui, Add, Button, , X
Gui, Add, Button, , Bottom
Gui, Add, Button, , Reload

win:=WindowTitle()
Gui, Show, h154 w478, %win%
;TODO do better math here for screen coordinates so that everything is shown in a pretty format
AppendToScrollback("Connecting to " . server  . " as " . nick())

;here's where we should do periodic checks, like if we should set the status to "away"
SetTimer, checkEverySecond, 1000
SetTimer, checkEveryTenSeconds, % 1000 * 10
SetTimer, checkEveryMinute, % 1000 * 60
return
;done with all start-up tasks
;}}}

;{{{ TODOs
;I THINK I FIXED THESE
;TODO only show the tail of the scrollback, delete the rest
;TODO figure out why Hatchling stops responding to pings

;TODO rename occurances of nick to myNick
;TODO send message asking other occurances of my nick to log out if they are inactive
;TODO automatically change my nick to my desired nick if that nick is available

;TODO identify
;TODO ipc gui? - I don't think I need to do this
;TODO multi-channel
;TODO config files

;TODO ip lookup /INFO
;TODO nick lookup (automatically displayed?)
;TODO window to look at recent pastebin
;TODO button to run recent pastebin
;}}}

;{{{ Misc Handlers
ButtonClose:
ButtonX:
ExitApp

exithandler:
sendData("PART " . channel() . WindowTitle())
sendData("QUIT")
ws2_cleanup()
exitapp

;TODO figure out WTH this label is for!
EditedReadOnly:
GuiControl, Text, Edit1, %chatScrollback%
return

ButtonBottom:
ScrollToBottom()
return

ButtonReload:
Reload

ButtonSend:
Gui, Submit, NoHide

if (InputText = "/QUIT")
   GoSub, exithandler
if (InputText = "/EXIT")
   GoSub, exithandler

msg:="PRIVMSG " . channel() . " :" . InputText
GuiControl, Text, Edit2,
appendToScrollback(nick() . ": " . InputText)
sendData(msg)
return

nick:
changeNick(nick())
return
;}}}

;{{{ Timed checks
checkEverySecond:
return

checkEveryTenSeconds:
if enableAutoAwaySuffix
   checkIfAfk()
return

checkEveryMinute:
return
;}}}

;{{{ DataProcess() function (executes every time a message is received)
DataProcess(socket, data)
{
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
      RegExMatch(match6, "\:(.+)$", message)
   message:=message1
   all=%nick%\\%nickreg%\\%location%\\\%command%\\\%channel%\\\\%message%

   addtotrace(data) ;for testing
   ;addtotrace(all) ;for testing

   if (nick = nick())
   {
      ;Things from me
      if (command = "JOIN")
         appendToScrollback("Joined Channel: " . channel)
      ;note that the server doesn't actually respond to tell me what I said
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
      if (command = "QUIT") ;note that this is for all channels that we saw they were in... :/
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

   RegExMatch(data, "^([^ ]+)? ?([^ ]+)? ?([^ ]+)? ?(.+)?$", param)
   ;AppendToCsv(param1, param2, param3, param4, data)

   ;parsing
   StringSplit, param, data, %A_Space%
   name := SubStr(data, 2, InStr(data,"!")-2 )

   ;respond to a ping, let them know we are here
   if(param1 == "PING")
   {
      sendData("PONG " . param2)
      ;appendToScrollback("PONG!!!")
      ;addToTrace("PONG!!!") ;for testing
      checkIfAfk()
      ;TODO return cause this command is so different and annoying
   }
   ;that nick is taken, let's use a different one
   ;FIXME this does not work ... I kinda want to do it differently, anyway
;:niven.freenode.net 433 * camerb__ :Nickname is already in use.
   ;else if(instr(data,"* " . nick() . " :Nickname is already in use."))
   ;if (command = "433")
   ;{
      ;appendToScrollback("Nick is already taken.")
     ;;if(differentnick = 0)
     ;;{
        ;Random, rand, 11111, 99999
        ;changenick(nick() . rand)
        ;differentnick := 1
     ;;}
     ;;SetTimer, nick, -60000
   ;}
}
;}}}

;{{{ Functions
AppendToScrollback(textToAppend)
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

nick()
{
   global
   nick:=substr(nick, 1, 16)
   return nick ;"cam_irc"
}

awaynick()
{
   global
   awaylen := strlen(awaySuffix)
   nick:=substr(nick(), 1, 16 - awaylen)
   return nick . awaySuffix
}

channel()
{
   ;should only send to the currently selected channel
   global
   return channel ;"#ahk-bots-n-such"
}

checkIfAfk()
{
   global
   if enableAutoAwaySuffix
   {
      if (A_TimeIdlePhysical > 1000 * 60 * autoAwayTimeout)
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
   ;text="%t1%","%t2%","%t3%","%t4%"`r`n
   ;text=%t1%,%t2%,%t3%,%t4%`r`n
   text=%t1%,%t2%,%t3%,%t4%`n
   FileAppend, %text%, C:\Dropbox\Public\logs\irc.csv
}

CompositeColorBrightness(color)
{
   RegExMatch(color, "(.).(.).(.).", majorColor)
   Loop, 3
   {
      ;TODO maybe use a hex to dec lib instead
      thisVal := majorColor%A_Index%
      thisVal := RegExReplace(thisVal, "A", 10)
      thisVal := RegExReplace(thisVal, "B", 11)
      thisVal := RegExReplace(thisVal, "C", 12)
      thisVal := RegExReplace(thisVal, "D", 13)
      thisVal := RegExReplace(thisVal, "E", 14)
      thisVal := RegExReplace(thisVal, "F", 15)
      totalBrightness += thisVal
   }
   return totalBrightness
}

jsonLength(jsonBlob, address)
{
   address=hk[length].joe
   address=hk[length]
   loop
   {
      i := A_Index
      ;thisElement=%address%[%i%]
      thisElement := RegExReplace(address, "length", i)
      thisValue := json(jsonBlob, thisElement)
      if NOT thisValue
         return i-1
   }
}
;}}}

;{{{ LoadConfig()
LoadConfig()
{
   global
   configFile=hatchling_config.json

;get defaultConfig
defaultConfig=
(
{
   "config": {
      //awesome or barebones (or minimalist)
      "auto_generation_of_new_elements": "awesome"
   },
   "servers": ZZZserverConfigHereZZZ,
   "appearance": {
      "font_color": "CCCCEE",
      "background_color": "000020"
   },
   "autoAwaySuffixChange": {
      "enable": false,
      "timeout": "8",
      "suffix": "^afk"
   },
   "debug": {
      "showAllButtons": false
   }
}
)

defaultServerConfig=
(
[{
      //Hatchling only supports one server and one channel at present. All other servers and channels will be ignored.
      "server": "irc.freenode.net",
      "port": "6667",
      "nick": "hatch_%rand%",
      "password": "",
      "channels": [{
         "name": "#ahk-bots-n-such"
      }]
   }]
)

   ;TODO need to have two default configs:
   ;  one for the newest, latest, greatest featureset (most of these will be used by camerb)
   ;  one for the limited, barebones functionality featureset

   ;get config from file
   if FileExist(configFile)
      FileRead, config, %configFile%

   autoGenerationStyle := json(config, "config.auto_generation_of_new_elements")
   if InStr(autoGenerationStyle, "minimalist")
   {
      json(defaultConfig, "config.auto_generation_of_new_elements", "minimalist")
      fg := CompositeColorBrightness( json(config, "appearance.font_color") )
      bg := CompositeColorBrightness( json(config, "appearance.background_color") )
      json(defaultConfig, "appearance.font_color", bg < 22 ? "FFFFFF" : "000000")
      json(defaultConfig, "appearance.background_color", fg < 22 ? "FFFFFF" : "000000")
      ;TODO maybe we could check to see to ensure that bg/fg colors will produce visible text
   }

   ;loop over each config item and put it in config if blank
   newConfig := defaultConfig
   configItems := "appearance.font_color,appearance.background_color,autoAwaySuffixChange.enable,autoAwaySuffixChange.timeout,autoAwaySuffixChange.suffix"
   Loop, parse, configItems, CSV
   {
      thisItem := A_LoopField
      fromFile := json(config, thisItem)
      fromDefault := json(defaultConfig, thisItem)
      newValue := strlen(fromFile) ? fromFile : fromDefault
      json(newConfig, thisItem, newValue)
   }

   serversList:=json(config, "servers")
   ;msgbox % serversList
   ;msgbox % defaultServerConfig
   if serversList
      newConfig:=RegExReplace(newConfig, "ZZZserverConfigHereZZZ", serversList)
   else
      newConfig:=RegExReplace(newConfig, "ZZZserverConfigHereZZZ", defaultServerConfig)

   ;json(config, "simple", "hi")
   joe:=json(config, "servers")
   addtotrace(joe)

   ;write the entire config, if we added new elements
   if (newConfig != config)
   {
      FileDelete, %configFile%
      FileAppend, %newConfig%, %configFile%
   }

   return newConfig
}
;}}}

