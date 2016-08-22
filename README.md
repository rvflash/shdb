# shdb

Bash command line tools to dump or load MySql table's structure or data.

> Create a folder by database and one folder by table inside.
> Enable re-building or not, to prevent overloading.
> Remove "DROP TABLE" in SQL file, add "IF EXISTS" on table and replace "INSERT" by "INSERT IGNORE 


## About

Developed to provide methods to save in a GIT repository the structure and default data of MySql tables.
In order that this deposit is also readable by a human being, the storage respects the following naming convention:

```bash
> DATABASE_NAME
>   - TABLE_NAME
>       |_ table.sql
>       |_ data.sql
```

`table.sql` contains the table's structure and `data.sql`, the data to insert on it.
In order to manage various project, it is possible to force the name of data's files.

For example, this structure offers possibility to remove a specific table on an existing database by overwrite its file with drop table query.


## Required

mysql & mysqldump command line tools


### Dump: export one, more or all tables from a database.

It is possible to make several databases simultaneously, but surely of little use in a production environment.

```bash
usage: ./dump.sh -d databases [-t tables] [-h host] [-u user] [-p password] [-b backupDirectory] [-f sqlFileName] [-w whereCondition] [-v] [-D] [-T] [-A]
-d for database name(s), separated by a space
-t for table name(s), separated by a space
-h for database hostname, default 'localhost'
-u for database username, default 'mysql'
-p for database password, default ''
-b for backup folder path
-f to name sql data file, default 'datas.sql'
-w for limit rows selected by the given WHERE condition
-v used to print SQL Query
-D for export data with schema
-T for keep TMP tables, by convention named with '_' as first letter or with '_TMP' on the name
-A for keep auto-increment value
```


### Load: import one, more or all tables in one or more databases

```bash
usage: ./load.sh -b rootRepository [-d databases] [-t tables] [-h host] [-u user] [-p password] [-f sqlFileNames] [-v] [-r] [-B]
-b for root repository with SQL files
-d for database name(s), separated by a space
-t for table name(s), separated by a space
-h for database hostname, default 'localhost'
-u for database username, default 'mysql'
-p for database password, default ''
-f for sql file name(s) with data to load, separated by a space
-r for launch a dry-run, see result without apply it on database
-v for verbose mode
-B to force re-build (drop table, etc.)
```

#### Prevent the re-building of data and structure

Apply the following change on SQL to load:

* Remove `DROP TABLE`
* Replace `CREATE TABLE` by `CREATE TABLE IF NOT EXISTS`
* Replace `INSERT INTO` by `INSERT IGNORE INTO`

#### Dry-run

You also can launch a dry-run to see all the SQL queries before load it on database:

```bash
./load.sh -b "/tmp/shdb" -r -d "test" -B
Load test [++++++++++++++++++++] 100%

DROP TABLE IF EXISTS `rv`;
CREATE TABLE `rv` (
  `id` int(10) unsigned NOT NULL,
  `name` varchar(255) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

INSERT IGNORE INTO `rv` (`id`, `name`) VALUES (1,'Hello'),(2,'World');
```