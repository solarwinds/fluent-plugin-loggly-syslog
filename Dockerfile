FROM fluent/fluentd:v1.7-2

# Use root account to use apk
USER root

# below RUN includes plugins - you may customize including plugins as you wish
RUN apk add --no-cache --update --virtual .build-deps \
        sudo build-base ruby-dev git \
 && sudo gem install fluent-plugin-loggly-syslog \
 && sudo gem sources --clear-all \
 && apk del .build-deps \
 && rm -rf /tmp/* /var/tmp/* /usr/lib/ruby/gems/*/cache/*.gem

USER fluent