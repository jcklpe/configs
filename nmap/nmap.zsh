#!/usr/bin/env bash

#//-check for open ports quickie
alias nmap-quick='sudo nmap -sS $1'
# {{www.hostname.com or IP address}}

#//- check for specific open port

alias nmap-scanport='nmap -p $1'
# specific port or  {{www.hostname.com}}
