#!/bin/bash

BINDIR=$(dirname "$(readlink -fn "$0")")
cd "$BINDIR"

: '
	**************************************
	***  Copyright (C) � 2016 Mike R.  ***
	***      All rights reserved.      ***
	***     Selling is prohibited!     ***
	***  GitHub.com/MikesCodeProjects  ***
	**************************************
	
	This Script was tested on Debian 8 (Jessie) and Ubuntu 16.10 (Yakkety Yak)
	
	Example-Filename:	control.sh
	Example-Execution:	./control.sh
	
	Commandline-Parameters:
		Execution:		Parameter:			Action:
		----------------------------------------------------------------------
		./control.sh	start				Starts the server.
		./control.sh	stop				Stops the server.
		./control.sh	restart				Restarts the server.
		./control.sh	status				Shows: Is the server running?
		./control.sh	console				Opens the servers console.
		./control.sh	help				Shows the help-page.
		./control.sh	* (wildcard)		Shows you the usage.
'

: ' >>> NOVICE-SETUP <<< '

APPLICATION_NAME="Application-Server"
SCREEN_NAME="ApplicationScreenName" # No dots! No lead with 'K_'!
EXECUTION_FILE="startfile -parameter1 -parameter2"
EXECUTING_USER="root"

SCREEN_KEEPER=false
MIN_ELAPSED_TIME=30
MAXCOUNT_TIME_EXCEEDED=3
RESTART_DELAY=0

: ' >>> ADVANCED-SETUP <<< '

NOT_RECOMMEND_FORCE_RUN=false

ENABLE_USERDEFINED_STOP=false
function userdefined_stop() { # Params: SCREEN_NAME/SCREEN_NAME_FULL
	# For commands to send or so...
	
	screen_send_cmd "${1}" "save-all"
	echo -en "."
	sleep 1
	
	screen_send_cmd "${1}" "stop"
	echo -en "."
	sleep 1
	
	return 0
}

: ' >>> SCRIPT-SETUP <<< ' # // DONT CHANGE THIS IF YOU DONT KNOW ABOUT THIS SETTINGS

# Regex
REGEX_SCREEN_NAME="^([^[:space:]\.]+)$"						# ScreenName
REGEX_SCREEN_NAME_KEEPER="^K_([^[:space:]\.]+)$"				# ScreenName-Keeper
REGEX_SCREEN_NAME_FULL="^([0-9]{1,5})\.([^[:space:]\.]+)$"	# ScreenName-Full


# tput-COLORS
COLOR_WHITE="$(tput setaf 7)"
COLOR_RED="$(tput setaf 1)"
COLOR_GREEN="$(tput setaf 2)"
COLOR_YELLOW="$(tput setaf 3)"
COLOR_CYAN="$(tput setaf 6)"

COLOR_BOLD="$(tput bold)"
#COLOR_UNDERLINE="$(tput smul)"
#COLOR_UNDERLINE_END="$(tput rmul)"
#COLOR_ITALIC="$(tput sitm)"
#COLOR_ITALIC_END="$(tput ritm)"
#COLOR_BLINK="$(tput blink)"
#COLOR_REVERSE="$(tput rev)"
#COLOR_INVISIBLE="$(tput invis)"

COLOR_RESET="$(tput sgr0)"

# Preparation

FULL_COMMAND_LINE="${0} ${@}"

: ' >>> METHODS <<< '

function get_current_user() { # Params: RETURN
	local get_current_user_return="";
	
	get_current_user_return=$(whoami)
	
	eval "${1}=\"${get_current_user_return}\""
	unset -v get_current_user_return
	
	return 0
}

function user_exists() { # Params: USER
	if getent passwd ${1} > /dev/null; then
		return 0
	fi;
	return 1
}

function correct_user_running() {
	if [ $(get_current_user RET; echo "${RET}") == "root" ] && [ ${EXECUTING_USER} != "root" ]; then # IF [ user == root and havetouser != root ]
		return 1
	elif [ $(get_current_user RET; echo "${RET}") == "${EXECUTING_USER}" ]; then # IF [ user == havetouser ]
		return 0
	else # ELSE: IF [ user != root and user != havetouser ]
		return 1
	fi;
}

function user_permitted() { # Params: USER
	if user_exists "${1}"; then
		if [ $(get_current_user RET; echo "${RET}") == "root" ] && [ ${1} != "root" ]; then # IF [ user == root and havetouser != root ]
			return 0
		elif [ $(get_current_user RET; echo "${RET}") == "${1}" ]; then # IF [ user == havetouser ]
			return 0
		else # ELSE: IF [ user != root and user != havetouser ]
			return 1
		fi;
		
		return 1
	fi;
}

function redirect_user() { # Params: USER
	if user_exists "${1}"; then
		if user_permitted "${1}"; then
			if ! correct_user_running; then
				sudo -u ${1} ${FULL_COMMAND_LINE}
				unset -v FULL_COMMAND_LINE
				return $?
			fi;
		fi;
	fi;
	
	return 1
}

function redirect_processed() {
	CMDLINE=$(ps -p ${PPID} -o args --no-headers)
	P_CMDLINE=$(ps -p $(ps -o ppid= ${PPID} | sed -e 's/^[ ]//' ) -o args --no-headers)
	
	COMP_CMDLINE="sudo -u ${EXECUTING_USER} ${FULL_COMMAND_LINE}"
	COMP_P_CMDLINE="/bin/bash ${FULL_COMMAND_LINE}"
	
	if [ "${CMDLINE}" == "${COMP_CMDLINE}" ] && [ "${P_CMDLINE}" == "${COMP_P_CMDLINE}" ]; then
		return 0
	fi;
	
	unset -v CMDLINE P_CMDLINE COMP_CMDLINE COMP_P_CMDLINE
	
	return 1
}

