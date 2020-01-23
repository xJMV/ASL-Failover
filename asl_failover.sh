#!/usr/bin/env bash

###########################################
#######                             #######
####### VA2XJM - ASL Server Monitor #######
#######                             #######
###########################################
# Ping & validate connection to two ASL   #
# Internet linked nodes. Connect to       #
# PRIMARY or failover to SECONDARY        #
###########################################

###########################################
#               Instructions              #
# 1) Place the script on ASL system and   #
#    edit settings below.                 #
# 2) chmod +x the script.                 #
# 3) Set a cronjob to run it for you      #
# 4) Now enjoy :)                         #
###########################################

###
#### Settings
###

# Local node
NODE="1999"

# Primary remote node
NODE_PRIM="2000"
NODE_PRIM_H=$NODE_PRIM".nodes.allstarlink.org"

# Secondary remote node
NODE_SEC="2001"
NODE_SEC_H=$NODE_SEC".nodes.allstarlink.org"

###
#### /Settings
###

###
#### Check if Internet is avail
###
if ! ping -c1 google.com &>/dev/null; then
        echo "-> Internet not available."
        exit
fi

###
#### Retrieve actual connected node
###
ALINKS=`asterisk -rx "rpt xnode $NODE" | grep RPT_ALINKS= | rev | cut -d "=" -f1 | rev`
echo "-> Connected to : $ALINKS"

if grep -q $NODE_PRIM <<<"$ALINKS"; then
        if ping -c 1 $NODE_PRIM_H &> /dev/null; then
                echo "--> Connected to PRIMARY node."
                echo "-> DONE."
                exit

        else
                echo "--> PRIMARY node not responsding PING."
                if grep -q $NODE_SEC <<<"$ALINKS"; then
                         echo "--> Connected to SECONDARY node. Failover mode."
                else
                        echo "--> Connecting to SECONDARY node..."
                        if ping -c1 $NODE_SEC_H &>/dev/null; then
                                asterisk -rx "rpt cmd $NODE ilink 11 $NODE_PRIM"
                                asterisk -rx "rpt cmd $NODE ilink 13 $NODE_SEC"
                                ALINKS=`asterisk -rx "rpt xnode $NODE" | grep RPT_ALINKS= | rev | cut -d "=" -f1 | rev`
                                if grep -q $NODE_SEC <<<"$ALINKS"; then
                                        echo "--> Connected to SECONDARY node. Failover mode."
                                        exit
                                else
                                        echo "--> Connection to SECONDARY failed."
                                        exit
                                fi
                        else
                                echo "--> SECONDARY is not responding to PING."
                                exit
                        fi
                fi
        fi
fi

if grep -q $NODE_SEC <<<"$ALINKS"; then
        echo "-> Connected to SECONDARY node. Trying to reconnect to PRIMARY."
        if ping -c1 $NODE_PRIM_H &>/dev/null; then
                echo "--> PRIMARY node responding to ping. Reconnecting..."
                asterisk -rx "rpt cmd $NODE ilink 11 $NODE_SEC"
                asterisk -rx "rpt cmd $NODE ilink 13 $NODE_PRIM"
                ALINKS=`asterisk -rx "rpt xnode $NODE" | grep RPT_ALINKS= | rev | cut -d "=" -f1 | rev`

                if grep -q $NODE_PRIM <<<"$ALINKS"; then
                        echo "--> Reconnected to PRIMARY!"
                        echo "-> DONE."
                        exit
                else
                        asterisk -rx "rpt cmd $NODE ilink 13 $NODE_SEC"
                        echo "--> Reconnection to PRIMARY failed. Failover to SECONDARY."
                        exit
                fi
        else
                echo "-> PRIMARY is not responding to PING. Stay on SECONDARY."
                exit
        fi
fi

# IF not ALINKS
if [ "$ALINKS" == 0 ]; then
        echo "-> Not linked. Trying unsupervised reconnection..."
        asterisk -rx "rpt cmd $NODE ilink 13 $NODE_PRIM"
        asterisk -rx "rpt cmd $NODE ilink 13 $NODE_SEC"
        echo "-> Stand by for next check for connection confirmation."
        exit
fi

echo "-end"