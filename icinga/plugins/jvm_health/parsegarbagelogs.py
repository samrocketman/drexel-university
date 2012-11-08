#!/usr/bin/env python
#Author: Chris Holcombe
import os.path
import os

sqlite_3 = 1;

try:
    import sqlite3
    sql = sqlite3;
except ImportError:
    import sqlite
    sql = sqlite;
    sqlite_3 = 0;
from cStringIO import StringIO

import optparse
import re
import sys

__author__ = "cjh66"
__date__ = "$Jan 26, 2010 1:58:58 PM$"

GarbageLog = None;
sqlitedb = None;
skip_times = 0;

#Counters to sum up events
young_gc_events = 0;
young_gc_time = 0;
full_gc_events = 0;
full_gc_time = 0;

def is_number(s):
    try:
        float(s)
        return True
    except ValueError:
        return False

def get_current_data():
    if(sqlitedb is None):
        print "Could not locate sqlite database";
        sys.exit(-1);
    conn = sql.connect(sqlitedb);
    if(conn is None):
        print "Could not connect to sqlite database";
        sys.exit(-1);
    cursor = conn.cursor();
    cursor.execute("select *,ROWID from datapoints ORDER BY ROWID DESC Limit 1");
    row = cursor.fetchone();    
    if (row is None):
        conn.close();
        return None;
    else:
        #this query will get the latest non zero old_space and perm_space information.
        #we're assuming old/perm space stays the same until otherwise notified.  
        cursor.execute("select old_space,perm,ROWID from datapoints where perm > 0 and old_space > 0 order by ROWID DESC Limit 1");
        row2 = cursor.fetchone();
        if(row2 is None):
            #couldn't gather all the data we needed.  Just fill in what we have an return it.
            ####
            file_string = StringIO();
            #timestamp
            file_string.write(row[0]);
            file_string.write(",");
            #young_space
            file_string.write(row[1]);
            file_string.write(",");
            #old_space, most likely zero in this case
            file_string.write(row[2]);
            file_string.write(",");
            #perm_space, most likely zero in this case
            file_string.write(row[3]);
            file_string.write(",");
            #young_gc_events
            file_string.write(row[4]);
            file_string.write(",");
            #young_gc_collection_time
            file_string.write(row[5]);
            file_string.write(",");
            #full_gc_events
            file_string.write(row[6]);
            file_string.write(",");
            #full_gc_collection_time
            file_string.write(row[7]);
            file_string.write(",");
            #total_gc_collection_time
            file_string.write(row[8]);

            conn.close();

            return file_string.getvalue();
        if(len(row) is 10 and len(row2) is 3):
            #we got the correct data, proceed
            #clunky way of doing it but several for loops looks bad also
            file_string = StringIO();
            #timestamp
            file_string.write(row[0]);
            file_string.write(",");
            #young_space
            file_string.write(row[1]);
            file_string.write(",");
            #old_space
            file_string.write(row2[0]);
            file_string.write(",");
            #perm_space
            file_string.write(row2[1]);
            file_string.write(",");
            #young_gc_events
            file_string.write(row[4]);
            file_string.write(",");
            #young_gc_collection_time
            file_string.write(row[5]);
            file_string.write(",");
            #full_gc_events
            file_string.write(row[6]);
            file_string.write(",");
            #full_gc_collection_time
            file_string.write(row[7]);
            file_string.write(",");
            #total_gc_collection_time
            file_string.write(row[8]);

            return file_string.getvalue();
        else:
            return None;

    conn.close();

def insert_data_into_db(timestamp, young, old, per, y_gc, y_gc_time, f_gc, f_gc_time, t_gc_time):
    #jetty changes up the names to:
    #DefNew -> YoungGen
    #Perm -> PermGen
    #Tenured -> OldGen

    if(sqlitedb == None):
        print "Could not locate sqlite database";
        sys.exit(-1);
    conn = sql.connect(sqlitedb);
    if(conn == None):
        print "Could not connect to sqlite database";
        sys.exit(-1);
    cursor = conn.cursor();
    if not is_number(timestamp):
        timestamp = "0"
    if(sqlite_3):
        cursor.execute("Insert into datapoints values(?,?,?,?,?,?,?,?,?)", (timestamp, young, old, per, y_gc, y_gc_time, f_gc, f_gc_time, t_gc_time,));
    else:
        cursor.execute("Insert into datapoints values(%s,%s,%s,%s,%s,%s,%s,%s,%s)", (timestamp, young, old, per, y_gc, y_gc_time, f_gc, f_gc_time, t_gc_time,));

    rowid = cursor.lastrowid;
    conn.commit();
    conn.close();
    #check if the insert worked or not.  Return true/false accordingly.
    if (rowid > 0):
        return True;
    else:
        return False;

