# Just a Python and Cloudformation repository

This repository contains two directories:
- The directory *dir1* contains a sample python3 script that would download a bunch of files in parallel. Right now it supports http, https and S3.
- The directory *dir2* contains a cloudformation template, a bash scripts to do the deploys and updates and some additional files, some of those resources will be deployed inside the instances (from a secured S3 bucket) and a cloud-init scripts (Amazon's user-data field) reponsible of the final provision of the instances, including fetching those S3 resources we were talking about.

## Python downloader

The python script can receive two different flags:

- The *-h* shows the help
- The *-u|--url* can receive one or remote url (http, https and s3 urls).

The script will download the requested files in the current directory. If one file appears more than once, only the last one will be downloaded (to avoid downloading the same file more than once).

The S3 module will use the credentials configured with *aws configure*. It will use the *default* profile.

When the script finishes it will report the status of the downloads.

If one file does uses an unsupported url scheme, the script will report that and exit with error code *1*

Upon exiting, if all the downloads went well and all the requested files used a supported url schema, the script will return *0*. Otherwise will return *1*.

### Requirements

The downloader requires:

- Python 3
- The boto3 module

To install boto3, issue the following commands:

``` pip3 install boto3
```

The FTP and HTTP(S) modules are part of the Python 3 base libraries so no need to any additional installation.

## Cloudformation

The cloudformation work is under the directory *dir2*. All references to files will be relative to that directory.

### Requirements:

The template assumes we have the following:

- Already configured AWS profile.
- AMI: I've used the  Ubuntu 18.04LTS Amazon stock image (AMI ID: ami-0bdf93799014acdc4). However, to fasten the deploy we would probably need a customized version (having the Nginx and OpenJdk-8 packages inp lace)
- Security groups: I've used a security group allowing the ingress tcp ports 22, 80 and 443.
- Region: I have used the *eu-central-1*. This will
- VPC and subnets: I have used three subnets, each one
- Keypair: Keypair already provided (EC2 -> keypairs)
- SSL Certificate: Because I did not have a DNS domain I did not use HTTPS in my tests. However the template sets the balancer to use HTTPS and a AWS SSL Certificate (in the template, directive *SSLCertificateId: arn:aws:iam::...*
- Cloudformation user. For the sake of simplicity I have used a user with programmatic access and AdminAccess.
- DNS hosted zone.

### Rationale

To provide the desired functionality, I've designed a script called *glovo-app-cf.sh* which takes one argument *-t {create-stack|update-stack}*. The script can be customized by passing it some environment variables:

```
     BUILD_NUMBER:      To set the version of the ASG and the instances (defaults to 1)
     PROFILE:           AWS profile to use (defaults to the default profile)
     SG_VALUE:          Comma delimited list of security groups to use
     AMIID:             AMI ID to use (Defaults to Amazon stock Ubuntu 18.04LTS)
     INSTANCETYPE:      Instance type (Defaults to t2.micro)
     KP:                Keypair to use
     SUBNETS:           Comma delimited list of subnets to put the load balancer and the instances
     MINSIZE:           Min size of the autoscaling group (Defaults 1)
     DESIREDCAPACITY:   Desired  size of the autoscaling group (Defaults 2)
     MAXSIZE:           Max size of the autoscaling group (Defaults 3)
     AWSCERTIFICATE:    AWS Certificate ID to use in the HTTPS balancer
     DNSRECORD:			DNS A record that will point to the load balancer
     CLOUD_INIT_PATH:   Path of the cloud-init script to use
```

The script uses the template under the directory *cloudformation/autoscaling.yml*. That template receives some parameters:

```
    ParameterKey=KeyName,ParameterValue=${KP} \
	ParameterKey=AMIId,ParameterValue=${AMIID} \
	ParameterKey=InstanceTypeParameter,ParameterValue=${INSTANCETYPE} \
	ParameterKey=VersionId,ParameterValue=${BUILD_NUMBER} \
	ParameterKey=SecurityGroup,ParameterValue=\"${SG_VALUE}\" \
	ParameterKey=Subnets,ParameterValue=\"${SUBNETS}\" \
	ParameterKey=MinSize,ParameterValue=\"${MINSIZE}\" \
	ParameterKey=DesiredCapacity,ParameterValue=\"${DESIREDCAPACITY}\" \
	ParameterKey=MaxSize,ParameterValue=\"${MAXSIZE}\" \
	ParameterKey=AWSCertificate,ParameterValue=${AWSCERTIFICATE} \
	ParameterKey=UserData,ParameterValue=$(base64 ${CLOUD_INIT_PATH})
```

The approach I have used is to have an ASG, an Autoscaling Configuration, an ELB in front and a DNS record pointing to the ELB. When a new code is deployed, the stack gets updated, the new ASG gets attached to the ELB and the old ASG gets deleted when the new ASG is operational. That way we can avoid the loss of service. In a real scenario I'd keep the old ASG lowering the number of machines to 1; should any problem happen with the new deployment we can easily rollback.

Another solution to deploy the app would be to create a complete new stack (including the ELB, ASG and ASC) and use route53 with weighted Alias DNS records pointing to the ELB and then lower the weight of the old deploy to send the traffic to new stack. This solution is fairly complex and requires a bit more of work.

Given those two solutions, I went with the easier one which involves upgrading the stack (that is, only having one stack always in place).

The script uses the *BUILD_NUMBER* variable to provision the new ASG and tag the instances. That variable must always increment and must always be set to force the deploy of the new ASG and its instances.

### Autoscaling

The template uses the CloudFomation directives *GlovoAppScaleUpPolicy* and *GlovoAppScaleDownPolicy* of the type *AWS::AutoScaling::ScalingPolicy* to scale up and down.

Those scaling policies are triggered by two *AWS::CloudWatch::Alarm* alarms. The scale up policy check if the running instances are using more that the 90% of the CPU more that 5 minutes. Those values could be easily changed using parameters (the task is trivial) but I kept those figures for the sake of simplicity of the template. The same happens with the scale down policy, which will remove one instance if the CPU usage is below the 70% during 5 minutes or more.

### Deploying of new code

When a stack update happens, a new autoscaling group will be provisioned and attached to the GlovoAppLB. To avoid connection outtages, the AutoScaling has been set up with the following:

```
UpdatePolicy:
  AutoScalingReplacingUpdate:
	WillReplace: Boolean
```

This will deploy new instances and will wait until the new instances are running. When the new instances are in place, the old autoscaling group will be removed.

To accomplish that, we need to upgrade the *BUILD_NUMBER*.

### Load balancer

Our solution uses a Amazon ELB load balancer. The autoscaling group provisioned will be attached to that ELB. The ELB will listen to port 443 using an Amazon certificate (flag SSLCertificateId) and redirect the traffic to the AutoScaling instances of their port 80 (where the Nginx is listening and which will add the *X-Glovo-Systems-Engineer-Candidate* HTTP header).

### Deploy of the instances

The autoscaling group will use an AMI ID to provide the instances in the group. Because we want the deploy as fast as possible one would use the user-data and the cloud-init script to make the AMI as agnostic as possible.

Cloud-init supports any sort of executable script (which will be run just once) or a cloud init yaml, which can describe what to do on deploy and even what to do at every reboot.

Cloud-init provides a set of modules (like Ansible, Saltstack do) to automate tasks indenpendently of the underlying OS. However, some complex tasks require the use of custom scripts.

To solve our problem I decided to go with a custom script. I'll use the stock Ubuntu 18.04LTS Amazon AMI. I could a bit more customized AMI, but I did not want to go with a custom AMI because I wanted to avoid having a custom AMI there.

The cloud-init script passed to the instances will do the following:

- install_dependencies step: Install the webupd8team/java ppa repository, update sources and install *Nginx*, the *aws-cli* and the *OpenJdk-8*.
- enable swap step: Enable swap. The Amazon instances provisioned using the Ubuntu 18.04LTS AMI do not have their swap set up.
-provision_app_directory step: We want to have the jar running from a directory outside the root or any other user $HOME directory. This step will provide the directory */var/www/glovo-app*.
- copy_http_resources step: This step will fetch the jar from the origin. *I'd change the name of the jar artifact to some like systems-engineer-interview-latest-SNAPSHOT.jar without version. Otherwise when the version changes we would need to change the cloud-init script. This step will softlink the versioned artifact to systems-engineer-interview.jar and run it as a systemd service.*
- copy_s3_resources step: Because our setup needs some additional resources, we need an additional repository to fetch those resources from. I created an S3 bucket (s3://cloudformation.gustau.perez) to fetch the nginx configuration and a systemd service to run the jar artifact as a service. The nginx configuration will go to */etc/nginx/sites-enabled/default* and will configure the server to proxy pass *localhost:80* to *localhost:8080* (where the jar artifact listens).
- create_glovo-app_user step: This step ensures the glovo-app user is in place, if the user is not there it will be created. The glovo-app systemd service will use that user.
- start_servers step: this step will restart the Nginx server (so the changes to its config will take effect) and enable and run the glovo-app jar as a system service.

### Systemd service

The systemd is fairly simple. It's as simple as:

```
[Unit]
Description=Glovo-App Daemon

[Service]
ExecStart=/usr/bin/java -jar /var/www/glovo-app/systems-engineer-interview.jar server
User=glovo-app
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=glovo-app

[Install]
WantedBy=multi-user.target
```

it will send its logs to syslog. Those can be processed afterwards (for example, using rsyslog to send those logs to ElasticSearch).

### Nginx setup

The webserver choosed is Nginx, because of its simplicity in configuration and perfomance. This is just a personal opinion, any other modern webserver (like Apache, Lighttpd or any other with any proxy pass and HTTP headers modifications options available).

To do the job, I simply added the following to the default Nginx *location /*:

```
location / {
	# First attempt to serve request as file, then
	# as directory, then fall back to displaying a 404.
	try_files $uri $uri/ =404;
	proxy_pass                      http://localhost:8080;
	proxy_set_header                X-Glovo-Systems-Engineer-Candidate 1;
	proxy_pass_request_headers      on;
}
```

### Securely accessing the S3 bucket for configuration retrival

To securely retrieve the configurations and settings, there's a S3 bucket. I've created a profile to grant access to that bucket:

```
{
     "Version": "2012-10-17",
     "Statement": [
         {
             "Effect": "Allow",
             "Action": [
                 "s3:Get*",
                 "s3:List*"
             ],
             "Resource": ["arn:aws:s3:::<s3:cloudformation.gustau.perez>"]
         }
    ]
}
```

This policy allows the readonly access to an specific bucket. We'll use that to grant access to the instances in the autoscaling group. That way we don't need to put the credentials inside the AMIs or pass the via cloud-init, which is dangerous; instead by proividing those instances that IAM role we can easily revoke the access to the bucket.

### A proposal on how to inject configuration to the app and how to manage/store/version this configuration (e.g. database url and password).

There are a few options. One could be to use VAULT to access those credentials in a secure manner.

Another options will be to use S3 buckets and granting access to those buckets using IAM roles. That way we don't spread credentials in the instances and the role can be revoked as soon as the machines don't need it.

### A proposal for application log management and archiving

To manage the logs and archive them, one easy solution would be to send them to a centralized repository of logs. To do so, we could change the *Rsyslog* daemon on each instance to poll the *syslog* output, for any log tagged withg *glovo-app* the *Rsyslog* could send them to a centralized Rsyslog machine.

That machine would receive the logs from all the instances, could parse them and convert them to json and inject them using the rsyslog *omelasticsearch* to a ES cluster.

There those logs could be aggregated, explored, alarms could be defined, etc...

I'd change the code of the artifact jar to log its build number, that way it could easy to explore the behaviour depending on the build number/version of the artifact.

### Usage:

To create a new stack, given a security group and three subnets

```
SG_VALUE=sg-00cb6fd66209c6f64 SUBNETS=subnet-49633d04,subnet-4e92d933,subnet-ad001cc6 BUILD_NUMBER=1 ./glovo-app-cf.sh -t create-stack
```

Notice the *BUILD_NUMBER=1*. This is the first build.

To update a stack, let's suppose it's the third build:

```
SG_VALUE=sg-00cb6fd66209c6f64 SUBNETS=subnet-49633d04,subnet-4e92d933,subnet-ad001cc6 BUILD_NUMBER=3 ./glovo-app-cf.sh -t update-stack
```
