/system script
:if (any get [find name=powerOn]) do={ 
    remove [find name=powerOn];
}
add dont-require-permissions=no name=powerOn policy=\
    read,write,policy,test source=":local send do={\r\
    \n  :local chatId \"your chat id\"\r\
    \n  :local token \"your token\"\r\
    \n  :local tgUrl \"https://api.telegram.org/bot\$token/sendMessage\?chat_i\
    d=\$chatId&text=\$1&parse_mode=Markdown\";\r\
    \n  /tool fetch http-method=post url=\$tgUrl keep-result=no;\r\
    \n}\r\
    \n\r\
    \n:local replaceChar do={\r\
    \n  :for i from=0 to=([:len \$1] - 1) do={\r\
    \n    :local char [:pick \$1 \$i]\r\
    \n    :if (\$char = \$2) do={\r\
    \n      :set \$char \$3\r\
    \n    }\r\
    \n    :set \$output (\$output . \$char)\r\
    \n  }\r\
    \n  :return \$output\r\
    \n}\r\
    \n\r\
    \n#Convert seconds to HH:mm:ss notation\r\
    \n:local convertSeconds do={\r\
    \n  :local hours ((\$1)/3600);\r\
    \n  :local sec (\$1%3600)\r\
    \n  :local min ((\$sec)/60)\r\
    \n  :set sec (\$sec%60)\r\
    \n  :local result \"\"\r\
    \n  :if (\$hours = 0) do={ \r\
    \n    :set \$hours \"00\"\r\
    \n  } else={\r\
    \n    :if (\$hours < 10) do={ \r\
    \n      :set \$hours \"0\$hours\"\r\
    \n    }\r\
    \n  }\r\
    \n  :if (\$min = 0) do={ \r\
    \n    :set \$min \"00\"\r\
    \n  } else={\r\
    \n    :if (\$min <10) do={ \r\
    \n      :set \$min \"0\$min\"\r\
    \n    }\r\
    \n  }\r\
    \n  :if (\$sec = 0) do={\r\
    \n    :set \$sec \"00\"\r\
    \n  } else={\r\
    \n    :if (\$sec < 10) do={ \r\
    \n      :set \$sec \"0\$sec\"\r\
    \n    }\r\
    \n  }\r\
    \n  return \"\$hours:\$min:\$sec\"\r\
    \n}\r\
    \n\r\
    \n#convert Mikrotik date&time to Unix-time\r\
    \n:local EpochTime do={\r\
    \n  #Parameters\r\
    \n  #   \$1 \97 date if any\r\
    \n  #   \$2 \97 time if any\r\
    \n  :local ds [/system clock get date]\r\
    \n  :if (any \$1) do={ \r\
    \n    :set \$ds \$1;\r\
    \n  }\r\
    \n  \r\
    \n  :local months;\r\
    \n  :local isLeap ((([:pick \$ds 9 11]-1)/4) != (([:pick \$ds 9 11])/4));\
    \r\
    \n  :if (\$isLeap) do={\r\
    \n    :set months {\"jan\"=0;\"feb\"=31;\"mar\"=60;\"apr\"=91;\"may\"=121;\
    \"jun\"=152;\"jul\"=182;\"aug\"=213;\"sep\"=244;\"oct\"=274;\"nov\"=305;\"\
    dec\"=335};\r\
    \n  } else={\r\
    \n    :set months {\"jan\"=0;\"feb\"=31;\"mar\"=59;\"apr\"=90;\"may\"=120;\
    \"jun\"=151;\"jul\"=181;\"aug\"=212;\"sep\"=243;\"oct\"=273;\"nov\"=304;\"\
    dec\"=334};\r\
    \n  }\r\
    \n  :local yy [:pick \$ds 9 11];\r\
    \n  :local mmm [:pick \$ds 0 3];\r\
    \n  :local dayOfMonth [:pick \$ds 4 6];\r\
    \n  :local dayOfYear ((\$months->\$mmm)+\$dayOfMonth);\r\
    \n  :local y2k 946684800;\r\
    \n  :set ds ((\$yy*365)+(([:pick \$ds 9 11]-1)/4)+\$dayOfYear);\r\
    \n  :local ts [/system clock get time];\r\
    \n  :if (any \$2) do={ \r\
    \n    :set \$ts \$2;\r\
    \n  }\r\
    \n  :local hh [:pick \$ts 0 2];\r\
    \n  :local mm [:pick \$ts 3 5];\r\
    \n  :local ss [:pick \$ts 6 8]\r\
    \n  :set ts ((\$hh*60*60)+(\$mm*60)+\$ss);\r\
    \n  :return (\$ds*24*60*60 + \$ts + y2k - [/system clock get gmt-offset]);\
    \r\
    \n}\r\
    \n\r\
    \n#last time of script execution. {date;time}\r\
    \n:local lastTimeSeen;\r\
    \n#file to save last time of script execution between reboots\r\
    \n:local fileName \"lastTimeSeen.txt\"\r\
    \n#according to warning https://wiki.mikrotik.com/wiki/Manual:System/File \
    need to check if 'flash' directory exists\r\
    \ndo {\r\
    \n  #trying to get 'flash' directory.\r\
    \n  file get [find name=\"flash\"]\r\
    \n  :set \$fileName \"flash/\$fileName\"\r\
    \n} on-error={\r\
    \n  #do nothing\r\
    \n}\r\
    \n\r\
    \n:local dt {[system clock get date]; [system clock get time]}\r\
    \ndo {\r\
    \n  #read from file\r\
    \n  :set \$lastTimeSeen [:toarray [\$replaceChar [/file get \$fileName con\
    tents] \";\" \",\"]]\r\
    \n  #save new date&time\r\
    \n  /file set \$fileName contents=\$dt\r\
    \n} on-error={\r\
    \n  #if error, i.e. file doesn't exist, create it.\r\
    \n  /system clock print file=\$fileName\r\
    \n  #/file print file=\$fileName\r\
    \n  :delay 5s\r\
    \n  #save date & time\r\
    \n  /file set \$fileName contents=\$dt\r\
    \n  return \"\"\r\
    \n}\r\
    \n:global firstRun;\r\
    \n:if (!any \$firstRun) do={ \r\
    \n  #time before reboot\r\
    \n  :local before [:tonum [\$EpochTime (\$lastTimeSeen->0) (\$lastTimeSeen\
    ->1)]];\r\
    \n  #time after reboot\r\
    \n  #if time after reboot less than before, it means sntp client has not u\
    pdated yet.\r\
    \n  #So wait for it\r\
    \n  :local after [:tonum [\$EpochTime]];\r\
    \n  :while (\$after < \$before) do={\r\
    \n    :delay 1m;\r\
    \n    :set \$after [:tonum [\$EpochTime]]\r\
    \n  }\r\
    \n  :local name [system identity get name]\r\
    \n  :log info (\"Bot. PowerOn. \" . [:tostr \$lastTimeSeen] . \". after=\$\
    after. before=\$before\");\r\
    \n  :local msgText (\"*\$name*%0APowered off \".(\$lastTimeSeen->0).\" at \
    \".(\$lastTimeSeen->1).\"%0A\");\r\
    \n  :set \$msgText (\$msgText.\"Stay offline during \".[\$convertSeconds (\
    \$after-\$before)]);\r\
    \n  \$send \$msgText;\r\
    \n  :set \$firstRun \"true\";\r\
    \n}"
/system scheduler
:if (any get [find name=reportPowerOn]) do={ 
    remove [find name=reportPowerOn];
}
add interval=1m name=reportPowerOn on-event="/system script run powerOn" policy=read,write,policy,test