def check_timestamp(timestamp):
    if(sqlitedb == None):
        print "Could not locate sqlite database";
        sys.exit(-1);
    conn = sql.connect(sqlitedb);
    if(conn == None):
        print "Could not connect to sqlite database";
        sys.exit(-1);
    cursor = conn.cursor();
    t = (timestamp,)

    if(sqlite_3):
        cursor.execute("Select timestamp from `datapoints` where `timestamp` = ?", t);
    else:
        cursor.execute("Select timestamp from `datapoints` where `timestamp` = %s", t);
    row = cursor.fetchone();
    conn.close();
    if row == None:
        return False;
    else:
        return True;

#this will truncate the database to save space.  max_value is the
#maximum amount of entries the database should have
#Deletes entries from the database.  The max_value is the maximum 
#number of entries the database should contain. Example: max_value = 100
#database contains 200 entries.  1-100 will be deleted and 101-200 will be retained.
def cleanup_db(max_value):
    if(sqlitedb == None):
        print "Could not locate sqlite database";
        sys.exit(-1);
    conn = sql.connect(sqlitedb);
    if(conn == None):
        print "Could not connect to sqlite database";
        sys.exit(-1);
    cursor = conn.cursor();
    cursor.execute("select ROWID from datapoints order by ROWID desc limit 1");
    largest_row = cursor.fetchone();
    cursor.execute("select count(ROWID) from datapoints");
    num_of_rows = cursor.fetchone();
    if (largest_row is None):
        print "Sqlite database error, unable to determine largest row in database";
        return -1;
    else:
        if(num_of_rows[0] > max_value):
            #database is too large, truncate
            #save the newest rows and delete the oldest rows
            print "Cleaning up database";
            print "Deleting all rows with ROWID less than: " + str(int(largest_row[0])-int(max_value));
            max = (int(largest_row[0])-int(max_value),)

            if(sqlite_3):
                cursor.execute("Delete from `datapoints` where ROWID < ?", max);
                conn.commit();
            else:
                cursor.execute("Delete from `datapoints` where ROWID < %s", max);
                conn.commit();

            conn.close();
            return 1;
        else:
            conn.close();
            return 0;

def parse_heap_block(line):
    #307212K->68908K (340800K)
    token_index = 0;
    r_token_index = line.find("-");
    starting_occupancy = line[token_index:r_token_index];
    starting_occupancy = re.sub("\D", "", starting_occupancy);

    token_index = r_token_index + 2;
    r_token_index = line.find("(", token_index);
    ending_occupancy = line[token_index:r_token_index];
    ending_occupancy = re.sub("\D", "", ending_occupancy);

    token_index = r_token_index + 1;
    r_token_index = line.find(")", token_index);
    max_size = line[token_index:r_token_index];
    max_size = re.sub("\D", "", max_size);

    return starting_occupancy, ending_occupancy, max_size

def parse_collector_block(line):
    #   [PSYoungGen: 579136K->5184K(624000K)]
    #or [PSOldGen: 85996K->51496K(110912K)]
    #or [PSPermGen: 57347K->57347K(57536K)]
    #or [DefNew: 1152K->64K(1152K), 0.0032350 secs]

    #set the inital index positions
    token_index = 0;
    r_token_index = line.find(":");

    collector = line[token_index:r_token_index];

    #get the starting occupancy:
    token_index = r_token_index;
    r_token_index = line.find("-", token_index);

    starting_occupancy = line[token_index + 2:r_token_index];
    starting_occupancy = re.sub("\D", "", starting_occupancy);

    #advance to next field and get ending occupancy:
    token_index = r_token_index + 2;
    r_token_index = line.find("(", token_index);
    ending_occupancy = line[token_index:r_token_index];

    token_index = r_token_index + 1;
    r_token_index = line.find(")", token_index);
    max_size = line[token_index:r_token_index];
    max_size = re.sub("\D", "", max_size);

    #strip non-numeric chars
    ending_occupancy = re.sub("\D", "", ending_occupancy);

    percent_usage = float (1.0 * int(ending_occupancy) / int(max_size)) * 100;
    percent_usage = int(percent_usage);

    return collector, starting_occupancy, ending_occupancy, max_size, percent_usage;

def parse_time_block(line):
    #[Times: user=90.00 sys=9.08, real=75.96 secs]

    #get the user time
    token_index = line.find("=");
    r_token_index = line.find(" ", token_index);
    u_time = line[token_index + 1:r_token_index];

    #get the system time
    token_index = line.find("=", r_token_index);
    r_token_index = line.find(",", token_index);
    s_time = line[token_index + 1:r_token_index];


    #get the real time
    token_index = line.find("=", r_token_index);
    r_token_index = line.find(" ", token_index);
    r_time = line[token_index + 1:r_token_index];

    return u_time, s_time, r_time;

