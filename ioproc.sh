#!/bin/bash

function displayHelp()
{
	#Help function
	echo "-c Regular expression"
	echo "-s Minimum date"
	echo "-e Maximum date"
	echo "-u Selection of processes by user name"
	echo "-p Number of processes"
	echo "-r Reverse"
	echo "-w Sort and write values"
	echo "-t Sort on total values"
	echo "The last argumments should be an int (time value)"
	rm -rf temp
	exit
}

function getprocfiles()
{
	#Read the files and add them to a temporary directory.
        proclist=$( ls /proc )
        mkdir "temp/temp$1"
	#Processes without permissions only teh comm is copied.
        for procid in $proclist
        do
                if [ -r "/proc/$procid/io" ]; then
                        mkdir "temp/temp$1/$procid"
                        cp "/proc/$procid/comm" "temp/temp$1/$procid/comm"
                        cp "/proc/$procid/io" "temp/temp$1/$procid/$procid"
                        echo $(stat -c "%U" /proc/$procid/io) >> "temp/temp$1/$procid/comm"
			echo $(stat -c "%z" /proc/$procid/io) >> "temp/temp$1/$procid/comm"
			echo $(stat -c "%Z" /proc/$procid/io) >> "temp/temp$1/$procid/comm"
                elif [ -e "/proc/$procid/comm" ]; then
                        mkdir "temp/temp$1/$procid"
                        cp "/proc/$procid/comm" "temp/temp$1/$procid/comm"
                        echo $(stat -c "%U" /proc/$procid/io) >> "temp/temp$1/$procid/comm"
			echo $(stat -c "%z" /proc/$procid/io) >> "temp/temp$1/$procid/comm"
			echo $(stat -c "%Z" /proc/$procid/io) >> "temp/temp$1/$procid/comm"
                fi
        done
}

function validarArgumentos()
{
	#Check the number of arguments.
        if  (( $# > 14 )) || (( $# < 1 )); 
                then
                        displayHelp
                        exit
        fi
        #Check if the last argument is an int.
        if ! [[ ${@: -1} =~ ^[0-9]+$ ]];
                then
                	#Activates help menu.
					if [[ "${@: -1}" == "-help" ]] || [[ "${@: -1}" == "--help" ]] || [[ "${@: -1}" == "-h" ]] ;
						then
							displayHelp "$1"
							exit
					else
						echo "The last argument should be a positive int or zero"
						exit
					fi
        fi

        checkargument=0
        previousoption=""
        for argument in "$@"
        do
        	case $argument in
        		-t | -r | -w | -c | -u )
					checkargument=2
        			;;
        		-p | -s | -e )
					checkargument=1
					previousoption="$argument"
					;;
				*)
					if [[ $checkargument -eq 2 ]]; then
						checkargument=0
						continue
					fi
					if [[ "$previousoption" == "-p" && ${@: -1} =~ ^[0-9]+$ ]]; then
						if [[ "$argument" -lt 0 ]]; then
							echo "The last argument should be a positive int or zero."
							exit 1
						fi
					elif [[ "$previousoption" == "-s" || "$previousoption" == "-e" ]]; then
						data=$(date -d "$argument" 2> /dev/null) || erro=$?
						if [[ $erro -eq 0 ]]; then
							continue
						else
							echo "Invalid date"
							exit 1
						fi	
					elif [[ "$argument" == "${@: -1}" ]]; then
						continue
					else
						echo "Invalid option"
					fi
					checkargument=0
					;;
        	esac

        done
}

function precheckfiles()
{
	#Check if processes still exist.
        tempfiles1=$( ls temp/temp1 )
        for tempfile in $tempfiles1
        do
                if ! [ -e "temp/temp2/$tempfile" ]; then
                        rm -rf "temp/temp2/$tempfile"
                fi
        done
        tempfiles2=$( ls temp/temp2 )
        for tempfile in $tempfiles2
        do
                if ! [ -e "temp/temp2/$tempfile" ]; then
                        rm -rf "temp/temp1/$tempfile"
                fi
        done
}

