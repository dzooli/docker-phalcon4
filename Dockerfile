FROM php:7.4-fpm AS phalcon

LABEL maintainer="MilesChou <github.com/MilesChou>, fizzka <github.com/fizzka>, ZoltanFabian <zoltan.dzooli.fabian@gmail.com>"
LABEL name="Phalcon4-Nginx"
LABEL version="1.0.0"

ARG PHALCON_VERSION=4.1.2
ARG PHALCON_EXT_PATH=php7/64bits
ARG DEBIAN_FRONTEND=noninteractive

# Setup dpkg and install Phalcon
RUN     /bin/sh -c set -xe \
    && echo '#!/bin/sh' > /usr/sbin/policy-rc.d \
    && echo 'exit 101' >> /usr/sbin/policy-rc.d \
    && chmod +x /usr/sbin/policy-rc.d \
    && dpkg-divert --local --rename --add /sbin/initctl \
    && cp -a /usr/sbin/policy-rc.d /sbin/initctl \
    && sed -i 's/^exit.*/exit 0/' /sbin/initctl \
    && echo 'force-unsafe-io' > /etc/dpkg/dpkg.cfg.d/docker-apt-speedup \
    && echo 'DPkg::Post-Invoke { "rm -f /var/cache/apt/archives/*.deb /var/cache/apt/archives/partial/*.deb /var/cache/apt/*.bin || true"; };' > /etc/apt/apt.conf.d/docker-clean \
    && echo 'APT::Update::Post-Invoke { "rm -f /var/cache/apt/archives/*.deb /var/cache/apt/archives/partial/*.deb /var/cache/apt/*.bin || true"; };' >> /etc/apt/apt.conf.d/docker-clean \
    && echo 'Dir::Cache::pkgcache ""; Dir::Cache::srcpkgcache "";' >> /etc/apt/apt.conf.d/docker-clean \
    && echo 'Acquire::Languages "none";' > /etc/apt/apt.conf.d/docker-no-languages \
    && echo 'Acquire::GzipIndexes "true"; Acquire::CompressionTypes::Order:: "gz";' > /etc/apt/apt.conf.d/docker-gzip-indexes \
    && echo 'Apt::AutoRemove::SuggestsImportant "false";' > /etc/apt/apt.conf.d/docker-autoremove-suggests \
    && mkdir -p /run/systemd && echo 'docker' > /run/systemd/container && \
    apt update && \
    apt install -y git unzip locales libzip-dev apt-utils libzip4 && \
    /usr/local/bin/pecl channel-update pecl.php.net && \
    /usr/local/bin/pecl install psr && \
    docker-php-source extract && \
    docker-php-ext-install zip && \
    docker-php-ext-enable psr && \
    # Additional speedup
    docker-php-ext-enable opcache && \
    # Compile Phalcon
    curl -LO https://github.com/phalcon/cphalcon/archive/v${PHALCON_VERSION}.tar.gz && \
    tar xzf ${PWD}/v${PHALCON_VERSION}.tar.gz && \
    docker-php-ext-install -j $(getconf _NPROCESSORS_ONLN) ${PWD}/cphalcon-${PHALCON_VERSION}/build/${PHALCON_EXT_PATH} && \
    # Remove all temp files
    rm -r \
    ${PWD}/v${PHALCON_VERSION}.tar.gz \
    ${PWD}/cphalcon-${PHALCON_VERSION} && \
    echo '\
    opcache.interned_strings_buffer=16\n\
    opcache.load_comments=Off\n\
    opcache.max_accelerated_files=16000\n\
    opcache.save_comments=Off\n\
    ' >> /usr/local/etc/php/conf.d/docker-php-ext-opcache.ini

# Supervisor, extensions, composer, Phalcon-devtools and Nginx
FROM phalcon AS phalcon-nginx

ARG DEBIAN_FRONTEND=noninteractive
ARG ENV=development

ENV TZ=Europe/Budapest
ENV LANG=en_US.UTF-8
ENV TERM=linux

WORKDIR /

COPY config/supervisord.conf /etc/supervisord.conf
COPY scripts/entrypoint.sh /entrypoint.sh
COPY config/99-additional.ini /usr/local/etc/php/conf.d/

RUN apt -y install apt-utils libzip4 libzip-dev git unzip locales iproute2 nano supervisor nginx-light && \
    docker-php-ext-install zip && \
    docker-php-source extract && \
    pecl install apcu && \
    pecl install xdebug && \
    docker-php-ext-enable xdebug && \
    docker-php-ext-enable apcu && \
    locale-gen && \
    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
    php composer-setup.php --filename=composer --install-dir=/usr/bin --2 && \
    rm composer-setup.php && \
    echo 'chdir=/var/www/html' >> /usr/local/etc/php-fpm.d/www.conf && \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && \
    echo $TZ > /etc/timezone && \
    cp /usr/local/etc/php/php.ini-${ENV} /usr/local/etc/php/php.ini && \
    composer global require phalcon/devtools -vv -o && \
    composer global require phalcon/migrations -vv -o && \
    ln -s /root/.composer/vendor/bin/phalcon /usr/local/bin/phalcon && \
    ln -s /root/.composer/vendor/bin/phalcon-migrations /usr/local/bin/phalcon-migrations && \
    ln -s /root/.composer/vendor/bin/psysh /usr/local/bin/psysh && \
    chmod u+x /entrypoint.sh && \
    mkdir /var/log/php-fpm && \
    chown www-data /var/log/php-fpm && \
    chown -R www-data /var/www/html

COPY config/default.conf /etc/nginx/sites-available/default

ENTRYPOINT /entrypoint.sh

# Database connection extensions for PHP
FROM phalcon-nginx AS db-extensions

RUN apt install -y libpq-dev && \
    docker-php-source extract && \
    docker-php-ext-configure pdo_mysql --with-pdo-mysql=mysqlnd && \
    docker-php-ext-configure mysqli --with-mysqli=mysqlnd && \
    docker-php-ext-install pdo_mysql && \
    docker-php-ext-install pdo_pgsql && \
    docker-php-ext-enable pdo_pgsql && \
    /usr/local/bin/pecl clear-cache && \
    apt remove -y libzip-dev zlib1g-dev libxml2-dev libicu-dev \
    libc6-dev unixodbc-dev linux-libc-dev \
    libgcc-8-dev libbinutils binutils \
    binutils-common && \
    rm -rf /tmp/pear && \
    apt clean && \
    apt -y autoremove && \
    docker-php-source delete

WORKDIR /var/www/html
