#include *i thirdParty\winsock2.ahk
#include *i winsock2.ahk
#singleinstance force
#persistent
setbatchlines -1
onexit exithandler

random,rand,10,99

;TODO load from config files
configFile=hatchling_config.json
channel=#ahk-bots-n-such
nick=hatch_%rand%
enableAutoAwaySuffix:=false
awaySuffix=^afk
server=irc.freenode.net
port=6667
if FileExist(configFile)
{
   config := FileRead(configFile)
   server := json(config, "simple.server")
   port := json(config, "simple.port")
   channel := json(config, "simple.channel")
   nick := json(config, "simple.nick")
   password := json(config, "password")
   enableAutoAwaySuffix := json(config, "autoAway.enabled")
   awaySuffix := json(config, "autoAway.suffix")
   ; := json(config, "")
;server port 
}
else
{
   FileCreate(configFile)
}

if TODOchoseTogenerateConfigWithWizard
{
config=
(
{
   simple: {
      server: "%server%",
      port: "%port%",
      channel: "%channel%",
      nick: "%nick%"
   }
}
)
FileCreate(config, configFile)
}

;make connection
ws2_cleanup()
socket:=ws2_connect(server . ":" . port)
ws2_asyncselect(socket,"dataprocess")

;choose nick
changenick(nick())
sendData("USER " . nick() . " * * :the Hatchling IRC client, made by camerb")
sendData("JOIN " . channel())

Gui, +LastFound -Caption +ToolWindow
Gui, Add, Edit, r10 w500 vOut ReadOnly
Gui, Add, Edit, w500 vInputText
Gui, Add, Button, Default, Send
Gui, Show

;here's where we should do periodic checks, like if we should set the status to "away"
SetTimer, checkEverySecond, 1000
SetTimer, checkEveryTenSeconds, % 1000 * 10
SetTimer, checkEveryMinute, % 1000 * 60
return

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
   appendToScrollback(data)
   ;addtotrace(data) ;for testing

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
      ;checkIfAfk()
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
   chatScrollback .= "`n" . textToAppend
   GuiControl, Text, Edit1, %chatScrollback%
   PostMessage, 0xB1, -2, -1, Edit1, A
   PostMessage 0xB7, , , Edit1, A
}

sendData(data){
   global socket
   ws2_senddata(socket,data "`r`n")
}

exithandler:
sendData("PART " . channel())
sendData("QUIT")
ws2_cleanup()
exitapp

nick:
changeNick(nick())
return

checkEverySecond:
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
   if (newNick != currentNick)
   {
      cmd=NICK %newNick%
      sendData(cmd)
      currentNick := newNick
   }
}