def parse_2(filename):
    '''
        We're going to try and find 2 things.
        First we want the last Full GC line.  After that we want the last
        Regular GC line.  This should have enough data to fill in 1 sqlite
        database entry.  This will reduce overhead on the sqlite database
        by 99% most likely instead of storing every row.

        Note young_gc_events/time and full_gc_events/time will be off
        using this method.  Not sure how to fix this just yet.
    '''
    global young_gc_time
    global full_gc_events
    global full_gc_time
    global young_gc_events
    parse_points = [];
    insert_data = [0,0,0]
    reg_gc = None
    full_gc = None
    
    for line in os.popen('tac %s'%filename):
        #do something with the line
        if reg_gc is None and "Full" not in line:
            reg_gc = line
        elif full_gc is None and "Full" in line:
            full_gc = line
        if reg_gc is not None and full_gc is not None:
            break

    #parse the regular GC line we found
    timestamp = reg_gc[0:reg_gc.find(":")];

    for i in xrange(len(reg_gc)):
        if(cmp(reg_gc[i], "[") == 0):
            parse_points.append(i);
        elif(cmp(reg_gc[i], "]") == 0):
            start = parse_points.pop();
            section = reg_gc[start + 1:i];    #current location in string
            if "Full" in section:
                #just get the full gc time and continue
                comma = section.rfind(",");
                space = section.find(" ",comma+2);
                time = section[comma+2:space];
                full_gc_time+=float(time);
                full_gc_events+=1;
                continue;
            elif "GC" in section:
                #just get the regular gc time and continue
                comma = section.rfind(",");
                space = section.find(" ",comma+2);
                time = section[comma+2:space];
                young_gc_time+=float(time);
                young_gc_events+=1;
                continue;
            elif "PSOldGen" in section:
                insert_data[1] = parse_collector_block(section)[4];
            elif "PSPermGen" in section:
                insert_data[2] = parse_collector_block(section)[4];
            elif "PSYoungGen" in section:
                insert_data[0] = parse_collector_block(section)[4];
            elif "DefNew"in section:
                insert_data[0] = parse_collector_block(section)[4];
            elif "Tenured" in section:
                insert_data[1] = parse_collector_block(section)[4];
            elif "Perm" in section:
                insert_data[2] = parse_collector_block(section)[4];

    #parse the full gc line if it was found
    if full_gc is not None:
        for i in xrange(len(full_gc)):
            if(cmp(full_gc[i], "[") == 0):
                parse_points.append(i);
            elif(cmp(full_gc[i], "]") == 0):
                start = parse_points.pop();
                section = full_gc[start + 1:i];    #current location in string
                if "Full" in section:
                    #just get the full gc time and continue
                    comma = section.rfind(",");
                    space = section.find(" ",comma+2);
                    time = section[comma+2:space];
                    full_gc_time+=float(time);
                    full_gc_events+=1;
                    continue;
                elif "GC" in section:
                    #just get the regular gc time and continue
                    comma = section.rfind(",");
                    space = section.find(" ",comma+2);
                    time = section[comma+2:space];
                    young_gc_time+=float(time);
                    young_gc_events+=1;
                    continue;
                elif "PSOldGen" in section:
                    insert_data[1] = parse_collector_block(section)[4];
                elif "PSPermGen" in section:
                    insert_data[2] = parse_collector_block(section)[4];

                #skip the young data section, the regular gc block will give
                #us more updated info
                #elif "PSYoungGen" in section:
                    #insert_data[0] = parse_collector_block(section)[4];
                #elif "DefNew"in section:
                    #insert_data[0] = parse_collector_block(section)[4];

                elif "Tenured" in section:
                    insert_data[1] = parse_collector_block(section)[4];
                elif "Perm" in section:
                    insert_data[2] = parse_collector_block(section)[4];

    insert_data_into_db(timestamp, insert_data[0], insert_data[1],
                        insert_data[2], young_gc_events, young_gc_time,
                        full_gc_events, full_gc_time, (full_gc_time + young_gc_time));