function defaultordenation()
{
	rm -rf temp/proclines.bak
        touch temp/proclines.bak
	sort -t " " -k 6,6 -n -r -o "temp/proclines.bak" "temp/proclines"
	rm -rf temp/proclines
        cp temp/proclines.bak temp/proclines
        rm -rf temp/proclines.bak
}
function createproclinefile()
{
	#Extracts I/O info and store it into a temporary file.
	rm -rf "temp/proclines"
	touch "temp/proclines"
	ttempfiles1=$( ls temp/temp1 )
	ttempfiles2=$( ls temp/temp2 )
	for piddir in $ttempfiles1
	do
		COMMS=$( head -1 "temp/temp1/$piddir/comm" | tail -1)
		USERS=$( head -2 "temp/temp1/$piddir/comm" | tail -1)
		if [ -e "temp/temp1/$piddir/$piddir"  ]; then
			READBS=$( grep read_bytes "temp/temp1/$piddir/$piddir" | cut -d" " -f2 )
			WRITEBS=$( grep -m 1 write_bytes "temp/temp1/$piddir/$piddir" | cut -d" " -f2 )
			RATERS1=$( grep rchar "temp/temp1/$piddir/$piddir" | cut -d" " -f2 )
			RATERS2=$( grep rchar "temp/temp2/$piddir/$piddir" | cut -d" " -f2 )
			let "RATERS = ($RATERS2 - $RATERS1) / $1"
			RATEWS1=$( grep wchar "temp/temp1/$piddir/$piddir" | cut -d" " -f2 )
                	RATEWS2=$( grep wchar "temp/temp2/$piddir/$piddir" | cut -d" " -f2 )
			let "RATEWS = ($RATEWS2 - $RATEWS1) / $1"
			let "TOTALB = ($READBS + $WRITEBS)"
		#Defines I/O when there is no read permissions.
		else
			READBS=-1
			WRITEBS=-1
			RATERS=-1
			RATEWS=-1
			TOTALB=-1
		fi
		DATES=$( head -3 "temp/temp1/$piddir/comm" | tail -1 )
		TIMESTAMPS=$( head -4 "temp/temp1/$piddir/comm" | tail -1)
		printf "$COMMS $USERS $piddir $READBS $WRITEBS $RATERS $RATEWS $DATES $TIMESTAMPS $TOTALB\n" >> "temp/proclines"
	done
	defaultordenation
}

function filterregex()
{
	#Sort by regular expression.
        rm -rf temp/proclines.bak
        touch temp/proclines.bak
        sed -n "/^$1$/p" temp/proclines > temp/proclines.bak
        rm -rf temp/proclines
        cp temp/proclines.bak temp/proclines
        rm -rf temp/proclines.bak
}

function filterbyuser()
{
	#Sort by username.
        rm -rf temp/proclines.bak
        touch temp/proclines.bak
        sed -n "/\<$1\>/p" temp/proclines > temp/proclines.bak
        rm -rf temp/proclines
        cp temp/proclines.bak temp/proclines
        rm -rf temp/proclines.bak
}

function sortbynumberofprocs()
{
	#Sort by number of processes.
	rm -rf temp/proclines.bak
	touch temp/proclines.bak
	head -n "$1" temp/proclines > temp/proclines.bak
	rm -rf temp/proclines
        cp temp/proclines.bak temp/proclines
        rm -rf temp/proclines.bak
}

function filtrardataminima()
{
	# Minimum date filtering.
	valorminimo=$(date --date="$1" +"%s")
	rm -rf temp/proclines.bak
        touch temp/proclines.bak
	while read line; do
		valortemp=$(echo "$line" | cut -d" " -f11)
		if [[ $valortemp -ge $valorminimo ]]; then
			echo "$line" >> temp/proclines.bak
		fi
	done < temp/proclines
	rm -rf temp/proclines
	cp temp/proclines.bak temp/proclines
	rm -rf temp/proclines.bak
}

function filtrardatamaxima()
{
	# Maximum date filtering.
	valormaximo=$(date --date="$1" +"%s")
        rm -rf temp/proclines.bak
        touch temp/proclines.bak
        while read line; do
                valortemp=$(echo "$line" | cut -d" " -f11)
                if [[ $valortemp -le $valormaximo ]]; then
                        echo "$line" >> temp/proclines.bak
                fi
        done < temp/proclines
        rm -rf temp/proclines
        cp temp/proclines.bak temp/proclines
        rm -rf temp/proclines.bak
}

