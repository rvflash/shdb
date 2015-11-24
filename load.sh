#!/bin/bash

@note Do not use, in progress

##
# Provide interface to load SQL data and/or structure to (re)build a database
# Get SQL files in a directory with the following convention:
# > /DATABASE_NAME/TABLE_NAME/table.sql for table schema
# > /DATABASE_NAME/TABLE_NAME/datas.sql for datas of this table
# Can load all tables of database or specific ones in entry

# Default values
SCRIPT=`basename ${BASH_SOURCE[0]}`
CURDATE=`date +%Y%m%d%H%M%S`
ERR_FILE="/tmp/$CURDATE¨shbd_load.err"
DB_HOST="localhost"
DB_USERNAME="root"
DB_PASSWORD="root"
DB_NAMES=""
TABLE_NAMES=""
VERBOSE=""
DRY_RUN=0;
WITH_SCHEMA=0
WITH_DATA=0
FORCE_REBUILD=0

function usage () {
    echo "Usage: ${SCRIPT} -b sourcedirectory [-d databases] [-t tablenames] [-h hostname] [-u username] [-p password] [-l logfilepath] [-v] [-r] [-B] [-D]"
    echo "-b for root repository with SQL files"
    echo "-d for database name, separated by a space"
    echo "-t for table name(s), separated by a space"
    echo "-h for database hostname"
    echo "-u for database username"
    echo "-p for database password"
    echo "-l to change default log file path"
    echo "-v used to print SQL Query"
    echo "-r for lauch a dry-run, see result wihout apply it"
    echo "-D for export data"
    echo "-B to force re-build (drop table, etc.)"

    if [ "$1" != "" ] && [ "" = "MYSQL" ]; then
        echo "> $1 in command line is required"
    elif [ "$1" != "" ]; then
        echo "> Mandatory field: $1"
    fi
}

# Script usage & check if mysqldump is availabled
if [ $# -lt 1 ] ; then
    usage
    exit 1
elif ! MYSQL_PATH="$(type -p mysql)" || [ -z "$MYSQL_PATH" ]; then
    usage MYSQL
    exit 1
fi

# Read the options
# Use getopts vs getopt for MacOs portability
while getopts "b::d::h::u::p::t:l:Drv" FLAG; do
    case "${FLAG}" in
        b) BACKUP_ROOT="$OPTARG" ;;
        d) DB_NAMES="$OPTARG" ;;
        t) TABLE_NAMES="$OPTARG" ;;
        h) if [ "$OPTARG" != "" ]; then DB_HOST="$OPTARG"; fi ;;
        u) if [ "$OPTARG" != "" ]; then DB_USERNAME="$OPTARG"; fi ;;
        p) if [ "$OPTARG" != "" ]; then DB_PASSWORD="$OPTARG"; fi ;;
        l) if [ "$OPTARG" != "" ]; then ERR_FILE="$OPTARG"; fi ;;
        v) VERBOSE="-v" ;;
        r) DRY_RUN=1 ;;
        D) WITH_DATA=1 ;;
        D) FORCE_REBUILD=1 ;;
        *) usage; exit 1 ;;
        ?) exit 2 ;;
    esac
done
shift $(( OPTIND - 1 ));

# Mandatory options
if [ -z "BACKUP_ROOT" ]; then
    usage BACKUP_ROOT
    exit 2
else
    OPTIONS="$OPTIONS --log-error=$ERR_FILE"
    if [ "$VERBOSE" != "" ]; then
        OPTIONS="$OPTIONS $VERBOSE"
    fi
fi

function exitOnError ()
{
    if [ "$1" != "0" ]; then
        echo "$2" >> "$ERR_FILE"
        exit 1;
    fi
}

for DB_NAME in "$DB_NAMES"; do

    if [ "${BACKUP_ROOT: -1}" = "/" ]; then
        BACKUP_ROOT="${BACKUP_ROOT:0:-1}"
    fi
    BACKUP_FILE="/tmp/$DB_NAME.sql"

    for SQL_FILE in `find "$BACKUP_ROOT/$DB_NAME/" -name "*.sql"`; do
        # Remove SQL comments and empty lines
        cat ${SQL_FILE} | sed -e 's/--.*$//' -e 's/\/.*$//' -e '/^$/d' >> ${BACKUP_FILE}
    done

    # Re-build database / tables ?
    if [ ${FORCE_REBUILD} = 0 ]; then
        sed -i 's/CREATE TABLE/CREATE TABLE IF NOT EXISTS/g' ${BACKUP_FILE}
        sed -i -e 's/DROP TABLE.*$//' ${BACKUP_FILE}
    fi

    if [ ${DRY_RUN} = 1 ]; then
        cat ${BACKUP_FILE}
    else
        echo "Incoming..."
        mysql ${OPTIONS} -h "$DB_HOST" -u "$DB_USERNAME" -p"$DB_PASSWORD" ${DB_NAME} < ${BACKUP_FILE} 2>> ${ERR_FILE}
    fi
done