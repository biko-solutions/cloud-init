#!/bin/bash

wget https://github.com/prometheus/node_exporter/releases/download/v1.8.2/node_exporter-1.8.2.linux-amd64.tar.gz
tar xzvf node_exporter-1.8.2.linux-amd64.tar.gz

useradd -rs /bin/false node_exporter
mv node_exporter-1.8.2.linux-amd64/node_exporter /usr/bin/
chown node_exporter:node_exporter /usr/bin/node_exporter

cat <<EOF >/etc/systemd/system/node_exporter.service
[Unit]
Description=Prometheus Node Exporter
Requires=network.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
Restart=on-failure
ExecStart=/usr/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable node_exporter.service
systemctl start node_exporter.service
systemctl status node_exporter.service

ufw allow 9100/tcp
