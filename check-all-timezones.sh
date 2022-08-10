#!/bin/bash

# Prerequisite software:
#   curl, jq, awk, sed, docker-compose, dateutils

wait_mysqld() {
    while :
    do
        docker-compose exec -it -e MYSQL_PWD=example db mysql -BNe 'SELECT 1' && break
        sleep 1
    done
}

wait_ghost() {
    while :
    do
        [ "`curl -s localhost:8080/ghost/api/admin/site/ | jq -r '.site.title' 2> /dev/null`" = 'Ghost' ] && break
        sleep 1
    done
}

git clone --depth 1 https://github.com/levee223/ghost-framework.git framework

docker-compose up --wait db
wait_mysqld

docker-compose up --wait
wait_ghost

awk '/^Z/ { print $2 }; /^L/ { print $3 }' /usr/share/zoneinfo/tzdata.zi | while read -d $'\n' timezone; do
    echo $timezone
    sed -i "s|TZ: .*\$|TZ: $timezone|" docker-compose.yml
    docker-compose up --wait 2> /dev/null
    wait_ghost
    export TZ=$timezone
    current_timestamp=`date +'%Y-%m-%d %H:%M:%S'`
    docker-compose logs --no-log-prefix ghost | awk '$1 ~ /^\[/{ print substr($0,2,19) }' | while read -d $'\n' log_timestamp; do
        [ "`dateutils.ddiff -f %M "$current_timestamp" "$log_timestamp"`" != "0" ] && echo "❌ $timezone $current_timestamp $log_timestamp"
    done
done
