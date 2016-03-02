# shdb

Bash command line tools to dump and load MySQl table's structure with or without datas.
Create a folder by database and one folder by table inside.
Enable re-building or not to prevent overloading. Remove "DROP TABLE" in SQL file, add "IF EXISTS" on table and replace "INSERT" by "INSERT IGNORE 

## About
Developed to provide methods to save the structure and default informations of MySql tables in a GIT repository.
In order that this deposit is also readable by a human being, the storage respects the following naming convention.

* /{DATABASE_NAME}/{TABLE_NAME}/[table|datas].sql

In this folder table.sql contains the structure of the table and datas.sql the datas.
In order to manage various project, it is possible to force name of data's file.
@example /{DATABASE_NAME}/{TABLE_NAME}/datas_plus.sql

For example, this structure offers possibility to remove a specific table on an existing database by overwrite
its file with drop table query.

## Required

mysql & mysqldump command line tools

### Dump: export one, more or all tables from a database.

It is possible to make several databases simultaneously but surely of little use in a production environment.

usage: ./dump.sh -d databases [-t tables] [-h host] [-u user] [-p password] [-b backupDirectory] [-f sqlFileName] [-w whereCondition] [-v] [-D] [-T]
* -d for database name(s), separated by a space
* -t for table name(s), separated by a space
* -h for database hostname, default 'localhost'
* -u for database username, default 'mysql'
* -p for database password, default ''
* -b for backup folder path
* -f to name sql data file, default 'datas.sql'
* -w for limit rows selected by the given WHERE condition
* -v used to print SQL Query
* -D for export data with schema
* -T for keep TMP tables, by convention named with '_' as first letter or with '_TMP' on the name

### Load: import one, more or all tables in one or more databases

* Usage: ./load.sh -b sourcedirectory [-d databases] [-t tablenames] [-h hostname] [-u username] [-p password] [-l logfilepath] [-v] [-r] [-D]
* -b for root repository with SQL files
* -d for database name, separated by a space
* -t for table name(s), separated by a space
* -h for database hostname
* -u for database username
* -p for database password
* -l to change default log file path
* -v used to print SQL Query
* -r for lauch a dry-run, see result wihout apply it
* -D for export data with schema
* -B to force re-build (drop table, etc.)

#### Prevent the re-building (remove drop table, create only if not exists and ignore duplicated content)

```bash
./load.sh -b "/tmp/rv" -d my_base -v -r -D
-- --------------------------------------------------------------- my_base

CREATE TABLE IF NOT EXISTS `RV` (
  `RV_ID` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `TITLE` char(12) COLLATE utf8_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`RV_ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

INSERT IGNORE INTO `RV` (`RV_ID`, `TITLE`) VALUES (1,'Hello'),(2,'World');
````