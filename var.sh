export TAIGAPASS="taiga"
export BASEPASS="aqwe123"
export BASEIP="localhost"
export DOMAIN=$(ifconfig  | grep 'inet addr:'| grep -v '127.0.0.1' | cut -d: -f2 | awk '{ print $1}')
export SECRETKEY="aqwertyuiopaqwertyuiop"
