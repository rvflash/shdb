#!/usr/bin/env bash

##
# shdb
#
# Provide interface to load SQL data and/or structure to (re)build a database
#
# Get SQL files in directory with the following convention:
# > /DATABASE_NAME/TABLE_NAME/table.sql for table schema
# > /DATABASE_NAME/TABLE_NAME/data.sql or other sql files for data of the table
# Can load all tables of database or specific ones in entry
#
# @copyright 2016 Hervé Gouchet
# @license http://www.apache.org/licenses/LICENSE-2.0
# @source https://github.com/rvflash/shdb

# Environment
scriptPath="$0"; while [[ -h "$scriptPath" ]]; do scriptPath="$(readlink "$scriptPath")"; done
scriptRoot=$(dirname "$scriptPath")

source "${scriptRoot}/conf/shdb.sh"
source "${scriptRoot}/vendor/bash-packages/file.sh"
source "${scriptRoot}/vendor/bash-packages/term.sh"
source "${scriptRoot}/vendor/bash-packages/strings.sh"
source "${scriptRoot}/vendor/bash-packages/log/print.sh"
source "${scriptRoot}/vendor/bash-packages/database/mysql.sh"

# Quiet log by default
logMute 1

# Default values for entry points
dbNames=""
tableNames=""
dbHost="${SHDB_DB_HOST}"
dbUser="${SHDB_DB_USERNAME}"
dbPassword="${SHDB_DB_PASSWORD}"
loadDir="${SHDB_TMP_DIR}"
dataFileNames="${SHDB_SQL_TABLE_FILENAME}"
declare -i dryRun=0
declare -i forceRebuild=0


##
# Help
# @return string
function usage ()
{
    local errorName="$1"

    echo "usage: ./load.sh -b rootRepository [-d databases] [-t tables] [-h host] [-u user] [-p password] [-f sqlFileNames] [-v] [-r] [-B]"
    echo "-b for root repository with SQL files"
    echo "-d for database name(s), separated by a space"
    echo "-t for table name(s), separated by a space"
    echo "-h for database hostname, default '${SHDB_DB_HOST}'"
    echo "-u for database username, default '${SHDB_DB_USERNAME}'"
    echo "-p for database password, default '${SHDB_DB_PASSWORD}'"
    echo "-f for sql file name(s) with data to load, separated by a space"
    echo "-r for launch a dry-run, see result without apply it on database"
    echo "-v for verbose mode"
    echo "-B to force re-build (drop table, etc.)"
    echo

    if [[ "$errorName" == "MYSQL" ]]; then
        echo "> ${errorName} in command line is required"
    elif [[ -n "$errorName" ]]; then
        echo "> Mandatory field: ${errorName}"
    fi
}

# Script usage & check if mysqldump is availabled
if [ $# -lt 1 ] ; then
    usage
    exit 1
elif [[ -z "$(type -p mysql)" ]]; then
    usage MYSQL
    exit 2
fi

# Read the options
# Use getopts vs getopt for MacOs portability
while getopts ":b:d::t::h::u::p:f:vrB" FLAG; do
    case "${FLAG}" in
        b)
           loadDir="$(trim "$OPTARG")"
           if [[ "$loadDir" == *"*"* ]]; then
               loadDir=""
           fi
           if [[ -n "$loadDir" && "${loadDir:0:1}" != "/" ]]; then
               loadDir="${scriptRoot}/${loadDir}"
           fi
           if [[ "${loadDir: -1}" == "/" ]]; then
               loadDir="${loadDir:0:-1}"
           fi
           ;;
        d) dbNames="$(trim "$OPTARG")" ;;
        t) tableNames="$(trim "$OPTARG")" ;;
        h) if [[ -n "$OPTARG" ]]; then dbHost="$OPTARG"; fi ;;
        u) if [[ -n "$OPTARG" ]]; then dbUser="$OPTARG"; fi ;;
        p) if [[ -n "$OPTARG" ]]; then dbPassword="$OPTARG"; fi ;;
        f) if [[ -n "$OPTARG" && "$OPTARG" != *"*"* ]]; then dataFileNames+=" $(trim "$OPTARG")"; fi ;;
        r) dryRun=1 ;;
        v) logMute 0 ;;
        B) forceRebuild=1 ;;
        *) usage; exit 1 ;;
        ?) exit 2 ;;
    esac
done
shift $(( OPTIND - 1 ));

# Mandatory options
if [[ -z "$loadDir" || ! -d "$loadDir" ]]; then
    usage ROOT_REPOSITORY
    exit 2