function executed_byBash() {
	#CMDLINE=$(ps -p ${PPID} -o args --no-headers)
	CMDLINE=$(ps -p $(ps -o ppid= ${PPID} | sed -e 's/^[ ]//' ) -o args --no-headers)
	
	COMP_CMDLINE="/bin/bash ./control.sh"
	
	if [ "${#CMDLINE}" -ge 22 ]; then
		if [ "${CMDLINE:0:22}" == "${COMP_CMDLINE}" ]; then
			return 0
		fi;
	fi;
	
	unset -v CMDLINE COMP_CMDLINE
	
	return 1
}

function executed_bySSHD() {
	#CMDLINE=$(ps -p ${PPID} -o args --no-headers)
	CMDLINE=$(ps -p $(ps -o ppid= ${PPID} | sed -e 's/^[ ]//' ) -o args --no-headers)
	
	COMP_CMDLINE="sshd: "
	
	if [ "${#CMDLINE}" -ge 6 ]; then
		if [ "${CMDLINE:0:6}" == "${COMP_CMDLINE}" ]; then
			return 0
		fi;
	fi;
	
	unset -v CMDLINE COMP_CMDLINE
	
	return 1
}

: '
	@Developer Notes
	
	Function: ......... screen_list
	Explaination ...... Returns all the screens back, which run on the current user.
	Parameters:
		RETURN ........ Return-Value (List of all Screens)
	
	Additional Notes:
		$(RETURN) | sed -n ${LINE}p		........................................	Get 3rd line of ${RETURN} (In Example: ${LINE} = 3; Rule: ${LINE} > 0)
		$(RETURN) | grep -F ".${SCREEN_NAME}	"	............................	Get only screens with ${SCREEN_NAME}
		grep -c . <<<"$(RETURN)"	............................................	Get lines count of ${RETURN}
		echo "${FGET}" | grep -F "${1}" | cut -f1 -d'	' | cut -f1 -d'.'	....	Get PID of a screen  -  Please check for duplicate
		
'

function screen_list() { # Params: RETURN Optional:SCREEN_NAME
	local screen_list_return="";
	
	#FLIST=$( screen -ls | grep -P "^\t([0-9]{1,5})\.([^\t\s\.]+)\t\(([0-9]{2}\/[0-9]{2}\/[0-9]{4})\s([0-9]{2}\:[0-9]{2}\:[0-9]{2})\s(PM)\)\t\(([^\(\)]*)\)$" | sed -e 's/^[ \t]*//' )  # @Deprecated
	screen_list_return=$( screen -ls | grep -P "^(\t|\s)([0-9]{1,5})\.([^\t\s\.]+)(\t|\s)\(([0-9]{2}\/[0-9]{2}\/([0-9]{2}|[0-9]{4}))\s([0-9]{2}\:[0-9]{2}\:[0-9]{2})(\s(PM|AM))?\)(\t|\s)\(([^\(\)]*)\)$" | sed -e 's/^[ \t]*//' )
	
	if [[ "${2}" =~ ${REGEX_SCREEN_NAME_FULL} ]]; then
		screen_list_return=$( echo "${screen_list_return}" | grep -P "{2}(\t|\s)" )
	elif [[ "${2}" =~ ${REGEX_SCREEN_NAME} ]]; then
		screen_list_return=$( echo "${screen_list_return}" | grep -P "^([0-9]{1,5})\.${2}(\t|\s)" )
	fi;
	
	eval "${1}=\"${screen_list_return}\""
	unset -v screen_list_return
	
	return 0
}

function screen_count() { # Params: RETURN SCREEN_NAME/SCREEN_NAME_FULL
	local screen_count_return="0";
	
	if [[ "${2}" =~ ${REGEX_SCREEN_NAME_FULL} ]]; then
		if screen_status ${2}; then
			screen_count_return="1"
		else
			return 1
		fi;
	elif [[ "${2}" =~ ${REGEX_SCREEN_NAME} ]]; then
		screen_list screen_count_return "${2}"
		
		screen_count_return=$( grep -c . <<<"${screen_count_return}" )
	else
		return 1
	fi;
	
	eval "${1}=\"${screen_count_return}\""
	unset -v screen_count_return
	
	return 0
}

function screen_pid() { # Params: RETURN SCREEN_NAME/SCREEN_NAME_FULL
	local screen_pid_return="0";
	
	if [[ "${2}" =~ ${REGEX_SCREEN_NAME_FULL} ]]; then
		if screen_status "${2}"; then
			screen_pid_return=$( echo -e "${2}" | cut -f1 -d'.' )
		else
			return 1
		fi;
	elif [[ "${2}" =~ ${REGEX_SCREEN_NAME} ]]; then
		screen_list screen_pid_return "${2}"
		
		if [ "$( grep -c . <<<"${screen_pid_return}" )" -eq 1 ]; then
			screen_pid_return=$( echo -e "${screen_pid_return}" | cut -f1 -d'	' | cut -f1 -d'.' )
		else
			echo -e "Hier:${2}"
			return 1
		fi;
	else
		return 1
	fi;
	
	eval "${1}=\"${screen_pid_return}\""
	unset -v screen_pid_return
	
	return 0
}

