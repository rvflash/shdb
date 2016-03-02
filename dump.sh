#!/usr/bin/env bash

##
# shdb
#
# Provide interface to dump SQL data and/or structure
# Store table structure in file named `table.sql` in path DATABASE_NAME/tableName/table.sql
# Store datas table in file named `datas.sql` by default, in path DATABASE_NAME/tableName/table.sql
#
# @copyright 2016 Hervé Gouchet
# @license http://www.apache.org/licenses/LICENSE-2.0
# @source https://github.com/rvflash/shdb

# Environment
scriptPath="$0"; while [[ -h "$scriptPath" ]]; do scriptPath="$(readlink "$scriptPath")"; done
scriptRoot=$(dirname "$scriptPath")

source "${scriptRoot}/conf/shdb.sh"
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
dumpDir="${SHDB_TMP_DIR}"
dumpDataFileName="${SHDB_SQL_DATA_FILENAME}"
whereCondition=""
declare -i withData=0
declare -i withTmpTable=0

##
# Help
# @return string
function usage ()
{
    local errorName="$1"

    echo "usage: ./dump.sh -d databases [-t tables] [-h host] [-u user] [-p password] [-b backupDirectory] [-f sqlFileName] [-w whereCondition] [-v] [-D] [-T]"
    echo "-d for database name(s), separated by a space"
    echo "-t for table name(s), separated by a space"
    echo "-h for database hostname, default '${SHDB_DB_HOST}'"
    echo "-u for database username, default '${SHDB_DB_USERNAME}'"
    echo "-p for database password, default '${SHDB_DB_PASSWORD}'"
    echo "-b for backup folder path"
    echo "-f to name sql data file, default '${SHDB_SQL_DATA_FILENAME}'"
    echo "-w for limit rows selected by the given WHERE condition"
    echo "-v used to print SQL Query"
    echo "-D for export data with schema"
    echo "-T for keep TMP tables, by convention named with '_' as first letter or with '_TMP' on the name"
    echo

    if [[ "$errorName" == "MYSQLDUMP" ]]; then
        pErrorF "> %s in command line is required" "$errorName"
    elif [[ -n "$errorName" ]]; then
        pErrorF "> Mandatory field: %s" "$errorName"
    fi
}

# Script usage & check if mysqldump command is availabled
if [[ $# -lt 1 ]]; then
    usage
    exit 1
elif [[ -z "$(type -p mysqldump)" ]]; then
    usage MYSQLDUMP
    exit 2
fi

# Read the options
# Use getopts vs getopt for MacOs portability
while getopts ":h::u::p:d::t::b:l:f:w:DTv" FLAG; do
    case "${FLAG}" in
        d) dbNames="$(trim "$OPTARG")" ;;
        t) tableNames="$(trim "$OPTARG")" ;;
        h) if [[ -n "$OPTARG" ]]; then dbHost="$OPTARG"; fi ;;
        u) if [[ -n "$OPTARG" ]]; then dbUser="$OPTARG"; fi ;;
        p) if [[ -n "$OPTARG" ]]; then dbPassword="$OPTARG"; fi ;;
        b)
           dumpDir="$(trim "$OPTARG")"
           if [[ -n "$dumpDir" && "${dumpDir:0:1}" != "/" ]]; then
               dumpDir="${scriptRoot}/${dumpDir}"
           fi
           ;;
        f) if [[ -n "$OPTARG" ]]; then dumpDataFileName="$OPTARG"; fi ;;
        w) whereCondition="$OPTARG" ;;
        v) logMute 0 ;;
        D) withData=1 ;;
        T) withTmpTable=1 ;;
        *) usage; exit 1 ;;
        ?) exit 2 ;;
    esac
done
shift $(( OPTIND - 1 ));

# Mandatory options
if [[ -z "$dbNames" ]]; then
    usage DB_NAME
    exit 1
fi

for dbName in ${dbNames}; do

    # Connection check
    dbLink=$(mysqlConnect "$dbHost" "$dbUser" "$dbPassword" "$dbName")
    if [[ $? -ne 0 ]]; then
        pFatal "ConnectionError.DATABASE"
    fi

    # If no table in entry, we retrieve all available tables for the database
    if [[ -z "$tableNames" ]]; then
        result=$(mysqlFetchRaw "$dbLink" "SHOW TABLES FROM ${dbName};")
        if [[ $? -ne 0 ]]; then
            pFatal "QueryError.SHOW_TABLES"
        fi
        declare -a dbTableNames="(${result})"
    else
        declare -a dbTableNames="(${tableNames})"
    fi

    # Start process bar
    if logIsMuted; then
        progressBar "$dbName" "0" "${#dbTableNames[@]}"
    fi

    declare -i k
    for k in "${!dbTableNames[@]}"; do
        # Table to process
        tableName="${dbTableNames[$k]}"

        # Skip TMP tables
        if [[ ${withTmpTable} -eq 0 ]] && [[ "$tableName" == "_"* || "$tableName" == *"_TMP"* ]]; then
            pInfoF "DumpSkipTable.%s" "$tableName"
            continue
        fi

        # One folder by table name (remove redundant slash) and create workspace
        if [[ "${dumpDir: -1}" == "/" ]]; then
            dumpDir="${dumpDir:0:-1}"
        fi
        dumpDbDir="${dumpDir}/${dbName}/${tableName}"
        mkdir -p "$dumpDbDir"

        # Dump table structure
        dumpTableFile="${dumpDbDir}/${SHDB_SQL_TABLE_FILENAME}"
        mysqlDump "$dbLink" "$tableName" "${SHDB_DUMP_TABLE_OPTIONS}" > "$dumpTableFile"
        if [[ $? -ne 0 ]]; then
            pFatalF "DumpError.%s\n%s" "$tableName" "$(mysqlLastError "$dbLink")"
        else
            pInfoF "DumpTable.%s (%s)" "$tableName" "$dumpTableFile"
        fi

        # Dump with datas table
        if [[ ${withData} -eq 1 ]]; then
            dumpDataFile="${dumpDbDir}/${dumpDataFileName}"
            dataOptions="${SHDB_DUMP_DATA_OPTIONS}"
            if [[ -n "${whereCondition}" ]]; then
                dataOptions+=" --where="${whereCondition}""
            fi
            mysqlDump "$dbLink" "$tableName" "$dataOptions" > "$dumpDataFile"
            if [[ $? -ne 0 ]]; then
                pFatalF "DumpError.%s\n%s" "$tableName" "$(mysqlLastError "$dbLink")"
            else
                pInfoF "DumpDataTable.%s (%s)" "$tableName" "$dumpDataFile"
            fi
        fi

        # Update progress bar
        if logIsMuted; then
            progressBar "$dbName" "$(($k+1))" "${#dbTableNames[@]}"
        fi
    done;
done;