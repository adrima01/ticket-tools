#!/bin/bash 
. ~/.inc_rt.conf
. ./inc_xmpp.conf
. ./inc_external.conf
URLLIST=""
multi="False"

take_screenshot () { #where is take_screenshot called?
    if [ -z "$1" ]
    then
        exit 17 
    else
        URL="$1" #path to the screenshot or website to be screenshot?
        URL="`echo $URL|sed -e 's/&/\&/g'`"
    fi
    if [ -z "$2" ] 
    then
        FETCH=1
    else
        FETCH="$2"
    fi
    if [ -z "$3" ]
    then
        COMMENT=1
    else
        COMMENT="$3"
    fi
    SCREENSHOT=`/usr/local/bin/faup -f host "$URL"`
    echo "$SCREENSHOT"
    export URL; ssh ${SCREENSHOT_IDENTITY} ${SCREENSHOT_QUERY_USER}@${SCREENSHOT_SERVER} "$URL" #are defined in inc_external.conf-example??
    if [ $FETCH -eq 1 ]
    then
        sleep 2
        export URL; scp ${SCREENSHOT_IDENTITY} ${SCREENSHOT_FETCH_USER}@${SCREENSHOT_SERVER}:~/screenshots/${SCREENSHOT}.png screenshots/
        sleep 1
        if [ $COMMENT -eq 1 ] 
        then
            $RT_BIN comment $tn -m "screenshot of $URL" -a screenshots/${SCREENSHOT}.png
        fi
    fi
}

show_actions () {
    URL="$1"
    URL=`echo $URL|sed -e "s/h[xX][xX]p\:/http\:/"`
    URL=`echo $URL|sed -e "s/h[xX][xX]ps\:/https\:/"`
    echo "Reported URL: $URL"
    while read reps
    do
        URL="`echo $URL | sed -e \"s/$reps/someone\@taggingserver\.com/g\"`" #why?!
    done < get-reports.replacements-email
    while read reps
    do
        URL="`echo $URL | sed -e \"s/$reps/$REPLACED_DOMAIN/g\"`"
    done < get-reports.replacements
    echo "Sanitized URL: $URL"
    URL_RF=`fang "$URL"`  #$URL = fang $URL wouldn't be easier? why the checking?
    if [[ ! $URL == $URL_RF ]]
    then
      URL=$URL_RF
      echo "Refanged URL: $URL"
    fi
    #UA_RESULT="`echo $URL | $URLABUSE_BIN`"
    #echo "$UA_RESULT"
    echo "Take-down consideration for $URL"
    #echo "Emails:"
    #echo "$UA_RESULT" | grep "All emails" | cut -d ":" -f2
    #if [[ $URL =~ "cloudserver21.eu" ]]
    if [[ `echo $URL | fgrep -f /home/rommelfs/ticket-tools/warning.inc` ]]
    then
      echo "* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *"
      echo " ATTENTION: $URL is on a warning list. Do not process!"
      echo "* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *"
    fi
    read -rsn1 -p"press (1) phishing, (2) malware, (3) defacement, (4) webshell, (5) cybersquatting - (8) ignore, (9) ignore and close, (i) ignore and whitelist, (e) edit URL, (0) exit" option;echo
    case $option in
    "e") read -e -p "Edit URL: " -i "$URL" URL
        show_actions "$URL"
        ;;
    1)  echo "Phishing server take-down request"
        #take_screenshot "$URL"
        echo "$URL"
        $CREATETICKET_BIN $tn $TEMPLATE_PHISHING "$URL" 0 36 $MISP_PHISHING_ID
        #/opt/rt4/bin/rt resolve $tn
        $RT_BIN edit $tn set queue="Automated security reports" 
        $RT_BIN edit $tn set CF-Classification="Phishing"
        $RT_BIN edit $tn set CF-RSIT_1002="Fraud"
        ;;
    2)  echo "Malware server take-down request"
        $CREATETICKET_BIN $tn $TEMPLATE_MALWARE "$URL" 0 36
        #/opt/rt4/bin/rt resolve $tn
        $RT_BIN edit $tn set queue="Automated security reports"
        $RT_BIN edit $tn set CF-Classification="Malware"
        $RT_BIN edit $tn set CF-RSIT_1002="Malicious Code"
        ;;
    3)  echo "Defaced server take-down request"
        $CREATETICKET_BIN $tn $TEMPLATE_DEFACEMENT "$URL" 0 36
        #/opt/rt4/bin/rt resolve $tn
        $RT_BIN edit $tn set queue="Automated security reports"
        $RT_BIN edit $tn set CF-Classification="System Compromise"
        $RT_BIN edit $tn set CF-RSIT_1002="Information Content Security"
        #take_screenshot $URL
        ;;
    4)  echo "Compromised server take-down request"
        $CREATETICKET_BIN $tn $TEMPLATE_COMPROMISED_WEBSHELL "$URL" 0 36
        #/opt/rt4/bin/rt resolve $tn
        $RT_BIN edit $tn set queue="Automated security reports"
        $RT_BIN edit $tn set CF-Classification="System Compromise"
        $RT_BIN edit $tn set CF-RSIT_1002="Intrusions"
        #take_screenshot $URL
        ;;
    5)  echo "Cybersquatting take-down request"
        $CREATETICKET_BIN $tn $TEMPLATE_CYBERSQUATTING "$URL" 0 36
        #/opt/rt4/bin/rt resolve $tn
        $RT_BIN edit $tn set queue="Automated security reports"
        $RT_BIN edit $tn set CF-Classification="Scam"
        $RT_BIN edit $tn set CF-RSIT_1002="Fraud"
        #take_screenshot $URL
        ;;
    8)  ;;
    9)  $RT_BIN comment $tn -m "URL unreachable at time of testing or not considered malicious"
        $RT_BIN resolve $tn
        ;;
    0)  exit
        ;;
    "i") DOMAIN=`faup -f domain "$URL"`
        echo $DOMAIN >> spambee-ignorelist.inc
	$RT_BIN comment $tn -m "URL not considered to be malicious and whitelisted"
        $RT_BIN resolve $tn
        ;;
    *)  echo "unrecognized option"
        ;;
    esac  
}
#start of the program
if [[ -z "$1" ]]
then
    echo "Usage: $0 [report-type|ticket-id]"
    echo "Defined report types:"
    cat get-reports.inc |grep ")"| cut -d ")" -f1 |grep -v "*"
    exit 1