function screen_status() { # Params: SCREEN_NAME/SCREEN_NAME_FULL
	local screen_status_list="";
	screen_list screen_status_list "${1}"
	
	if [ "$( grep -c . <<<"${screen_status_list}" )" -ne 0 ]; then # IF there does screens exists with this name
		return 0
	fi;
		
	unset -v screen_status_list
	
	return 1
}

function screen_start() { # Params: SCREEN_NAME COMMAND_LINE
	if [[ ${1} =~ ${REGEX_SCREEN_NAME} ]] && [ ! -z "${2}" ]; then
		if ! screen_status "${1}"; then
			screen -admS ${1} ${2}
			return 0
		fi;
	fi;
	
	return 1
}

function screen_stop() { # Params: SCREEN_NAME/SCREEN_NAME_FULL
	if [[ ${1} =~ ${REGEX_SCREEN_NAME} ]] || [[ ${1} =~ ${REGEX_SCREEN_NAME_FULL} ]]; then
		if screen_status "${1}"; then
			screen -X -S ${1} quit
			return 0
		fi;
	fi;
	
	return 1
}

function screen_reattach() { # Params: SCREEN_NAME/SCREEN_NAME_FULL
	if [[ ${1} =~ ${REGEX_SCREEN_NAME} ]] || [[ ${1} =~ ${REGEX_SCREEN_NAME_FULL} ]]; then
		if screen_status "${1}"; then
			script -q -c "screen -rxS ${1}"
			return 0
		fi;
	fi;
	
	return 1
}

function screen_send_string() { # Params: SCREEN_NAME/SCREEN_NAME_FULL STRING
	if ( [[ ${1} =~ ${REGEX_SCREEN_NAME} ]] || [[ ${1} =~ ${REGEX_SCREEN_NAME_FULL} ]] ) && [ ! -z "${2}" ]; then
		if screen_status "${1}"; then
			screen -S ${1} -X stuff "${2}"
			return 0
		fi;
	fi;
	
	return 1
}

function screen_send_cmd() { # Params: SCREEN_NAME/SCREEN_NAME_FULL COMMAND_LINE
	if ( [[ ${1} =~ ${REGEX_SCREEN_NAME} ]] || [[ ${1} =~ ${REGEX_SCREEN_NAME_FULL} ]] ) && [ ! -z "${2}" ]; then
		if screen_status "${1}"; then
			screen -S ${1} -X stuff "${2}^M"
			return 0
		fi;
	fi;
	
	return 1
}

function get_distrib_name() { # Params: RETURN
	local distrib_name_return="";
	
	if [ -f /etc/os-release ]; then
		distrib_name_return="$(cat /etc/os-release | grep -P "^NAME=" | cut -f2 -d'=')"
		if [ "${distrib_name_return:0:1}" = "\"" ]; then
			distrib_name_return="${distrib_name_return:1:${#distrib_name_return}-2}"
		fi;
	elif [ -f /etc/lsb-release ]; then
		distrib_name_return="$(cat /etc/lsb-release | grep -P "^DISTRIB_ID=" | cut -f2 -d'=')"
		if [ "${distrib_name_return:0:1}" = "\"" ]; then
			distrib_name_return="${distrib_name_return:1:${#distrib_name_return}-2}"
		fi;
	else
		return 1
	fi;
	
	eval "${1}=\"${distrib_name_return}\""
	unset -v distrib_name_return
	
	return 0
}

function get_distrib_version() { # Params: RETURN
	local distrib_version_return="";
	
	if [ -f /etc/os-release ]; then
		distrib_version_return="$(cat /etc/os-release | grep -P "^VERSION_ID=" | cut -f2 -d'=')"
		if [ "${distrib_version_return:0:1}" == "\"" ]; then
			distrib_version_return="${distrib_version_return:1:${#distrib_version_return}-2}"
		fi;
	elif [ -f /etc/lsb-release ]; then
		distrib_version_return="$(cat /etc/lsb-release | grep -P "^DISTRIB_RELEASE=" | cut -f2 -d'=')"
		if [ "${distrib_version_return:0:1}" == "\"" ]; then
			distrib_version_return="${distrib_version_return:1:${#distrib_version_return}-2}"
		fi;
	else
		return 1
	fi;
	
	eval "${1}=\"${distrib_version_return}\""
	unset -v distrib_version_return
	
	return 0
}