function reverter()
{	
	#Reverse.
	rm -rf temp/proclines.bak
    	touch temp/proclines.bak
	tac temp/proclines > temp/proclines.bak
	rm -rf temp/proclines
	cp temp/proclines.bak temp/proclines
	rm -rf temp/proclines.bak
}

function sortonwritevalues()
{
	rm -rf temp/proclines.bak
    	touch temp/proclines.bak
	sort -t " " -k 7,7 -n -r -o "temp/proclines.bak" "temp/proclines"
	rm -rf temp/proclines
    	cp temp/proclines.bak temp/proclines
    	rm -rf temp/proclines.bak
}
function sortontotalvalues()
{
	rm -rf temp/proclines.bak
    	touch temp/proclines.bak
	sort -t " " -k 4,4 -n -r -o "temp/proclines.bak" "temp/proclines"
	rm -rf temp/proclines
    	cp temp/proclines.bak temp/proclines
    	rm -rf temp/proclines.bak
}
function sortonreadvalues()
{
	rm -rf temp/proclines.bak
    	touch temp/proclines.bak
	sort -t " " -k 5,5 -n -r -o "temp/proclines.bak" "temp/proclines"
	rm -rf temp/proclines
    	cp temp/proclines.bak temp/proclines
    	rm -rf temp/proclines.bak
}
function imprimir()
{
	printf "%15s  %18s  %11s  %10s  %10s  %13s  %13s  %s\n" "COMM" "USER" "PID" "READB" "WRITEB" "RATER" "RATEW" "DATE"
	while read line; do
		COMM=$( echo "$line" | cut -d" " -f1 )
		USER=$( echo "$line" | cut -d" " -f2 )
		PID=$( echo "$line" | cut -d" " -f3 )
		READB=$( echo "$line" | cut -d" " -f4 )
		WRITEB=$( echo "$line" | cut -d" " -f5 )
		RATER=$( echo "$line" | cut -d" " -f6 )
		RATEW=$( echo "$line" | cut -d" " -f7 )
		TIMESTAMP=$( echo "$line" | cut -d" " -f11 )
		DATE=$( date -d "@$TIMESTAMP" +"%b %e %k:%M")
		printf "%15s  %18s  %11s  %10s  %10s  %13s  %13s  %s\n" "$COMM" "$USER" "$PID" "$READB" "$WRITEB" "$RATER" "$RATEW" "$DATE"
	done < temp/proclines
}
#MAIN

#Delete temporary directory if processes is intererrupted by user.
trap "rm -rf temp; exit 0" SIGINT

validarArgumentos "$@"

if [ -d temp ]; then
         rm -rf temp
fi

mkdir temp

getprocfiles "1"
sleep "${@: -1}s"
getprocfiles "2"
precheckfiles
createproclinefile "${@: -1}"

reversion=0
wvalues=0
tvalues=0

while getopts "c:s:e:u:p:rwt" arg; do
  case $arg in
		c)
			value="${OPTARG}"
			filterregex "$value"
			;;
		s)
			data_minima="${OPTARG}"
			filtrardataminima "$data_minima"
			;;
		e)
			data_maxima="${OPTARG}"
			filtrardatamaxima "$data_maxima"
			;;
		u)
			utilizador="${OPTARG}"
			filterbyuser "$utilizador"
			;;
		p)
			numero_processos="${OPTARG}"
			sortbynumberofprocs "$numero_processos"
			;;
		r)
			reversion=1
			;;
		w)
			wvalues=1
			;;
		t)
			tvalues=1
			;;

	    \?)
	      echo "Invalid option: -$OPTARG" >&2
	      ;;
  esac
done

if [[ $wvalues -eq 1 ]]; then
	if [[ $tvalues -eq 1 ]]; then
		sortonreadvalues
	else
		sortonwritevalues
	fi
elif [[ $tvalues -eq 1 ]]; then
		sortontotalvalues
fi
if [[ $reversion -eq 1 ]]; then
	reverter
fi

imprimir

rm -rf temp
