#!/bin/bash

# предполагается, что на сервере уже развернут postgres, nginx, certbot, установлен apache2-utils для конфигурирования базовой HTTP аутентификации в Nginx

exec > >(tee "$(pwd)"/install_project.log) 2>&1

BASE_DIR=$(pwd)
# Пользователь от имени которого будет запускаться odoo
OE_USER=""
# Репозиторий откуда мы будем брать проект
REPO_URI=""
# Название проекта она же папка проекта
PROJECT_NAME=""
BRANCH_NAME=""
PROJECT_PATH="$BASE_DIR"/"${PROJECT_NAME}"/"${BRANCH_NAME}"
# Настройки для создания конфигурации nginx
WEBSITE_NAME=""
ADMIN_EMAIL=""
# Порты на которых будут работать odoo
PORT_START=""
# Пароль Postgres
PG_PASSW=""
# Мастер-пароль для Odoo
ADMIN_PSW=""
# Универсальный пароль для Odoo
SUPER_ADMIN_PSW=""

create_odoo_config() {
  cat <<EOF >"$PROJECT_PATH"/config_local/odoo-server.conf
[options]
addons_path = $PROJECT_PATH/odoo/addons,
  $PROJECT_PATH/extra_addons/core_addons
admin_passwd = $ADMIN_PSW
auth_admin_passkey_password = $SUPER_ADMIN_PSW
auth_admin_passkey_send_to_user = False
auth_admin_passkey_sysadmin_email = False
csv_internal_sep = ,
data_dir = $PROJECT_PATH/.local
db_host = localhost
db_maxconn = 64
db_name = False
db_password = $PG_PASSW
db_port = 15432
db_sslmode = prefer
db_template = template0
db_user = $PROJECT_NAME-$BRANCH_NAME
dbfilter = 
demo = {}
email_from = False
geoip_database = /usr/share/GeoIP/GeoLite2-City.mmdb
http_enable = True
http_interface = 
http_port = ${PORT_START}69
import_partial = 
limit_memory_hard = 2147483648
limit_memory_soft = 2155872256
limit_request = 8192
limit_time_cpu = 1200
limit_time_real = 1800
limit_time_real_cron = 0
list_db = True
log_db = False
log_db_level = warning
log_handler = :INFO
log_level = info
logfile = $PROJECT_PATH/odoo-server.log
gevent_port = ${PORT_START}72
max_cron_threads = 1
modules_auto_install_disabled = iap,iap_mail,crm_iap_lead_enrich,crm_iap_mine,iap_crb,website_crm_iap_reveal,account_edi,account_edi_proxy_client,account_edi_ubl_cii,snailmail,snailmail_account,partner_autocomplete,sms,calendar_sms,crm_sms,event_sms,project_sms,stock_sms,website_sms,website_crm_sms,mass_mailing_sms,mass_mailing_crm_sms,mass_mailing_event_sms,mass_mailing_event_track_sms,mass_mailing_sale_sms,website_mass_mailing_sms,web_unsplash
modules_auto_install_enabled = module_change_auto_install,base_setup,bus,mail,auth_signup,app_addons_view,auth_admin_passkey,base_technical_features,database_cleanup,date_range,base_sparse_field,queue_job,web_refresher,auditlog,hide_powered_by_and_manage_db,auto_database_backup,base_user_role,chatter_filter,chatter_toggle,simbioz_theme,mail_debrand,mail_tracking,module_auto_update,sentry,server_action_mass_edit,simbioz_dev_tools,web_dialog_size,web_group_expand,web_widget_domain_editor_dialog,rowno_in_tree
osv_memory_age_limit = False
osv_memory_count_limit = False
pg_path = 
pidfile = 
proxy_mode = True
reportgz = False
running_env = test
screencasts = 
screenshots = /tmp/odoo_tests
sentry_auto_log_stacks = False
sentry_dsn = # https://<public_key>:<secret_key>@sentry.example.com/<project id>
sentry_enabled = False
sentry_environment = # production / staging / development
sentry_exclude_loggers = werkzeug
sentry_ignore_exceptions = odoo.exceptions.AccessDenied,odoo.exceptions.AccessError,odoo.exceptions.MissingError,odoo.exceptions.RedirectWarning,odoo.exceptions.UserError,odoo.exceptions.ValidationError,odoo.exceptions.Warning,odoo.exceptions.except_orm
sentry_include_context = True
sentry_logging_level = # notset, debug, info, warn, error, critical
sentry_odoo_dir = # path to odoo_addons
sentry_processors = raven.processors.SanitizePasswordsProcessor,odoo.addons.sentry.logutils.SanitizeOdooCookiesProcessor
sentry_release = 1.3.2
sentry_transport = threaded
server_wide_modules = web,module_change_auto_install,queue_job,mail_tracking,base_sparse_field,sentry,module_auto_update
smtp_password = False
smtp_port = 25
smtp_server = localhost
smtp_ssl = False
smtp_user = False
syslog = False
test_enable = False
test_file = 
test_tags = None
transient_age_limit = 1.0
translate_modules = ['all']
unaccent = False
upgrade_path = 
without_demo = False
workers = 2

[queue_job]
channels = root:2
EOF
}