function get_distrib_version_name() { # Params: RETURN
	local distrib_version_name_return="";
	
	f_distrib_name=""
	get_distrib_name f_distrib_name
	f_distrib_name_lowercase="$(echo "${distrib_name}" | awk '{print tolower($0)}')"
	
	f_distrib_version=""
	get_distrib_version f_distrib_version
	
	if [ "${f_distrib_name_lowercase}" == "debian" ] || [ "${f_distrib_name_lowercase}" == "debian gnu/linux" ]; then
		if [ "${f_distrib_version}" == "7" ]; then
			distrib_version_name_return="Wheezy"
		elif [ "${f_distrib_version}" == "8" ]; then
			distrib_version_name_return="Jessie"
		elif [ "${f_distrib_version}" == "9" ]; then
			distrib_version_name_return="Stretch"
		elif [ "${f_distrib_version}" == "10" ]; then
			distrib_version_name_return="Buster"
		elif [ "${f_distrib_version}" == "11" ]; then
			distrib_version_name_return="Bullseye"
		fi;
	elif [ "${f_distrib_name_lowercase}" == "ubuntu" ]; then
		if [ "${f_distrib_version}" == "12.04 LTS" ] \
			|| [ "${f_distrib_version}" == "12.04.1 LTS" ] \
			|| [ "${f_distrib_version}" == "12.04.2 LTS" ] \
			|| [ "${f_distrib_version}" == "12.04.3 LTS" ] \
			|| [ "${f_distrib_version}" == "12.04.4 LTS" ] \
			|| [ "${f_distrib_version}" == "12.04.5 LTS" ]; then
			distrib_version_name_return="Precise Pangolin"
		elif [ "${f_distrib_version}" == "12.10" ]; then
			distrib_version_name_return="Quantal Quetzal"
		elif [ "${f_distrib_version}" == "13.04" ]; then
			distrib_version_name_return="Raring Ringtail"
		elif [ "${f_distrib_version}" == "13.10" ]; then
			distrib_version_name_return="Saucy Salamander"
		elif [ "${f_distrib_version}" == "14.04 LTS" ] \
			|| [ "${f_distrib_version}" == "14.04.1 LTS" ] \
			|| [ "${f_distrib_version}" == "14.04.2 LTS" ] \
			|| [ "${f_distrib_version}" == "14.04.3 LTS" ] \
			|| [ "${f_distrib_version}" == "14.04.4 LTS" ] \
			|| [ "${f_distrib_version}" == "14.04.5 LTS" ]; then
			distrib_version_name_return="Trusty Tahr"
		elif [ "${f_distrib_version}" == "14.10" ]; then
			distrib_version_name_return="Utopic Unicorn"
		elif [ "${f_distrib_version}" == "15.04" ]; then
			distrib_version_name_return="Vivid Vervet"
		elif [ "${f_distrib_version}" == "15.10" ]; then
			distrib_version_name_return="Wily Werewolf"
		elif [ "${f_distrib_version}" == "16.04 LTS" ] \
			|| [ "${f_distrib_version}" == "16.04.1 LTS" ] \
			|| [ "${f_distrib_version}" == "16.04.2 LTS" ]; then
			distrib_version_name_return="Xenial Xerus"
		elif [ "${f_distrib_version}" == "16.10" ]; then
			distrib_version_name_return="Yakkety Yak"
		elif [ "${f_distrib_version}" == "17.04" ]; then
			distrib_version_name_return="Zesty Zapus"
		fi;
	fi;
	
	if [ -z "${distrib_version_name_return}" ]; then
		distrib_version_name_return="Unknown Codename"
	fi;
	
	eval "${1}=\"${distrib_version_name_return}\""
	unset -v distrib_version_name_return
	
	return 0
}

: ' >>> SCRIPT <<< '

EXIT_CODE=0 # DO NOT CHANGE THIS

distrib_name=""
get_distrib_name distrib_name
distrib_name_lowercase="$(echo "${distrib_name}" | awk '{print tolower($0)}')"

distrib_version=""
get_distrib_version distrib_version

distrib_version_name=""
get_distrib_version_name distrib_version_name


if [ "${distrib_name_lowercase}" != "ubuntu" ] && [ "${distrib_name_lowercase}" != "debian" ] && [ "${distrib_name_lowercase}" != "debian gnu/linux" ]; then
	if [ "${NOT_RECOMMEND_FORCE_RUN}" == false ]; then
		echo -e ""
		echo -e "${COLOR_RED}${COLOR_BOLD}  Your System is not intended to run this Script!${COLOR_RESET}"
		echo -e "${COLOR_WHITE}${COLOR_BOLD}----------------------------------------------------------------"
		echo -e "${COLOR_WHITE}${COLOR_BOLD}  Current Distribution:		${COLOR_YELLOW}${distrib_name} ${distrib_version} ${distrib_version_name}*${COLOR_RESET}"
		echo -e "${COLOR_WHITE}${COLOR_BOLD}  Supported Distribution:	${COLOR_YELLOW}Debian 7+ or Ubuntu 12.04+${COLOR_RESET}"
		echo -e "${COLOR_WHITE}${COLOR_BOLD}----------------------------------------------------------------"
		echo -e "${COLOR_RED}${COLOR_BOLD}  Setting 'NOT_RECOMMEND_FORCE_RUN' to 'true' forces the Script running!${COLOR_RESET}"
		echo -e ""
		exit 1
	fi;
fi;

if ! command -v screen &> /dev/null && [ "${NOT_RECOMMEND_FORCE_RUN}" == false ]; then
	echo -e "${COLOR_RED}${COLOR_BOLD}The required Package 'screen' isn't installed on your System!${COLOR_RESET}"
	echo -e "${COLOR_YELLOW}${COLOR_BOLD}Type in 'apt-get update; apt-get install screen' to install this Package.${COLOR_RESET}"
	exit 1
fi;

if ! command -v sudo &> /dev/null && [ "${NOT_RECOMMEND_FORCE_RUN}" == false ]; then
	echo -e "${COLOR_RED}${COLOR_BOLD}The required Package 'sudo' isn't installed on your System!${COLOR_RESET}"
	echo -e "${COLOR_YELLOW}${COLOR_BOLD}Type in 'apt-get update; apt-get install sudo' to install this Package.${COLOR_RESET}"
	exit 1
fi;

if ! user_permitted "${EXECUTING_USER}"; then
	echo -e "${COLOR_RED}${COLOR_BOLD}You are not permitted to run this Script!${COLOR_RESET}"
	exit 1
fi;

