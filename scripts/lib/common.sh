#!usr/bin/env bash

RED="\e[31m"
GREEN="\e[32m"
NOCOLOR="\e[0m"

function err(){
    >&2 printf "${1}\n"
}
function out() {
    printf "${1}\n ${@:2}"
}
function panic(){
    out "${1}"
    exit 1
}
function check_env(){
    for var in "$@"; do
        value= $(eval "echo \${$var}")
        if [ "$value" == "" ]; then
            panic "Enviroment variable  '$var' is required"
        fi
    done
}