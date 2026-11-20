FROM php:8.2-apache

# Aplikasi memakai PDO MySQL
RUN docker-php-ext-install pdo_mysql \
 && a2enmod headers

COPY docker/php.ini /usr/local/etc/php/conf.d/zz-eltru.ini

COPY --chown=www-data:www-data . /var/www/html/
RUN rm -rf /var/www/html/docker

# Folder yang ditulis aplikasi saat upload (foto profil & materi)
RUN chown -R www-data:www-data /var/www/html/asset/user /var/www/html/materi

EXPOSE 80
