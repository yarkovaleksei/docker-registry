# Docker Registry

Быстрый способ развернуть свой Docker Registry сервер на VPS.

Помимо Docker Registry включает в себя так же `Nginx` и `Certbot` для автоматического получения и обновления SSL сертификатов.
- - -

## Начало

Дальнейшее описание будет с учётом того, что VPS включён, на нём установлен `docker` и `docker-compose`, доменное имя куплено и привязано к IP адресу VPS сервера, иначе `Certbot` не сможет получить сертификат.

Перед началом надо клонировать репозиторий и перейти в каталог проекта:
```
$ git clone git@github.com:yarkovaleksei/docker-registry.git
$ cd docker-registry
```
- - -

## Файловая структура

```
docker-registry/
├── nginx
│   ├── default.conf  <-----------------  Основной конфиг Nginx
│   └── nginx-override.conf  <----------  Здесь модно переопределить параметры в секции `http`, чтобы не переопределять весь конфиг
├── docker-compose.yml  <---------------  Файл конфигурации `docker-compose`, отвечающий за взаимодействие сервисов
├── init-letsencrypt.sh  <--------------  Скрипт инициализирует первичное получение сертификатов
├── registry
│   ├── auth  <-------------------------  Файлы для авторизации (сгенерируем их на сервере, чтобы не добавлять в репозиторий)
│   └── data  <-------------------------  Здесь будут храниться образы (основное хранилище реестра)
└── ssl_renew.sh  <---------------------  Скрипт который будет добавлен в `crontab` и будет периодически обновлять SSL сертификаты
```

## Конфигурация проекта

Скопируйте файл с переменными окружения и отредактируйте файл `.env`, изменив значения переменных на нужные.
```
$ cp .env.dist .env
```

Отредактируйте файл `init-letsencrypt.sh` (15 и 16 строки), изменив значения переменных так как описано в комментариях. Рекомендую установить переменную `staging` в значение `1`, до того момента, как всё настроите. Иначе велик шанс упереться в лимиты Let's Encrypt и отладка затянется.

Отредактируйте файл `ssl_renew.sh`, изменив полный путь от корня системы до каталога, куда будет размещён этот репозиторий на VPS, например `/docker-registry`.
- - -

## Nginx и переменные окружения

В конфигах `Nginx` можно использовать переменные окружения. Это достигается за счёт скрипта `/docker-entrypoint.d/20-envsubst-on-templates.sh` в составе образа `nginx:stable-alpine`.

Перед стартом `Nginx` выполняются скрипты в каталоге `/docker-entrypoint.d`. Скрипт `20-envsubst-on-templates.sh` берёт файлы с расширением `.template` из каталога `/etc/nginx/templates` и заменяет шаблонные выражения на значения переменных окружения. После этого у файла из имени убирается `.template` и он помещается в каталог `/etc/nginx/conf.d`.
- - -

## Перенос на VPS

Для переноса проекта на VPS воспользуйтесь любым удобным для вас способом. Я буду использовать `rsync`.

Войдите на VPS по ssh и создайте каталог, который вы указали в скрипте `ssl_renew.sh`:
```
$ ssh root@IP-сервера
$ mkdir -p /docker-registry
$ cd /docker-registry
```

В соседней вкладке терминала на **локальной** машине выполните команду:
```
$ rsync -avzP "${PWD}/" root@IP-сервера:/docker-registry
```

Вы только что скопировали содержимое текущего каталога в каталог `/docker-registry` на вашем VPS.
- - -

## Конфигурация на VPS

Перейдите в каталог `/docker-registry/registry/auth` в терминале VPS сервера и выполните команду:
```
# cd /docker-registry/registry/auth
# apt install apache2-utils
```

Теперь создайте первого пользователя, заменив `username` желаемым именем пользователя. Флаг `-B` указывает, что нужно использовать шифрование `bcrypt`, которое более безопасно, чем шифрование по-умолчанию. Введите пароль в диалоговом окне:
```
# htpasswd -B -c registry.password username
```

Чтобы добавить пользователя или обновить пароль существующего, надо выполнить ту же команду, но без опции `-c`:
```
# htpasswd -B registry.password username
```
- - -

## Первый запуск

Теперь вы готовы к запуску.

Вернитесь в каталог `/docker-registry` и выполните скрипт инициализации `certbot`:
```
# cd /docker-registry
# chmod +x init-letsencrypt.sh
# ./init-letsencrypt.sh
```

