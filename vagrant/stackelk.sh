#!/bin/bash
#actualizar
apt-get update
#dependencias java
apt-get install -y  default-jre
#servidor nginx
apt-get -y install nginx
#Instalacion clave GPG de repositorio elastic search para ubuntu server
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
#Instalamos el paquete apt-transport-https. Ofrece a nuestro sistema la posibilidad de actualizar los paquetes con conexión SSL.
sudo apt-get install apt-transport-https
#añadimos repo de elasticsearch y actualizamos
echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-7.x.list
sudo apt update
#Instalacion logstash
apt install logstash
#configurar logstash
FILE1=/etc/logstash/conf.d/02-beats-input.conf
if ! [ -f "$FILE1" ]; then
    cat << EOF > $FILE1
    input {
         beats {
            port => 5044
        }
    }
EOF
fi

FILE2=/etc/logstash/conf.d/10-syslog-filter.conf
if ! [ -f "$FILE2" ]; then
    cat << EOF > $FILE2
    filter {
  if [fileset][module] == "system" {
    if [fileset][name] == "auth" {
      grok {
        match => { "message" => ["%{SYSLOGTIMESTAMP:[system][auth][timestamp]} %{SYSLOGHOST:[system][auth][hostname]} sshd(?:\[%{POSINT:[system][auth][pid]}\])?: %{DATA:[system][auth][ssh][event]} %{DATA:[system][auth][ssh][method]} for (invalid user )?%{DATA:[system][auth][user]} from %{IPORHOST:[system][auth][ssh][ip]} port %{NUMBER:[system][auth][ssh][port]} ssh2(: %{GREEDYDATA:[system][auth][ssh][signature]})?",
                  "%{SYSLOGTIMESTAMP:[system][auth][timestamp]} %{SYSLOGHOST:[system][auth][hostname]} sshd(?:\[%{POSINT:[system][auth][pid]}\])?: %{DATA:[system][auth][ssh][event]} user %{DATA:[system][auth][user]} from %{IPORHOST:[system][auth][ssh][ip]}",
                  "%{SYSLOGTIMESTAMP:[system][auth][timestamp]} %{SYSLOGHOST:[system][auth][hostname]} sshd(?:\[%{POSINT:[system][auth][pid]}\])?: Did not receive identification string from %{IPORHOST:[system][auth][ssh][dropped_ip]}",
                  "%{SYSLOGTIMESTAMP:[system][auth][timestamp]} %{SYSLOGHOST:[system][auth][hostname]} sudo(?:\[%{POSINT:[system][auth][pid]}\])?: \s*%{DATA:[system][auth][user]} :( %{DATA:[system][auth][sudo][error]} ;)? TTY=%{DATA:[system][auth][sudo][tty]} ; PWD=%{DATA:[system][auth][sudo][pwd]} ; USER=%{DATA:[system][auth][sudo][user]} ; COMMAND=%{GREEDYDATA:[system][auth][sudo][command]}",
                  "%{SYSLOGTIMESTAMP:[system][auth][timestamp]} %{SYSLOGHOST:[system][auth][hostname]} groupadd(?:\[%{POSINT:[system][auth][pid]}\])?: new group: name=%{DATA:system.auth.groupadd.name}, GID=%{NUMBER:system.auth.groupadd.gid}",
                  "%{SYSLOGTIMESTAMP:[system][auth][timestamp]} %{SYSLOGHOST:[system][auth][hostname]} useradd(?:\[%{POSINT:[system][auth][pid]}\])?: new user: name=%{DATA:[system][auth][user][add][name]}, UID=%{NUMBER:[system][auth][user][add][uid]}, GID=%{NUMBER:[system][auth][user][add][gid]}, home=%{DATA:[system][auth][user][add][home]}, shell=%{DATA:[system][auth][user][add][shell]}$",
                  "%{SYSLOGTIMESTAMP:[system][auth][timestamp]} %{SYSLOGHOST:[system][auth][hostname]} %{DATA:[system][auth][program]}(?:\[%{POSINT:[system][auth][pid]}\])?: %{GREEDYMULTILINE:[system][auth][message]}"] }
        pattern_definitions => {
          "GREEDYMULTILINE"=> "(.|\n)*"
        }
        remove_field => "message"
      }
      date {
        match => [ "[system][auth][timestamp]", "MMM  d HH:mm:ss", "MMM dd HH:mm:ss" ]
      }
      geoip {
        source => "[system][auth][ssh][ip]"
        target => "[system][auth][ssh][geoip]"
      }
    }
    else if [fileset][name] == "syslog" {
      grok {
        match => { "message" => ["%{SYSLOGTIMESTAMP:[system][syslog][timestamp]} %{SYSLOGHOST:[system][syslog][hostname]} %{DATA:[system][syslog][program]}(?:\[%{POSINT:[system][syslog][pid]}\])?: %{GREEDYMULTILINE:[system][syslog][message]}"] }
        pattern_definitions => { "GREEDYMULTILINE" => "(.|\n)*" }
        remove_field => "message"
      }
      date {
        match => [ "[system][syslog][timestamp]", "MMM  d HH:mm:ss", "MMM dd HH:mm:ss" ]
      }
    }
  }
}
EOF
fi
FILE3=/etc/logstash/conf.d/30-elasticsearch-output.conf
if ! [ -f "$FILE3" ]; then
    cat << EOF > $FILE3
    output {
        elasticsearch {
            hosts => ["localhost:9200"]
            manage_template => false
            index => "%{[@metadata][beat]}-%{[@metadata][version]}-%{+YYYY.MM.dd}"
        }
    } 
EOF
fi
#arrancar servicio
systemctl enable logstash --now
#instalar elasticsearch
apt install elasticsearch
#el usuario elasticsearch tiene permisos para escribir en /var/lib/elasticsearch.
chown -R elasticsearch:elasticsearch /var/lib/elasticsearch
chmod -R 754 /var/lib/elasticsearch
#arrancamos el servicio.
systemctl enable elasticsearch --now
#instalamos Kibana
apt install kibana
#modificacion configuracion nginx a puerto 80
rm /etc/nginx/sites-available/default -d
FILE4=/etc/nginx/sites-available/default 
if ! [ -f "$FILE4" ]; then
    cat << EOF > $FILE4
    # Managed by installation script - Do not change
    server {
        listen 80;
        server_name kibana.demo.com localhost;
        auth_basic "Restricted Access";
        auth_basic_user_file /etc/nginx/htpasswd.users;
        location / {
            proxy_pass http://localhost:5601;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host \$host;
            proxy_cache_bypass \$http_upgrade;
        }
    }  
EOF
fi
#generar fichero htpasswd.users con usuario y pass encriptados.
#primero creamos carpeta .kibana con password en interior
touch /vagrant/.kibana
printf 'qwerty' > /vagrant/.kibana
#generar fichero de passwords
echo "kibanaadmin:$(openssl passwd -apr1 -in /vagrant/.kibana)" | sudo tee -a /etc/nginx/htpasswd.users
#reinicio servicios nginx y kibana
service nginx restart
service kibana restart
#MAQUINA 2 FINALIZADA