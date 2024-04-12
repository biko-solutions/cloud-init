#!/bin/bash

# location /web/database/ {
#   auth_basic "Protected Area";
#   auth_basic_user_file /etc/nginx/.htpasswd;
#   proxy_pass http://$UPSTREAM_ODOO;
# }

# разворачиваем на сервере препрода
# разворачиваем сразу две базы stage и dev
# предполагается, что на сервере уже развернут postgres, nginx, certbot
# предполагается, что postgres в докере (временно)
# структура каталога
# имя проекта
#    dev/
#    stage/

BASE_DIR=$(pwd)

exec > >(tee "$BASE_DIR"/install_project.log) 2>&1

PROJECT_NAME="prioritet"
DEV_PATH=$(pwd)/"${PROJECT_NAME}"/dev
STAGE_PATH=$(pwd)/"${PROJECT_NAME}"/stage
REPO_URI="git@github.com:biko-solutions/prioritet.git"
DOMAIN=".biko-solutions.dev"
DEV_PORT_START=80
STAGE_PORT_START=81
ADMIN_EMAIL="no-reply@biko-solutions.dev"
DEV_SUBDOMAIN="preprod-test"
STAGE_SUBDOMAIN="stage-test"
DOMAIN="biko-solutions.dev"
OE_USER="bikoadmin"

create_odoo_config() {
  cat <<EOF >"$1"/config_local/odoo-server.conf
[options]
addons_path = $1/odoo/addons,
  $1/extra_addons/core_addons,
  $1/extra_addons/demo_addons,
  $1/extra_addons/custom_addons
admin_passwd = admin25UX
auth_admin_passkey_password = 443bc8FA
auth_admin_passkey_send_to_user = False
auth_admin_passkey_sysadmin_email = False
csv_internal_sep = ,
data_dir = $1/.local
db_host = localhost
db_maxconn = 64
db_name = False
db_password = odoo
db_port = 5432
db_sslmode = prefer
db_template = template0
db_user = $PROJECT_NAME-$2
dbfilter = 
demo = {}
email_from = False
geoip_database = /usr/share/GeoIP/GeoLite2-City.mmdb
http_enable = True
http_interface = 
http_port = ${3}69
import_partial = 
limit_memory_hard = 2147483648
limit_memory_soft = 2155872256
limit_request = 8192
limit_time_cpu = 60
limit_time_real = 120
limit_time_real_cron = 0
list_db = True
log_db = False
log_db_level = warning
log_handler = :INFO
log_level = info
logfile = $1/odoo-server.log
longpolling_port = ${3}72
max_cron_threads = 1
modules_auto_install_disabled = simbioz_speed_patch,simbioz_date_time,iap,iap_mail,crm_iap_lead_enrich,crm_iap_lead,account_edi_ubl_cii,snailmail,snailmail_account,web_progress,discuss_show_members,oi_mail,partner_autocomplete,sms,web_unsplash
modules_auto_install_enabled = base_setup,bus,mail,auth_signup,module_change_auto_install,simbioz_dev_tools,ks_curved_backend_theme,ks_curved_backend_theme_chatter,simbioz_custom_css,base_module_reload,app_addons_view,web_dialog_size,disable_tour,rowno_in_tree,smart_warnings,sticky_kanban_header,sticky_notes,email_widget_validator,phone_widget_validator,dynamic_date_filter,hspl_no_mail_server_copied,auth_admin_passkey,auto_backup,base_custom_filter,base_export_manager,base_sparse_field,queue_job,base_import_async,base_optional_quick_create,base_technical_features,base_user_role,database_cleanup,date_range,document_url,email_template_qweb,hide_any_menu,listview_change_bgcolor,mail_optional_follower_notification,mail_quoted_reply,mail_restrict_follower_selection,mail_show_follower,mail_tracking,module_auto_update,rp_db_size_v13,sentry,web_advanced_search,calendar,board,mail_activity_board,web_group_expand,web_listview_range_select,web_m2x_options,web_m2x_options_manager,web_search_with_and,web_tree_many2one_clickable,web_widget_image_download,test_performance,test_mail,fetchmail_incoming_log,bi_all_in_one_hide,calendar_partner_color
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
server_wide_modules = web,module_change_auto_install,queue_job,base_sparse_field,sentry,module_auto_update,wk_redis_session,hspl_no_mail_server_copied,bi_view_editor
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
  docker exec postgres-postgres-1 psql -U root -d postgres -c "CREATE USER \"$PROJECT_NAME-$1\" WITH CREATEDB PASSWORD 'odoo';"
}