fi

re='^[0-9]+$'
if [[ "$1" =~ $re ]] #regex auf $1 anwenden
then
  multi="True"
fi

if [[ "$1" = "validated" ]]
then
  multi="True"
fi

. ./get-reports.inc "$1"
if [[ $LAST = "No matching results." ]]
then
    echo "No tickets to process."
    exit
fi

if [[ "$1" =~ "phishtank" ]]
then
  N_REPORTS=0
  echo "Looking at Phishtank URLs"
  if [ -f phishtank.lock ]
  then
    echo "This script seems to be running alredy. Please check"
    exit 16
  fi
  touch phishtank.lock
  if [ -f online-valid.json ]
  then 
    echo "Move crashfile"
    mv online-valid.json online-valid.json-crashed
  fi
  /usr/bin/wget -4 $PHISHTANK_URL ipv4
  if [ ! -f online-valid.json ]
  then
    echo "Couldn't fetch phishtank file. Please check the last output"
    rm phishtank.lock
    exit 1
  fi
  OLDTIMESTAMP=`cat phishtank.timestamp`
  MAXTIMESTAMP=$OLDTIMESTAMP
  while read URL; read TIME
  do
    echo "URL:  $URL"
    echo "DATE: $TIME" 
    #URL=`echo $URL | sed 's/5C//g'`
    #URL="`echo $URL | tr -d '\\'`"
    EPOCH=$(date -d "$TIME" +"%s")
    if [ $EPOCH -gt $OLDTIMESTAMP ]
    then
      echo "time: $TIME"
      echo "epoch: $EPOCH"
      echo "url: $URL"
      #take_screenshot "$URL" 0 0
      $CREATETICKET_BIN $PHISHTANK_TICKET $TEMPLATE_PHISHING "$URL" 2 36 $MISP_PHISHING_ID_PHISHTANK
      N_REPORTS=$((N_REPORTS+1))
    fi
    if [ $EPOCH -gt $MAXTIMESTAMP ]
    then
      MAXTIMESTAMP=$EPOCH
    fi
  done <<EOT
