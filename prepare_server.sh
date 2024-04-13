#!/bin/bash

###  WKHTMLTOPDF download links
## === Ubuntu Trusty x64 & x32 === (for other distributions please replace these two links,
## in order to have correct version of wkhtmltopdf installed, for a danger note refer to
## https://github.com/odoo/odoo/wiki/Wkhtmltopdf ):
## https://www.odoo.com/documentation/14.0/setup/install.html#debian-ubuntu

WKHTMLTOX_X64="https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.$(lsb_release -c -s)_amd64.deb"
WKHTMLTOX_X32="https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.$(lsb_release -c -s)_i386.deb"

sudo apt install software-properties-common -y
# libpng12-0 dependency for wkhtmltopdf
sudo add-apt-repository ppa:linuxuprising/libpng12 -y
sudo apt-get update
sudo apt-get upgrade -y
sudo apt install mc -y

echo -e "\n---- Set TimeZone Europe/Kiev ----"
sudo timedatectl set-timezone 'Europe/Kiev'
sudo dpkg-reconfigure --frontend noninteractive tzdata

echo -e "\n---- Install PostgreSQL Server ----"
sudo apt-get install postgresql postgresql-server-dev-all -y

#--------------------------------------------------
# Install Dependencies
#--------------------------------------------------
echo -e "\n--- Installing Python 3 + pip3 --"
sudo apt-get install git python3 python3-pip build-essential wget python3-dev python3-venv python3-wheel python3-testresources libxslt-dev libzip-dev libldap2-dev libsasl2-dev python3-setuptools node-less libpng12-0 libjpeg-dev gdebi -y

sudo apt-get install -y --no-install-recommends fonts-noto-cjk libssl-dev python3-num2words python3-pdfminer python3-phonenumbers python3-pyldap python3-qrcode python3-slugify python3-watchdog python3-xlrd python3-xlwt

echo -e "\n---- Installing nodeJS NPM and rtlcss for LTR support ----"
sudo apt-get install nodejs npm -y
sudo npm install @odoo/owl@1.4.0 -y

#--------------------------------------------------
# Install Wkhtmltopdf if needed
#--------------------------------------------------
echo -e "\n---- Install wkhtml and place shortcuts on correct place for ODOO 14 ----"
#pick up correct one from x64 & x32 versions:
if [ "$(getconf LONG_BIT)" = "64" ]; then
  _url=$WKHTMLTOX_X64
else
  _url=$WKHTMLTOX_X32
fi
sudo wget "$_url"
sudo gdebi --n $(basename $_url)
sudo ln -s /usr/local/bin/c /usr/bin
sudo ln -s /usr/local/bin/wkhtmltoimage /usr/bin

rm -f wkhtmltox_0.12.5-1.*.deb

sudo apt install nginx -y
sudo apt install snapd -y
sudo snap install core
sudo snap refresh core
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot
