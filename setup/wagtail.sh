#!/bin/bash
# Startup basic wagtail project
# -------------------------------------------
# This will include gunicorn and postgresgl

source /etc/mailinabox.conf # get global vars
source setup/functions.sh # load our functions

# Install packages and basic configuration
# ----------------------------------------

# Install packages.
echo "Installing Wagtail, gunicorn, and postgresql..."

RETURN_TO=$(pwd)
mkdir "$WAGTAIL_LOC"
cd "$WAGTAIL_LOC"


hide_output pip3 install cookiecutter
cookiecutter https://github.com/pydanny/cookiecutter-django

WAGTAIL_PROJ=$(ls -td -- */ | head -n 1)
cd $WAGTAIL_PROJ
hide_output pip3 install -r requirements/production.txt


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

:'
# This is contained in the web setup
cat > /etc/nginx/sites-available/huetest << EOF;
server {
    listen 80;
    localhost 155.138.238.79;

    location = /favicon.ico { access_log off; log_not_found off; }
    location /root/huetest/huetest/static/ {
        root /root/huetest;
    }

    location / {
        include proxy_params;
        proxy_pass http://unix:/run/gunicorn.sock;
    }
}
EOF
'
restart_service gunicorn.socket

cd "$RETURN_TO" || exit















# Enable the Dovecot antispam plugin.
# (Be careful if we use multiple plugins later.) #NODOC
sed -i "s/#mail_plugins = .*/mail_plugins = \$mail_plugins antispam/" /etc/dovecot/conf.d/20-imap.conf
sed -i "s/#mail_plugins = .*/mail_plugins = \$mail_plugins antispam/" /etc/dovecot/conf.d/20-pop3.conf

chmod a+x /usr/local/bin/sa-learn-pipe.sh

# Create empty bayes training data (if it doesn't exist). Once the files exist,
# ensure they are group-writable so that the Dovecot process has access.
sudo -u spampd /usr/bin/sa-learn --sync 2>/dev/null
chmod -R 660 $STORAGE_ROOT/mail/spamassassin
chmod 770 $STORAGE_ROOT/mail/spamassassin

# Kick services.
restart_service spampd
restart_service dovecot