$(cat online-valid.json |jq  -r '[.[] | .url, .verification_time ] | .[]'|sed -e "s/\\\//g")
EOT
  echo $MAXTIMESTAMP > phishtank.timestamp
  if [ $N_REPORTS -gt 0 ]
  then
    echo "New reports: $N_REPORTS"
  else
    echo "No new reports."
  fi
  echo "do backup of phishtank file"
  mv online-valid.json online-valid.json-previous
  rm phishtank.lock
  exit 0 
fi

if [[ "$1" =~ "cert-bund" ]]
then
  for tn in $LAST
  do
    SUBJECT=`$RT_BIN show $tn -f subject`
    echo $SUBJECT
    OLD_IFS="$IFS"
    IFS=$'\n'
    for t in $CERTBUND_TOPICS
    do
      IFS=',' read -ra cb_conf <<< "$t"
      CB_TOPIC="${cb_conf[0]}"
      CB_PATH="${cb_conf[1]}"
      CB_TICKET="${cb_conf[2]}"
      if [[ "$SUBJECT" =~ "$CB_TOPIC" ]]
        then
          echo "$SUBJECT matches $CB_TOPIC"
          tmpfile_csv=$(mktemp --suffix=.csv /tmp/get_cert-bund.XXXXXX)
          $RT_BIN show $tn | grep "Affected hosts on your networks:" -A 1000 |grep "^\""|grep -v "Affected hosts on" > $tmpfile_csv
          echo "Processing CERT-Bund"
          echo "Topic: $CB_TOPIC"
          echo "Template: $CB_PATH"
          echo "Master Ticket: $CB_TICKET"
          $CREATE_BULK_BIN $CB_TICKET $CB_PATH $tmpfile_csv "1" $tn
          $RT_BIN resolve $tn
          rm $tmpfile_csv
      fi
    done
    IFS="$OLD_IFS"
  done
  exit 0
fi

if [[ "$1" =~ "shadowserver-variot" ]]
then
  for tn in $LAST
  do
    SUBJECT=`$RT_BIN show $tn -f subject`
    echo $SUBJECT
    ATTACHMENT=`$RT_BIN show $tn/attachments | grep .csv|cut -d ":" -f 1`
    echo $ATTACHMENT
    DIR=$(echo $SUBJECT | grep Subject| cut -d "]" -f 2|cut -d ":" -f 2 | cut -d " " -f 2)
    SUBJECT=$(echo $SUBJECT | grep Subject| cut -d "]" -f 2| sed -e 's/://g'|cut -d " " -f 2-)
    mkdir -p "./variot/$DIR"
    tmpfile="./variot/$DIR/$SUBJECT.csv"
    if [[ ! -z $ATTACHMENT ]]
    then
      $RT_BIN show $tn/attachments/$ATTACHMENT/content > "$tmpfile"
      echo "$tmpfile"
    else
      URL_FROM_BODY=$($RT_BIN show $tn|grep https|head -1|xargs)
      echo "url: $URL_FROM_BODY"
      /usr/bin/wget -4 "$URL_FROM_BODY" -O "$tmpfile"
      echo "$tmpfile"
    fi
    $RT_BIN resolve $tn
  done
  exit 0
fi