Если всё прошло удачно, то в логах вы увидите примерно следующее:
```
# ./init-letsencrypt.sh
### Downloading recommended TLS parameters ...

### Creating dummy certificate for example.com ...
Creating network "docker-registry_app-network" with driver "bridge"
Creating network "docker-registry_default" with the default driver
Pulling registry (registry:2.7.1)...
2.7.1: Pulling from library/registry
12008541203a: Pull complete
Digest: sha256:bac2d7050dc4826516650267fe7dc6627e9e11ad653daca0641437abdf18df27
Status: Downloaded newer image for registry:2.7.1
Pulling nginx (nginx:stable-alpine)...
stable-alpine: Pulling from library/nginx
f81ca69df58f: Pull complete
Digest: sha256:e015192ec74937149dce3aa1feb8af016b7cce3a2896246b623cfd55c14939a6
Status: Downloaded newer image for nginx:stable-alpine
Pulling certbot (certbot/certbot:)...
latest: Pulling from certbot/certbot
339de151aab4: Pull complete
Digest: sha256:c62b7ca0d8a064a9a260ee331adbe25abb1802ed104abe85a3e02062bbcf9d60
Status: Downloaded newer image for certbot/certbot:latest
Creating registry ... done
Creating nginx    ... done
Creating docker-registry_certbot_run ... done
Generating a RSA private key
..........................................................++++
...................++++
writing new private key to '/etc/letsencrypt/live/example.com/privkey.pem'
-----

### Starting nginx ...
Recreating registry ... done
Recreating nginx    ... done

### Deleting dummy certificate for example.com ...
Creating docker-registry_certbot_run ... done

### Requesting Let's Encrypt certificate for example.com ...
Creating docker-registry_certbot_run ... done
Saving debug log to /var/log/letsencrypt/letsencrypt.log
Plugins selected: Authenticator webroot, Installer None
Account registered.
Requesting a certificate for example.com and www.example.com
Performing the following challenges:
http-01 challenge for example.com
http-01 challenge for www.example.com
Using the webroot path /var/www/certbot for all unmatched domains.
Waiting for verification...
Cleaning up challenges

IMPORTANT NOTES:
 - Congratulations! Your certificate and chain have been saved at:
   /etc/letsencrypt/live/example.com/fullchain.pem
   Your key file has been saved at:
   /etc/letsencrypt/live/example.com/privkey.pem
   Your certificate will expire on 2021-08-17. To obtain a new or
   tweaked version of this certificate in the future, simply run
   certbot again. To non-interactively renew *all* of your
   certificates, run "certbot renew"

### Reloading nginx ...
2021/05/19 17:43:43 [notice] 39#39: signal process started

```

Всё прошло успешно. Можно переходить к настройкам.

Отредактируйте файл `init-letsencrypt.sh`, установив переменную `staging` в значение `0`. Теперь остановите контейнер и снова запустите скрипт:
```
# docker-compose down
# ./init-letsencrypt.sh
```

Скрипт увидит, что в каталоге `/docker-registry/certbot` что-то есть и спросит - заменить содержимое или перезаписать. Смело жмите `y` и `Enter`.

Поздравляю! Теперь ваш собственный Docker Registry доступен по адресу `https://example.com`.

Откройте в браузере `https://example.com/v2`. В появившейся форме введите логин и пароль, который задавали при создании файла `registry.password`. После авторизации вы должны увидеть на странице `{}`.
- - -

## Автообновление SSL сертификата

Let's Encrypt выдаёт сертификат сроком 90 дней, но можно периодически запрашивать и обновлять его. Для этого у нас есть скрипт `ssl_renew.sh`. Для начала сделаем его исполняемым:
```
# chmod +x ssl_renew.sh
```

Далее откройте root-файл crontab для запуска скрипта обновления с заданным интервалом:
```
# crontab -e
```

Если вы в первый раз редактируете этот файл, вам будет предложено выбрать редактор:
```
no crontab for root - using an empty one

Select an editor.  To change later, run 'select-editor'.
  1. /bin/nano        <---- easiest
  2. /usr/bin/vim.basic
  3. /usr/bin/vim.tiny
  4. /bin/ed

Choose 1-4 [1]:
```

Добавьте внизу файла следующую строку:
```
...
*/5 * * * * /docker-registry/ssl_renew.sh >> /var/log/cron.log 2>&1
```

В результате будет установлен интервал в 5 минут для выполнения работы, и вы можете проверить, работает ли запрос обновления так, как предполагается. Также мы создали файл журнала, `cron.log`, чтобы записывать соответствующий вывод выполнения задания.

Через 5 минут проверьте `cron.log`, чтобы убедиться, что запрос обновления выполнен успешно:
```
# tail -f /var/log/cron.log
```

