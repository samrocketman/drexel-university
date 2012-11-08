#!/usr/bin/python
__author__="Chris Holcombe"
__date__ ="$May 13, 2010 1:08:49 PM$"

'''
The purpose of this script is to tell nagios when the java process
being monitored is having a problem.  I am defining a 'warning' state to be
when the java young memory space is about 50% usage.  I will also make the
'critical' state be when the young memory space usage is about 90% and the JVM
is probably about to crash.

This script will connect to the sqlite database defined, query the last known
state of the JVM and then decide what exit code/return status to return to
nagios.

Nagios return status:

0   OK          The plugin was able to check the service and it appeared to be functioning properly
1   Warning     The plugin was able to check the service, but it appeared to be above some "warning" threshold.
2   Critical    The plugin detected that either the service was not running or it was above some "critical" threshold

'''
sqlite_3 = 1;

import sys
import os

try:
    import sqlite3
    sql = sqlite3;
except ImportError:
    import sqlite
    sql = sqlite;
    sqlite_3 = 0;


sqlitedb='/var/db/sqldb'     #SQLite database to store the information we're collecting

def get_current_data():
    if(sqlitedb is None):
        return None
    conn = sql.connect(sqlitedb);
    if(conn is None):
        return None
    cursor = conn.cursor();
    cursor.execute("select young_space,ROWID from datapoints ORDER BY ROWID DESC Limit 1");
    row = cursor.fetchone();
    conn.close();
    if (row is None):
        conn.close();
        return None;
    else:
        #this query will get the latest young_space information.
        return row[0]

def main():
    global sqlitedb

    # Check to see if the user supplied good file information
    if (os.path.isfile(sqlitedb) is False):
        print "Can not find Sqlitedb: " + sqlitedb;
        sys.exit(2);

    # Get the current usage data
    young_space = int(get_current_data())
    if young_space is None:
        print "Error getting young space information"
        sys.exit(2)
    elif young_space < 50:
        print "Young space usage is good"
        sys.exit(0)
    elif young_space >= 50 and young_space < 90:
        print "Young space usage is > 50%"
        sys.exit(1)
    else:
        print "Young space usage is > 90%.  Crash is highly likely."
        sys.exit(2)

if __name__ == "__main__":
    print main()
