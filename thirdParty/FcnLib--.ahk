;named FcnLib-- because this is incredibly ghetto, and I am disappointed in myself for deciding to do this...
;  Someday I will release a nifty error-handling lib, along with my rewrites lib, and that will make this stuff less retarded

;ghettoness for getting hatchling to work quickly
fatalErrord(t8="", t7="", t6="", t5="", t4="", t3="", t2="", t1="")
{
}

;ghettoness for getting hatchling to work quickly
errord(t8="", t7="", t6="", t5="", t4="", t3="", t2="", t1="")
{
}

;ghettoness for getting hatchling to work quickly
ensureendswith(t8="", t7="", t6="", t5="", t4="", t3="", t2="", t1="")
{
}


;ghettoness for getting hatchling to work quickly
addtotrace(t8)
{
   traceFile=C:\Dropbox\Public\logs\trace.txt
   if NOT RegExMatch(A_ComputerName, "(PHOSPHORUS|BAUSTIAN-09PC)")
      return
   if NOT FileExist(traceFile)
      return
   text := t8 . "`n"
   FileAppend, %text%, %traceFile%
}