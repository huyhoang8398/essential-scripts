#!/bin/bash

#title           :dump_mysql.sh
#description     :This script will make mysqldump and transfer to backup folder.
#author          :DO Hoang
#date            :2023-05-11
#version         :0.1
#bash_version    :4.2.46(2)-release
#===============================================================================

DATE=$(date +%Y%m%d%H%M)
NPROC=$(nproc)

# Check if dump_mysql.conf is present and load it
if [ ! -f $(dirname $0)/dump_mysql.conf ]
then
    echo "$(dirname $0)/dump_mysql.conf is not a file or can't read it"
    exit 1
else
    source $(dirname $0)/dump_mysql.conf
fi

# Check if default cnf file exists
if [ ! -f $MYSQL_CNF ]
then
    echo "$MYSQL_CNF is not a file or can't read it"
    exit 1
fi

do_compress () {
    if [ -f $1 ]
    then
        # Fast compress Or not
        if [[ -x /usr/bin/pigz && $PIGZ = 1 && $NPROC -ge 4 ]]
        then
            /usr/bin/pigz -p $(($NPROC / 2)) $1 || return 1
        elif [[ -x /usr/bin/pigz && $PIGZ -gt 1 && $PIGZ -le $NPROC ]]
        then
            /usr/bin/pigz -p $PIGZ $1 || return 1
        else
            /bin/gzip $1 || return 1
        fi
    fi
}

## Query if we have enough space to dump & compress database
#have_enough_space() {
#   DB_SIZE=$(${BIN_MYSQL} --defaults-file=${MYSQL_CNF} ${MYSQL_OPTS} -Ns -e "SELECT ROUND(SUM(data_length + index_length) / 1024) AS 'Size (KB)' FROM information_schema.TABLES WHERE table_schema='${1}';")
#   DB_SIZE_PLUS_COMPRESS=$(echo $(( $DB_SIZE + $DB_SIZE * 10 / 100 )))
#   FS_FREE_SPACE=$(df -k ${DUMP_PATH}/CURRENT --output=avail | grep -v Avail)
#   if [ $FS_FREE_SPACE -lt $DB_SIZE_PLUS_COMPRESS ]
#   then
#       echo "There is not enough space do dump base $1"
#       exit 1
#   fi
#}

if [ ! -d ${DUMP_PATH} ]
then
    mkdir -p ${DUMP_PATH}
fi

if [ ! -d ${DUMP_PATH}/CURRENT ]
then
    mkdir ${DUMP_PATH}/CURRENT
fi

if [ ! -d ${DUMP_PATH}/OLD ]
then
    mkdir ${DUMP_PATH}/OLD
fi

##begin##
# Delete first oldest backups
if [ ${DUMP_RETENTION} -gt 0 ]
then
    find ${DUMP_PATH}/OLD/ -type f -mtime +${DUMP_RETENTION} -delete
    # Then move the latest backup to the old directory
    mv ${DUMP_PATH}/CURRENT/* ${DUMP_PATH}/OLD/
    # Compress uncompressed files in OLD directory if exists
    if /bin/ls ${DUMP_PATH}/OLD/*.sql 1> /dev/null 2>&1 ; then do_compress ${DUMP_PATH}/OLD/*.sql || exit 1 ; fi
else
    #Remove all daily dumps
    /bin/rm -f ${DUMP_PATH}/CURRENT/* ${DUMP_PATH}/OLD/*
fi

# What should I backup ?
if [ "$DB_LIST" = "ALL" ]
then
    # List all databases
    DB_LIST=$(${BIN_MYSQL} --defaults-file=${MYSQL_CNF} ${MYSQL_OPTS} -Ns -e "SELECT \`schema_name\` from INFORMATION_SCHEMA.SCHEMATA  WHERE \`schema_name\` NOT IN('information_schema', 'sys', 'performance_schema');"|sed -r "s/^($DB_EXCLUDE)$//"|sed '/^$/d')

fi

# Do I have something to do ?
if [ -z "$DB_LIST" ] ; then echo "There is no database, this is a problem"; exit 1; fi
# So let's do this !
for DB in $DB_LIST
do
    ## Do I have enough space to do the job ?
    #have_enough_space $DB
    # Dump to SQL
    ${BIN_MYDUMP} --defaults-file=${MYSQL_CNF} ${MYSQL_OPTS} ${MYSQLDUMP_OPTS} --routines --lock-tables --events ${DB} > ${DUMP_PATH}/CURRENT/${DB}_${DATE}.sql 
    # Check if previous command is failed
    if [ $? -ne 0 ]; then
        echo "dumping ${DB} FAILED"
        exit 1
    fi
    # Secure dump
    /bin/chmod ${CHMOD} ${DUMP_PATH}/CURRENT/${DB}_${DATE}.sql
    # Change group if defined
    if [ -n "$GRP" ] ; then /bin/chgrp $GRP ${DUMP_PATH}/CURRENT/${DB}_${DATE}.sql ; fi
    
    # Compress
    do_compress ${DUMP_PATH}/CURRENT/${DB}_${DATE}.sql || exit 1
done