if ! [[ ${SCREEN_NAME} =~ ${REGEX_SCREEN_NAME} ]] || [[ ${SCREEN_NAME} =~ ${REGEX_SCREEN_NAME_KEEPER} ]]; then
	echo -e "${COLOR_RED}${COLOR_BOLD}Invalid Name for Screen, given in Variable 'SCREEN_NAME'!${COLOR_RESET}\n"
	exit 1
fi;

if executed_bySSHD; then
	echo -e "${COLOR_CYAN}${COLOR_BOLD}====================  [ ${SCREEN_NAME} | ${EXECUTING_USER} ]  ====================${COLOR_RESET}\n"
fi;

if ! redirect_processed; then
	if ! correct_user_running; then
		if user_exists "${EXECUTING_USER}"; then
			echo -e "${COLOR_YELLOW}${COLOR_BOLD}Trying to change the user authority...${COLOR_RESET}"
			redirect_user "${EXECUTING_USER}"
			exit $?
		else
			echo -e "${COLOR_RED}${COLOR_BOLD}User doesn't exists, given in Variable 'EXECUTING_USER'!${COLOR_RESET}"
			exit 1
		fi;
	fi;
else
	if ! correct_user_running; then
		echo -e "${COLOR_RED}${COLOR_BOLD}Failed to change the user authority!${COLOR_RESET}"
		exit 1
	else
		echo -e "${COLOR_GREEN}${COLOR_BOLD}Successfully changed the user authority!${COLOR_RESET}\n"
	fi;
fi;