create_postgres_user() {
  docker exec -it postgres_docker-postgres-1 bash -c "
  PGPASSWORD=\"$PG_PASSW\" createuser -U odoo -s \"$PROJECT_NAME-$BRANCH_NAME\" &&
  PGPASSWORD=\"$PG_PASSW\" psql -U odoo -d postgres -c \"ALTER USER \\\"$PROJECT_NAME-$BRANCH_NAME\\\" WITH PASSWORD '$PG_PASSW' CREATEDB NOCREATEROLE NOSUPERUSER NOREPLICATION;\"
"
}

create_nginx_config() {
  UPSTREAM_ODOO=odoo_${PROJECT_NAME}_$BRANCH_NAME
  UPSTREAM_CHAT=odoo_${PROJECT_NAME}_${BRANCH_NAME}_chat
  cat <<EOF >/tmp/nginx_site.conf
upstream $UPSTREAM_ODOO {
  server 127.0.0.1:${PORT_START}69;
}
upstream $UPSTREAM_CHAT {
  server 127.0.0.1:${PORT_START}72;
}

server {

  # set proper server name after domain set
  server_name $WEBSITE_NAME;

  # Headers for Odoo proxy mode
  proxy_set_header X-Forwarded-Host $host;
  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  proxy_set_header X-Forwarded-Proto $scheme;
  proxy_set_header X-Real-IP $remote_addr;


  # Logs
  access_log /var/log/nginx/${PROJECT_NAME}_$BRANCH_NAME-access.log;
  error_log /var/log/nginx/${PROJECT_NAME}_$BRANCH_NAME-error.log;

  #   increase    proxy   buffer  size
  proxy_buffers 16 64k;
  proxy_buffer_size 128k;
  proxy_read_timeout 900s;
  proxy_connect_timeout 900s;
  proxy_send_timeout 900s;
  proxy_next_upstream error timeout invalid_header http_500 http_502 http_503;

  # Compression
  gzip on;
  gzip_min_length 1100;
  gzip_buffers 4 32k;
  gzip_types text/css text/plain text/xml application/xml application/json application/javascript;
  gzip_vary on;
  client_max_body_size 256m;
EOF
  if [ -f /etc/nginx/.htpasswd ]; then
    cat <<EOF >>/tmp/nginx_site.conf
  # Protect database manager
  location /web/database/ {
    auth_basic "Protected Area";
    auth_basic_user_file /etc/nginx/.htpasswd;
    proxy_pass http://$UPSTREAM_ODOO;
  }
EOF
  fi
  cat <<EOF >>/tmp/nginx_site.conf
  # Odoo main application
  location / {
      proxy_set_header X-Forwarded-Host $http_host;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto $scheme;
      proxy_set_header X-Real-IP $remote_addr;
      proxy_pass http://odoo_simbioz_pms_fams_it_main;
      proxy_redirect off;
  }

  # Websockets (chat, live notifications)
  location /websocket {
      proxy_pass http://odoo_simbioz_pms_fams_it_main_chat;
      proxy_set_header Upgrade $http_upgrade;
      proxy_set_header Connection "Upgrade";
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  }

  # Static files caching
  location ~* \.(js|css|png|jpg|jpeg|gif|ico|woff2?|ttf|svg)$ {
      expires 2d;
      proxy_pass http://odoo_simbioz_pms_fams_it_main;
      add_header Cache-Control "public, no-transform";
  }

  # Static files (Odoo attachments, assets)
  location ~ /[a-zA-Z0-9_-]*/static/ {
      proxy_cache_valid 200 302 60m;
      proxy_cache_valid 404      1m;
      proxy_buffering    on;
      expires 864000;
      proxy_pass http://odoo_simbioz_pms_fams_it_main;
  }

}
EOF
  sudo mv /tmp/nginx_site.conf /etc/nginx/sites-available/"${PROJECT_NAME}"_"$BRANCH_NAME".conf
  sudo ln -s /etc/nginx/sites-available/"${PROJECT_NAME}"_"$BRANCH_NAME".conf /etc/nginx/sites-enabled/"${PROJECT_NAME}"_"$BRANCH_NAME".conf
  sudo systemctl restart nginx

  sudo certbot --nginx -d "$WEBSITE_NAME" --noninteractive --agree-tos --email "$ADMIN_EMAIL" --redirect
  sudo systemctl restart nginx
}