fi

# Get database(s) to manage
declare -a dtf="(${dataFileNames})"
if [[ -z "$dbNames" ]]; then
    dbNames=$(scanDirectory "$loadDir")
fi

# Build sql file to load
declare -a dbs="(${dbNames})"
for dbName in "${dbs[@]}"; do

    # Database to process
    loadBd="Load ${dbName}"
    if logIsMuted; then
        progressBar "$loadBd"
    fi

    # Connection check
    if [[ ${dryRun} -eq 0 ]]; then
        dbLink=$(mysqlConnect "$dbHost" "$dbUser" "$dbPassword" "$dbName")
        if [[ $? -ne 0 ]]; then
            error="ConnectionError.DATABASE"
            if logIsMuted; then
                progressBar "$loadBd" 0 -1 "$error"
            fi
            pFatal "$error"
        fi
    fi
    dbFile="${SHDB_TMP_DIR}/${dbName}_${RANDOM}.sql"
    rm -f "$dbFile"

    # Get table(s) to load
    if [[ -z "$tableNames" ]]; then
        declare -a tbs="($(scanDirectory "${loadDir}/${dbName}"))"
    else
        declare -a tbs="(${tableNames})"
    fi

    # Update progress bar with number of table to proceed
    declare -i max=10
    max+="${#tbs[@]}"
    if logIsMuted; then
        progressBar "$loadBd" 1 ${max}
    fi

    declare -i step
    for step in "${!tbs[@]}"; do
        tbName="${tbs[$step]}"
        for dtFile in "${dtf[@]}"; do
            sqlDir="${loadDir}"
            if [[ "$dbName" != "-" ]]; then
                # Limit by database name
                sqlDir+="/${dbName}"
            fi
            if [[ "$tbName" != "-" ]]; then
                # Limit by table name
                sqlDir+="/${tbName}"
            fi

            # Create one SQL file with files in this directory
            find "${sqlDir}" -name "$dtFile" -type f -print0 2>/dev/null | while read -d '' -r sqlFile; do
                if [[ "$sqlFile" != *"/${SHDB_SQL_TABLE_FILENAME}" ]]; then
                    cat "$sqlFile" >> "$dbFile"
                elif [[ -f "$dbFile" ]]; then
                    cat "$sqlFile" "$dbFile" > "${dbFile}-e" && mv "${dbFile}-e" "${dbFile}"
                else
                    cat "$sqlFile" > "$dbFile"
                fi
            done
        done
        if logIsMuted; then
            progressBar "$loadBd" ${step} ${max}
        fi
    done

    # Load file on database or only launched as dry-run
    if [[ ! -f "$dbFile" ]]; then
        error="LoadError.NO_FILE"
        if logIsMuted; then
            progressBar "$loadBd" ${step} -1 "$error"
        fi
        pWarnF "${error} (%s)" "$dbName"
        continue
    fi

    # Remove SQL comments and empty lines
    sed -e "s/--.*$//" -e "s/\/.*$//" -e "/^$/d" "$dbFile" > "${dbFile}-e" && mv "${dbFile}-e" "${dbFile}"

    # Re-build database / tables ?
    if [[ ${forceRebuild} -eq 0 ]]; then
        sed -e "s/INSERT INTO/INSERT IGNORE INTO/g" \
            -e "s/CREATE TABLE/CREATE TABLE IF NOT EXISTS/g" \
            -e "s/DROP TABLE.*$//" "$dbFile" > "${dbFile}-e" && mv "${dbFile}-e" "${dbFile}"
    fi

    # Load file in mysql database or if dry run, display dump
    if [[ ${dryRun} -eq 1 ]]; then
        if logIsMuted; then
            progressBar "$loadBd" ${max} ${max}
            echo
        fi
        pWarnF "\n-- --------------------------------------------------------------- %s\n" "$dbName"
        cat "$dbFile"
        echo
    else
        mysqlLoad "$dbLink" "$dbFile"
        if [[ $? -ne 0 ]]; then
            error="LoadError.FAIL"
            if logIsMuted; then
                progressBar "$loadBd" ${step} -1 "$error"
            fi
            pFatalF "${error} (%s)\n%s" "$dbFile" "$(mysqlLastError "$dbLink")"
        else
            if logIsMuted; then
                progressBar "$loadBd" ${max} ${max}
            fi
            pInfoF "LoadDatabase.SUCCESS (%s: %s)" "$dbName" "$dbFile"
        fi
    fi
done