Вы должны увидеть примерно следующее:
```
Creating docker-registry_certbot_run ...
Creating docker-registry_certbot_run ... done
Saving debug log to /var/log/letsencrypt/letsencrypt.log

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Processing /etc/letsencrypt/renewal/example.com.conf
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Cert not due for renewal, but simulating renewal for dry run
Plugins selected: Authenticator webroot, Installer None
Simulating renewal of an existing certificate for example.com and www.example.com
Performing the following challenges:
http-01 challenge for example.com
http-01 challenge for www.example.com
Using the webroot path /var/www/certbot for all unmatched domains.
Waiting for verification...
Cleaning up challenges

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
new certificate deployed without reload, fullchain is
/etc/letsencrypt/live/example.com/fullchain.pem
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Congratulations, all simulated renewals succeeded:
  /etc/letsencrypt/live/example.com/fullchain.pem (success)
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Killing nginx ...
Killing nginx ... done
```

Также вы можете удалить параметр `--dry-run` из скрипта `ssl_renew.sh`.

Сделаем его исполняемым:
```
# chmod +x ssl_renew.sh
```

Теперь вы можете изменить файл `cron-file.txt` для настройки ежедневного интервала. Чтобы запускать скрипт каждые 12 часов, например, вы должны изменить последнюю строку файла, которая должна выглядеть следующим образом:
```
0 12 * * * /docker-registry/ssl_renew.sh >> /var/log/cron.log
```

Теперь укажем утилите `crontab` наш  файл:
```
# crontab cron-file.txt
```

И проверим что сохранилось:
```
# crontab -l
0 12 * * * /docker-registry/ssl_renew.sh >> /var/log/cron.log
```

Ваше задание `cron` гарантирует, что ваши сертификаты не окажутся устаревшими, обновляя их в случае истечения срока действия.
- - -

## Публикация в реестре

Создайте на своей локальной машине небольшой пустой образ для отправки в новый реестр. Флаги `-i` и `-t` обеспечивают доступ к контейнеру через интерактивную оболочку:
```
$ docker run -t -i ubuntu /bin/bash
```

После завершения выгрузки вы попадете в диалог Docker. Обратите внимание, что идентификатор контейнера после `root@` может отличаться. Внесите быстрые изменения в файловую систему, создав файл с именем `SUCCESS`. На следующем шаге вы сможете использовать данный файл, чтобы определить, была ли публикация успешной:
```
root@f7e13d5464d1:/# touch /SUCCESS
```

Выход из контейнера Docker:
```
root@f7e13d5464d1:/# exit
```

Следующая команда создает новый образ под названием `test-image` на основе уже запущенного образа и всех внесенных изменений. В нашем случае добавление файла `/SUCCESS` включается в новый образ.

Сохраните изменение:
```
$ docker commit $(docker ps -lq) test-image
```

Сейчас образ существует только на локальном компьютере. Теперь вы можете отправить его в новый реестр, который вы создали. Войдите в свой реестр Docker:
```
$ docker login https://example.com
```

Введите `username` и соответствующий пароль, который задавали при создании файла `registry.password`. Затем поставьте для образа метку расположения частного реестра, чтобы отправить туда образ
```
$ docker tag test-image example.com/test-image
```

Отправьте образ с меткой в реестр:
```
$ docker push example.com/test-image
```

Вы должны увидеть примерно следующее:
```
The push refers to a repository [example.com/test-image]
e3fbbfb44187: Pushed
5f70bf18a086: Pushed
a3b5c80a4eba: Pushed
7f18b442972b: Pushed
3ce512daaf78: Pushed
7aae4540b42d: Pushed
latest: digest: sha256:e37b78552ffa5389b1d74d2be70a9159075f11716416c3a430f4c0f6512e2f34 size: 1150
```

> Вы убедились, что ваш реестр успешно выполняет аутентификацию пользователей, и что прошедшие аутентификацию пользователи могут отправлять образы в реестр. Теперь вы должны убедиться, что вы можете извлекать образы из реестра.

## Извлечение образов из реестра

Для теста можно воспользоваться другим компьютером, где ещё нет образа `example.com/test-image`, либо удалить образ на текущеё машине:
```
$ docker image rm test-image
```

Убедитесь что образ удалён:
```
$ docker image ls | grep test-image
```

Вы не должны увидеть ни одной строчки в результате выполнения команды.

Теперь попробуйте получить образ из реестра:
```
$ docker pull example.com/test-image
```

Docker загрузит образ и вернется в командную строку. Если вы запустите образ, то увидите, что ранее созданный файл `SUCCESS` находится в этом образе:
```
$ docker run -it example.com/test-image /bin/bash
```

Выведите список файлов в оболочке bash:
```
$ ls
```

Вы увидите файл SUCCESS, который вы создали для этого образа:
```
SUCCESS  bin  boot  dev  etc  home  lib  lib64  media   mnt  opt  proc  root  run  sbin  srv  sys  tmp  usr  var
```

Поздравляю! Вы завершили настройку защищенного реестра для отправки и получения образов.
