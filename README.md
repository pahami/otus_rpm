# Тема: RPM

## Описание домашнего задания 
### Размещаем свой RPM в своем репозитории
  1. Создать свой RPM пакет (можно взять свое приложение, либо собрать, например, NGINX с определенными опциями).
  2. Создать свой репозиторий и разместить там ранее собранный RPM.

  Реализовать это все либо в Vagrant, либо развернуть у себя через Nginx и дать ссылку на репозиторий.

  Задание выполнено при помощи скрипта rpm.sh который запускается при создании виртуальной машины командой 'vagrant up'. Создания ВМ можно подключиться командой 'vagrant ssh'

Для проверки можете можно проверить репозиторий:
```
curl -a http://localhost/repo/
yum list | grep otus
```


  1. Настроить рабочий стенд
  2. Основная часть: 
    - vagrant up должен поднимать 2 настроенных виртуальных машины (сервер NFS и клиента) без дополнительных ручных действий;
    - на сервере NFS должна быть подготовлена и экспортирована директория; 
    - в экспортированной директории должна быть поддиректория с именем upload с правами на запись в неё; 
    - экспортированная директория должна автоматически монтироваться на клиенте при старте виртуальной машины (systemd, autofs или fstab — любым способом);
    - монтирование и работа NFS на клиенте должна быть организована с использованием NFSv3.
  3. Для самостоятельной реализации: 
    - настроить аутентификацию через KERBEROS с использованием NFSv4.


## Выполнение задания:

### 1. Настройка рабочего стенда

Выполнение домашнего задания предполагает, что на компьютере установлен Vagrant+VirtualBox   

Развернем Vagrant-стенд:
  - Создайте папку с проектом и зайдите в нее (например: /otus_rpm):
```
mkdir -p otus_rpm ; cd ./otus_rpm
```
  - Клонируете проект с Github, набрав команду:
```
apt update -y && apt install git -y ; git clone https://github.com/pahami/otus_rpm.git
```
  - Запустите проект из папки, в которую склонировали проект (в нашем примере ./otus_rpm):
```
vagrant up
```
  - Подключиться к созданной виртуальной машине
```
vagrant ssh
```
  - Дальнейшие действия выполняются от пользователя root. Переходим в root пользователя
```
sudo -iyum install -y wget rpmdevtools rpm-build createrepo \
yum-utils cmake gcc git nano
```
  - Загрузим SRPM пакет Nginx для дальнейшей работы над ним:
```
mkdir rpm && cd rpm
yumdownloader --source nginx
```
  - При установке такого пакета в домашней директории создается дерево каталогов для сборки, далее поставим все зависимости для сборки пакета Nginx:



### Создание своего RPM пакета с добавлением модуля для NGINX ngx_broli

  - Для данного задания нам понадобятся следующие установленные пакеты:
```
rpm -Uvh nginx*.src.rpm
```
PS При выполнении будут ошибки:
```
warning: user mockbuild does not exist - using root
warning: group mock does not exist - using root
```
Эти предупреждения появляются при попытке установить или обновить пакеты с использованием утилиты mock, которая создает изолированную среду для сборки RPM-пакетов. Они указывают на отсутствие пользователя mockbuild и группы mock, которые необходимы для правильной работы mock. В нашем случае данную ошибку можно игнорировать.
```
yum-builddep nginx
```

  - Скачиваем исходный код модуля ngx_brotli — он потребуется при сборке:
```
cd /root
git clone --recurse-submodules -j8 https://github.com/google/ngx_brotli
cd ngx_brotli/deps/brotli
mkdir out && cd out
```
  - Собираем модуль ngx_brotli:
```
cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DCMAKE_C_FLAGS="-Ofast -m64 -march=native -mtune=native -flto -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections" -DCMAKE_CXX_FLAGS="-Ofast -m64 -march=native -mtune=native -flto -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections" -DCMAKE_INSTALL_PREFIX=./installed ..
cmake --build . --config Release -j 2 --target brotlienc
cd ../../../..
```
  - Поправим сам spec файл, чтобы Nginx собирался с необходимыми нам опциями: находим секцию с параметрами configure (до условий if) и добавляем указание на модуль (не забудьте указать завершающий обратный слэш):
```
--add-module=/root/ngx_brotli \
```
  - Приступаем к сборке RPM пакета:
```
cd ~/rpmbuild/SPECS/
rpmbuild -ba nginx.spec -D 'debug_package %{nil}'
```
  - Копируем пакеты в общий каталог:
```
cp ~/rpmbuild/RPMS/noarch/* ~/rpmbuild/RPMS/x86_64/
cd ~/rpmbuild/RPMS/x86_64
```
  - Теперь можно установить наш пакет и убедиться, что nginx работает:
```
yum localinstall *.rpm
systemctl start nginx
systemctl status nginx
```
Далее мы будем использовать его для доступа к своему репозиторию.


