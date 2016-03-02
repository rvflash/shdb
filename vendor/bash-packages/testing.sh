#!/usr/bin/env bash

##
# bash-packages
#
# Part of bash-packages project.
#
# @package testing
# @copyright 2016 Hervé Gouchet
# @license http://www.apache.org/licenses/LICENSE-2.0
# @source https://github.com/rvflash/bash-packages

# Constant
declare -r BP_TESTING_PACKAGE_NAME="Package"
declare -r BP_TESTING_UNIT_FILE_SUFFIX="Test.sh"

# ASCII Color
declare -r BP_TESTING_COLOR_OFF='\033[0m'
declare -r BP_TESTING_COLOR_RED='\033[0;31m'
declare -r BP_TESTING_COLOR_RED_BG='\033[101m'
declare -r BP_TESTING_COLOR_GREEN='\033[0;32m'
declare -r BP_TESTING_COLOR_GREEN_BG='\033[42m'
declare -r BP_TESTING_COLOR_YELLOW='\033[0;33m'
declare -r BP_TESTING_COLOR_BLUE='\033[0;34m'
declare -r BP_TESTING_COLOR_GRAY='\033[0;90m'


##
# Basic function to test A with B and validate the behavior of a method
# @codeCoverageIgnore
# @param string $1 Method's name
# @param string $2 Expected string
# @param string $3 Received string to compare with expected string
# @exit 1 If one of the three parameters are empty
function bashUnit ()
{
    local method="$1"
    local expected="$2"
    local received="$3"

    if [[ -z "$method" || -z "$expected" || -z "$received" ]]; then
        echo -i "${BP_TESTING_COLOR_RED}Missing values for BashUnit testing tool${BP_TESTING_COLOR_OFF}"
        exit 1
    fi

    echo -ne "${BP_TESTING_COLOR_GRAY}Function${BP_TESTING_COLOR_OFF} ${method}: "

    if [[ "$received" == "$expected" ]]; then
        echo -ne "${BP_TESTING_COLOR_GREEN}OK${BP_TESTING_COLOR_OFF}\n"
    else
        echo -ne "${BP_TESTING_COLOR_YELLOW}KO${BP_TESTING_COLOR_OFF}\n"
        echo -ne "    > ${BP_TESTING_COLOR_GREEN}Expected:${BP_TESTING_COLOR_OFF} ${BP_TESTING_COLOR_GREEN_BG}${expected}${BP_TESTING_COLOR_OFF}\n"
        echo -ne "    > ${BP_TESTING_COLOR_RED}Received:${BP_TESTING_COLOR_OFF} ${BP_TESTING_COLOR_RED_BG}${received}${BP_TESTING_COLOR_OFF}\n"
    fi
}

##
# Launch all bash file with suffix Test.sh in directory passed as first parameter
# @codeCoverageIgnore
# @param string TestsDir
# @return string
function launchAllTests ()
{
    local dir="$1"
    if [[ -z "$dir" || ! -d "$dir" ]]; then
        return 1
    fi

    local fileName bashFile
    declare -a bashFiles="($(find "${dir}" -iname "*${BP_TESTING_UNIT_FILE_SUFFIX}" -type f 2>> /dev/null))"

    # Integrety check
    echo -ne "Expecting ${#bashFiles[@]} tests\n"

    declare -i count
    for bashFile in "${bashFiles[@]}"; do
        count+=1
        fileName="$(basename "${bashFile}" "${BP_TESTING_UNIT_FILE_SUFFIX}")"
        echo -e "\n#${count} ${BP_TESTING_PACKAGE_NAME} ${BP_TESTING_COLOR_BLUE}${fileName/_/\/}${BP_TESTING_COLOR_OFF}"
        echo -e "$(${bashFile})"
    done
}