#!usr/bin/env bash

##RESTART SCRIPT FRM ORIGIN IF NECESSARY
real_script_file="$(readlink $0)"

if [ "${real_script_file}" != "" ]; then
    set -e
    eval "${real_script_file} $@"
    exit 0
fi

source "${LIB_DIR}/common.sh"
source "${LIB_DIR}/k8s.sh"

cat <<EOF
 _______ __________________ _______           _______  _        _______             _______  _______  _______          _________ _______  _______ 
(  ____ )\__   __/\__    _/(  ___  )|\     /|(  ____ )( (    /|(  ____ \|\     /|  (  ____ \(  ____ \(  ____ )|\     /|\__   __/(  ____ \(  ____ \
| (    )|   ) (      )  (  | (   ) || )   ( || (    )||  \  ( || (    \/( \   / )  | (    \/| (    \/| (    )|| )   ( |   ) (   | (    \/| (    \/
| (____)|   | |      |  |  | |   | || |   | || (____)||   \ | || (__     \ (_) /   | (_____ | (__    | (____)|| |   | |   | |   | |      | (__    
|  _____)   | |      |  |  | |   | || |   | ||     __)| (\ \) ||  __)     \   /    (_____  )|  __)   |     __)( (   ) )   | |   | |      |  __)   
| (         | |      |  |  | |   | || |   | || (\ (   | | \   || (         ) (           ) || (      | (\ (    \ \_/ /    | |   | |      | (      
| )      ___) (___|\_)  )  | (___) || (___) || ) \ \__| )  \  || (____/\   | |     /\____) || (____/\| ) \ \__  \   /  ___) (___| (____/\| (____/\
|/       \_______/(____/   (_______)(_______)|/   \__/|/    )_)(_______/   \_/     \_______)(_______/|/   \__/   \_/   \_______/(_______/(_______/
                                                                                                                                                  
 _______  _______  _______          _________ _______ _________ _______  _        _______  _______                                                
(  ____ )(  ____ )(  ___  )|\     /|\__   __/(  ____ \\__   __/(  ___  )( (    /|(  ____ \(  ____ )                                               
| (    )|| (    )|| (   ) || )   ( |   ) (   | (    \/   ) (   | (   ) ||  \  ( || (    \/| (    )|                                               
| (____)|| (____)|| |   | || |   | |   | |   | (_____    | |   | |   | ||   \ | || (__    | (____)|                                               
|  _____)|     __)| |   | |( (   ) )   | |   (_____  )   | |   | |   | || (\ \) ||  __)   |     __)                                               
| (      | (\ (   | |   | | \ \_/ /    | |         ) |   | |   | |   | || | \   || (      | (\ (                                                  
| )      | ) \ \__| (___) |  \   /  ___) (___/\____) |___) (___| (___) || )  \  || (____/\| ) \ \__                                               
|/       |/   \__/(_______)   \_/   \_______/\_______)\_______/(_______)|/    )_)(_______/|/   \__/                                               
                                                                                                                                                  
EOF

#SKIP PSQL PASS PROMPT
secret_name="${SERVICE_NAME}-db-conf"
export PGPASSWORD="${MASTER_DBPASSWORD}"

## CHECK IF SECRET EXISTS AND CREATE OR RETREIVE DB PASSWORD
secret_exists="$(secret_exists "${secret_name}")"
if [ "${secret_exists}" == "1" ]; then
    out "Secret exists ${secret_name}"
    export DB_PASS="$(secret_get "${secret_name}" | jq ".data.password" | sed 's/"//g' | base64 -d)"
    out "Got existing password ${DB_PASS}"
else
    export DB_PASS="$(openssl rand -base64 12)"
    out "Generated new password ${DB_PASS}"
fi
## Check if user is valid
if !psql -U "${MASTER_DBUSER}" -d postgres -c "select 1" -h "${DB_HOST}" -p "${DB_PORT}" &>/dev/null; then
    panic "Failed to connect to PostgreSQL at host ${DB_HOST} on port ${DB_PORT} with user ${MASTER_DBUSER}"
fi
echo "Database user '${MASTER_DBUSER}' is valid on host '${DB_HOST}' on port '${DB_PORT}'"

## Check if database exists and create if it does not
if [ "$(psql -lqt -U "${MASTER_DBUSER}" -d postgres -c "\\l" -h "${DB_HOST}" -p "${DB_PORT}" | cut -d \| -f 1 | grep -w "${DB_NAME}")" == "" ]; then
    echo "Creating database ${DB_NAME}"
    sql=$(cat ${INIT_DIR}/schema.sql)
    echo "inserting SQL '${sql}'"
    psql -U "${MASTER_DBUSER}" -d postgres -h "${DB_HOST}" -p "${DB_PORT}" <<EOF
    create database ${DB_NAME};
    create user ${DB_USER} with password '${DB_PASS}';   
EOF
    ## init tables.
    export PGPASSWORD="${DB_PASS}"
    psql -U "${DB_USER}" -d "${DB_NAME}" -h "${DB_HOST}" -p "${DB_PORT}" <<EOF
    ${sql}
EOF
else
    ## update user
    echo "Database ${DB_NAME} exist updating user"
    psql -U "${MASTER_DBUSER}" -d postgres -h "${DB_HOST}" -p "${DB_PORT}" <<EOF
        alter user ${DB_USER} with password '${DB_PASS}';
        grant all on database ${DB_NAME} to ${DB_USER};
EOF
fi
## CREATE KUBERNETES SECRET
if [ "${secret_exists}" == "0" ]; then
    echo "Generating secret ${secret_name} user '${DB_USER}' password '${DB_PASS}'"
    read -r -d '' secret_data <<EOF
        "database.name": "$(printf "${DB_NAME}" | base64)",
        "username": "$(printf "${DB_USER}" | base64)",
        "password": "$(printf "${DB_PASS}" | base64)"
EOF
    echo "DATA ${secret_data}"
    create_secret "${secret_name}" "${secret_data}"
fi