create_odoo_service() {
  cat <<EOF >/tmp/odoo.service
[Unit]
Description=${PROJECT_NAME}_$BRANCH_NAME
Requires=postgresql.service
After=network.target postgresql.service

[Service]
Type=simple
SyslogIdentifier=${PROJECT_NAME}_$BRANCH_NAME
PermissionsStartOnly=true
User=$OE_USER
Group=$OE_USER
ExecStart=$PROJECT_PATH/venv/bin/python $PROJECT_PATH/odoo-bin -c $PROJECT_PATH/config_local/odoo-server.conf
StandardOutput=journal+console

[Install]
WantedBy=multi-user.target
EOF
  sudo mv /tmp/odoo.service /etc/systemd/system/"${PROJECT_NAME}"_"$BRANCH_NAME".service
  sudo systemctl daemon-reload
  sudo systemctl enable "${PROJECT_NAME}"_"$BRANCH_NAME"
  sudo systemctl start "${PROJECT_NAME}"_"$BRANCH_NAME"
  sudo systemctl status "${PROJECT_NAME}"_"$BRANCH_NAME"
}

create_project() {
  echo "====== CREATING $BRANCH_NAME ======"
  sudo mkdir -p "$PROJECT_PATH"
  sudo chown $OE_USER:$OE_USER -R "$BASE_DIR"/"${PROJECT_NAME}"/
  echo "====== 1. CLONING REPOSITORIES ======"
  git clone --recurse-submodules -b "$BRANCH_NAME" "$REPO_URI" "$PROJECT_PATH"

  echo "====== 2. CHECKOUT SUBMODULES TO NEEDED BRANCHES ======"
  git -C "$PROJECT_PATH" submodule foreach -q --recursive 'branch="$(git config -f $toplevel/.gitmodules submodule.$name.branch)"; git checkout $branch'

  echo "====== 3. INSTALLING PYTHON PACKAGES ======"
  python3.10 -m venv "$PROJECT_PATH"/venv
  source "$PROJECT_PATH"/venv/bin/activate
  pip install wheel setuptools
  pip install --no-build-isolation gevent==21.8.0
  pip install -r "$PROJECT_PATH"/requirements.txt
  pip install -r "$PROJECT_PATH"/extra_requirements.txt
  pip install click-odoo-contrib -e "$PROJECT_PATH"
  deactivate

  echo "====== 4. CREATING ODOO CONFIGURATION ======"
  mkdir -p "$PROJECT_PATH"/config_local
  create_odoo_config

  #echo "====== 5. CREATE POSTGRES USER ======"
  create_postgres_user

  if [ -n "${WEBSITE_NAME}" ]; then
    echo "====== 6. SETUP NGINX ======"
    create_nginx_config
  else
    echo "Переменная WEBSITE_NAME не установлена. Пропуск настройки nginx."
  fi

  echo "====== 7. SETUP ODOO SERVICE ======"
  create_odoo_service
}

check_variables() {
  for var_name in OE_USER REPO_URI PROJECT_NAME BRANCH_NAME BASE_DIR PORT_START; do
    if [ -z "${!var_name}" ]; then # Используем непосредственную подстановку для получения значения переменной
      echo "Ошибка: переменная $var_name не установлена."
      exit 1
    fi
  done
}

# Вызов функции проверки
check_variables
ssh-keyscan -H gitlab.simbioz.com.ua >>~/.ssh/known_hosts
ssh-keyscan -H github.com >>~/.ssh/known_hosts
create_project
