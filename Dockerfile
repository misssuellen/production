FROM alpine:3.13

ENV COMPOSER_HOME=/var/cache/composer
ENV PROJECT_ROOT=/sw6
ENV ARTIFACTS_DIR=/artifacts
ENV LD_PRELOAD=/usr/lib/preloadable_libiconv.so

# Copy composer.lock and composer.json
COPY composer.lock composer.json $PROJECT_ROOT/

# install all dependencies
RUN apk --no-cache add \
        nginx supervisor curl zip rsync xz coreutils \
        php7 php7-fpm \
        php7-ctype php7-curl php7-dom php7-fileinfo php7-gd \
        php7-iconv php7-intl php7-json php7-mbstring \
        php7-mysqli php7-openssl php7-pdo_mysql \
        php7-session php7-simplexml php7-tokenizer php7-xml php7-xmlreader php7-xmlwriter \
        php7-zip php7-zlib php7-phar php7-opcache php7-sodium git \
        gnu-libiconv \
    && rm /etc/nginx/conf.d/default.conf \
    && mkdir -p /var/cache/composer


# Install composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Copy system configs
COPY config/etc /etc

# Add user for shopware application
RUN adduser -u 1000 -D -h $PROJECT_ROOT sw6 sw6
# Copy existing application directory contents
COPY . $PROJECT_ROOT

# Copy existing application directory permissions
COPY --chown=sw6:sw6 . $PROJECT_ROOT

# Make sure files/folders needed by the processes are accessible when they run under the sw6
RUN mkdir -p /var/{lib,tmp,log}/nginx \
    && chown -R sw6.sw6 /run /var/{lib,tmp,log}/nginx \
    && chown -R sw6.sw6 /var/cache/composer

WORKDIR $PROJECT_ROOT

RUN mkdir -p $PROJECT_ROOT/var/cache \
    chown -R sw6.sw6 $PROJECT_ROOT

USER sw6

#ADD --chown=sw6 . .

RUN composer install

RUN chown -R 1000 $PROJECT_ROOT

RUN APP_URL="http://localhost" DATABASE_URL="" bin/console assets:install \
    && rm -Rf var/cache \
    && touch install.lock \
    && mkdir -p var/cache

# Expose the port nginx is reachable on
EXPOSE 8000

# Let supervisord start nginx & php-fpm
ENTRYPOINT ["./bin/entrypoint.sh"]

# Configure a healthcheck to validate that everything is up&running
HEALTHCHECK --timeout=10s CMD curl --silent --fail http://127.0.0.1:8000/fpm-ping
