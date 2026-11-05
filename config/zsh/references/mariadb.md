# 🧠 MariaDB / MySQL CLI Cheat Sheet

## 🔍 Connecting

```bash
mariadb -u root -p                              # Connect as root (prompts for password)
mariadb -u root -p dbname                       # Connect directly to a database
mariadb -u user -p -h 192.168.1.10              # Connect to remote host
mariadb -u user -p -h 127.0.0.1 -P 3307         # Non-default port (needs -h/--protocol=tcp; localhost uses the socket and ignores -P)
mariadb -u user -p -S /var/run/mysqld/mysqld.sock  # Connect via Unix socket
mariadb --defaults-file="$HOME/.my.cnf"         # Use custom config file (must be the first option; ~ is not expanded after =)
```

## 💾 Dump and Backup (mariadb-dump / mysqldump)

```bash
mariadb-dump -u root -p dbname > dump.sql                    # Dump single database
mariadb-dump -u root -p --all-databases > all.sql            # Dump all databases
mariadb-dump -u root -p dbname table1 table2 > tables.sql   # Dump specific tables
mariadb-dump -u root -p --no-data dbname > schema.sql        # Schema only (no data)
mariadb-dump -u root -p --no-create-info dbname > data.sql   # Data only (no schema)
mariadb-dump -u root -p --single-transaction dbname > dump.sql  # Consistent dump without locking (InnoDB)
mariadb-dump -u root -p --routines --triggers dbname > full.sql # Include stored procedures and triggers
mariadb-dump -u root -p dbname | gzip > dump.sql.gz          # Dump and compress
```

## 📥 Restore and Import

```bash
mariadb -u root -p dbname < dump.sql                         # Restore from dump file
gunzip < dump.sql.gz | mariadb -u root -p dbname             # Restore from compressed dump
mariadb -u root -p -e "SOURCE /path/to/dump.sql"             # Restore via SOURCE command
mariadb -u root -p dbname < schema.sql && mariadb -u root -p dbname < data.sql  # Schema then data
```

## 🔧 One-Liner Queries (-e flag)

```bash
mariadb -u root -p -e "SHOW DATABASES"                       # List all databases
mariadb -u root -p -e "SHOW TABLES" dbname                   # List tables in database
mariadb -u root -p -e "DESCRIBE users" dbname                # Show table structure
mariadb -u root -p -e "SELECT COUNT(*) FROM users" dbname    # Quick row count
mariadb -u root -p -e "SHOW PROCESSLIST"                     # Show active connections
mariadb -u root -p -e "SHOW VARIABLES LIKE '%max_connections%'"  # Check setting
```

## 📊 Common SQL Operations

```sql
-- Inside the mariadb shell:

SHOW DATABASES;                                  -- List all databases
CREATE DATABASE mydb CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;  -- Create database
DROP DATABASE mydb;                              -- ⚠️ Deletes database and all its data, no confirmation
USE mydb;                                        -- Switch to database

SHOW TABLES;                                     -- List tables
DESCRIBE users;                                  -- Show table columns and types
SHOW CREATE TABLE users\G                        -- Show full CREATE statement (vertical)
SHOW TABLE STATUS\G                              -- Table sizes, engine, row counts
SHOW INDEX FROM users;                           -- Show indexes on table

SELECT * FROM users LIMIT 10;                    -- Quick peek at data
SELECT COUNT(*) FROM users;                      -- Row count
SELECT table_name, table_rows, data_length, index_length
  FROM information_schema.tables
  WHERE table_schema = 'mydb'
  ORDER BY data_length DESC;                     -- Table sizes in a database
```

## 👤 User Management

```sql
CREATE USER 'app'@'localhost' IDENTIFIED BY 'password';               -- Create local user
CREATE USER 'app'@'%' IDENTIFIED BY 'password';                       -- Create user (any host)
GRANT ALL PRIVILEGES ON mydb.* TO 'app'@'localhost';                  -- Grant all on database
GRANT SELECT ON mydb.* TO 'readonly'@'%';                             -- Read-only privileges
REVOKE ALL PRIVILEGES ON mydb.* FROM 'app'@'localhost';               -- Revoke privileges
DROP USER 'app'@'localhost';                                          -- Delete user
SELECT user, host FROM mysql.user;                                     -- List all users
```

## 🔍 Diagnostics

```sql
SHOW PROCESSLIST;                                -- Active queries and connections
SHOW FULL PROCESSLIST;                           -- With full query text
KILL <id>;                                       -- Kill a running query by process ID
SHOW ENGINE INNODB STATUS\G                      -- InnoDB diagnostics
SHOW GLOBAL STATUS LIKE 'Threads_connected';     -- Current connection count
SHOW GLOBAL VARIABLES LIKE 'max_connections';    -- Max allowed connections
SHOW SLAVE STATUS\G                              -- Replication status (replica)
SHOW MASTER STATUS\G                             -- Replication status (primary)
```

## 🧰 Output Formatting

```bash
mariadb -u root -p -e "SELECT * FROM users" --batch dbname    # Tab-separated output (scriptable)
mariadb -u root -p -e "SELECT * FROM users" --batch -N dbname # Tab-separated, no headers
mariadb -u root -p -e "SELECT * FROM users\G" dbname   # Vertical format (one column per line)
mariadb -u root -p --html -e "SELECT * FROM users" db   # HTML table output
mariadb -u root -p --xml -e "SELECT * FROM users" db    # XML output
```

## 🔗 Common Combos

```bash
# Dump remote DB, restore locally (no -p: two prompts in one pipeline collide — put creds in ~/.my.cnf or use MYSQL_PWD)
mariadb-dump -u root -h remote_host dbname | mariadb -u root local_db

# Dump, compress, and copy to remote server
mariadb-dump -u root -p dbname | gzip | ssh user@host "cat > /backups/dump.sql.gz"

# Quick table size report
mariadb -u root -p -e "SELECT table_name, ROUND(data_length/1024/1024, 2) AS 'Size (MB)' FROM information_schema.tables WHERE table_schema='mydb' ORDER BY data_length DESC"

# Export query result to naive CSV (GNU sed; no quoting — breaks on commas, quotes, NULL; use SELECT ... INTO OUTFILE or a real tool for real CSV)
mariadb -u root -p -e "SELECT * FROM users" --batch -N dbname | sed 's/\t/,/g' > users.csv

# Copy table between databases (no -p: two prompts collide — use ~/.my.cnf or MYSQL_PWD)
mariadb-dump -u root source_db table1 | mariadb -u root target_db

# ⚠️ Kill all user queries running longer than 60 seconds (needs creds in ~/.my.cnf, one connection per id)
mariadb -u root -e "SELECT id FROM information_schema.processlist WHERE time > 60 AND command NOT IN ('Sleep','Binlog Dump','Binlog Dump GTID') AND user NOT IN ('system user','event_scheduler')" --batch -N | xargs -I {} mariadb -u root -e "KILL {}"
```

## ⚠️ Gotchas

```bash
# mariadb-dump locks tables by default — use --single-transaction for InnoDB
# Always quote passwords in scripts: -p'my pass' (no space after -p)
# \G at end of query = vertical output (inside shell), --batch = scriptable output
# mysql and mariadb CLIs are interchangeable on MariaDB servers
# FLUSH PRIVILEGES is needed after direct grants table edits, not after GRANT/REVOKE
# Default character set: always specify utf8mb4, not utf8 (which is only 3 bytes in MySQL)
```

