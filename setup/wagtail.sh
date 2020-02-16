#!/bin/bash
# Startup basic wagtail project
# -------------------------------------------
# This will include gunicorn and postgresgl

source /etc/mailinabox.conf # get global vars
source setup/functions.sh # load our functions
source /etc/mailinabox.conf # load global vars

# Install packages and basic configuration
# ----------------------------------------

# Install packages.
echo "Installing Wagtail, gunicorn, and postgresql..."

hide_output pip3 install cookiecutter
apt_install build-essential
apt_install postgresql-server-dev-all

RETURN_TO=$(pwd)
mkdir "$WAGTAIL_LOC" || echo ''
cd "$WAGTAIL_LOC"

#WAGTAIL_PROJ=$(ls -td -- */ | head -n 1)
#mkdir "$WAGTAIL_PROJ" || echo ''
#
if [ ! -d ~/.cookiecutters/ ]; then
  mkdir ~/.cookiecutters/ || echo ''
fi
if [ ! -d ~/.cookiecutters/cookiecutter-django/ ]; then
  mkdir ~/.cookiecutters/cookiecutter-django/ || echo ''
fi

git clone https://github.com/pydanny/cookiecutter-django ~/.cookiecutters/cookiecutter-django/ || echo ''


cat > ~/.cookiecutters/cookiecutter-django/cookiecutter.json << EOF;
{
	"project_name": "$WAGTAIL_PROJ",
	"project_slug": "$WAGTAIL_PROJ",
	"description": "A project made with mailinabox plus wagtail",
	"author_name": "${EMAIL_ADDR%%@*}",
	"domain_name": "$PRIMARY_HOSTNAME",
	"email": "$EMAIL_ADDR",
	"version": "0.1.0",
	"open_source_license": "GPLv3",
	"timezone": "UTC",
	"windows": "n",
	"use_pycharm": "n",
	"use_docker": "n",
	"postgresql_version": "11.3",
	"js_task_runner": "Gulp",
	"cloud_provider": "None",
	"use_drf": "n",
	"custom_bootstrap_compilation": "y",
	"use_compressor": "y",
	"use_celery": "n",
	"use_mailhog": "n",
	"use_sentry": "n",
	"use_whitenoise": "y",
	"use_heroku": "n",
	"ci_tool": "None",
	"keep_local_envs_in_vcs": "y",
	"debug": "n"
}
EOF

#cookiecutter https://github.com/pydanny/cookiecutter-django
cookiecutter ~/.cookiecutters/cookiecutter-django/

hide_output pip3 install -r $WAGTAIL_PROJ/requirements/production.txt

cat > /etc/systemd/system/gunicorn.socket << EOF;
[Unit]
Description=gunicorn socket

[Socket]
ListenStream=/run/gunicorn.sock

[Install]
WantedBy=sockets.target
EOF


cat > /etc/systemd/system/gunicorn.service << EOF;
[Unit]
Description=gunicorn daemon
Requires=gunicorn.socket
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=$WAGTAIL_LOC/$WAGTAIL_PROJ
ExecStart=/usr/local/bin/gunicorn \
  --access-logfile - \
  --workers 3 \
  --bind unix:/run/gunicorn.sock \
  $WAGTAIL_PROJ.wsgi:application

[Install]
WantedBy=multi-user.target
EOF


systemctl start gunicorn
systemctl enable gunicorn
#restart_service gunicorn.socket
#systemctl restart nginx

cd "$RETURN_TO" || exit






