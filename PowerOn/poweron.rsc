:local send do={
  :local chatId "your chat id"
  :local token "your token"
  :local tgUrl "https://api.telegram.org/bot$token/sendMessage?chat_id=$chatId&text=$1&parse_mode=Markdown";
  /tool fetch http-method=post url=$tgUrl keep-result=no;
}

:local replaceChar do={
  :for i from=0 to=([:len $1] - 1) do={
    :local char [:pick $1 $i]
    :if ($char = $2) do={
      :set $char $3
    }
    :set $output ($output . $char)
  }
  :return $output
}

#Convert seconds to HH:mm:ss notation
:local convertSeconds do={
  :local hours (($1)/3600);
  :local sec ($1%3600)
  :local min (($sec)/60)
  :set sec ($sec%60)
  :local result ""
  :if ($hours = 0) do={ 
    :set $hours "00"
  } else={
    :if ($hours < 10) do={ 
      :set $hours "0$hours"
    }
  }
  :if ($min = 0) do={ 
    :set $min "00"
  } else={
    :if ($min <10) do={ 
      :set $min "0$min"
    }
  }
  :if ($sec = 0) do={
    :set $sec "00"
  } else={
    :if ($sec < 10) do={ 
      :set $sec "0$sec"
    }
  }
  return "$hours:$min:$sec"
}

#convert Mikrotik date&time to Unix-time
:local EpochTime do={
  #Parameters
  #   $1 — date if any
  #   $2 — time if any
  :local ds [/system clock get date]
  :if (any $1) do={ 
    :set $ds $1;
  }
  
  :local months;
  :local isLeap ((([:pick $ds 9 11]-1)/4) != (([:pick $ds 9 11])/4));
  :if ($isLeap) do={
    :set months {"jan"=0;"feb"=31;"mar"=60;"apr"=91;"may"=121;"jun"=152;"jul"=182;"aug"=213;"sep"=244;"oct"=274;"nov"=305;"dec"=335};
  } else={
    :set months {"jan"=0;"feb"=31;"mar"=59;"apr"=90;"may"=120;"jun"=151;"jul"=181;"aug"=212;"sep"=243;"oct"=273;"nov"=304;"dec"=334};
  }
  :local yy [:pick $ds 9 11];
  :local mmm [:pick $ds 0 3];
  :local dayOfMonth [:pick $ds 4 6];
  :local dayOfYear (($months->$mmm)+$dayOfMonth);
  :local y2k 946684800;
  :set ds (($yy*365)+(([:pick $ds 9 11]-1)/4)+$dayOfYear);
  :local ts [/system clock get time];
  :if (any $2) do={ 
    :set $ts $2;
  }
  :local hh [:pick $ts 0 2];
  :local mm [:pick $ts 3 5];
  :local ss [:pick $ts 6 8]
  :set ts (($hh*60*60)+($mm*60)+$ss);
  :return ($ds*24*60*60 + $ts + y2k - [/system clock get gmt-offset]);
}

# check if system time is sync
:local TimeIsSync do={
  :if ([ /system ntp client get enabled ] = true) do={
    :do {
      :if ([ /system ntp client get status ] = "synchronized") do={
        :return true;
      }
    } on-error={
      :if ([ :typeof [ /system ntp client get last-adjustment ] ] = "time") do={
        :return true;
      }
    }
    :return false;
  }

  :if ([ /ip cloud get ddns-enabled ] = true && [ / ip cloud get update-time ] = true) do={
    :if ([ :typeof [ / ip cloud get public-address ] ] = "ip") do={
      :return true;
    }
    :return false;
  }
  :return true;
}

:while ([$TimeIsSync]=false) do={
  :if ([ :len [ / system script find where name="rotate-ntp" ] ] > 0 && \
         ([ / system resource get uptime ] % (180 * 1000000000)) = 0s) do={
      :do {
        / system script run rotate-ntp;
      } on-error={
        :log debug "Running rotate-ntp failed.";
      }
    }
  :delay 500ms;
}

#last time of script execution. {date;time}
:local lastTimeSeen;
#file to save last time of script execution between reboots
:local fileName "lastTimeSeen.txt"
#according to warning https://wiki.mikrotik.com/wiki/Manual:System/File need to check if 'flash' directory exists
do {
  #trying to get 'flash' directory.
  file get [find name="flash"]
  :set $fileName "flash/$fileName"
} on-error={
  #do nothing
}

:local dt {[system clock get date]; [system clock get time]}
do {
  #read from file
  :set $lastTimeSeen [:toarray [$replaceChar [/file get $fileName contents] ";" ","]]
  #save new date&time
  /file set $fileName contents=$dt
} on-error={
  #if error, i.e. file doesn't exist, create it.
  /file print file=$fileName
  :delay 5s
  #save date & time
  /file set $fileName contents=$dt
  return ""
}


:global firstRun;
:if (!any $firstRun) do={ 
  #time before reboot saved in file
  :local before [:tonum [$EpochTime ($lastTimeSeen->0) ($lastTimeSeen->1)]];
  #time after reboot
  :local after [:tonum [$EpochTime]];
  :local name [system identity get name]
  :log info ("Bot. PowerOn. " . [:tostr $lastTimeSeen] . ". after=$after. before=$before");
  :local msgText ("*$name*%0APowered off ".($lastTimeSeen->0)." at ".($lastTimeSeen->1)."%0A");
  :set $msgText ($msgText."Powered on at ".($dt->0)." ".($dt->1)."%0A");
  :set $msgText ($msgText."Stay offline during ".[$convertSeconds ($after-$before)]);
  $send $msgText;
  :set $firstRun "true";
}