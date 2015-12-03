#!/usr/bin/env bash

##
# Provide interface to load SQL data and/or structure to (re)build a database
# Get SQL files in a directory with the following convention:
# > /DATABASE_NAME/TABLE_NAME/table.sql for table schema
# > /DATABASE_NAME/TABLE_NAME/datas.sql for datas of this table
# Can load all tables of database or specific ones in entry

source inc.common.sh

# Environment
getDirectoryPath "${BASH_SOURCE[0]}"
SCRIPT_ROOT="$DIRECTORY_PATH"
SCRIPT=`basename ${BASH_SOURCE[0]}`
ERR_FILE="${TMP_DIR}${RANDOM}_load.err"

# Default values
TABLE_NAMES=""
OPTIONS=""
VERBOSE=""
DRY_RUN=0;
WITH_SCHEMA=0
WITH_DATA=0
FORCE_REBUILD=0

function usage ()
{
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
    echo "-B to force re-build (drop table, etc.)"
    echo "-D for export data"

    if [ "$1" != "" ] && [ "" = "MYSQL" ]; then
        echo "> $1 in command line is required"
    elif [ "$1" != "" ]; then
        echo "> Mandatory field: $1"
    fi
}

# Script usage & check if mysqldump is availabled
if [ $# -lt 2 ] ; then
    usage
    exit 1
elif ! MYSQL_PATH="$(type -p mysql)" || [ -z "$MYSQL_PATH" ]; then
    usage MYSQL
    exit 1
fi

# Read the options
# Use getopts vs getopt for MacOs portability
while getopts "b:d::t::h::u::p:l:vrBD" FLAG; do
    case "${FLAG}" in
        b) if [ "${OPTARG:0:1}" = "/" ]; then BACKUP_ROOT="$OPTARG"; else BACKUP_ROOT="$SCRIPT_ROOT$OPTARG"; fi ;;
        d) DB_NAMES="$OPTARG" ;;
        t) TABLE_NAMES="$OPTARG" ;;
        h) if [ "$OPTARG" != "" ]; then DB_HOST="$OPTARG"; fi ;;
        u) if [ "$OPTARG" != "" ]; then DB_USERNAME="$OPTARG"; fi ;;
        p) if [ "$OPTARG" != "" ]; then DB_PASSWORD="$OPTARG"; fi ;;
        l) if [ "$OPTARG" != "" ]; then ERR_FILE="$OPTARG"; fi ;;
        v) VERBOSE="-v" ;;
        r) DRY_RUN=1 ;;
        B) FORCE_REBUILD=1 ;;
        D) WITH_DATA=1 ;;
        *) usage; exit 1 ;;
        ?) exit 2 ;;
    esac
done
shift $(( OPTIND - 1 ));

# Mandatory options
if [ -z "$BACKUP_ROOT" ]; then
    usage BACKUP_ROOT
    exit 2
elif [ -z "$DB_NAMES" ]; then
    usage DB_NAMES
    exit 1
else
    if [ "$VERBOSE" != "" ]; then
        OPTIONS="$OPTIONS $VERBOSE"
    fi
fi

for DB_NAME in ${DB_NAMES}; do

    for TABLE_NAME in "${TABLE_NAMES[@]}"; do

        # Define workspace
        if [ "${BACKUP_ROOT: -1}" = "/" ]; then
            BACKUP_ROOT="${BACKUP_ROOT:0:-1}"
        fi
        BACKUP_FILE="${TMP_DIR}${DB_NAME}.sql"

        SQL_SEARCH_PATH="${BACKUP_ROOT}/${DB_NAME}"
        if [ "$TABLE_NAME" != "" ]; then
            SQL_SEARCH_PATH="${SQL_SEARCH_PATH}/$TABLE_NAME/"
        fi
        if [ "$WITH_DATA" -eq 0 ]; then
            SQL_SEARCH_FILE="table.sql"
        else
            SQL_SEARCH_FILE="*.sql"
        fi

        # Clean workspace
        rm -f "$BACKUP_FILE"

        # Force table creation before inserting datas
        SQL_FILES=$(find "${SQL_SEARCH_PATH}" -name "${SQL_SEARCH_FILE}" -type f 2>> "$ERR_FILE")
        exitOnError $? "Unable to find: $SQL_SEARCH_PATH" "$VERBOSE" "$ERR_FILE"

        for SQL_FILE in ${SQL_FILES}; do
            if [ "$SQL_FILE" != *"/$SQL_TABLE_FILENAME" ]; then
                cat "$SQL_FILE" >> "$BACKUP_FILE"
            elif [ -f  "$BACKUP_FILE" ]; then
                cat "$SQL_FILE" | cat "$BACKUP_FILE" > "$BACKUP_FILE"
            else
                cat "$SQL_FILE" > "$BACKUP_FILE"
            fi
        done

        # Remove SQL comments and empty lines
        sed -i -e "s/--.*$//" -e "s/\/.*$//" -e "/^$/d" "$BACKUP_FILE"

        # Re-build database / tables ?
        if [ "$FORCE_REBUILD" -eq 0 ]; then
            sed -i "s/INSERT INTO/INSERT IGNORE INTO/g" "$BACKUP_FILE"
            sed -i "s/CREATE TABLE/CREATE TABLE IF NOT EXISTS/g" "$BACKUP_FILE"
            sed -i -e "s/DROP TABLE.*$//" "$BACKUP_FILE"
        fi

        # Load file in mysql database or if dry run, display dump
        if [ "$DRY_RUN" -eq 1 ]; then
            echo "-- --------------------------------------------------------------- $DB_NAME"
            cat "$BACKUP_FILE"
        else
            mysql ${OPTIONS} -h "$DB_HOST" -u "$DB_USERNAME" -p"$DB_PASSWORD" ${DB_NAME} < "$BACKUP_FILE" 2>> "$ERR_FILE"
            exitOnError $? "Unable to load in mysql database the file named: $BACKUP_FILE" "$VERBOSE" "$ERR_FILE"
            if [ "$VERBOSE" != "" ]; then
                echo "SQL file $BACKUP_FILE loaded with success in $DB_NAME"
            fi
        fi

    done

done