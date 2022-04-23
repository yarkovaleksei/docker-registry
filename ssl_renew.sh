#!/bin/bash

# Запускаем certbot из контейнера, просим обновить сертификат и посылаем сигнал перезагрузки сервису nginx
# Когда настройка будет завершена - удалите опцию --dry-run, чтобы скрипт обновлял сертификат, а не эмулировал обновление
/usr/local/bin/docker-compose -f /docker-registry/docker-compose.yml run certbot renew --no-random-sleep-on-renew --dry-run
/usr/local/bin/docker-compose -f /docker-registry/docker-compose.yml kill -s SIGHUP nginx
/usr/local/bin/docker-compose -f /docker-registry/docker-compose.yml stop certbot
