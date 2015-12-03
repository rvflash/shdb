#!/usr/bin/env bash

##
# Provide interface to run SQL queries

source inc.common.sh

# Environment
SCRIPT=`basename ${BASH_SOURCE[0]}`
ERR_FILE="${TMP_DIR}${RANDOM}_query.err"

# Default values
OPTIONS="--unbuffered --quick --show-warnings --skip-column-names --batch --silent --wait"

function usage ()
{
    echo "Usage: ${SCRIPT} -d database -q query [-h hostname] [-u username] [-p password] [-l logfilepath] [-v]"
    echo "-d for database name"
    echo "-q for SQL query"
    echo "-h for database hostname"
    echo "-u for database username"
    echo "-p for database password"
    echo "-l to change default log file path"
    echo "-v used to print SQL Query"

     if [ "$1" != "" ] && [ "$1" = "MYSQL" ]; then
        echo "> MYSQL in command line is required"
     elif [ "$1" != "" ]; then
        echo "> Mandatory field: $1"
     fi
}

# Script usage & check if mysql is availabled
if [ $# -lt 3 ]; then
    usage
    exit 1
elif ! MYSQL_PATH="$(type -p mysql)" || [ -z "$MYSQL_PATH" ]; then
    usage MYSQL
    exit 2
fi

# Read the options
# Use getopts vs getopt for MacOs portability
while getopts "d:q::h::u::p:l:v" FLAG; do
    case "${FLAG}" in
        d) DB_NAME="$OPTARG" ;;
        q) QUERY="$OPTARG" ;;
        h) if [ "$OPTARG" != "" ]; then DB_HOST="$OPTARG"; fi ;;
        u) if [ "$OPTARG" != "" ]; then DB_USERNAME="$OPTARG"; fi ;;
        p) if [ "$OPTARG" != "" ]; then DB_PASSWORD="$OPTARG"; fi ;;
        l) if [ "$OPTARG" != "" ]; then ERR_FILE="$OPTARG"; fi ;;
        v) OPTIONS="$OPTIONS --verbose" ;;
        *) usage; exit 1 ;;
        ?) exit 2 ;;
    esac
done
shift $(( OPTIND - 1 ));

# Mandatory options
if [ -z "$DB_HOST" ]; then
    usage DB_HOST
    exit 1
elif [ -z "$DB_NAME" ]; then
    usage DB_NAME
    exit 1
elif [ -z "$QUERY" ]; then
    usage QUERY
    exit 1
else
    QUERY_METHOD=$(echo "$QUERY" | awk '{ print tolower($1) }')
    if [ "$QUERY_METHOD" != "show" ]; then
        OPTIONS="$OPTIONS --raw"
    fi
fi

SQL=$(mysql ${OPTIONS} -h "$DB_HOST" -u "$DB_USERNAME" -p"$DB_PASSWORD" ${DB_NAME} -e "$QUERY" 2>> ${ERR_FILE})
if [ $? -ne 0 ]; then
    if [[ "$OPTIONS" == *"verbose"* ]]; then
        if [ -f ${ERR_FILE} ]; then
            echo "$QUERY" | cat ${ERR_FILE} > ${ERR_FILE}
        else
            echo "$QUERY" > ${ERR_FILE}
        fi
        cat "$ERR_FILE" | while  read ERR_LINE; do
            echo "$ERR_LINE"
        done
    fi
    exit $?
elif [ "$QUERY_METHOD" = "select" ] || [ "$QUERY_METHOD" = "show" ]; then
    echo "$SQL"
fi