case "${1}" in
	start)
		if screen_status "${SCREEN_NAME}"; then # IF [ SCREEN is running ]  OR  [ K_SCREEN is running ]
			echo -e "${COLOR_RED}${COLOR_BOLD}The ${APPLICATION_NAME} is already running!${COLOR_RESET}"
			exit 1
		fi;
		
		# Start the Screen
		echo -en "${COLOR_WHITE}${COLOR_BOLD}Trying to start the ${APPLICATION_NAME}" # ${COLOR_RESET}"
		
		screen_start "${SCREEN_NAME}" "${EXECUTION_FILE}"
		
		counter=1
		while [ "$counter" -le 10 ]; do
			if ! screen_status "${SCREEN_NAME}"; then
				echo -en "."
				sleep 1
			else
				break
			fi;
			counter=$(($counter+1))
		done;
		unset -v counter
		echo -e "${COLOR_RESET}"
		
		if ! screen_status "${SCREEN_NAME}"; then
			echo -e "${COLOR_RED}${COLOR_BOLD}Failed to start the ${APPLICATION_NAME}!${COLOR_RESET}"
			exit 1
		else
			echo -e "${COLOR_GREEN}${COLOR_BOLD}Successfully started the ${APPLICATION_NAME}!${COLOR_RESET}"
		fi;
		
		# Start the Keeper-Screen
		
		if [ "${SCREEN_KEEPER}" == true ]; then
			if screen_status "K_${SCREEN_NAME}"; then
				echo -e "${COLOR_RED}${COLOR_BOLD}The Keeper for the ${APPLICATION_NAME} is already running!${COLOR_RESET}"
				exit 0
			fi;
			
			echo -en "${COLOR_WHITE}${COLOR_BOLD}Trying to start the Keeper for the ${APPLICATION_NAME}"
			
			screen_start "K_${SCREEN_NAME}" "${0}"
			
			counter=1
			while [ "$counter" -le 10 ]; do
				if ! screen_status "K_${SCREEN_NAME}"; then
					echo -en "."
					sleep 1
				else
					break
				fi;
				counter=$(($counter+1))
			done;
			unset -v counter
			echo -e "${COLOR_RESET}"
			
			if ! screen_status "K_${SCREEN_NAME}"; then
				echo -e "${COLOR_RED}${COLOR_BOLD}Failed to start the Keeper for the ${APPLICATION_NAME}!${COLOR_RESET}"
				exit 1
			else
				echo -e "${COLOR_GREEN}${COLOR_BOLD}Successfully started the Keeper for the ${APPLICATION_NAME}!${COLOR_RESET}"
			fi;
		fi;
	;;
	stop)
		if ! screen_status "${SCREEN_NAME}" && ! screen_status "K_${SCREEN_NAME}"; then
			echo -e "${COLOR_RED}${COLOR_BOLD}The ${APPLICATION_NAME} and the Keeper isn't running!${COLOR_RESET}"
			exit 1
		fi;
		
		# Stop the Keeper
		
		if ! screen_status "K_${SCREEN_NAME}"; then # IF [ SCREEN isn't running ]
			if [ "${SCREEN_KEEPER}" == true ]; then
				echo -e "${COLOR_RED}${COLOR_BOLD}The Keeper of the ${APPLICATION_NAME} isn't running!${COLOR_RESET}"
			fi;
		else
			echo -en "${COLOR_WHITE}${COLOR_BOLD}Trying to stop the Keeper of the ${APPLICATION_NAME} by sending a Term-Signal"
			
			SCREEN_PID=""
			
			if ! screen_pid SCREEN_PID "K_${SCREEN_NAME}"; then
				echo -e "${COLOR_RED}${COLOR_BOLD}Failed to stop the Keeper of the ${APPLICATION_NAME} while getting the PID of the screen!${COLOR_RESET}"
			fi;
			
			kill -SIGTERM "${SCREEN_PID}" 2> /dev/null
			
			counter=1
			while [ "$counter" -le 10 ]; do
				if screen_status "K_${SCREEN_NAME}"; then
					echo -en "."
					sleep 1
				else
					break
				fi;
				counter=$(($counter+1))
			done;
			unset -v counter
			echo -e "${COLOR_RESET}"
			
			if ! screen_status "K_${SCREEN_NAME}"; then
				echo -e "${COLOR_GREEN}${COLOR_BOLD}Successfully stopped the Keeper of the ${APPLICATION_NAME}!${COLOR_RESET}"
			else
				echo -e "${COLOR_RED}${COLOR_BOLD}Failed to stop the Keeper of the ${APPLICATION_NAME}!${COLOR_RESET}"
				
				if [ "${2}" == "force" ] || [ "${2}" == "brute-force" ]; then
					echo -en "${COLOR_WHITE}${COLOR_BOLD}Trying to stop the Keeper of the ${APPLICATION_NAME} by sending a Quit-Signal"
					
					kill -SIGQUIT "${SCREEN_PID}" 2> /dev/null
					
					counter=1
					while [ "$counter" -le 10 ]; do
						if screen_status "K_${SCREEN_NAME}"; then
							echo -en "."
							sleep 1
						else
							break
						fi;
						counter=$(($counter+1))
					done;
					unset -v counter
					echo -e "${COLOR_RESET}"
					
					
					if ! screen_status "K_${SCREEN_NAME}"; then
						echo -e "${COLOR_GREEN}${COLOR_BOLD}Successfully stopped the Keeper of the ${APPLICATION_NAME}!${COLOR_RESET}"
					else
						echo -e "${COLOR_RED}${COLOR_BOLD}Failed to stop the Keeper of the ${APPLICATION_NAME}!${COLOR_RESET}"
						
						if [ "${2}" == "brute-force" ]; then
							echo -en "${COLOR_WHITE}${COLOR_BOLD}Trying to stop the Keeper of the ${APPLICATION_NAME} by sending a Kill-Signal"
							
							kill -SIGKILL "${SCREEN_PID}" 2> /dev/null
							
							counter=1
							while [ "$counter" -le 10 ]; do
								if screen_status "K_${SCREEN_NAME}"; then
									echo -en "."
									sleep 1
								else
									break
								fi;
								counter=$(($counter+1))
							done;
							unset -v counter
							echo -e "${COLOR_RESET}"
							
							if screen_status "K_${SCREEN_NAME}"; then
								echo -e "${COLOR_RED}${COLOR_BOLD}Failed to stop the Keeper of the ${APPLICATION_NAME}!${COLOR_RESET}"
								echo -e "${COLOR_RED}${COLOR_BOLD}Finally the Keeper of the ${APPLICATION_NAME} is still running!${COLOR_RESET}"
							fi;
						fi;
					fi;
				fi;
			fi;
			
			unset -v SCREEN_PID
		fi;
		
		# Stop the Application
		
		if ! screen_status "${SCREEN_NAME}"; then # IF [ SCREEN isn't running ]
			echo -e "${COLOR_RED}${COLOR_BOLD}The ${APPLICATION_NAME} isn't running!${COLOR_RESET}"
		else
			if [ "${ENABLE_USERDEFINED_STOP}" == true ]; then
				echo -en "${COLOR_WHITE}${COLOR_BOLD}Trying to stop the ${APPLICATION_NAME}"
				
				userdefined_stop "${SCREEN_NAME}"
				
				counter=1
				while [ "$counter" -le 10 ]; do
					if screen_status "${SCREEN_NAME}"; then
						echo -en "."
						sleep 1
					else
						break
					fi;
					counter=$(($counter+1))
				done;
				unset -v counter
				echo -e "${COLOR_RESET}"
			fi;
			
			if ! screen_status "${SCREEN_NAME}" && [ "${ENABLE_USERDEFINED_STOP}" == true ]; then
				echo -e "${COLOR_GREEN}${COLOR_BOLD}Successfully stopped the ${APPLICATION_NAME}!${COLOR_RESET}"
			else
				if [ "${ENABLE_USERDEFINED_STOP}" == true ]; then
					echo -e "${COLOR_RED}${COLOR_BOLD}Failed to stop the ${APPLICATION_NAME}!${COLOR_RESET}"
				else
					echo -e "${COLOR_RED}${COLOR_BOLD}No userdefined stop was set!${COLOR_RESET}"
				fi;
				
				if [ "${2}" == "force" ] || [ "${2}" == "brute-force" ] || [ "${ENABLE_USERDEFINED_STOP}" == false ]; then
					echo -en "${COLOR_WHITE}${COLOR_BOLD}Trying to stop the ${APPLICATION_NAME} by sending a Term-Signal"
					
					SCREEN_PID=""
					
					if ! screen_pid SCREEN_PID "${SCREEN_NAME}"; then
						echo -e "${COLOR_RED}${COLOR_BOLD}Failed to stop the ${APPLICATION_NAME} while getting the PID of the screen!${COLOR_RESET}"
					fi;
					
					kill -SIGTERM "${SCREEN_PID}" 2> /dev/null
					
					counter=1
					while [ "$counter" -le 10 ]; do
						if screen_status "${SCREEN_NAME}"; then
							echo -en "."
							sleep 1
						else
							break
						fi;
						counter=$(($counter+1))
					done;
					unset -v counter
					echo -e "${COLOR_RESET}"
					
					if ! screen_status "${SCREEN_NAME}"; then
						echo -e "${COLOR_GREEN}${COLOR_BOLD}Successfully stopped the ${APPLICATION_NAME}!${COLOR_RESET}"
					else
						echo -e "${COLOR_RED}${COLOR_BOLD}Failed to stop the ${APPLICATION_NAME}!${COLOR_RESET}"
						
						if [ "${2}" == "brute-force" ]; then
							echo -en "${COLOR_WHITE}${COLOR_BOLD}Trying to stop the ${APPLICATION_NAME} by sending a Kill-Signal"
							
							kill -SIGKILL "${SCREEN_PID}" 2> /dev/null
							
							counter=1
							while [ "$counter" -le 10 ]; do
								if screen_status "${SCREEN_NAME}"; then
									echo -en "."
									sleep 1
								else
									break
								fi;
								counter=$(($counter+1))
							done;
							unset -v counter
							echo -e "${COLOR_RESET}"
							
							if screen_status "${SCREEN_NAME}"; then
								echo -e "${COLOR_RED}${COLOR_BOLD}Failed to stop the ${APPLICATION_NAME}!${COLOR_RESET}"
								echo -e "${COLOR_RED}${COLOR_BOLD}Finally the ${APPLICATION_NAME} is still running!${COLOR_RESET}"
							fi;
						fi;
					fi;
					
					unset -v SCREEN_PID
				fi;
			fi;
		fi;
	;;
	restart)
		: 'if ! screen_status "${SCREEN_NAME}" && ! screen_status "K_${SCREEN_NAME}"; then
			echo -e "${COLOR_RED}${COLOR_BOLD}There is no ${APPLICATION_NAME} and Keeper running!${COLOR_RESET}"
			exit 1
		fi;'
		echo -e "${COLOR_YELLOW}${COLOR_BOLD}Restart in progress...${COLOR_RESET}"
		
		${0} stop
		: 'if screen_status "${SCREEN_NAME}" || screen_status "K_${SCREEN_NAME}"; then
			echo -e "${COLOR_RED}${COLOR_BOLD}Failed to restart! Restart-progress stopped.${COLOR_RESET}"
			exit 1
		fi;'
		${0} start
	;;
	status)
		if screen_status "${SCREEN_NAME}"; then
			echo -e "${COLOR_GREEN}${COLOR_BOLD}The ${APPLICATION_NAME} is running!${COLOR_RESET}"
		else
			echo -e "${COLOR_RED}${COLOR_BOLD}The ${APPLICATION_NAME} isn't running!${COLOR_RESET}"
		fi;
		
		if [ "${SCREEN_KEEPER}" == true ] || screen_status "K_${SCREEN_NAME}"; then
			if screen_status "K_${SCREEN_NAME}"; then
				echo -e "${COLOR_GREEN}${COLOR_BOLD}The Keeper of the ${APPLICATION_NAME} is running!${COLOR_RESET}"
			else
				echo -e "${COLOR_RED}${COLOR_BOLD}The Keeper of the ${APPLICATION_NAME} isn't running!${COLOR_RESET}"
			fi;
		fi;
	;;
	console)
		if ! screen_status "${SCREEN_NAME}"; then
			echo -e "${COLOR_RED}${COLOR_BOLD}The ${APPLICATION_NAME} isn't running!${COLOR_RESET}"
			exit 1
		fi;
		
		if ! screen_reattach "${SCREEN_NAME}"; then
			echo -e "${COLOR_RED}${COLOR_BOLD}Couldn't reattach the screen of the ${APPLICATION_NAME}!${COLOR_RESET}"
		else
			clear; clear
		fi;
	;;
	help)
		case "$2" in
			start)
				echo -e "\e[93mUse: \"${0} ${2}\" to start ${APPLICATION_NAME}."
			;;
			stop)
				echo -e "\e[93mUse: \"${0} ${2}\" to stop ${APPLICATION_NAME}."
			;;
			status)
				echo -e "\e[93mUse: \"${0} ${2}\" to show ${APPLICATION_NAME} is online or offline."
			;;
			console)
				echo -e "\e[93mUse: \"${0} ${2}\" to go into ${APPLICATION_NAME}-Console."
			;;
			*)
				echo -e "\e[93mUse: \"${0} help {start|stop|status|console}\" for details"
		esac
	;;
	*)
		CMDLINE=$(ps -p ${PPID} -o args --no-headers)
		
		if [ -z "${1}" ] \
			&& ( ( [ "$(echo -e "${CMDLINE}" | awk '{print $1}')" == "SCREEN" ] \
			&& [ "$(echo -e "${CMDLINE}" | awk '{print $2}')" == "-admS" ] \
			&& [ "$(echo -e "${CMDLINE}" | awk '{print $3}')" == "K_${SCREEN_NAME}" ] \
			&& [ "$(basename $(echo -e "${CMDLINE}" | awk '{print substr($0, index($0,$4))}') 2> /dev/null)" == "$(basename ${0} 2> /dev/null)" ] ) \
			|| ( [ -e "$(basename $(echo -e "${CMDLINE}" | awk '{print substr($0, index($0,$2))}') 2> /dev/null)" ] \
				&& [ "$(basename $(echo -e "${CMDLINE}" | awk '{print substr($0, index($0,$2))}') 2> /dev/null)" == "$(basename ${0} 2> /dev/null)" ] ) ); then
			# Only accessible in a screen with the right name.
			
			if [ "${SCREEN_KEEPER}" != true ]; then
				echo -e "${COLOR_WHITE}${COLOR_BOLD}The Keeper for the ${APPLICATION_NAME} isn't enabled!${COLOR_RESET}"
				exit 1
			fi;
			
			: '
				SCREEN_KEEPER=true
				MIN_ELAPSED_TIME=30
				MAXCOUNT_TIME_EXCEEDED=2
				RESTART_DELAY=0'
			
			# Variables
			COUNT_TIME_EXCEEDED=0
			LAST_START_TIME=0
			TRYING_START_SINCE=0
			TRIED_START_SCREEN=false
			
			WHILE_ENABLED=true
			
			# Traps
			trap "WHILE_ENABLED=false" SIGINT SIGKILL SIGTERM SIGQUIT
			
			while [ "${WHILE_ENABLED}" == true ]; do
				if ! screen_status "${SCREEN_NAME}"; then
					if [ "${TRYING_START_SINCE}" -eq 0 ]; then
						echo -e "${COLOR_RED}${COLOR_BOLD}It was determined that the ${APPLICATION_NAME} isn't running!${COLOR_RESET}"
						
						if [ "$(($(date +%s) - ${LAST_START_TIME}))" -ge "${MIN_ELAPSED_TIME}" ] || [ "${MIN_ELAPSED_TIME}" -eq 0 ] || [ "${LAST_START_TIME}" -eq 0 ]; then
							COUNT_TIME_EXCEEDED=0
						else
							COUNT_TIME_EXCEEDED=$((${COUNT_TIME_EXCEEDED}+1))
						fi;
						
						if [ "${COUNT_TIME_EXCEEDED}" -le "${MAXCOUNT_TIME_EXCEEDED}" ]; then
							TRYING_START_SINCE="$(date +%s)"
							
							if [ "${RESTART_DELAY}" -gt 0 ] && [ "${LAST_START_TIME}" -gt 0 ]; then
								echo -e "${COLOR_WHITE}${COLOR_BOLD}Trying to re-/start the ${APPLICATION_NAME} in ${RESTART_DELAY} seconds!${COLOR_RESET}"
							fi;
						else
							echo -e "${COLOR_RED}${COLOR_BOLD}The ${APPLICATION_NAME} will not re-/start!${COLOR_RESET}"
							WHILE_ENABLED=false
						fi;
					else
						if ( [ "$(($(date +%s) - (${TRYING_START_SINCE} + ${RESTART_DELAY})))" -ge 0 ] || [ "${RESTART_DELAY}" -eq 0 ] || [ "${LAST_START_TIME}" -eq 0 ] ) && [ "${TRIED_START_SCREEN}" == false ]; then
							echo -en "${COLOR_WHITE}${COLOR_BOLD}Trying to re-/start the ${APPLICATION_NAME}"
							TRIED_START_SCREEN=true
							screen_start "${SCREEN_NAME}" "${EXECUTION_FILE}"
						elif [ "${TRIED_START_SCREEN}" == true ]; then
							if [ "$(($(date +%s) - ${TRYING_START_SINCE}))" -gt 10 ]; then
								echo -e "${COLOR_RESET}"
								echo -e "${COLOR_RED}${COLOR_BOLD}Couldn't re-/start the ${APPLICATION_NAME}!${COLOR_RESET}"
								echo -e "${COLOR_RED}${COLOR_BOLD}Stopping the Keeper!${COLOR_RESET}"
								TRYING_START_SINCE=0
								WHILE_ENABLED=false
							else
								echo -en "."
							fi;
						fi;
					fi;
				else
					if [ "${TRYING_START_SINCE}" -gt 0 ]; then
						echo -e "${COLOR_RESET}"
						echo -e "${COLOR_GREEN}${COLOR_BOLD}The ${APPLICATION_NAME} re-/started successfully!${COLOR_RESET}"
						LAST_START_TIME="$(date +%s)"
						TRYING_START_SINCE=0
						TRIED_START_SCREEN=false
					elif [ "${LAST_START_TIME}" -eq 0 ]; then
						echo -e "${COLOR_RED}${COLOR_BOLD}It was determined that the ${APPLICATION_NAME} is already running!${COLOR_RESET}"
						LAST_START_TIME=$(($(date +%s) - ${MIN_ELAPSED_TIME}))
					fi;
				fi;
				sleep 1
			done;
			
			unset -v COUNT_TIME_EXCEEDED LAST_START_TIME TRYING_START_SINCE TRIED_START_SCREEN
		else
			echo -e "\e[93mUsage: ${0} {start|stop|restart|status|console|help}"
		fi;
		
		unset -v CMDLINE
	;;
esac

unset -v APPLICATION_NAME SCREEN_NAME EXECUTION_FILE EXECUTING_USER SCREEN_KEEPER MIN_ELAPSED_TIME RESTART_DELAY

exit ${EXIT_CODE}

: '
	**************************************
	***  Copyright (C) � 2016 Mike R.  ***
	***      All rights reserved.      ***
	***     Selling is prohibited!     ***
	**************************************
	
	This Script was tested on Debian 8 (Jessie) and Ubuntu 16.10 (Yakkety Yak)
	
	Example-Filename:	control.sh
	Example-Execution:	./control.sh
	
	Commandline-Parameters:
		Execution:		Parameter:			Action:
		----------------------------------------------------------------------
		./control.sh	start				Starts the server.
		./control.sh	stop				Stops the server.
		./control.sh	restart				Restarts the server.
		./control.sh	status				Shows: Is the server running?
		./control.sh	console				Opens the servers console.
		./control.sh	help				Shows the help-page.
		./control.sh	* (wildcard)		Shows you the usage.
'