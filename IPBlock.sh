#!/bin/bash

# Define black-list texts to scan in the responsed html
search_Texts=(
    apache
    apache2
    centos
    ubuntu
    )

# IP address validation function
function validate_ip()
{
    local  ip=$1
    local  stat=1

    # check if $ip is only consist of numbers.
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        # check if every digits are less than 255
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

# CSF IP Drop fuction
function CSF_Drop_IP()
{
    local ip=$1

    echo "trying to deny $ip ..."
    # Denied IPs are defined in /etc/csf/csf.deny.
    while IFS=' ' read -r denied_IP; do
        # If the IP is already denied, ignore.
        if [[ "$ip" == $(echo $denied_IP | awk '{print $1}') ]]; then
            echo "The IP $ip is already denied."
            return
        fi
    done < "/etc/csf/csf.deny"

    /usr/sbin/csf -d $ip
    echo "The IP address $ip has been denied successfully."
    sleep 1

    return
}

# Get all IPs from netstat session.
IPs=$(netstat -atun | awk '{print $5}' | cut -d: -f1 | sed -e '/^$/d' |sort | uniq -c | sort -n | awk '{print $2}')

# Create the Valid_IPs array. Only get valid IPs from parsed IPs from netstat
valid_IPs=()
dropped_IPs=()

dropped_Status=0

while IFS='' read -r -a IP_Array; do
    for IP in "${IP_Array}"; do
        # check if the parsed $IP is valid IP address. skip unvalid IPs
        if validate_ip $IP ; then
            # check if the parsed $IP is 0.0.0.0. if then ignore
            if [ $IP != "0.0.0.0" ]; then
                if [ $IP != "127.0.0.1" ]; then
                    valid_IPs+=($IP)
                fi
            fi
        fi
    done
done <<< "$IPs"

echo "All IPs from netstat session."
echo "========================================================================"
echo ${valid_IPs[@]}
echo "========================================================================"

# Make a html folder in which response html file will be saved.
if [ ! -d /etc/html ]
then
    mkdir -p /etc/html
else
    rm -rf /etc/html
    mkdir -p /etc/html
fi

# get response data by wget and save into /html folder.
for valid_IP in "${valid_IPs[@]}"
do
    wget http://$valid_IP --timeout=1 --output-document=/etc/html/$valid_IP.html --tries=1
done

# check html file if there is any black-list text.
for html_file in $(ls /etc/html)
do
    blacklist_status=0
    for search_Text in ${search_Texts[@]}
    do
        null=""
        if grep -q $search_Text "/etc/html/$html_file"
        then
            blacklist_status=1
            break
        fi
    done

    # if there is any black-list text in one IP's html file, drop that IP.
    if [ $blacklist_status == 1 ]; then
        # get IP address from file name.  10.10.10.10.html => 10.10.10.10
        drop_IP=${html_file::-5}

        # Check unless the IP already dropped and drop.
        if CSF_Drop_IP $drop_IP ; then
            dropped_Status=1
            dropped_IPs+=($drop_IP)
        fi
    fi
done

echo "The IPs '${dropped_IPs[@]}' has been blocked."

if [ $dropped_Status == 1 ]; then
    echo "Trying to send email about the CSF status..."

    # send email to administrator about the CSF changed status.
    subject="CSF1 Firewall Status"
    body="The IPs '${dropped_IPs[@]}' has been blocked."
    from="csf1@gmail.com"
    pass="csf1's password"
    to="tgsyan@gmail.com"
    server="smtp.gmail.com:587"

    # send email
    echo $subject | sendemail -l /var/log/email.log -f $from -u $body -t $to -s $server -o tls=yes -xu $from -xp $pass

    echo "email has been sent."
fi

# remove /html folder
rm -rf /etc/html
