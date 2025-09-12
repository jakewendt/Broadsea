
#	Run Broadsea on AWS

Important note. For the moment this isn't even remotely secure. But it runs.

##	Install AWS command line

```BASH
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
sudo installer -pkg AWSCLIV2.pkg -target /
```


#	Creating AWS root user access keys directly from the command line interface (CLI) is not possible.
#	Root user access keys can only be generated through the AWS Management Console.
#
#	From the AWS IAM console
#	Create a UserGroup with a variety of administrative privileges. I called my AdminUsers
#	Create a Admin User in the Admin UserGroup. I called mine Jake.
#	Create a UserGroup with a variety of limited privileges. I called my PrimaryUsers
#	For your admin user, under Security Credentials, create access keys
#	You can do some of this from the command line if you really want the challenge.
#		aws iam create-group --group-name YourGroupName
#		aws iam create-user --user-name YourUserName
#		aws iam add-user-to-group --user-name YourUserName --group-name YourGroupName
#		aws iam create-access-key --user-name YourUserName
#
#	Locally, configure the aws cli. You can add a profile if you already have multiple setups
#	the profile name doesn't need to match the AWS IAM profile, but its less confusing if it does.
#	The just created keys are required here. The default region and output are optional.
#	This will create files in ~/.aws/ which you could, if you choose, manually edit.

```BASH
aws configure 

aws configure --profile jake
```



```BASH
start_ec2_instance.bash
```




```BASH
echo ${instance}

instance_ids=$(echo "$instance" | jq '.Instances[].InstanceId' | tr -d '"')
echo $instance_ids

ip=$( aws $profile $region ec2 describe-instances \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --instance-ids ${instance_ids} | tr -d \" )


echo ssh -i ${key} -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ec2-user@${ip}
ssh -i ${key} -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ec2-user@${ip}
```






scp this script up to instance?


```BASH
sudo yum install -y docker git

export DOCKER_CONFIG=${DOCKER_CONFIG:-/usr/local/lib/docker/cli-plugins}
sudo mkdir -p $DOCKER_CONFIG/cli-plugins
sudo curl -SL https://github.com/docker/compose/releases/download/v2.39.3/docker-compose-linux-x86_64 -o $DOCKER_CONFIG/cli-plugins/docker-compose
sudo chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose

docker compose version

sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER
sudo chmod 666 /var/run/docker.sock
sudo chmod 777 /usr/local/lib/docker/cli-plugins
sudo systemctl restart docker
sudo systemctl status docker

docker run hello-world



git clone https://github.com/jakewendt/Broadsea.git

cd Broadsea
git checkout jake



#	change .env BROADSEA_HOST="127.0.0.1" to actual ip address

public_ip_address=$( curl http://checkip.amazonaws.com )
sed -i "s/127.0.0.1/${public_ip_address}/" .env



#	~16GB
docker compose --env-file .env --profile default up --detach



How to connect? the ip address

As soon as a browser tries to connect, the shell becomes unresponsive
t3.micro too small? t3.large is working. Somewhere in the middle? >2GB memory
t3.small may work. t3.medium probably would work.
Currently NOT SECURE IN THE LEAST.


#	>23GB
docker compose --env-file .env --profile default --profile pgadmin4 --profile jupyter-notebook --profile open-shiny-server up --detach



#	open the ip address on your browser


#	sudo shutdown now # will delete
```


How to secure?





