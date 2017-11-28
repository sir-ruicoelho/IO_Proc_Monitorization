#!/bin/bash

function displayHelp()
{
	#Função de ajuda
	echo "-c Expressão regular"
	echo "-s Data mínima"
	echo "-e Data máxima"
	echo "-u Seleção de processos através do nome do utilizador"
	echo "-p Número de processos"
	echo "-r Reverso"
	echo "-w Sort and write values"
	echo "-t Sort on total values"
	echo "O último argumento deverá ser o tempo"
	rm -rf temp
	exit
}

function getprocfiles()
{
		#Faz a leitura dos ficheiros e armazena no diretório temporário
        proclist=$( ls /proc )
        mkdir "temp/temp$1"
        #Nos processos que não temos premissões apenas copiará o comm adicionando mais algumas informações ao ficheiro
        for procid in $proclist
        do
                if [ -r "/proc/$procid/io" ]; then
                        #echo "Tem premissões de leitura do ficheiro /proc/$procid/io. Copiando os ficheiros para temp/temp$1/$procid"
                        mkdir "temp/temp$1/$procid"
                        cp "/proc/$procid/comm" "temp/temp$1/$procid/comm"
                        cp "/proc/$procid/io" "temp/temp$1/$procid/$procid"
                        echo $(stat -c "%U" /proc/$procid/io) >> "temp/temp$1/$procid/comm"
			echo $(stat -c "%z" /proc/$procid/io) >> "temp/temp$1/$procid/comm"
			echo $(stat -c "%Z" /proc/$procid/io) >> "temp/temp$1/$procid/comm"
                elif [ -e "/proc/$procid/comm" ]; then
                		#echo "Não tem premissão de leitura do ficheiro /proc/$procid/io. Copiando os ficheiros para temp/temp$1/$procid"
                        mkdir "temp/temp$1/$procid"
                        cp "/proc/$procid/comm" "temp/temp$1/$procid/comm"
                        echo $(stat -c "%U" /proc/$procid/io) >> "temp/temp$1/$procid/comm"
			echo $(stat -c "%z" /proc/$procid/io) >> "temp/temp$1/$procid/comm"
			echo $(stat -c "%Z" /proc/$procid/io) >> "temp/temp$1/$procid/comm"
                fi
        done
        #echo "Cópia de processos terminada"
}

function validarArgumentos()
{
        #Verifica número de argumentos
        if  (( $# > 14 )) || (( $# < 1 )); 
                then
                        displayHelp
                        exit
        fi
        #Verifica se o último argumento é um número
        if ! [[ ${@: -1} =~ ^[0-9]+$ ]];
                then
                	#Ativa o menu de ajuda se o último argumento for -help, --help ou -h
					if [[ "${@: -1}" == "-help" ]] || [[ "${@: -1}" == "--help" ]] || [[ "${@: -1}" == "-h" ]] ;
						then
							displayHelp "$1"
							exit
					else
						echo "Último argumento tem de ser inteiro positivo"
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
							echo "Tem de ser um inteiro positivo ou zero"
							exit 1
						fi
					elif [[ "$previousoption" == "-s" || "$previousoption" == "-e" ]]; then
						data=$(date -d "$argument" 2> /dev/null) || erro=$?
						if [[ $erro -eq 0 ]]; then
							continue
						else
							echo "Data inválida"
							exit 1
						fi	
					elif [[ "$argument" == "${@: -1}" ]]; then
						continue
					else
						echo "Opção inválida!"
					fi
					checkargument=0
					;;
        	esac

        done
}

function precheckfiles()
{
		#Verifica se os processos extraídos inicialmente continuam a existir
        tempfiles1=$( ls temp/temp1 )
        for tempfile in $tempfiles1
        do
                if ! [ -e "temp/temp2/$tempfile" ]; then
                        #echo "$tempfile doesnt exist in temp/temp2. deleting it"
                        rm -rf "temp/temp2/$tempfile"
                fi
        done
        tempfiles2=$( ls temp/temp2 )
        for tempfile in $tempfiles2
        do
                if ! [ -e "temp/temp2/$tempfile" ]; then
                        #echo "$tempfile doesnt exist in temp/temp1. deleting it"
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
	#Extrai as informações do I/O e armazena num ficheiro temporário
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
		#Define o I/O quando não temos premissões de leitura
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
		#Faz a ordenação pela expressão regular
        rm -rf temp/proclines.bak
        touch temp/proclines.bak
        sed -n "/^$1$/p" temp/proclines > temp/proclines.bak
        rm -rf temp/proclines
        cp temp/proclines.bak temp/proclines
        rm -rf temp/proclines.bak
}

function filterbyuser()
{
		#Faz a ordenação pelo nome de utilizador
        rm -rf temp/proclines.bak
        touch temp/proclines.bak
        sed -n "/\<$1\>/p" temp/proclines > temp/proclines.bak
        rm -rf temp/proclines
        cp temp/proclines.bak temp/proclines
        rm -rf temp/proclines.bak
}

function sortbynumberofprocs()
{
	rm -rf temp/proclines.bak
	touch temp/proclines.bak
	head -n "$1" temp/proclines > temp/proclines.bak
	rm -rf temp/proclines
        cp temp/proclines.bak temp/proclines
        rm -rf temp/proclines.bak
}

function filtrardataminima()
{
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

#Apaga o diretório no caso do utilizador terminar com a sua KeyBoard
trap "rm -rf temp; exit 0" SIGINT

#Chamada da função de validação
validarArgumentos "$@"

#Verifica se o diretório temp/ existe e, caso exista, elimina-o
if [ -d temp ]; then
        #echo "apagando o diretorio ./temp"
         rm -rf temp
fi

#Criação do diretório temp/
#echo "criando o diretorio ./temp"
mkdir temp

#Faz a leitura dos processos e armazena-os para posterior tratamento
getprocfiles "1"
sleep "${@: -1}s"
getprocfiles "2"
precheckfiles
createproclinefile "${@: -1}"

reversion=0
wvalues=0
tvalues=0
#Vai buscar os filtros a aplicar
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

#Imprime a tabela na consola
imprimir

#Remove o diretório temporado criado e termina a monitorização
#echo deleting temporary files
rm -rf temp
