# docker-phalcon4

## Description

Docker container for PHP development with Phalcon4 using PHP-fpm, Nginx and the supervisor. On Docker Hub: dzooli/php-phalcon4.

### Installed tools

- composer
- phalcon-devtools
- phalcon-migrations
- nano
- iproute2

### Installed PHP extensions

- apcu
- opcache
- pdo_mysql
- pdo_pgsql
- xdebug

## Usage

```bash
docker run -v "$(pwd)"/src:/var/www/html -p 8080:80 dzooli/php-phalcon4
```
