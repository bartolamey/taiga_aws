import boto3
import time
import datetime
import os

#---------------AWS переменные------------------------------------------------------------------------------------
ec2          = boto3.resource('ec2')
client       = boto3.client('ec2')
waiter       = client.get_waiter('instance_status_ok')
instance     = ec2.Instance('id')
email_send   = 'mail@mail.com'

#---------------Создаём ключ доступа------------------------------------------------------------------------------
#to_day       = datetime.datetime.today().strftime("%d.%m.%Y_")
keypair_name = datetime.datetime.today().strftime("%d.%m.%Y___") + email_send  + '.pem'
new_keypair  = ec2.create_key_pair(KeyName=keypair_name)
with open(keypair_name, 'w') as file:
    file.write(new_keypair.key_material)
print('Создаём ключ доступа к EC2 ' + keypair_name)

#---------------Создание EC2--------------------------------------------------------------------------------------
print('Создаём новую EC2')

new_instance = ec2.create_instances(
    ImageId          = 'ami-0d5d9d301c853a04a',
    MinCount         = 1,
    MaxCount         = 1,
    InstanceType     = 't2.micro',
    KeyName          = keypair_name,
    SecurityGroupIds = [
        'sg-0eec6a32e376ef5c1',
	    'sg-04743adbd14fa93e2'
 ]
)
print (new_instance[0].id)
time.sleep(1)

#---------------Ожидание готовности ВМ-----------------------------------------------------------------------------
print ('Ожидаем создание ES2 ' + new_instance[0].id)
new_instance[0].wait_until_running()
new_instance[0].load() 
waiter.wait(InstanceIds=[new_instance[0].id])
print ('Public DNS подключения ' + new_instance[0].public_dns_name)
time.sleep(1)

#--------------Copy sh----------------------------------------------------------------------------------------------
os.system('chmod 400 ' + keypair_name)
os.system('scp -i ' + keypair_name + ' -o StrictHostKeyChecking=no install.sh ubuntu@' + new_instance[0].public_dns_name + ':/home/ubuntu')
os.system('scp -i ' + keypair_name + ' -o StrictHostKeyChecking=no http.sh ubuntu@' + new_instance[0].public_dns_name + ':/home/ubuntu')
os.system('scp -i ' + keypair_name + ' -o StrictHostKeyChecking=no var.sh ubuntu@' + new_instance[0].public_dns_name + ':/home/ubuntu')
os.system('ssh -i ' + keypair_name + ' -o StrictHostKeyChecking=no ubuntu@' + new_instance[0].public_dns_name +  ' bash install.sh')
#os.system('ssh -i ' + keypair_name + ' -o StrictHostKeyChecking=no ubuntu@' + new_instance[0].public_dns_name +  ' sudo -su taiga ./http.sh')

#scp -i 29.12.2020___mail@mail.com.pem install.sh ubuntu@3.22.166.179:/home/ubuntu
#scp -i 29.12.2020___mail@mail.com.pem http.sh ubuntu@3.22.166.179:/home/ubuntu
#ssh -i 29.12.2020___mail@mail.com.pem ubuntu@3.22.166.179 'sudo su taiga ./http.sh'


#os.system('ssh -i ' + keypair_name + ' -o StrictHostKeyChecking=no ubuntu@' + new_instance[0].public_dns_name +  'echo taiga | sudo -S -H -u taiga -c 'bash http.sh')