### Создание своего репозитория и размещение там ранее собранного RPM
  
  - Теперь приступим к созданию своего репозитория. Директория для статики у Nginx по умолчанию /usr/share/nginx/html. Создадим там каталог repo:
```
mkdir /usr/share/nginx/html/repo
```
  - Копируем туда наши собранные RPM-пакеты:
```
cp ~/rpmbuild/RPMS/x86_64/*.rpm /usr/share/nginx/html/repo/
```
  - Инициализируем репозиторий командой:
```
createrepo /usr/share/nginx/html/repo/
```
  - Настроим в NGINX доступ к листингу каталога. В файле /etc/nginx/nginx.conf в блоке server добавим следующие директивы:
```
	index index.html index.htm;
	autoindex on;
```
  - Проверяем синтаксис и перезапускаем NGINX:
```
nginx -t
```
<details>

<summary> Вывод результата </summary>

```
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```
</details>

```
nginx -s reload
```
  - Можно посмотреть в браузере или с помощью curl:
```
curl -a http://localhost/repo/

<details>

<summary> Вывод результата </summary>

```

<a href="repodata/">repodata/</a>                                          12-Jan-2025 19:16                   -
<a href="nginx-1.20.1-20.el9.alma.1.x86_64.rpm">nginx-1.20.1-20.el9.alma.1.x86_64.rpm</a>              12-Jan-2025 19:16               36229
<a href="nginx-all-modules-1.20.1-20.el9.alma.1.noarch.rpm">nginx-all-modules-1.20.1-20.el9.alma.1.noarch.rpm</a>  12-Jan-2025 19:16                7341
<a href="nginx-core-1.20.1-20.el9.alma.1.x86_64.rpm">nginx-core-1.20.1-20.el9.alma.1.x86_64.rpm</a>         12-Jan-2025 19:16              593388
<a href="nginx-filesystem-1.20.1-20.el9.alma.1.noarch.rpm">nginx-filesystem-1.20.1-20.el9.alma.1.noarch.rpm</a>   12-Jan-2025 19:16                8424
<a href="nginx-mod-devel-1.20.1-20.el9.alma.1.x86_64.rpm">nginx-mod-devel-1.20.1-20.el9.alma.1.x86_64.rpm</a>    12-Jan-2025 19:16              759610
<a href="nginx-mod-http-image-filter-1.20.1-20.el9.alma.1.x86_64.rpm">nginx-mod-http-image-filter-1.20.1-20.el9.alma...&gt;</a> 12-Jan-2025 19:16               19351
<a href="nginx-mod-http-perl-1.20.1-20.el9.alma.1.x86_64.rpm">nginx-mod-http-perl-1.20.1-20.el9.alma.1.x86_64..&gt;</a> 12-Jan-2025 19:16               30994
<a href="nginx-mod-http-xslt-filter-1.20.1-20.el9.alma.1.x86_64.rpm">nginx-mod-http-xslt-filter-1.20.1-20.el9.alma.1..&gt;</a> 12-Jan-2025 19:16               18150
<a href="nginx-mod-mail-1.20.1-20.el9.alma.1.x86_64.rpm">nginx-mod-mail-1.20.1-20.el9.alma.1.x86_64.rpm</a>     12-Jan-2025 19:16               53793
<a href="nginx-mod-stream-1.20.1-20.el9.alma.1.x86_64.rpm">nginx-mod-stream-1.20.1-20.el9.alma.1.x86_64.rpm</a>   12-Jan-2025 19:16               80419
<a href="percona-release-latest.noarch.rpm">percona-release-latest.noarch.rpm</a>                  04-Jul-2024 09:46               27900

```
</details>

  - Все готово для того, чтобы протестировать репозиторий.
  - Добавим его в /etc/yum.repos.d:
```
cat >> /etc/yum.repos.d/otus.repo << EOF
[otus]
name=otus-linux
baseurl=http://localhost/repo
gpgcheck=0
enabled=1
EOF
```
  - Убедимся, что репозиторий подключился и посмотрим, что в нем есть:
yum repolist enabled | grep otus
```
otus otus-linux
```
  - Добавим пакет в наш репозиторий:
```
cd /usr/share/nginx/html/repo/
wget https://repo.percona.com/yum/percona-release-latest.noarch.rpm
```
  - Обновим список пакетов в репозитории:
createrepo /usr/share/nginx/html/repo/
yum makecache
yum list | grep otus
<details>
<summary> Вывоод результата </summary>
```
percona-release.noarch 	1.0-27 		otus
```
</details>

  - Установим percona из нашего репозитория
```
yum install -y percona-release.noarch
```
Все прошло успешно. В случае, если вам потребуется обновить репозиторий (а это
делается при каждом добавлении файлов) снова, то выполните команду
```
createrepo /usr/share/nginx/html/repo/.
```
