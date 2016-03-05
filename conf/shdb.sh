#!/usr/bin/env bash

##
# shdb
#
# Configuration file of shdb project
#
# @copyright 2016 Hervé Gouchet
# @license http://www.apache.org/licenses/LICENSE-2.0
# @source https://github.com/rvflash/shdb

declare -r SHDB_TMP_DIR="/tmp/shdb"
declare -r SHDB_SQL_TABLE_FILENAME="table.sql"
declare -r SHDB_SQL_DATA_FILENAME="data.sql"
declare -r SHDB_DB_HOST="localhost"
declare -r SHDB_DB_USERNAME="mysql"
declare -r SHDB_DB_PASSWORD=""

 # Single transaction as option is mandatory for Brighthouse database
declare -r SHDB_DUMP_OPTIONS="--opt --no-create-db --skip-trigger"
declare -r SHDB_DUMP_TABLE_OPTIONS="${SHDB_DUMP_OPTIONS} --no-data --single-transaction"
declare -r SHDB_DUMP_DATA_TABLE_OPTIONS="${SHDB_DUMP_OPTIONS} --no-create-info --compact --complete-insert"

# Create temporary workspace
mkdir -p "${SHDB_TMP_DIR}"