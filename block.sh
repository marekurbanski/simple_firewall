#!/bin/bash

##################### Info and Settings ##########################
# Script should be run in crontab
# It will check apache (or other) file, parse it and check
# for potential attack attempt
# If this attemp is found, the source IP will be blocked
# Log file(s) are setup on the bottom of script
# You can setup different actions for example instead blocking
# IP by iptables, you can setup firewall rules on Mikrotik
#
# Debug log: true / false
#
DEBUG=true 
# number of trying to unsuccessful access
#
COUNT_TO_BAN=2 
# time in seconds to block with iptables
#
BLOCK_TIME=3600
##################################################################



SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd $SCRIPT_DIR

if [ ! -d blocked ]
    then
    mkdir blocked
    fi

if [ ! -f logtail2 ]
    then
    wget https://raw.githubusercontent.com/marekurbanski/logtail2/master/logtail2
    chmod +x logtail2
    fi

function log {
    if [ "$DEBUG" == "true" ]
        then
        echo $1
        fi
}

function check_file {
    ./logtail2 $1 > tmp
    cat tmp | grep -e 'not found or unable to stat' -e 'script not found' -e 'rejecting client initiated renegotiation' -e 'client used wrong authentication scheme' -e 'access to /cgi-bin/XXXXX' | grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}" | sort | uniq > ip.list

    while read IP
        do
        count=`cat tmp | grep "$IP" | sort | uniq | wc -l | xargs`
        if (( $count > ${COUNT_TO_BAN} ))
            then
            TS=`date +%s`
            let TS=TS+BLOCK_TIME
            iptables -A INPUT -s $IP -p tcp -m state --state NEW -j DROP
            rm -rf blocked/$IP
            echo $TS > blocked/$IP
            log "Blocking $IP" 
        else
            echo "$IP logged less than ${COUNT_TO_BAN}"
        fi
        log "$count"
    done <ip.list


    for IP in `ls blocked/`
        do
        TS=`cat blocked/$IP`
        NOW=`date +%s`
        if (( $NOW > $TS ))
            then
            iptables -D INPUT -s $IP -p tcp -m state --state NEW -j DROP
            log "Deleting $IP because now:$NOW > unblock:$TS"
            rm -rf blocked/$IP
        else
            T="$((TS-NOW))"
            log "$IP still blocked because now:$NOW < unblock:$TS. I will wait still $T seconds."
        fi
    done

    rm -rf tmp
    rm -rf ip.list
}

################### Set log files here ####################
# Usage
# check_file FILE_WITH_APACHE_LOGS
#

check_file '/var/log/httpd/error_log'

