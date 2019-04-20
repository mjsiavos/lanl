#!/bin/bash

cd data

# download the data
echo "[+] Downloading and unzipping the data"
declare -a files=('auth.txt' 'proc.txt' 'flows.txt' 'dns.txt' 'redteam.txt')
for f in "${files[@]}"
do
	if [ ! -f $f ]
	then
		wget "https://csr.lanl.gov/data/cyber1/$f.gz" -q --show-progress --progress=bar:force:noscroll
		gunzip "$f.gz"
	fi
done

# create the end files where our data will be saved with the headers
echo "[+] Creating initial versions of final files"
declare -a files=('computers.csv' 'user_domains.csv' 'ports.csv' 'processes.csv' 'auth_type.csv' 'auth_orientation.csv' 'logon_type.csv')
for f in "${files[@]}"
do
	echo 'id,name' > $f
done

# extract information from the raw files into the reference files
echo "[+] Creating reference tables"
awk -F ',' '{print $2 >> "user_domains.txt"} {print $3 >> "user_domains.txt"} {print $4 >> "computers.txt"} {print $5 >> "computers.txt"} {print $6 >> "auth_type.txt"} {print $7 >> "logon_type.txt"} {print $8 >> "auth_orientation.txt"}' auth.txt

awk -F ',' '{print $3 >> "computers.txt"} {print $4 >> "ports.txt"} {print $5 >> "computers.txt"} {print $6 >> "ports.txt"}' flows.txt

awk -F ',' '{print $2 >> "user_domains.txt"} {print $3 >> "computers.txt"} {print $4 >> "processes.txt"}' proc.txt

awk -F ',' '{print $2 >> "computers.txt"} {print $3 >> "computers.txt"}' dns.txt

awk -F ',' '{print $2 >> "user_domains.txt"} {print $3 >> "computers.txt"} {print $4 >> "computers.txt"}' redteam.txt

# dedupe the lookup tables and assign row numbers to the files
echo "[+] Deduping and assigning ID values to the lookup tables"
declare -a files=('computers' 'user_domains' 'ports' 'processes' 'auth_type' 'auth_orientation' 'logon_type')
for f in "${files[@]}"
do
        # Sort the file and make it unique, and then add line numbers
        echo "Working on $f..."
        cat $f.txt | sort --parallel=4 -u | awk '{printf "%s,%s\n",NR,$0}' >> $f.csv
        rm $f.txt
done

# replace the data in the main tables with the lookup values in the reference tables
declare -a files=('computers.csv' 'ports.csv' 'processes.csv' 'user_domains.csv' 'auth_type.csv' 'auth_orientation.csv' 'logon_type.csv')
for f in "${files[@]}"
do
	sort -k 2 -t , -o $f $f
done

echo "[+] Normalizing auth.txt"
sort -k 2 -t "," auth.txt | join -1 2 -2 2 -t , -o 1.1,2.1,1.3,1.4,1.5,1.6,1.7,1.8,1.9 - user_domains.csv | sort -k 3 -t , | join -1 3 -2 2 -t , -o 1.1,1.2,2.1,1.4,1.5,1.6,1.7,1.8,1.9 - user_domains.csv | sort -k 4 -t , | join -1 4 -2 2 -t , -o 1.1,1.2,1.3,2.1,1.5,1.6,1.7,1.8,1.9 - computers.csv | sort -k 5 -t , | join -1 5 -2 2 -t , -o 1.1,1.2,1.3,1.4,2.1,1.6,1.7,1.8,1.9 - computers.csv | sort -k 6 -t , | join -1 6 -2 2 -t , -o 1.1,1.2,1.3,1.4,1.5,2.1,1.7,1.8,1.9 - auth_type.csv | sort -k 7 -t , | join -1 7 -2 2 -t , -o 1.1,1.2,1.3,1.4,1.5,1.6,2.1,1.8,1.9 - logon_type.csv | sort -k 8 -t , | join -1 8 -2 2 -t , -o 1.1,1.2,1.3,1.4,1.5,1.6,1.7,2.1,1.9 - auth_orientation.csv | sort -k 1 -t , | sed -e "s/Success/1/g;s/Failure/0/g" > auth.csv

echo "[+] Normalizing flows.txt"
sort -k 3 -t , flows.txt | join -1 3 -2 2 -t , -o 1.1,1.2,2.1,1.4,1.5,1.6,1.7,1.8,1.9 - computers.csv | sort -k 4 -t , | join -1 4 -2 2 -t , -o 1.1,1.2,1.3,2.1,1.5,1.6,1.7,1.8,1.9 - ports.csv | sort -k 5 -t , | join -1 5 -2 2 -t , -o 1.1,1.2,1.3,1.4,2.1,1.6,1.7,1.8,1.9 - computers.csv | sort -k 6 -t , | join -1 6 -2 2 -t , -o 1.1,1.2,1.3,1.4,1.5,2.1,1.7,1.8,1.9 - ports.csv| sort -k 1 -t , > flows.csv

echo "[+] Normalizing proc.txt"
sort -k 2 -t , proc.txt | join -1 2 -2 2 -t , -o 1.1,2.1,1.3,1.4,1.5 - user_domains.csv | sort -k 3 -t , | join -1 3 -2 2 -t , -o 1.1,1.2,2.1,1.4,1.5 - computers.csv | sort -k 4 -t , | join -1 4 -2 2 -t , -o 1.1,1.2,1.3,2.1,1.5 - processes.csv| sort -k 1 -t , | sed -e "s/Start/1/g;s/End/0/g" > proc.csv

echo "[+] Normalizing dns.txt"
sort -k 2 -t , dns.txt | join -1 2 -2 2 -t , -o 1.1,2.1,1.3 - computers.csv | sort -k 3 -t , | join -1 3 -2 2 -t , -o 1.1,1.2,2.1 - computers.csv | sort -k 1 -t , > dns.csv

echo "[+] Normalizing redteam.txt"
sort -k 2 -t , redteam.txt | join -1 2 -2 2 - user_domains.csv -t , -o 1.1,2.1,1.3,1.4 | sort -k 3 -t , | join -1 3 -2 2 - computers.csv -t , -o 1.1,1.2,2.1,1.4 | sort -k 4 -t , | join -1 4 -2 2 - computers.csv -t , -o 1.1,1.2,1.3,2.1 | sort -k 1 -t , > redteam.csv

cd -
