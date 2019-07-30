### Server Preparations for On Playa operations

Install the following packages:
* certbot
* Docker version 19.03.0 or later
* Docker Compose version 1.24.0 or later
* git

Stop Postfix

$ systemctl stop postfix
$ systemctl disable postfix

# Setup /root/.twiliorc
# ACCOUNTSID, AUTHTOKEN, or CALLERID

# install twilio-sms into /usr/local/bin
# install monit-sms into /root

To install git (as root):
$ apt-get install git

To install certbot (as root):

$ apt-get install certbot

To install monit (as root):

$ apt-get install monit

To install Docker visit:
https://docs.docker.com/install/linux/docker-ce/ubuntu/

To install Docker Compose visit:
https://docs.docker.com/compose/install/

## Add certificates to monit

# Add basic mailer

$ apt-get install mailutils

## Container names

| Name    | Description                        | Built from           |
|---------|------------------------------------|----------------------|
| api     | Clubhouse 2 API backend            | ./src/api            |
| client  | Clubhouse 2  web client            | ./src/client         |
| classic | Clubhouse 1                        | ./src/classic        |
| smtpd   | Postfix SMTP relay                 | ./smtpd + docker hub |
| nginx   | Nginx frontend                     | ./nginx + docker hub |
| db      | Mysql 5.6                          | docker hub mysql:5.6 |

## 1 - Pull down the Clubhouse repositories (classic, api backend, client)
$ bin/install

## 2 - Create a secrets.yml file

Copy the template from secrets-example.yml:

$ cp secrets-example.yml secrets.yml

Use your favorite editor to enter the authentication information.

You will need to obtain or decide on the following pieces:

* Mysql database password for the "rangers" user - THIS CANNOT BE CHANGED ONCE MYSQL HAS INITIALIZED THE DATABASE.
When mysql is launched for the very first time, the the "rangers" database is created with the username and password specified. The database will be empty and devoid of any schema.

* The JWT secret. Either copy the value from the AWS task environment.

* The AWS SES hostname along with the SES username and password. (Not the same as your AWS credentials)


## 3 - Build the Docker images
$ bin/build

## 4 - Obtain the HTTPS certificates

The docker stack should be stopped, and no other web services running on port 80s & 443. The ports should be reachable from the Internet.

To obtain a certificate for the Clubhouse ranger-clubhouse.nv.burningman.org):
(running in the top level directory where this file you are reading now is located)

$ certbot certonly --config-dir ./data/certs --standalone -d ranger-clubhouse.nv.burningman.org

To obtain a certificate for the IMS ranger-ims.nv.burningman.org:

$ certbot certonly --config-dir ./data/certs --standalone -d ranger-ims.nv.burningman.org

## Stop the AWS instances

See the AWS document on how to stop the AWS instances. The task counts should go to zero.


## Load the database

1. Obtain a production database dump from blaster. Make sure the API Fargate instances have been stopped so the database updates are not happening while the dump is running.

2. Copy said dump down to the local machine.

3. Launch the stack
$ bin/start

4. Use ```docker ps``` to check if the database instance has started. It may take a 1 or 2 minutes to fully boot since mysql will have to initialize an empty database when running for the first time. THE DATABASE PASSWORDS WILL BE SET AND CANNOT BE CHANGED FROM THIS POINT FORWARD.

5. Verify mysql  is running:

$ ./bin/mysql-rangers
You will be prompted for a password. Use the rangers password in secrets.yml

7. Load the production dump into the local database:

$ ./bin/mysql-rangers < NAME-OF-DUMP-FILE.sql

8. The database should be loaded up and the stack good to go.

## Test for mysql port exposure

On another machine:

$ telnet ranger-clubhouse.nv.burningman.org 3306

Telnet should NOT be able to connect. If it does, check the iptable entries on the server.
