#!/usr/bin/env bash

##
# shdb
#
# Provide interface to dump SQL data and/or structure
# Store table structure in file named `table.sql` in path DATABASE_NAME/tableName/table.sql
# Store data table in file named `data.sql` by default, in path DATABASE_NAME/tableName/table.sql
#
# @copyright 2016 Hervé Gouchet
# @license http://www.apache.org/licenses/LICENSE-2.0
# @source https://github.com/rvflash/shdb

# Environment
declare -- scriptPath="$0"; while [[ -h "$scriptPath" ]]; do scriptPath="$(readlink "$scriptPath")"; done
declare -- scriptRoot=$(dirname "$scriptPath")

source "${scriptRoot}/conf/shdb.sh"
source "${scriptRoot}/vendor/bash-packages/term.sh"
source "${scriptRoot}/vendor/bash-packages/strings.sh"
source "${scriptRoot}/vendor/bash-packages/log/print.sh"
source "${scriptRoot}/vendor/bash-packages/database/mysql.sh"

# Quiet log by default
logMute 1

# Default values for entry points
declare -- dbNames=""
declare -- tableNames=""
declare -- dbHost="${SHDB_DB_HOST}"
declare -- dbUser="${SHDB_DB_USERNAME}"
declare -- dbPassword="${SHDB_DB_PASSWORD}"
declare -- dumpDir="${SHDB_TMP_DIR}"
declare -- dumpDataFileName="${SHDB_SQL_DATA_FILENAME}"
declare -- whereCondition=""
declare -i withData=0
declare -i withTmpTable=0
declare -i withAutoIncrement=0


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
    echo "-A for keep auto-increment value"
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
while getopts ":d::h::u::p:t::b:f:w:DTvA" FLAG; do
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
        A) withAutoIncrement=1 ;;
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

declare -- error=""
for dbName in ${dbNames}; do

    # Database to process
    dumpBd="Dump ${dbName}"
    if logIsMuted; then
        progressBar "$dumpBd"
    fi

    # Connection check
    dbLink=$(mysqlConnect "$dbHost" "$dbUser" "$dbPassword" "$dbName")
    if [[ $? -ne 0 ]]; then
        error="ConnectionError.DATABASE"
        if logIsMuted; then
            progressBar "$dumpBd" 0 -1 "$error"
        fi
        pFatal "$error"
    fi

    # If no table in entry, we retrieve all available tables for the database
    if [[ -z "$tableNames" ]]; then
        result=$(mysqlFetchRaw "$dbLink" "SHOW TABLES FROM ${dbName};")
        if [[ $? -ne 0 ]]; then
            error="QueryError.SHOW_TABLES"
            if logIsMuted; then
                progressBar "$dumpBd" 0 -1 "$error"
            fi
            pFatal "$error"
        fi
        declare -a dbTableNames="(${result})"
    else
        declare -a dbTableNames="(${tableNames})"
    fi

    declare -i s="${#dbTableNames[@]}"
    declare -i k
    for k in "${!dbTableNames[@]}"; do

        # Table to process
        tableName="${dbTableNames[$k]}"

        # Skip temporary tables
        if [[ ${withTmpTable} -eq 0 ]] && [[ "$tableName" == "_"* || "$tableName" == *"_TMP"* ]]; then
            error=$(printf "DumpTable.SKIP_TABLE (%s)" "$tableName")
            if logIsMuted; then
                echo -ne " $error\n"
            else
                pWarn "$error"
            fi
            continue
        fi

        # One folder by table (remove redundant slash)
        if [[ "${dumpDir: -1}" == "/" ]]; then
            dumpDir="${dumpDir:0:-1}"
        fi
        dumpDbDir="${dumpDir}/${dbName}/${tableName}"
        mkdir -p "$dumpDbDir"

        # Dump table structure
        dumpTableFile="${dumpDbDir}/${SHDB_SQL_TABLE_FILENAME}"
        mysqlDump "$dbLink" "$tableName" "${SHDB_DUMP_TABLE_OPTIONS}" > "$dumpTableFile"
        if [[ $? -ne 0 ]]; then
            error="DumpError.UNKNOWN_TABLE (${tableName})"
            if logIsMuted; then
                progressBar "$dumpBd" "$k" -1 "$error"
            fi
            pFatalF "${error}\n%s" "$(mysqlLastError "$dbLink")"
        else
            if [[ ${withAutoIncrement} -eq 0 ]]; then
                # Manage sed -i on osx ...
                sed -e 's/ AUTO_INCREMENT=[0-9]*\b//' "$dumpTableFile" > "${dumpTableFile}-e" && mv "${dumpTableFile}-e" "$dumpTableFile"
            fi
            pInfoF "DumpTable.CREATE_TABLE (%s: %s)" "$tableName" "$dumpTableFile"
        fi

        # Dump with datas table
        if [[ ${withData} -eq 1 ]]; then
            dumpDataFile="${dumpDbDir}/${dumpDataFileName}"
            dataOptions="${SHDB_DUMP_DATA_TABLE_OPTIONS}"
            if [[ -n "${whereCondition}" ]]; then
                dataOptions+=" --where="${whereCondition}""
            fi
            mysqlDump "$dbLink" "$tableName" "$dataOptions" > "$dumpDataFile"
            if [[ $? -ne 0 ]]; then
                error="DumpError.READ_ONLY_TABLE (${tableName})"
                if logIsMuted; then
                    progressBar "$dumpBd" "$k" -1 "$error"
                fi
                pFatalF "${error}\n%s" "$(mysqlLastError "$dbLink")"
            else
                pInfoF "DumpTable.INSERT_TABLE (%s: %s)" "$tableName" "$dumpDataFile"
            fi
        fi

        # Update progress bar
        if logIsMuted; then
            progressBar "$dumpBd" "$(($k+1))" "$s"
        fi
    done;
done;