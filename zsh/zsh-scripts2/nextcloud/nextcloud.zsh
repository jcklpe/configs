##- Nextcloud related
# list all apps
alias nc-list='cd /var/www/nextcloud && sudo -u www-data php occ app:list'

#scan and clean up files
alias nc-scan='cd /var/www/nextcloud && sudo -u www-data php occ files:cleanup'

# turn off and on safe mode
alias nc-on='cd /var/www/nextcloud && sudo -u www-data php occ maintenance:mode --on'
alias nc-off='cd /var/www/nextcloud && sudo -u www-data php occ maintenance:mode --off'

alias nc-repair='cd /var/www/nextcloud && sudo -u www-data php occ maintenance:repair'