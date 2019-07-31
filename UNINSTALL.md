# Uninstalling the Playa Clubhouse - AKA Moving The Clubhouse back to the cloud.

1. Announce on Control 1 the Clubhouse is shutting down a moving back to the Cloud.

2. TBD: stop the frontend nginx stack

3. Verify the frontend webserver is stopped by trying to visit ranger-clubhouse.nv.burningman.org

4. Dump the database

```sh
$ ./bin/rangers-exec db /usr/bin/mysqldump -u rangers -p rangers | gzip > rangers.sql.gz
```

You will be prompted for the local mysql password.

5. Transfer rangers.sql.gz up to blaster.

6. Load the production database with the dump

7. MAKE SURE ALL CHANGES/COMMITS TO THE CLUBHOUSE REPOSITORIES HAVE BEEN PUSHED UP, PASS THE TRAVIS-CI BUILDS, AND NO FARGATE DEPLOYMENTS ARE PENDING.

8. Login to Twilio, and reset the SMS endpoint.

In the sidebar select Programmable SMS > SMS > Message Services > Ranger SMS

Under inbound settings set "Request URL" back to:

https://ranger-clubhouse.burningman.org/api/sms/inbound

9. TBD: Spin up the api & client production Fargate instances.

10. TBD: Remove the redirection to ranger-clubhouse.nv from the Load Balancer.

11. Announce on Control 1 the Clubhouse has been moved back to the Cloud. Use the default world 'ranger-clubhouse.burningman.org' url.

12. Shutdown the playa sever, use an air compress or canned air to blast off the dust, pack up, enjoy the ride home.
