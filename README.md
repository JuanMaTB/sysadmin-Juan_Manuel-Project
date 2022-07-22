# sysadmin-Juanma
## Project sysadmin Juan Manuel Torrado Borrachero

1. Clone repository: https://github.com/KeepCodingCloudDevops6/sysadmin-Juanma.git

2. Launch vagrant up command terminal placed in Vagrant directory

3. First machine will launch Nginx, mariadb, filebeat and wordpress. Disk modifications to give extra size to maridb will be visible when rebooting the machines ( shutdown -r now ). Modified fstab for it

4. Second machine will launch ELK stack, php dependencies also nginx. Disk modifications to give extra size to elasticsearch will be visible when rebooting the machines ( shutdown -r now ). Modified fstab for it

5. ### Networking is automatically implemented between both machines 
     You can access wordpress through http://localhost:8080 to check its operation
     Kibana can be accessed via http://localhost:81 to test its functionality ( User = kibanaadmin Pass = qwerty )

6. Screenshots can be viewed from the Imagenes directory. The nginx logs have been captured as an example