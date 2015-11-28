# shdb

Bash command line tools to dump and load MySQl table's structure with or without datas.

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

Usage: ./dump.sh -d databases -t tablenames [-h hostname] [-u username] [-p password] [-b backupdirectory] [-f sqlfilename] [-l logfilepath] [-w wherecondition] [-v] [-D] [-T]
* -h for database hostname
* -u for database username
* -p for database password
* -d for database name, separated by a space
* -t for table name(s), separated by a space
* -b for backup folder path
* -f to name sql data file, named default if not set
* -l to change default log file path
* -D for export data with schema
* -T for keep TMP tables, by convention named with _ as fist letter or with _TMP on the name
* -w for limit rows selected by the given WHERE condition
* -v used to print SQL Query

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

#### Prevent the re-building (remove drop table, create only if not exists and ignore duplicate content)

```bash
./load.sh -d my_base -v -D -r
-- --------------------------------------------------------------- my_base

CREATE TABLE IF NOT EXISTS `RV` (
  `RV_ID` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `TITLE` char(12) COLLATE utf8_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`RV_ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

INSERT IGNORE INTO `RV` (`RV_ID`, `TITLE`) VALUES (1,'Hello'),(2,'World');
````

### Query: basic interface to run SQL query

* Usage: ./query.sh -d database -q query [-h hostname] [-u username] [-p password] [-l logfilepath] [-v]
* -h for database hostname
* -u for database username
* -p for database password
* -d for database name
* -q for SQL query
* -l to change default log file path
* -v used to print SQL Query