FROM alpine:3.19.1

COPY ./sync_script.sh /bin/sync_script

RUN apk --no-cache add bash curl jq libxml2-utils

RUN echo "0 0 * * * /bin/sync_script" > /var/spool/cron/crontabs/root && \
    chmod +x /bin/sync_script

CMD crond -l 2 -f
