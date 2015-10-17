#!/usr/bin/env bash

# Exit on the first error
set -e

# Manage logging
readonly SCRIPT_NAME=$(basename $0)
MAIN_LOG_FILE="/var/log/syncho_backup.log"
ERROR_LOG_FILE="/var/log/syncho_backup.err"

trap 'exec 2>&4 1>&3' 0 1 2 3
exec 3>&1 4>&2
exec > >(tee -ia "${MAIN_LOG_FILE}")
exec 2> >(tee -ia "${ERROR_LOG_FILE}")

# Create temporary directory
BACKUP_TMP_DIR="$(mktemp -d)"

# Always delete tmp dir
trap 'rm -rf "${BACKUP_TMP_DIR}"' EXIT


#================================ Define variables =============================

# Backup options
DO_BACKUP_FILES=0
DO_BACKUP_MYSQL=0
RECURSIVE_FILE_BACKUP=0

# Mysql variables
MYSQL_CNF_FILE=""
MYSQLDUMP="$(which mysqldump)"
MYSQL_OPTS='--events --triggers --routines --single-transaction --opt'

# Create date variable
NOW="$(date +%Y-%m-%d__%H-%M-%S)"

# SSH options
SSH_USERNAME=""
SSH_HOST=""
SSH_DEST_BACKUP_DIR=""
SSH_DEST_SYNCRO_SCRIPT=""


#================================ Define functions =============================

# Commands used to log
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $*"
    logger -p user.notice -t $SCRIPT_NAME "$*"
}

err() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') => $*" >&2
    logger -p user.error -t $SCRIPT_NAME "$*"
}

console() {
    echo "$*"
}

# The command line help
display_help() {
    console " "
    console "Usage : $0 [option...] [-f my_path:my_dest] [-d my_database]"
    console " "
    console "  General options :"
    console "    -h        Display this help message and exit"
    console "    -p        Backup directory"
    console " "
    console "  Database backups :"
    console "    -d        Do database backup, can be set multiple times"
    console "    -m        Do a mysql backup task, need at least one database"
    console " "
    console "  File backups :"
    console "    -f        Do file backup, can be set multiple times"
    console "    -r        Do recursive file backup"
    console " "
    console "  Logging :"
    console "    -l        Main log file"
    console "    -e        Error log file"
    console " "
    console "  SSH :"
    console "    -u        Username"
    console "    -H        Hostname"
    console "    -s        Remote script to execute"
    console "    -t        Target directory"
    exit 1
}

# The mysql backup command
backup_mysql_databases() {

    log "Start Mysql backup ..."

    # A mysql backup nead at least one database to backup
    if [[ ${#databases[@]} -le 0 ]]; then
        err "Error : Mysql backup need at leat one database"
        display_help
    fi

    # A mysql backup nead one credentials file
    if [[ -z "${MYSQL_CNF_FILE}" || ! -f "${MYSQL_CNF_FILE}" ]]; then
        err "Error : Mysql backup need one credentials file"
        display_help
    fi

    for database in "${databases[@]}"; do
        ${MYSQLDUMP} --defaults-extra-file="${MYSQL_CNF_FILE}" ${MYSQL_OPTS} \
            "${database}" > "${BACKUP_TMP_DIR}/${database}.sql"
    done

    log "Mysql backup finished"
}

# The files backup command
backup_files() {

    log "Start backup files task ..."

    # Check if file backup should be recursive
    if [[ ${RECURSIVE_FILE_BACKUP} -eq 1 ]]; then
        copy_cmd="cp -a "
    else
        copy_cmd=" cp "
    fi

    # Copy files
    for file in "${files[@]}"; do

        # Get origin path part
        origin="${file%:*}"

        # Get dest path part and create the path
        dest="${file##*:}"
        mkdir -p "${BACKUP_TMP_DIR}/${dest}"

        # Copy files
        ${copy_cmd} "${origin}" "${BACKUP_TMP_DIR}/${dest}"
    done

    log "Backup files finished"
}

# Argument parse
parse_arguments() {

    local hasActions=0

    while getopts "c:d:hH:mf:p:rs:t:u:" opt; do
        case $opt in
            c)
                MYSQL_CNF_FILE="${OPTARG}"
                ;;
            d)
                databases+=("${OPTARG}")
                ;;
            h)
                display_help
                ;;
            H)
                SSH_HOST="${OPTARG}"
                ;;
            m)
                DO_BACKUP_MYSQL=1
                hasActions=1
                ;;
            f)
                files+=("${OPTARG}")
                DO_BACKUP_FILES=1
                hasActions=1
                ;;
            p)
                BACKUP_DIR="${OPTARG}"
                ;;
            r)
                RECURSIVE_FILE_BACKUP=1
                ;;
            s)
                SSH_DEST_SYNCRO_SCRIPT="${OPTARG}"
                ;;
            t)
                SSH_DEST_BACKUP_DIR="${OPTARG}"
                ;;
            u)
                SSH_USERNAME="${OPTARG}"
                ;;
            :)
                err "Missing argument for -${OPTARG}"
                display_help
                ;;
            \?)
                err "Illegal option: -${OPTARG}"
                display_help
                ;;
        esac
    done
    shift $((OPTIND -1))

    if [[ ${hasActions} -eq 0 ]]; then
        err "Error : No backups defined"
        display_help
    else
        log "Valid params received"
    fi
}

# Backup directory management
manage_backup_dir() {

    # Script should receive backup directory
    if [[ -z "${BACKUP_DIR}" ]]; then
        err "Error : Backup directory is needed"
        display_help
    fi

    # If backup directory not exists, create it
    if [[ ! -d "${BACKUP_DIR}" ]]; then
        mkdir -p "${BACKUP_DIR}"
    fi
}


#================================ Create backup ================================

# Begin log
log '#------------------------------'
log "Starting script ${SCRIPT_NAME}"
log '#------------------------------'

# Parse arguments
parse_arguments "$@"

# Manage backup directory
manage_backup_dir

# Do mysql backup if needed
if [[ ${DO_BACKUP_MYSQL} -gt 0 ]]; then
    backup_mysql_databases
fi

# Do file backup if needed
if [[ ${DO_BACKUP_FILES} -gt 0 ]]; then
    backup_files
fi

# Create backup archive
BACKUP_FILENAME="${NOW}.tgz"
BACKUP_FILE="${BACKUP_DIR}/${BACKUP_FILENAME}"
tar -C "${BACKUP_TMP_DIR}" -czf "${BACKUP_FILE}" "./"


#================================ Transfer backup ==============================

# Copy backup
log "Lauching SCP to ${SSH_USERNAME}@${SSH_HOST}:${SSH_DEST_BACKUP_DIR}/"
if [[ -n "${SSH_USERNAME}" && -n "${SSH_HOST}" && -n "${SSH_DEST_BACKUP_DIR}" ]]; then
    scp "${BACKUP_FILE}" "${SSH_USERNAME}@${SSH_HOST}:${SSH_DEST_BACKUP_DIR}/"
fi

# Execute a script on destination if needed
if [[ -n "${SSH_DEST_SYNCRO_SCRIPT}" ]]; then
    ssh "${SSH_USERNAME}@${SSH_HOST}" -c "${SSH_DEST_SYNCRO_SCRIPT} ${SSH_DEST_BACKUP_DIR}/${BACKUP_FILENAME}"
fi

# End log
log '#-------------------------'
log "Script ended successfully"
log '#-------------------------'
