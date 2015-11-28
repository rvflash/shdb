#!/usr/bin/env bash

##
# Provide interface to show create table of one or various tables
# Usefull if mysqldump is not available

source inc.common.sh

# Environment
SCRIPT=`basename ${BASH_SOURCE[0]}`

function usage ()
{
    echo "Usage: ${SCRIPT} -d database -t tablenames [-h hostname] [-u username] [-p password] [-v]"
    echo "-h for database hostname"
    echo "-d for database name"
    echo "-t for table name(s), separated by a space"
    echo "-u for database username"
    echo "-p for database password"
    echo "-v used to print SQL Query"

     if [ "$1" != "" ]; then
        echo "> Mandatory field: $1"
     fi
}

# Script usage
if [ $# -lt 3 ] ; then
    usage
    exit 1
fi

# Read the options
# Use getopts vs getopt for MacOs portability
while getopts ":h::u::p:d:t:v" FLAG; do
    case "${FLAG}" in
        h) DB_HOST="$OPTARG" ;;
        u) DB_USERNAME="$OPTARG" ;;
        p) DB_PASSWORD="$OPTARG" ;;
        d) DB_NAME="$OPTARG" ;;
        t) TABLE_NAMES="$OPTARG" ;;
        v) VERBOSE="-v" ;;
        *) usage; exit 1 ;;
        ?) exit 2 ;;
    esac
done
shift $(( OPTIND - 1 ));

# Mandatory options
if [ -z "$TABLE_NAMES" ]; then
    usage TABLE_NAMES
    exit 2
fi

for TABLE_NAME in ${TABLE_NAMES}; do

    QUERY="SHOW CREATE TABLE $TABLE_NAME;"
    SCHEMA=$( ./query.sh -h "$DB_HOST" -u "$DB_USERNAME" -p "$DB_PASSWORD" -d "$DB_NAME" -q "$QUERY" "$VERBOSE")
    if [ $? -ne 0 ]; then
        exit $?
    fi

    # Remove redundant table name on the beginning
    SCHEMA=`echo "${SCHEMA}" | sed -e 's/.*CREATE TABLE/CREATE TABLE/'`
    if [ -z "$SCHEMA" ]; then
        continue
    fi
    if [ -z "$SQL" ]; then
        SQL="$SCHEMA;"
    else
        SQL="$SQL\n\n$SCHEMA;"
    fi
done

echo -e "$SQL"