def parse(file):
    #Parsing rules
    #1) whenever "[" is found, push that int location on the stack
    #2) whenever "]" is found, pop the stack and slice from "[":"]"
    #3) Check the sliced data to see what it is, Full GC, Regular GC, times, or some various generation info
    #4) Parse with the appropriate function
    #5) Truncate the file to size=0 to reset the log.

    global young_gc_time;
    global full_gc_events;
    global full_gc_time;
    global young_gc_events;
    parse_points = [];
    for line in file:
        colon = line.find(":")
        timestamp = line[0:colon];
        #print "Timestamp: '" + timestamp + "'";

        #if the data isn't in the database, insert it
        if(check_timestamp(timestamp) == 0):
            #print "Adding log event to database ";

            insert_data = [0,0,0];

            for i in xrange(colon,len(line)):
                if(cmp(line[i], "[") == 0):
                    parse_points.append(i);
                elif(cmp(line[i], "]") == 0):
                    start = parse_points.pop();
                    section = line[start + 1:i];    #current location in string
                    if "Full" in section:
                        #just get the full gc time and continue
                        comma = section.rfind(",");
                        space = section.find(" ",comma+2);
                        time = section[comma+2:space];
                        full_gc_time+=float(time);
                        full_gc_events+=1;
                        continue;
                    elif "GC" in section:
                        #just get the regular gc time and continue
                        comma = section.rfind(",");
                        space = section.find(" ",comma+2);
                        time = section[comma+2:space];
                        young_gc_time+=float(time);
                        young_gc_events+=1;
                        continue;
                    #elif "Times" in section:
                        #print "Times: ",
                        #print parse_time_block(section),
                    elif "PSOldGen" in section:
                        insert_data[1] = parse_collector_block(section)[4];
                    elif "PSPermGen" in section:
                        insert_data[2] = parse_collector_block(section)[4];
                    elif "PSYoungGen" in section:
                        insert_data[0] = parse_collector_block(section)[4];
                    elif "DefNew"in section:
                        insert_data[0] = parse_collector_block(section)[4];
                    elif "Tenured" in section:
                        insert_data[1] = parse_collector_block(section)[4];
                    elif "Perm" in section:
                        insert_data[2] = parse_collector_block(section)[4];
            #print "";
            #print "Full_GC_Events: " + str(full_gc_events);
            #print "Young_GC_Events: " + str(young_gc_events);
            #print "Young % full: " + str(insert_data[0]);
            #print "Old % full: " + str(insert_data[1]);
            #print "Perm % full: " + str(insert_data[2]);
            #print "\n" #skip a line
            insert_data_into_db(timestamp, insert_data[0], insert_data[1],
                                insert_data[2], young_gc_events, young_gc_time,
                                full_gc_events, full_gc_time, (full_gc_time + young_gc_time));

        #else:
            #print "Log event already recorded in database";

def main():
    global GarbageLog;
    global sqlitedb;
    global skip_times;

    parser = optparse.OptionParser(usage="usage: %prog [options] arg", version="%prog 1.2");
    parser.add_option("-f", dest="GarbageLog", help="Read data from log");
    parser.add_option("-s", dest="sqlitedb", help="Store data in sqlite database");
    parser.add_option("-c", dest="cleandb", help="Delete old data in the database.  Specify max number of rows")
    parser.add_option('-g', help='Get current data row', dest='get_data', default=False, action='store_true');

    #parse the command line arguments and see what we got
    (opts, args) = parser.parse_args();

    if opts.get_data is True:
        if opts.sqlitedb is None:
            print "Please also specify the sqlite database to use with -s option";
            parser.print_help();
            sys.exit(-1);
        sqlitedb = opts.sqlitedb;
        print get_current_data();
        sys.exit();

    if opts.cleandb is not None:
        if opts.sqlitedb is None:
            print "Please also specify the sqlite database to use with -s option";
            parser.print_help();
            sys.exit(-1);
        if(opts.cleandb.isdigit()):
            max_value = opts.cleandb;
            sqlitedb = opts.sqlitedb;
            cleanup_db(max_value);
            sys.exit();
        else:
            print "-c option needs a number specified.";
            parser.print_help();
            sys.exit(-1);

    if opts.GarbageLog is None:
        print "-f GarbageLog is missing";
        parser.print_help();
        sys.exit(-1);

    if opts.sqlitedb is None:
        print "-s sqlitedb is missing";
        parser.print_help();
        sys.exit(-1);

    GarbageLog = opts.GarbageLog;
    sqlitedb = opts.sqlitedb;

    # Check to see if the user supplied good file information
    if(os.path.isfile(GarbageLog) is False):
        print "Can not find Garbagelog: " + GarbageLog;
        print "exiting";
        sys.exit(-1);
    elif (os.path.isfile(sqlitedb) is False):
        print "Can not find Sqlitedb: " + sqlitedb;
        print "exciting";
        sys.exit(-1);


    #f = open(GarbageLog, "r+");
    parse_2(GarbageLog);
    cleanup_db(5000);
    #f.close();
    return;

if __name__ == "__main__":
    main();
