#!/bin/bash

# Default values
DB_HOST="localhost"
DB_USERNAME="root"
DB_PASSWORD="root"

# Constants
declare -r TMP_DIR='/tmp/'
declare -r CURDATE=`date +%Y%m%d%H%M%S`
declare -r SQL_TABLE_FILENAME='table.sql'
declare -r SQL_DATAS_FILENAME='datas.sql'

##
# Resolve $1 or current path until the file is no longer a symlink
# @param string $1 path
# @return string DIRECTORY_PATH
function getDirectoryPath ()
{
    local SOURCE="$1"
    while [ -h "$SOURCE" ]; do
      local DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
      SOURCE="$(readlink "$SOURCE")"
      # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
      [[ ${SOURCE} != /* ]] && SOURCE="$DIR/$SOURCE"
    done
    DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

    if [ "$DIR" = "" ]; then
        exit 1;
    fi
    DIRECTORY_PATH="$DIR/"
}

##
# Exit in error case, if $1 is not equals to 0
# @param string $1 return code of previous step
# @param string $2 message to log
# @param string $3 filepath for logs
# @param string $4 verbose mode
function exitOnError ()
{
    local ERR_CODE="$1"
    local ERR_MSG="$2"
    local ERR_FILE="$3"
    local ERR_LOG="$4"

    if [ "$ERR_CODE" != "0" ]; then
        if [ "$ERR_MSG" != "" ] && [ "$ERR_FILE" != "" ]; then
            echo "$ERR_MSG" >> ${ERR_FILE}
        fi
        if [ "$ERR_LOG" != "" ]; then
            if [ -z "$ERR_FILE" ]; then
                echo "$ERR_MSG"
            else
                cat ${ERR_FILE} | while  read ERR_LINE; do
                    echo "$ERR_LINE"
                done
            fi
        fi
        exit 1;
    fi
}