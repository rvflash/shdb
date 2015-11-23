#!/bin/bash

##
# Provide interface to dump SQL data and/or structure
# Store table struture in file named table.sql in path DATABASE_NAME/TABLE_NAME/table.sql
# Store datas table in file named datas.sql by default, in path DATABASE_NAME/TABLE_NAME/table.sql

# Default values
SCRIPT=`basename ${BASH_SOURCE[0]}`
CURDATE=`date +%Y%m%d%H%M%S`
ERR_FILE="/tmp/${CURDATE}_shbd_dump.err"
DB_HOST="localhost"
DB_USERNAME="root"
DB_PASSWORD="root"
TABLE_NAMES=""
OPTIONS="--opt --no-create-db --comments --dump-date --skip-triggers"
VERBOSE=""
WITH_DATA=0
WITH_TMP_TABLE=0
BACKUP_ROOT="/tmp/"
BACKUP_FILE=""
BACKUP_DATA_FILE="datas"

function usage () {
    echo "Usage: ${SCRIPT} -d databases [-t tablenames] [-h hostname] [-u username] [-p password] [-b backupdirectory] [-f sqlfilename] [-l logfilepath] [-v] [-D] [-T]"
    echo "-h for database hostname"
    echo "-u for database username"
    echo "-p for database password"
    echo "-d for database name, separated by a space"
    echo "-t for table name(s), separated by a space"
    echo "-b for backup folder path"
    echo "-f to name sql data file, named default if not set"
    echo "-l to change default log file path"
    echo "-D for export data with schema"
    echo "-T for keep TMP tables, by convention named with _ as fist letter or with _TMP on the name"
    echo "-v used to print SQL Query"

    if [ "$1" != "" ] && [ "$1" = "MYSQLDUMP" ]; then
        echo "> $1 in command line is required"
    elif [ "$1" != "" ]; then
        echo "> Mandatory field: $1"
    fi
}

# Script usage & check if mysqldump is availabled
if [ $# -lt 3 ] ; then
    usage
    exit 1
elif ! MYSQLDUMP_PATH="$(type -p mysqldump)" || [ -z "$MYSQLDUMP_PATH" ]; then
    usage MYSQLDUMP
    exit 2
fi

# Read the options
# Use getopts vs getopt for MacOs portability
while getopts ":h::u::p:d::t::b:l:f:DTv" FLAG; do
    case "${FLAG}" in
        h) if [ "$OPTARG" != "" ]; then DB_HOST="$OPTARG"; fi ;;
        u) if [ "$OPTARG" != "" ]; then DB_USERNAME="$OPTARG"; fi ;;
        p) if [ "$OPTARG" != "" ]; then DB_PASSWORD="$OPTARG"; fi ;;
        d) DB_NAMES="$OPTARG" ;;
        t) TABLE_NAMES="$OPTARG" ;;
        b) if [ "$OPTARG" != "" ]; then BACKUP_ROOT="$OPTARG"; fi ;;
        f) if [ "$OPTARG" != "" ]; then BACKUP_DATA_FILE="$OPTARG"; fi ;;
        l) if [ "$OPTARG" != "" ]; then ERR_FILE="$OPTARG"; fi ;;
        v) VERBOSE="-v" ;;
        D) WITH_DATA=1 ;;
        T) WITH_TMP_TABLE=1 ;;
        *) usage; exit 1 ;;
        ?) exit 2 ;;
    esac
done
shift $(( OPTIND - 1 ));

# Mandatory options
if [ -z "$DB_NAMES" ]; then
   usage DB_NAMES
   exit 1
else
    OPTIONS="$OPTIONS --log-error=$ERR_FILE"
    if [ "$VERBOSE" != "" ]; then
        OPTIONS="$OPTIONS --verbose"
    fi
fi

function exitOnError ()
{
    if [ "$1" != "0" ]; then
        echo "$2" >> "$ERR_FILE"
        if [ "$VERBOSE" != "" ]; then
            cat "$ERR_FILE" | while  read ERR_LINE; do
                echo "$ERR_LINE"
            done
        fi
        exit 1;
    fi
}

for DB_NAME in "$DB_NAMES"; do

    # If no table in entry, we retrieve all availables for the database
    if [ -z "$TABLE_NAMES" ]; then
        QUERY="SHOW TABLES FROM $DB_NAME;"
        TABLE_NAMES=`./query.sh ${VERBOSE} -h "$DB_HOST" -u "$DB_USERNAME" -p "$DB_PASSWORD" -d "$DB_NAME" -q "$QUERY"`
        exitOnError $? "Unable to retrieve list of tables for $DB_NAME"
        if [ "$VERBOSE" != "" ]; then
            echo "$TABLE_NAMES" | sed -n '/--------------/,/--------------/p' | sed 's/-*//' | sed '/^$/d'
            TABLE_NAMES=$(echo "$TABLE_NAMES" | sed '/--------------/,+1 d')
        fi
    fi

    for TABLE_NAME in ${TABLE_NAMES}; do
        # Skip TMP tables. With MySQL only as entry point, we could have done:
        # > SHOW TABLES FROM {DATABASE} WHERE Tables_in_{DATABASE} LIKE "%_TMP" OR Tables_in_{DATABASE} LIKE "\_%";
        if [ "$WITH_TMP_TABLE" = 0 ] && ([[ "$TABLE_NAME" == "_"* ]] || [[ "$TABLE_NAME" == *"_TMP"* ]]); then
            if [ "$VERBOSE" != "" ]; then
                echo "Skip TMP table named: $TABLE_NAME"
            fi
            continue
        fi

        # One folder by table name (remove redundant slash)
        if [ "${BACKUP_ROOT: -1}" = "/" ]; then
            BACKUP_ROOT="${BACKUP_ROOT:0:-1}"
        fi
        BACKUP_FILE="$BACKUP_ROOT/$DB_NAME/$TABLE_NAME"
        mkdir -p "$BACKUP_FILE"
        exitOnError $? "Unable to create path $BACKUP_FILE"

        # Dump table structure
        TABLE_BACKUP_FILE="$BACKUP_FILE/table.sql"
        mysqldump --no-data ${OPTIONS} -h "$DB_HOST" -u "$DB_USERNAME" -p"$DB_PASSWORD" "$DB_NAME" "$TABLE_NAME" > ${TABLE_BACKUP_FILE} 2>> ${ERR_FILE}
        exitOnError $? "Unable to dump table structure for $DB_NAME.$TABLE_NAME"
        if [ "$VERBOSE" != "" ]; then
            echo "SQL dump file for table structure for $DB_NAME.$TABLE_NAME: $TABLE_BACKUP_FILE"
        fi

        # Dump data only
        if [ "$WITH_DATA" = 1 ]; then
            DATA_BACKUP_FILE="$BACKUP_FILE/$BACKUP_DATA_FILE.sql"
            mysqldump --no-create-info ${OPTIONS} -h "$DB_HOST" -u "$DB_USERNAME" -p"$DB_PASSWORD" "$DB_NAME" "$TABLE_NAME" > ${DATA_BACKUP_FILE} 2>> ${ERR_FILE}
            exitOnError $? "Unable to dump datas of table $DB_NAME.$TABLE_NAME"
            if [ "$VERBOSE" != "" ]; then
                echo "SQL dump file for datas of table $DB_NAME.$TABLE_NAME: $DATA_BACKUP_FILE"
            fi
        fi
    done;

done;