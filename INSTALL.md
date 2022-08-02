# Server Preparations for On Playa Ops

### Set the server IP address

TBD: Talk with BMIT and find out what the IP address, router, and other bits are.

### Adjust the existing Ubuntu 22 configuration

1. As root, remove postfix, remove nginx, and uninstall Docker.
```sh
# apt-get purge postfix
# apt-get purge nginx nginx-common
# snap remove docker
# rm -R /var/lib/docker
```
apt-get update
apt-get install ufw
apt-get install git-all
apt install inetutils-ping

### Configure and enable the firewall

The only allowed incoming traffic into the server should be: ssh, http & https, the monit web server.

```sh
# ufw default deny incoming
# ufw default allow outgoing
# ufw allow 22/tcp
# ufw allow 80/tcp
# ufw allow 443/tcp
# ufw allow 9100/tcp
# ufw logging off
# ufw enable
```

### Install packages via apt get

```sh
# apt install certbot
# apt install git
# apt install monit
# apt install lm-sensors
```

```sh
# apt install mailutils
```
Select 'No Configuration' when prompted.

### Install the latest version of Docker

[Docker version 19.03.0 or later
https://docs.docker.com/install/linux/docker-ce/ubuntu/

Docker Compose version 1.24.0 or later
https://docs.docker.com/compose/install/

### Create 'rangers' account

```shell
useradd -m -G sudo,docker rangers
passwd rangers
```

or
```shell
usermod -a -G docker ranger
```

Remember the password and pass it on to the other Tech Ops team members.

The scripts will assume rangers home directory is '/home/rangers'


### Log into the 'rangers' account and install the playa repo, scripts, and config files

1. Pull down the playa ops repo (this repo you're reading now!):

```sh
$ git clone https://github.com/burningmantech/ranger-playa-ops.git
```

2. Run the install script which will pull down the Clubhouse repositories, and setup the data directory for use by the Docker services.

```sh
$ cd ranger-playa-ops
$ sh ./bin/install
```

NOTE: You will be asked for a github username and password in order to pull down the Clubhouse 1 repository.

2. As root, install all scripts in ./localbin into /usr/local/bin.

```sh
# cp ./localbin/* /usr/local/bin/
```

3. Still as root, install the twilio-sms command config file and edit.

```sh
# cp configs/twiliorc-example /root/.twiliorc
```

4. Still as root, create /root/.monit-phones, and add all phones numbers wishing to receive monit alerts. One phone number per line in E.164 format - e.g. +14155551212 (plus sign, followed by country code, no spaces or parens)

5. Still as root, copy the rangers monit file, and edit the AWS SES/SMTP credentials. Add any additional email addresses to receive monit alerts.

```sh
# cp configs/monit-rangers /etc/monit/conf.d/rangers
```

5. Generate a ~/.ssh/id_rsa.pub file and copyto rangers@burg.me:.ssh/authorized_keys

```sh
$ ssh-keygen -o
```
(hit enter when prompted for the passphrase.)

Log into rangers@burg.me and append the contents of ~rangers/.ssh/id_rsa.pub to rangers@burg.me:.ssh/authorized_keys.

The backup script will use this for off site backups.

6. As rangers, edit the cron file to run the Clubhouse backup on a hourly basis.

```cron
25  * * * * ./bin/ranger-playa-ops/bin/clubhouse-backup full
```

7. Check ssh credentials were copied over to authorized_keys correctly by ssh into the remote backup account.

```sh
$ ssh rangers@burg.me
```


### Start (restart) Monit

As root, stop and then start monit to pick up the ranger configuration.
```sh
# systemctl stop monit
(wait 15 seconds or so)
# systemctl start monit
```

You may receive several Monit alerts saying the Clubhouse services are down. That's okay, nothing is running yet.

### Obtain the HTTPS certificates

The docker stack should be stopped, and no other web services running on port 80s & 443. The ports should be reachable from the Internet.

As rangers, and in the ranger-playa-ops directory run certbot:

```sh
$ certbot certonly --config-dir ./data/certs --standalone -d ranger-clubhouse.nv.burningman.org
$ certbot certonly --config-dir ./data/certs --standalone -d ranger-ims.nv.burningman.org
```

### Setup, Build, And Start the Docker Clubhouse stack.

1. As rangers in the ranger-playa-ops directory, copy ./configs/rangers.env to ./rangers.env

2. Edit ./.rangers.env and set the AWS SES credentials, and JWT  token. The JWT token can set using the Fargate production value, or have a Tech Ninja generate a new one using the `php artisan jwt:secret` command in working API deployment.

3. Build the stack!

```sh
$ ./bin/rangers-build-all
```

4. Launch the stack! The mysql service may take upwards to a minute the first time it is launched.

```sh
$ ./bin/rangers-start
** Deploying Ranger stack (may receive warning about 'Ignoring unsupported options' -- safe to disregard)
Ignoring unsupported options: build

Creating network rangers_default
Creating service rangers_client
Creating service rangers_nginx
Creating service rangers_db
Creating service rangers_smtpd
Creating service rangers_api
```

Use `docker stack ps rangers` to verify the stack is running:

```
$ docker stack ps rangers
ID            NAME               IMAGE           NODE             DESIRED STATE  CURRENT STATE            ERROR         PORTS
sbag9v1bh377 rangers_nginx.1     nginx:prod      man_side_ranger  Running        Running 16 seconds ago
ssv2qvjbmaae rangers_api.1       apiserver:prod  man_side_ranger  Running        Running 25 seconds ago
khupgancf0or rangers_smtpd.1     smtpd:prod      man_side_ranger  Running        Running 27 seconds ago
xtk6reoez7ju rangers_db.1        mysql:5.6       man_side_ranger  Running        Running 29 seconds ago
kanr98oje1jb rangers_client.1    client:prod     man_side_ranger  Running        Running 31 seconds ago
w1f6dwbdtg8k rangers_api.2       apiserver:prod  man_side_ranger  Running        Running 24 seconds ago
```

5. After waiting a minute or so, open a web browser and visit ranger-clubhouse.nv.burningman.org. The login page should appear but you will not be able to log in due to the database not being loaded.

6. Test AWS SES credentials.

```sh
./bin/rangers-exec api.1 php artisan test:mail <youremail@domain.blah>
```

You should receive an email message. Check the smtp logs if the message does not appear:

```sh
./bin/rangers-log smtpd
```

At this point, monit may send out a few emails saying the services were successfully connected to. This is a good thing(tm).

### Warn on Control-1 / Ranger HQ the Clubhouse will be shutdown in 15 mins and transferred locally.

Give a 15 min, 5 min, and 1 minute warning. At the zero mark, announce the Clubhouse will be down for about a hour.

During the 15 minute countdown, go take a break. Think happy thoughts. The fun is about to start.

### Shutdown the AWS Clubhouse, and transfer the database

1. Log into AWS and stop ALL production client & api instances. Wait until all instances have been stopped. (TBD: set instance count to zero maybe?)

2. On blaster, dump the production database. Suggested naming is rangers-YYYY-MM-DD.sql. Compress with gzip.

3. Copy the database down to the server into the rangers account.

4. Change directories to ranger-playa-ops.

5. Load up the database (Docker stack must be running at this point):

```sh
gunzip < /path/to/dump | ./bin/rangers-mysql
```

The local mysql password will be required.

6. Verify the load was correct by trying to log into ranger-clubhouse.nv.burningman.org

### Copy the photos down from the S3 bucket to the local server

1. On the local terminal, as the rangers account, down load & sync the images:

```sh
$ TODO-WRITE-THIS-COMMAND

```

This command may take several minutes to run depending on how congested the playa Internet link is.

### Change the Twilio SMS end point.

Log into Twilio and change to Sub Account 'Rangers'

In the sidebar select Programmable SMS > SMS > Message Services > Ranger SMS

Under inbound settings set "Request URL" to

https://ranger-clubhouse.nv.burningman.org/api/sms/inbound


## Test mysql port exposure

On another machine, NOT ON THE SERVER, check to see if the mysql port is exposed:

$ telnet ranger-clubhouse.nv.burningman.org 3306

Telnet should NOT be able to connect. If it does, check the iptable entries on the server.

### Redirect all AWS Clubhouse traffic to the Playa server

Once the database is loaded, redirect all AWS Clubhouse traffic to the playa.

TBD: Set the AWS load balancer to redirect to ranger-clubhouse.nv.burningman.org?

### Congrats, the On Playa Clubhouse is running!

Feel the Ranger love..

### Summary of files which require credentials

| File                                   | Credentials needed                        |
--------------------------------------------------------------------------------------
| ~rangers/ranger-playa-ops/.rangers.env | AWS SES, JWT Token                        |
| rangers@burg.me:.ssh/authorized_keys   | id_pub.rsa for the server                 |
| /root/.twiliorc                        | Twilio Account SID and Auth Token         |
| /root/.monit-phones                    | Phone numbers to text monit alerts        |
| /etc/monit/conf.d/rangers              | AWS SES Credentials, Tech Ops email addrs.|
--------------------------------------------------------------------------------------

### Container names

| Name    | Description               | Built from                     |
|---------|---------------------------|--------------------------------|
| api     | Clubhouse 2 API backend   | ./src/api                      |
| client  | Clubhouse 2  web client   | ./src/client                   |
| smtpd   | Postfix SMTP relay        | ./services/smtpd + docker hub  |
| nginx   | Nginx frontend            | ./serviices/nginx + docker hub |
| db      | Mysql 5.6                 | docker hub mysql:5.6           |
------------------------------------------------------------------------
