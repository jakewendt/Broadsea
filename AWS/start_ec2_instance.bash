#!/usr/bin/env bash


profile="--profile jake"
region="--region us-east-1"

#aws ${profile} ${region} ec2 describe-key-pairs

key="broadsea.pem"

if [ ! -f "${key}" ] ; then
	echo "Creating a key pair PEM file"
	aws ${profile} ${region} ec2 create-key-pair \
		--key-name broadsea \
		--key-type rsa \
		--key-format pem \
		--query "KeyMaterial" \
		--output text > ${key}
	chmod 400 ${key}
fi

#aws ${profile} ${region} ec2 describe-key-pairs


subnets=$( aws ${profile} ${region} ec2 describe-subnets )
#echo ${subnets}


subnet_id=$(echo $subnets | jq -r '.Subnets | sort_by(.AvailableIpAddressCount) | reverse[0].SubnetId' )
echo "Subnet $subnet_id"


echo "Looking for default VPC"
vpcid=$(aws $profile $region ec2 describe-vpcs --filters "Name=isDefault,Values=true" | jq -r '.Vpcs[].VpcId' )
if [ -z "${vpcid}" ] ; then
	aws $profile $region ec2 create-default-vpc
	vpcid=$(aws $profile $region ec2 describe-vpcs --filters "Name=isDefault,Values=true" | jq -r '.Vpcs[].VpcId' )
fi
echo "VPC ID: ${vpcid}"


sg=$(aws $profile $region ec2 describe-security-groups --filters Name=vpc-id,Values=$vpcid Name=group-name,Values=default)
sgid=$(echo $sg | jq -r '.SecurityGroups[].GroupId' )
echo "Security Group Id: ${sgid}"


echo "Checking for existing ssh access"
ssh_access=$(aws $profile $region ec2 describe-security-groups --group-id ${sgid} --filters Name=group-name,Values=default Name=ip-permission.protocol,Values=tcp Name=ip-permission.from-port,Values=22 Name=ip-permission.to-port,Values=22 Name=ip-permission.cidr,Values='0.0.0.0/0' --query 'SecurityGroups[*].{Name:GroupName}')
if [ "$ssh_access" == "[]" ]; then
	echo "Explicitly enable ssh access (port 22)"
	aws $profile $region ec2 authorize-security-group-ingress \
		--protocol tcp --port 22 --cidr 0.0.0.0/0 \
		--group-id $sgid
else
	echo "SSH Access already exists. Skipping."
fi

echo "Checking for existing web port 80 access"
ssh_access=$(aws $profile $region ec2 describe-security-groups --group-id ${sgid} --filters Name=group-name,Values=default Name=ip-permission.protocol,Values=tcp Name=ip-permission.from-port,Values=80 Name=ip-permission.to-port,Values=80 Name=ip-permission.cidr,Values='0.0.0.0/0' --query 'SecurityGroups[*].{Name:GroupName}')
if [ "$ssh_access" == "[]" ]; then
	echo "Explicitly enable web access (port 80)"
	aws $profile $region ec2 authorize-security-group-ingress \
		--protocol tcp --port 80 --cidr 0.0.0.0/0 \
		--group-id $sgid
else
	echo "Web Access already exists. Skipping."
fi

echo "Checking for existing secure web port 443 access"
ssh_access=$(aws $profile $region ec2 describe-security-groups --group-id ${sgid} --filters Name=group-name,Values=default Name=ip-permission.protocol,Values=tcp Name=ip-permission.from-port,Values=443 Name=ip-permission.to-port,Values=443 Name=ip-permission.cidr,Values='0.0.0.0/0' --query 'SecurityGroups[*].{Name:GroupName}')
if [ "$ssh_access" == "[]" ]; then
	echo "Explicitly enable secure web access (port 443)"
	aws $profile $region ec2 authorize-security-group-ingress \
		--protocol tcp --port 443 --cidr 0.0.0.0/0 \
		--group-id $sgid
else
	echo "Secure Web Access already exists. Skipping."
fi


block=""
dry_run="--dry-run"
user_data=""
#	Amazon Linux 2023 kernel-6.12 AMI
image_id="ami-0d85d4f07a62e2969"
instance_type="t3.large"
key_name="broadsea"

command="aws $profile $region ec2 run-instances ${dry_run} ${block} \
  --image-id ${image_id} \
  --instance-type ${instance_type} \
  --key-name ${key_name} \
  --subnet-id ${subnet_id} \
  --associate-public-ip-address \
  --credit-specification '{\"CpuCredits\":\"unlimited\"}' \
  --instance-initiated-shutdown-behavior terminate \
  --block-device-mappings '{\"DeviceName\":\"/dev/xvda\",\"Ebs\":{\"Encrypted\":false,\"DeleteOnTermination\":true,\"Iops\":3000,\"VolumeSize\":32,\"VolumeType\":\"gp3\",\"Throughput\":125}}'"

echo "Starting instance with ..."
echo "$command"
#	use eval to preserve the escaped double quotes
instance=$( eval "${command}" )
echo ${instance}

instance_ids=$(echo "$instance" | jq -r '.Instances[].InstanceId' )
echo $instance_ids


if [ -n "${instance_ids}" ] ; then

#	ip=$( aws $profile $region ec2 describe-instances \
#		--query 'Reservations[0].Instances[0].PublicIpAddress' \
#		--instance-ids ${instance_ids} | tr -d \" )
#
#	echo ssh -i ${key} -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ec2-user@${ip}
#	#ssh -i ${key} -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ec2-user@${ip}

	echo "--------------------------------------------------"
	echo
	echo "In a moment, an IP address will be assigned."
	echo "Acquire it by running the following command ..."
	echo
	command="aws $profile $region ec2 describe-instances
		--query 'Reservations[0].Instances[0].PublicIpAddress'
		--instance-ids $instance_ids | tr -d '\"'"
	echo
	echo $command
	echo
	echo "Shortly thereafter, the instance will be available."
	echo "Connect to it like the following command, replacing the #.#.#.# with the acquired IP address."
	echo
	echo "ssh -i ${key} -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ec2-user@#.#.#.#"
	echo
	echo " ... if using MatLab or other X11 windowing software, you'll need the -X option ..."
	echo
	echo "ssh -X -i ${key} -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ec2-user@#.#.#.#"
	echo
	echo "OR (if just 1 instance)"
	echo
	echo -n "ip=\$( "
	echo -n $command
	echo " )"
	echo "echo \$ip"
	echo "ssh -i ${key} -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ec2-user@\${ip}"
	echo

fi



