# syntax=docker/dockerfile:1
FROM alpine

ARG APP='null'
ARG VERSION='0'

RUN apk --update --no-cache upgrade && apk --no-cache add thttpd && \
    printf '%s\n' '{"data": {"app": "'$APP'", "version": "'$VERSION'"}}'  \
       >/var/www/http/index.html && \
    printf '%s\n' 'dir=/var/www/http' 'chroot' 'user=thttpd' 'logfile=/dev/stderr' \
       'pidfile=/var/run/thttpd.pid' 'charset=utf-8' 'port=8080' >/etc/thttpd.conf

CMD ["/usr/sbin/thttpd", "-C", "/etc/thttpd.conf", "-D"]
