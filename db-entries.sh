#!/bin/bash

# Database credentials
DB_USER="root"
DB_PASSWORD="root"
DB_HOST="127.0.0.1"
DB_PORT="3306"
DB_NAME="db"

tables=$(mysql -u"$DB_USER" -p''"$DB_PASSWORD"'' -h"$DB_HOST" -P"$DB_PORT" -D "$DB_NAME" -e "SHOW TABLES;" | tail -n +2)

if [[ $1 = "-ss" ]]; then
    exec 4>&1
    exec > ss-output.txt

    for table in $tables; do
        latest_id=$(mysql -u"$DB_USER" -p"$DB_PASSWORD" -h"$DB_HOST" -P"$DB_PORT" -D "$DB_NAME" -e "SELECT id FROM $table ORDER BY id DESC LIMIT 1;" | tail -n +2)
        echo "$table:$latest_id"
    done

    exec 1>&4
    exec 4>&-
    echo "Snapshot taken"
elif [[ $1 = "-e" ]]; then

    if [ ! -e "ss-output.txt" ]; then
        echo "Snapshot file does not exist."
        exit 1
    fi

    declare -A table_values

    while IFS=":" read -r table value; do
        table_values["$table"]=$value
    done < "ss-output.txt"

    echo "New entries:"

    for table in $tables; do
    if [[ -v table_values["$table"] ]]; then
        latest_id="${table_values["$table"]}"

        mysql_output=$(mysql -u"$DB_USER" -p"$DB_PASSWORD" -h"$DB_HOST" -P"$DB_PORT" -D "$DB_NAME" -e "
            SELECT * FROM $table
            WHERE id > ${latest_id:-0};"
        )

        if [ -n "$mysql_output" ]; then
            echo -e "\e[32m${table^^}\e[0m"
            echo "$mysql_output"
        fi
    else
        echo "Value for $table not found in table_values."
    fi
    done
elif [[ $1 = "-l" ]]; then
    echo "Latest entries:"

    for table in $tables; do
    echo -e "\e[32m${table^^}\e[0m"
    mysql -u"$DB_USER" -p"$DB_PASSWORD" -h"$DB_HOST" -P"$DB_PORT" -D "$DB_NAME" -e "
        SELECT * FROM $table
        ORDER BY id DESC
        LIMIT 1;"
    done
else
    echo "Usage: flag -ss for snapshot of database, -e for entries after snapshot, -l for latest"
    exit 0;
fi

