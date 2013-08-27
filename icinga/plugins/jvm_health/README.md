# JVM GC Performance Tuning and Alerts

The garbage collector's young object memory space is reported so that memory leaks can be detected in developing applications.  To learn more about performance tuning and garbage collection in Java 1.6 then check out the following articles.

* http://www.petefreitag.com/articles/gctuning/
* http://www.oracle.com/technetwork/java/javase/gc-tuning-6-140523.html

---
## How it works

### Prerequisites

Be sure to place `jvm_health.py` and `parsegarbagelogs.py` in `/usr/local/sbin/`.

Must enable garbage collection logs in the JVM options.

    JAVA_OPTS="$JAVA_OPTS -XX:+PrintGCDetails -Xloggc:/path/to/log/garbage.log"

Create an sqlite database which will be used by `parsegarbagelogs.py`.


    sqlite3 /var/db/sqldb
    CREATE TABLE `datapoints` (`timestamp` varchar(40),`young_space` varchar(20), `old_space` varchar(20), `perm` varchar(20), `young_gc` varchar(25),`young_gc_collection_time` varchar(25), `full_gc` varchar(25), `full_gc_collection_time` varchar(25),`total_gc_time` varchar(25));
    .quit

There should be a cron job which runs parsegarbagelogs.py every 15 minutes.

    0,15,30,45 * * * * /usr/local/sbin/parsegarbagelogs.py -f /path/to/log/garbage.log -s /var/db/sqldb > /dev/null 2>&1


`parsegarbagelogs.py` parses the garbage collector logs and calculates the percentage of memory of the young object memory space against the total space. It takes that calculated value and stores it in an sqlite database located at /var/db/sqldb. parsegarbagelogs.py should have owner `root:nsca` with `755` permissions if you're using passive checks in Icinga. The cron job for `parsegarbagelogs.py` is run by root and `crontab -l` shows the cron job listing.

### Monitoring JVM-HEALTH

`jvm_health.py` is a Icinga plugin which reads the calculated percentage from the sqlite database and reports a status to Icinga. If the young object memory percentage is less than 50% then it is good. If greater than 50% then warning. If greater than 90% then critical and a crash is imminent. Here is the `cmds` variable in the [report-status.py](https://github.com/sag47/drexel-university/blob/master/icinga/scripts/report-status.py) script for [passive Icinga checks](http://docs.icinga.org/latest/en/passivechecks.html).

    cmds = {
      "LOAD": "check_load -w 5,5,5 -c 10,10,10",
      "DISK": "check_disk -w 5% -c 1%",
      "PROCS-SENDMAIL": "check_procs -u root -C sendmail -w 1: -c 1:",
      "PROCS-NTPD": "check_procs -u ntp -C ntpd -w 1: -c 1:",
      "JVM-HEALTH": "/usr/local/sbin/jvm_health.py"
    }

### Resolving JVM-HEALTH error states

First check the garbage.log to be sure that there is an actual problem with the free memory for young objects. See the articles previously mentioned for how to read garbage.log.  If garbage.log is truly reporting a problem then the next step is to look at munin for your JVM server under the "JVM Garbage Collection Time Spent" graph. It should look like a saw tooth under weekly, monthly, and yearly. If the graph is a permanently inclining step graph then it means there is possibly a memory leak in one of the test client apps on your JVM so work with your developer to figure out the root cause.  At this point, assuming you're not in a mid-crisis in production (you should have a service highly available or this should be a test system) you may go ahead and enable a remote JVM console and hook up Java VisualVM (`jvisualvm`).  See what you can figure out from thread dumps, heap dumps, and so on.  If you find your system is pegged at 100% CPU usage it could be caused by a race condition across unsynchronised threads.  You can verify that by profiling the runtime with `jvisualvm` and look to see if multiple threads are stuck in the same method.  Once you're done diagnosing you should go ahead and kill the JVM app server and restart it.

In Icinga, to resolve the error state you must execute `parsegarbagelogs.py` (it updates the sqldb), `jvm_health.py` (to verify the check passes), and `report-status.py` to ensure an update is immediately submitted to Icinga.
