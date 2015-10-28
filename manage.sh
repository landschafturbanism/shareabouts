#!/bin/bash

CUR_DIR=$(dirname $(readlink -f $0))
USER=creativesuburbs

WORK_DIR_MAIN=/opt/creativesuburbs
PYTHON_MAIN=$WORK_DIR_MAIN/env/bin/python
GUNICORN_MAIN=$WORK_DIR_MAIN/env/bin/gunicorn
CONF_MAIN=/opt/gunicorn_main.conf.py

WORK_DIR_API=/opt/creativesuburbs_api
PYTHON_API=$WORK_DIR_API/env/bin/python
GUNICORN_API=$WORK_DIR_API/env/bin/gunicorn
CONF_API=/opt/gunicorn_api.conf.py

# init sudo
sudo echo "" > /dev/null

cmd=$1; ! [ -z "$cmd" ] && shift
param1=$1; ! [ -z "$param1" ] && shift

checkps=`ps ax | grep gunicorn | grep -v grep | grep -v sudo`

case $cmd in
    start)
        if [ -n "$checkps" ]; then
            echo "gunicorn seems to be already running"
            exit 133
        fi
        DAEMONFLAG="-D"
        STARTMSG="daemon"
        [ "$param1" = "--debug" ] && DAEMONFLAG="" && STARTMSG="interactive"
        sudo -u $USER sh -c "cd $WORK_DIR_MAIN/src; $PYTHON_MAIN -W ignore $GUNICORN_MAIN -c $CONF_MAIN --chdir $WORK_DIR_MAIN/src project.wsgi:application $DAEMONFLAG"
        sudo -u $USER sh -c "cd $WORK_DIR_API/src; $PYTHON_API -W ignore $GUNICORN_API -c $CONF_API --chdir $WORK_DIR_API/src project.wsgi:application $DAEMONFLAG"
        if [ $? -ne 0 ]; then
            echo "ERROR starting gunicorn"
            exit 127
        else
            echo "Started $STARTMSG"
        fi
        sudo -u $USER sh -c "cd $WORK_DIR_API/src; $PYTHON_API manage.py celery worker -D --concurrency=2 --logfile=/var/log/creativesuburbs/celery.log --pidfile=/tmp/celery.pid"
        sudo service nginx restart
        ;;
    stop)
        if [ -z "$checkps" ]; then
            echo "gunicorn seems to be already stopped"
            exit 132
        fi
        ps ax | grep gunicorn | grep -v grep | grep -v sudo | awk '{print $1}' | xargs -r sudo kill -9
        echo "gunicorn killed"
        ps ax | grep celery | grep -v grep | grep -v sudo | awk '{print $1}' | xargs -r sudo kill -9
        echo "Celery processes killed"
        ;;
    reload)
        ps ax | grep gunicorn | grep -v grep | grep -v sudo | awk '{print $1}' | xargs -r sudo kill -s HUP
        sudo service nginx reload
        ;;
    *)
        echo "ERROR, wrong parameter"
        exit 1
esac
