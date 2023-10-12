#!/bin/bash

# Database credentials
DB_USER="root"
DB_PASSWORD="root"
DB_HOST="127.0.0.1"
DB_PORT="3306"
DB_NAME="db"

execute_mysql_query() {
    local query="$1"

    MYSQL_PWD="$DB_PASSWORD" mysql -u"$DB_USER" -h"$DB_HOST" -P"$DB_PORT" -D "$DB_NAME" --skip-column-names --batch -e "$query"
}

print_latest_entry() {
    local table="$1"
    echo 
    echo -e "\e[32m${table^^}:\e[0m"; MYSQL_PWD="$DB_PASSWORD" mysql -u"$DB_USER" -h"$DB_HOST" -P"$DB_PORT" -D "$DB_NAME" -e "
        SELECT * FROM $table
        ORDER BY id DESC
        LIMIT 1
    "
}

get_record_count() {
    local table="$1"
    echo $(execute_mysql_query "SELECT COUNT(*) FROM $table")
}

usage() {
    echo "Usage: $0 -ss for snapshot of database, -e for entries after snapshot, -l for latest"
}

tables=$(MYSQL_PWD="$DB_PASSWORD" mysql --user="$DB_USER" --password=''"$DB_PASSWORD"'' -h"$DB_HOST" -P"$DB_PORT" -D "$DB_NAME" -e "SHOW TABLES;" | tail -n +2)

if [[ $# -eq 0 ]]; then
    usage
    exit 1
fi

if [[ $1 = "-ss" ]]; then
    exec 4>&1
    exec > /tmp/ss-output.txt

    for table in $tables; do
        count=$(get_record_count "$table")
        echo "$table:$count"
    done

    exec 1>&4
    exec 4>&-
    echo "Snapshot taken"
    exit 0
elif [[ $1 = "-e" ]]; then

    if [ ! -e "/tmp/ss-output.txt" ]; then
        echo "Snapshot file does not exist."
        exit 1
    fi

    declare -A table_values

    while IFS=":" read -r table value; do
        table_values["$table"]=$value
    done < "/tmp/ss-output.txt"

    echo "Differences:"

    for table in $tables; do
    if [[ -v table_values["$table"] ]]; then
        prev_count="${table_values["$table"]}"

        new_count=$(get_record_count "$table")

        if [ "$prev_count" != "$new_count" ]; then
            diff=$((new_count - prev_count))
            echo -e "\e[32m${table^^}\e[0m $diff"
        fi
    else
        echo "Value for $table not found in table_values."
    fi
    done
    exit 0
elif [[ $1 = "-l" ]]; then
    echo "Latest entries:"

    for table in $tables; do
    print_latest_entry "$table"
    done
    exit 0
else
    usage
    exit 0;
fi

