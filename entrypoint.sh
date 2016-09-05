#!/usr/bin/env bash
set -e

if [ "$1" == 'supervisord' ]; then

    # Increase the maximum watches for inotify for very large repositories to be watched
    # Needs the privilegied docker option
    [ ! -z $MAX_INOTIFY_WATCHES ] && echo fs.inotify.max_user_watches=$MAX_INOTIFY_WATCHES | tee -a /etc/sysctl.conf && sysctl -p || true

    [ -z $UNISON_DIR ] && export UNISON_DIR="/data"

    [ ! -d $UNISON_DIR ] && mkdir -p $UNISON_DIR

    [ -z $UNISON_OWNER ] && export UNISON_OWNER="unison"

    export UNISON_OWNER_HOMEDIR=/home/$UNISON_OWNER

    if [ ! -z $UNISON_OWNER_UID ]; then

        # If uid doesn't exist on the system
        if ! cut -d: -f3 /etc/passwd | grep -q $UNISON_OWNER_UID; then
            echo "no user has uid $UNISON_OWNER_UID"

            # If user doesn't exist on the system
            if ! cut -d: -f1 /etc/passwd | grep -q $UNISON_OWNER; then
                useradd -u $UNISON_OWNER_UID $UNISON_OWNER -m
            else
                usermod -u $UNISON_OWNER_UID $UNISON_OWNER
            fi
        else
            echo "user with uid $UNISON_OWNER_UID already exist"
            existing_user_with_uid=$(awk -F: "/:$UNISON_OWNER_UID:/{print \$1}" /etc/passwd)
            mkdir -p /home/$UNISON_OWNER
            usermod --home /home/$UNISON_OWNER --login $UNISON_OWNER $existing_user_with_uid
            chown -R $UNISON_OWNER /home/$UNISON_OWNER
        fi
    else
        if ! id $UNISON_OWNER; then
            echo "adding user $UNISON_OWNNER".
            useradd -m $UNISON_OWNER
        else
            echo "user $UNISON_OWNNER already exists".
        fi
    fi

    chown -R $UNISON_OWNER:users $UNISON_DIR

    # see https://wiki.alpinelinux.org/wiki/Setting_the_timezone
    if [ -n ${TZ} ] && [ -f /usr/share/zoneinfo/${TZ} ]; then
        ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime
        echo ${TZ} > /etc/timezone
    fi

    # Check if a script is available in /docker-entrypoint.d and source it
    for f in /docker-entrypoint.d/*; do
        case "$f" in
            *.sh)     echo "$0: running $f"; . "$f" ;;
            *)        echo "$0: ignoring $f" ;;
        esac
    done
fi

exec "$@"
