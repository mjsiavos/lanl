#!/bin/bash

cd data

# download the data
echo "[+] Downloading and unzipping the data"
declare -a files=('auth.txt' 'proc.txt' 'flows.txt' 'dns.txt' 'redteam.txt')
for f in "${files[@]}"
do
	if [ ! -f $f ]
	then
		wget https://csr.lanl.gov/data/cyber1/$f.gz -q --show-progress --progress=bar:force:noscroll
		gunzip $f.gz
	fi
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
        echo "    Working on $f..."
	echo "id,name" > $f.csv
        cat $f.txt | sort --parallel=4 -u | awk '{printf "%s,%s\n",NR,$0}' >> $f.csv
        rm $f.txt
done

cd -
