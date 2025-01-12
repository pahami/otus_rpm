#!/bin/bash

# Установка необходимых зависимостей
yum install -y wget rpmdevtools rpm-build createrepo yum-utils cmake gcc git nano

# Скачивание исходников Nginx
mkdir -p /root/rpm
cd /root/rpm
yumdownloader --source nginx

# Установка зависимостей для сборки Nginx
rpm -ivh nginx*.src.rpm
yum-builddep nginx -y

# Клонируем репозиторий ngx_brotli
cd /root
git clone --recurse-submodules -j8 https://github.com/google/ngx_brotli

# Компиляция библиотеки Brotli
cd ngx_brotli/deps/brotli
mkdir out && cd out
cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DCMAKE_C_FLAGS="-Ofast -m64 -march=native -mtune=native -flto -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections" -DCMAKE_CXX_FLAGS="-Ofast -m64 -march=native"
cmake --build . --config Release -j 2 --target brotlienc

# Редактирование spec-файла Nginx для включения модуля Brotli
cd ../../../..
sed -i '/--with-debug/a\--add-module=/root/ngx_brotli \\' ~/rpmbuild/SPECS/nginx.spec
cd ~/rpmbuild/SPECS/
rpmbuild -ba nginx.spec -D 'debug_package %{nil}'
cp ~/rpmbuild/RPMS/noarch/* ~/rpmbuild/RPMS/x86_64/
cd ~/rpmbuild/RPMS/x86_64
yum localinstall -y *.rpm
systemctl start nginx

# Создание своего репозитория и размещение там ранее собранного RPM
#Добавляем директорию для репозитория и переносим туда собранные rpm пакеты
mkdir /usr/share/nginx/html/repo
cp ~/rpmbuild/RPMS/x86_64/*.rpm /usr/share/nginx/html/repo/
createrepo /usr/share/nginx/html/repo/

# Добавляем настройки в nginx.conf

sed -i '/server {/a \
index index.html index.htm; \
autoindex on;' /etc/nginx/nginx.conf

# Добавляем репозиторий в /etc/yum.repos.d:
cat >> /etc/yum.repos.d/otus.repo << EOF
[otus]
name=otus-linux
baseurl=http://localhost/repo
gpgcheck=0
enabled=1
EOF

nginx -s reload

# Добавляем пакет percona в наш репозиторий
cd /usr/share/nginx/html/repo/
wget https://repo.percona.com/yum/percona-release-latest.noarch.rpm
# Обновляем список пакетов в репозитории:
createrepo /usr/share/nginx/html/repo/
yum makecache
# Установим репозиторий percona-release
yum install -y percona-release.noarch