create_nginx_config() {
  UPSTREAM_ODOO=odoo_${PROJECT_NAME}_$1
  UPSTREAM_CHAT=odoo_${PROJECT_NAME}_$1_chat
  WEBSITE_NAME=${PROJECT_NAME}.${3}.${DOMAIN}
  cat <<EOF >/tmp/nginx_site.conf
upstream $UPSTREAM_ODOO {
  server 127.0.0.1:${2}69;
}
upstream $UPSTREAM_CHAT {
  server 127.0.0.1:${2}72;
}

server {

  # set proper server name after domain set
  server_name $WEBSITE_NAME;

  # Add Headers for odoo proxy mode
  proxy_set_header X-Forwarded-Host \$host;
  proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
  proxy_set_header X-Forwarded-Proto \$scheme;
  proxy_set_header X-Real-IP \$remote_addr;
  add_header X-Frame-Options "SAMEORIGIN";
  add_header X-XSS-Protection "1; mode=block";
  proxy_set_header X-Client-IP \$remote_addr;
  proxy_set_header HTTP_X_FORWARDED_HOST \$remote_addr;


  #   odoo    log files
  access_log  /var/log/nginx/${PROJECT_NAME}_$1-access.log;
  error_log       /var/log/nginx/${PROJECT_NAME}_$1-error.log;

  #   increase    proxy   buffer  size
  proxy_buffers   16  64k;
  proxy_buffer_size   128k;

  proxy_read_timeout 900s;
  proxy_connect_timeout 900s;
  proxy_send_timeout 900s;

  #   force   timeouts    if  the backend dies
  proxy_next_upstream error   timeout invalid_header  http_500    http_502
  http_503;

  types {
  text/less less;
  text/scss scss;
  }

  #   enable  data    compression
  gzip    on;
  gzip_min_length 1100;
  gzip_buffers    4   32k;
  gzip_types  text/css text/less text/plain text/xml application/xml application/json application/javascript application/pdf image/jpeg image/png;
  gzip_vary   on;
  client_header_buffer_size 4k;
  large_client_header_buffers 4 64k;
  client_max_body_size 0;

  location / {
  proxy_pass    http://$UPSTREAM_ODOO;
  # by default, do not forward anything
  proxy_redirect off;
  }

  location /longpolling {
  proxy_pass http://$UPSTREAM_CHAT;
  }
  location ~* .(js|css|png|jpg|jpeg|gif|ico)$ {
  expires 2d;
  proxy_pass http://$UPSTREAM_ODOO;
  add_header Cache-Control "public, no-transform";
  }
  # cache some static data in memory for 60mins.
  location ~ /[a-zA-Z0-9_-]*/static/ {
  proxy_cache_valid 200 302 60m;
  proxy_cache_valid 404      1m;
  proxy_buffering    on;
  expires 864000;
  proxy_pass    http://$UPSTREAM_ODOO;
  }

}
EOF
  sudo mv /tmp/nginx_site.conf /etc/nginx/sites-available/${PROJECT_NAME}_"$1".conf
  sudo ln -s /etc/nginx/sites-available/${PROJECT_NAME}_"$1".conf /etc/nginx/sites-enabled/${PROJECT_NAME}_"$1".conf
  sudo systemctl restart nginx

  sudo certbot --nginx -d $WEBSITE_NAME --noninteractive --agree-tos --email $ADMIN_EMAIL --redirect
  sudo systemctl restart nginx
}

create_odoo_service() {
  cat <<EOF >/tmp/odoo.service
[Unit]
Description=${PROJECT_NAME}_$1
After=network.target

[Service]
Type=simple
SyslogIdentifier=${PROJECT_NAME}_$1
PermissionsStartOnly=true
User=$OE_USER
Group=$OE_USER
ExecStart=$2/venv/bin/python $2/odoo-bin -c $2/config_local/odoo-server.conf
StandardOutput=journal+console

[Install]
WantedBy=multi-user.target
EOF
  sudo mv /tmp/odoo.service /etc/systemd/system/${PROJECT_NAME}_"$1".service
  sudo systemctl daemon-reload
  sudo systemctl enable ${PROJECT_NAME}_"$1"
  sudo systemctl start ${PROJECT_NAME}_"$1"
  sudo systemctl status ${PROJECT_NAME}_"$1"
}

create_project() {
  # $1 - branch name: dev, stage
  # $2 - project path
  # $3 - port (first 2 digits)
  # $4 - subdomain

  echo "====== CREATING $1 ======"
  mkdir -p "$2"
  echo "====== 1. CLONING REPOSITORIES ======"
  git clone --recurse-submodules -b "$1" "$REPO_URI" "$2"

  echo "====== 2. CHECKOUT SUBMODULES TO NEEDED BRANCHES ======"
  git -C "$2" submodule foreach -q --recursive 'branch="$(git config -f $toplevel/.gitmodules submodule.$name.branch)"; git checkout $branch'

  echo "====== 3. INSTALLING PYTHON PACKAGES ======"
  python3 -m venv "$2"/venv
  source "$2"/venv/bin/activate
  pip install wheel setuptools
  pip install -r "$2"/requirements.txt
  pip install -r "$2"/extra_requirements.txt
  pip install click-odoo-contrib -e "$2"
  deactivate

  echo "====== 4. CREATING ODOO CONFIGURATION ======"
  mkdir -p "$2"/config_local
  create_odoo_config "$2" "$1" "$3"

  echo "====== 5. CREATE POSTGRES USER ======"
  create_postgres_user "$1"

  echo "====== 6. SETUP NGINX ======"
  create_nginx_config "$1" "$3" "$4"

  echo "====== 7. SETUP ODOO SERVICE ======"
  create_odoo_service "$1" "$2"
}

create_project dev "$DEV_PATH" "$DEV_PORT_START" "$DEV_SUBDOMAIN"
create_project stage "$STAGE_PATH" "$STAGE_PORT_START" "$STAGE_SUBDOMAIN"