if [[ "$1" =~ "shadowserver" ]]
then
  for tn in $LAST
  do
    SUBJECT=`$RT_BIN show $tn -f subject`
    echo $SUBJECT
    OLD_IFS="$IFS"
    IFS=$'\n'
    for t in $SHADOWSERVER_TOPICS
    do
      IFS=',' read -ra ss_conf <<< "$t"
      SS_TOPIC="${ss_conf[0]}"
      SS_PATH="${ss_conf[1]}"
      SS_TICKET="${ss_conf[2]}"
      if [[ "$SUBJECT" =~ "$SS_TOPIC" ]]
        then
          echo "$SUBJECT matches $SS_TOPIC"
          ATTACHMENT=`$RT_BIN show $tn/attachments | grep .csv.zip|cut -d ":" -f 1`
          echo $ATTACHMENT
          tmpfile_zip=$(mktemp --suffix=.csv.zip /tmp/get_shadowserver.XXXXXX)
          $RT_BIN show $tn/attachments/$ATTACHMENT/content > $tmpfile_zip
          tmpfile_csv=$(mktemp --suffix=.csv /tmp/get_shadowserver.XXXXXX)
          7z -o/tmp -so x $tmpfile_zip > $tmpfile_csv
          echo $tmpfile_csv
          rm $tmpfile_zip
          echo "Processing ShadowServer..."
          echo "Topic: $SS_TOPIC"
          echo "Template: $SS_PATH"
          echo "Master Ticket: $SS_TICKET"
          $CREATE_BULK_BIN $SS_TICKET $SS_PATH $tmpfile_csv "1" $tn
          $RT_BIN resolve $tn
          rm $tmpfile_csv
      fi
    done
    IFS="$OLD_IFS"
    $RT_BIN resolve $tn
  done
  exit 0
fi

if [[ "$1" =~ "cert-eu" ]]
then
  for tn in $LAST
  do
    echo "Processing ticket: $tn"
    ATTACHMENT=`$RT_BIN show $tn/attachments | grep .json.zip|cut -d ":" -f 1`
    echo $ATTACHMENT
          tmpfile_zip=$(mktemp --suffix=.json.zip /tmp/get_cert-eu.XXXXXX)
          $RT_BIN show $tn/attachments/$ATTACHMENT/content > $tmpfile_zip
          tmpfile_json=$(mktemp --suffix=.json /tmp/get_cert-eu.XXXXXX)
          7z -y -o/tmp -so x $tmpfile_zip > $tmpfile_json 
          echo $tmpfile_json
          rm $tmpfile_zip
          echo "Processing CERT-EU"
          for URL in `cat $tmpfile_json | jq -r ."[][].url" | grep http`
          do
            show_actions "$URL"
          done
          rm $tmpfile_json
  done
  exit 0
fi

#echo "$1"
#if [[ "$1" =~ '^http.*' ]]
#then
#	echo "implementing it."
#	exit
#fi

i=0
for tn in $LAST 
do
    nb_tickets=`echo $LAST | wc -w`
    let nb_tickets=nb_tickets-$i
    echo -e "\nProcessing ticket #$tn ($nb_tickets left to process)"
    echo "Processing ticket #$tn"
    if [ "$multi" == "False" ]
    then
        LOOKYLOO=`$RT_BIN show $tn | egrep -o 'h[txX][txX]ps?://[^ :"]+'| grep 'lookyloo.circl.lu' | head -n 1`
        if [ ! -z $LOOKYLOO ] 
        then
            echo "Lookyloo archive: $LOOKYLOO"
        fi
        URL=`$RT_BIN show $tn | egrep -o 'h[txX][txX]ps?://[^ :"]+'| grep -v 'lookyloo.circl.lu' | head -n 1` 
        # If JSON:
        # URL=`$RT_BIN show $tn |jq -r  '.[] | keys[] '` 
        if [ -z $URL ]
        then
            echo "We should have a URL, but there is none. Something is wrong."
            URL="invalid.tld"
            #exit 1
        fi 
        DOMAIN=`faup -f domain "$URL"`
        echo $DOMAIN
        if [[ -z "$DOMAIN" ]]
        then
            DOMAIN="invalid domain"
        else
            if [[ `grep $DOMAIN spambee-ignorelist.inc` ]]
            then
                $RT_BIN resolve $tn
            fi
        fi
        show_actions $URL

    else # multi==true
        URLS=`$RT_BIN show $tn | egrep -o "h[txX][txX]ps?://[^ ]+"`
        for URL in $URLS
        do
            echo $URL
            if [ -z $URL ]
            then
                echo "We should have a URL, but there is none. Something is wrong."
                URL="invalid.tld"
                #exit 1
            fi
            #./rt show $tn
            show_actions $URL
        done
    fi
    let i=i+1
done
