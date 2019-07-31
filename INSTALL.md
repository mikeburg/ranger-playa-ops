# Server Preparations for On Playa Ops

### Create 'rangers' account

```sh
# useradd -G sudo rangers
# passwd rangers
```

Remember the password and pass it on to the other Tech Ops team members.

The scripts will assume rangers home directory is '/home/rangers'

### Adjust the existing Ubuntu 18 (Bionic) configuration

1. As root, stop and disable postfix
```sh
# systemctl stop postfix
# systemctl disable postfix
```

2. Still as root, remove the default Docker install. Ubuntu does not install the latest version.

```sh
# apt-get purge nginx nginx-common
# snap remove docker
# rm -R /var/lib/docker
```

### Configure and enable the firewall

The only allowed incoming traffic into the server should be: ssh, http & https, the monit web server.

```sh
# ufw default deny incoming
# ufw default allow outgoing
# ufw add 22/tcp
# ufw add 80/tcp
# ufw add 443/tcp
# ufw add 9100/tcp
# ufw enable
```

### Install packages via apt get

```sh
# apt install certbot
# apt install git
# apt install monit
# apt-get install mailutils
# apt install lm-sensors
```

Run `sensors-detect` after installing lm-sensors. Answer YES to probe all possible sensor chips.

### Install the latest version of Docker

[Docker version 19.03.0 or later
https://docs.docker.com/install/linux/docker-ce/ubuntu/

Docker Compose version 1.24.0 or later
https://docs.docker.com/compose/install/

After Docker is installed, initialize a Docker swarm

```sh
$ docker swarm init
```

### Set Docker to honor the existing iptables configuration

Create the /etc/docker/daemon.json  file and add the following json to it:
```json
{
  "iptables": false
}
```

(Older Docker  versions appear  use DOCKER_OPTS in /etc/default/docker with the "--iptables=false" argument. Newer versions use daemon.json.)

*The safest thing at this point is to reboot the machine to ensure Docker and ufw/iptables play nicely with one another.*

### Log into the 'rangers' account and install the playa repo, scripts, and config files

1. Pull down the playa ops repo (this repo you're reading now!):

```sh
$ git clone https://github.com/burningmantech/rangers-playa-ops
```

2. Run the install script which will pull down the Clubhouse repositories, and setup the data directory for use by the Docker services.

```sh
$ cd rangers-playa-ops
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

5. As rangers, add the id_rsa.pub file for rangers@burg.me (or whatever remote host is being used - make sure rangers-playa-ops/bin/clubhouse-backup is changed accordingly) to /home/rangers/.ssh/authorized_keys

6. As rangers, edit the cron file to run the Clubhouse backup on a hourly basis.

```cron
25  * * * * ./bin/rangers-playa-ops/bin/clubhouse-backup full
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

1. As rangers in the rangers-playa-ops directory, copy ./configs/rangers.env to ./rangers.env

2. Edit ./.rangers.env and set the AWS SES credentials, and JWT  token. The JWT token can set using the Fargate production value, or have a Tech Ninja generate a new one using the `php artisan jwt:secret` command in working API deployment.

3. Build the stack!

```sh
$ ./bin/rangers-build-all
```

4. Launch the stack! The mysql service may take upwards to a minute the first time it is launched.

```sh
$ ./bin/rangers-start
```

5. After waiting a minute or so, verify the stack is running by visiting ranger-clubhouse.nv.burningman.org. The login page should appear but you will not be able to log in.

6. Test AWS SES credentials.

```sh
./bin/rangers-exec api.1 php artisan test:mail <youremail@domain.blah>
```

You should receive an email message. Check the smtp logs if the message does not appear:

```sh
./bin/rangers-log smtpd
```

At this point, monit may send out a few emails saying the services were succesfully connected to. This is a good thing(tm).

### Transfer the Clubhouse database

1. Log into AWS and stop ALL production client & api instances. Wait until all instances have been stopped. (TBD: set instance count to zero maybe?)

2. On blaster, dump the production database. Suggested naming is rangers-YYYY-MM-DD.sql. Compress with gzip.

3. Copy the database down to the server into the rangers account.

4. Change directories to rangers-playa-ops.

5. Load up the database (Docker stack must be running at this point):

```sh
gunzip < /path/to/dump | ./bin/rangers-mysql
```

The mysql password will be required.

6. Verify the load was correct by trying to log into ranger-clubhouse.nv.burningman.org

### Rebuild the Photo Status cache, and download images.

1. Log in to the on playa Clubhouse with an Admin account.

2. Change the PhotoStoreLocally setting to true.

3. Go back to the server terminal, and as rangers in the rangers-playa-ops directory, rebuild the photo cache and download the images:

```sh
$ bin/rangers-exec api.1 php artisan lambase:syncphotos
```

This command may take several minutes to run.

### Change the Twilio SMS end point.

Log into Twilio and change to Sub Account 'Rangers'

In the sidebar select Programmable SMS > SMS > Message Services > Ranger SMS

Under inbound settings set "Request URL" to

https://ranger-clubhouse.nv.burningman.org/api/sms/inbound



## One last thing before going live - test for mysql port exposure

On another machine, NOT ON THE SERVER, check to see if the mysql port is exposed:

$ telnet ranger-clubhouse.nv.burningman.org 3306

Telnet should NOT be able to connect. If it does, check the iptable entries on the server.

### Redirect all AWS Clubhouse traffic to the Playa server

Once the database is loaded, redirect all AWS Clubhouse traffic to the playa.

TBD: Set the AWS load balancer to redirect to ranger-clubhouse.nv.burningman.org?

### Congrats, the On Playa Clubhouse is running!

Feel the Ranger love..

### Summary of files which require credentials

| File                            | Credentials needed                 |
------------------------------------------------------------------------
| ./ranger-playa-ops/.rangers.env | AWS SES, JWT Token                 |
| ./.ssh/known_keys               | id_pub.rsa of remote backup host   |
| /root/.twiliorc                 | Twilio Account SID and Auth Token  |
| /root/.monit-phones             | Phone numbers to text monit alerts |
| /etc/monit/conf.d/rangers       | AWS SES Credentials                |
------------------------------------------------------------------------

### Container names

| Name    | Description               | Built from                     |
|---------|---------------------------|--------------------------------|
| api     | Clubhouse 2 API backend   | ./src/api                      |
| client  | Clubhouse 2  web client   | ./src/client                   |
| classic | Clubhouse 1               | ./src/classic                  |
| smtpd   | Postfix SMTP relay        | ./services/smtpd + docker hub  |
| nginx   | Nginx frontend            | ./serviices/nginx + docker hub |
| db      | Mysql 5.6                 | docker hub mysql:5.6           |
------------------------------------------------------------------------
