#/bin/sh
mkdir -p /var/www/html/walleye/images
tar -zxvf  /usr/local/walleye/walleye.tgz -C /
chown -R walleye /var/www/html/walleye
chgrp -R walleye /var/www/html/walleye