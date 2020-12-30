#---------README.dm------------------------------------------------
Установка предназначена для развертвывание на AWS RC2.

#---------Установка (Можно было и эту часть автоматизировать)------
Для запуска нужно установить boto3, awscli и 
и ввести учёные данные от aws, а в часности ввсести 
Access, Secret key
sudo apt update
sudo apt install awscli
aws configure
sudo apt install python3-pip
sudo pip3 install boto3
git clone https://github.com/bartolamey/taiga_aws.git
cd taiga_aws
python3 ec2.py

сайт будет доступен по Public IPv4 DNS


#---------Переменные------------------------------------------------
var.sh - переменные 




