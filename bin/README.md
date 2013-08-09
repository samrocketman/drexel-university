# How do I use some of these scripts?

----
## clusterssh helper scripts

I use the following helper scripts to maintain the `/etc/clusters` file:

* `knownhosts.sh`
* `missing_from_all_clusters.sh`
* `servercount`
* `sort_clusters`

I maintain my `/etc/clusters` file with a standard naming convention.  The first line has an `All_clusters` alias.  Its only purpose is to be an alias for all aliases in the `/etc/clusters` file.  From there every alias starts with one of two standard prefixes: `cluster_` or `host_`.

Here is a sample `/etc/clusters` file using that naming convention.

    All_clusters cluster_website cluster_dns host_Config_management
    
    cluster_website host1.domain.com host2.domain.com host3.domain.com
    
    cluster_dns ns1.domain.com ns2.domain.com
    
    host_Config_management someconfigmanagement.domain.com

`knownhosts.sh` - This script reads stdin a list of host names, queries the ssh fingerprint, and checks to see if that known host exists in `~/.ssh/known_hosts`.  If it exists then it outputs nothing.  If there's any missing (or possibly incorrect) then it will output only the problem hosts.  If no hosts have any problems then it exits with a proper success exit code.  This can be used with `servercount`.

`missing_from_all_clusters.sh` - This goes through the `/etc/clusters` file for all of the aliases and checks to make sure that all aliases are added to `All_clusters`.  If there is no alias then it will output the problem entry.  There will be no output if all entries are properly accounted for.

`servercount` - This goes through the `/etc/clusters` file and displays a list of host names only (with no aliases).  This will consist of one host per line.

`sort_clusters` - As you keep adding aliases to `/etc/clusters` there becomes a need to alphabetically sort the aliases in the file.  This will sort the aliases.  It also sorts the list of aliases on the `All_clusters` line at the top of the file.

### Example usage

Get a head count of the number of servers in the clusters file.

    servercount | wc -l

Check that there aren't any bad `known_hosts` fingerprints for clusters host names.

    servercount | knownhosts.sh

Generage a list of ip addresses associated with all of the hosts.

    servercount | while read server;do dig +short ${server};done
    servercount | while read server;do echo "$(dig +short ${server}) ${server}";done

The remaining scripts are fairly standalone.

----
## wasted-ram-updates.py

Ever hear about Linux being able to update without ever needing to be restarted (with exception for a few critical packages)?  Ever wonder how to figure out which services need to actually be restarted after a large update of hundreds of packages?  With `wasted-ram-updates.py` you no longer need to wonder.

`wasted-ram-updates.py` helps to resolve these questions by showing which running processes are using files in memory that have been deleted on disk.  This lets you know that there is likely an outdated library being used.  If you restart the daemon associated with this process then it will use the updated copy of the library.

### List of packages which require a restart

Over time I've encountered a small list of critical packages which require a restart of the Linux OS.  Here's a non-comprehensive list of which I'm aware.  Feel free to open an [issue](https://github.com/sag47/drexel-university/issues) letting me know of another package which requires a system reboot.

* dbus (used by `/sbin/init` which is pid 1)
* glibc
* kernel

Other than that you should be able to simply restart the associated service.

_Please note: some programs regularly create and delete temporary files which will show up in `wasted-ram-updates.py`.  This is normal and does not require a service restart for this case._

### Example usage

Just display an overall summary

    wasted-ram-updates.py summary

Organize the output by deleted file handle (I've found this to be less useful for accomplishing a system update).

    wasted-ram-updates.py

Organize the output by process ID and show a heirarchy of deleted file handles as children to the PIDs.  This is the most useful command for determining which services to restart.

    wasted-ram-updates.py pids

----
## gitar.sh - A simple deduplication and compression script
This is an [original idea by Tom Dalling](http://tomdalling.com/blog/random-stuff/using-git-for-hacky-archive-deduplication/).

`gitar.sh` is a simple deduplication and compression script.  It uses git to deduplicate data and then other compression algorithms to compress data.  This short script was made for when you have to compress a large amount of duplicated files.  It also comes with a handly little utility, `gintar.sh`, for decompressing the archive on the receiving end.  See Usage section for more information.

`gitar.sh` assumes you do not have [lrzip](https://github.com/ckolivas/lrzip) readily available.  lrzip can compress better and deduplicate better than this script.  Also, this script has known limitations which are not bound to lrzip such as not being able to compress git repositories.  gitar.sh is meant as a quick hack 'n slash dedupe and compress.  See the benchmarks for when I tested gitar.sh against other compression methods.

### Compression options
You can set different compression options with the `compression_type` environment variable.

    #  0 - no compression, just deduplication
    #  1 - deduplication+optimized git compression
    #  2 - deduplication+optimized git+gzip compression
    #  3 - deduplication+optimized git+bzip2 compression
    export compression_type=3

### Known Limitations/Won't Fix
* Not able to compress git repositories or nested git repositories.
* If you're using `gitar.sh` on a directory that contains wholly unique data and no duplicates then the result will actually be slightly larger than using `tar` with `bzip2` or `gzip` due to the metadata of `git`.
* When extracting a `.gitar` archive using `tar` it is possible to destroy a git repository in the current working directory if one previously exists.
* It is assumed you will be compressing a single directory.  If you need to compress multiple directories or files then place them all inside of a directory to be gitar'd.
* You must compress a directory located in the current directory or located in a child.  If the path you're compressing is located above the current working directory in a parent directory then this will fail because git can't do that.

### Usage
Simply compress a directory.

    gitar.sh "somedirectory"

Subshell the compressing of an archive and set the compression level to 2

    (export compression_type=2; gitar.sh "somedirectory")

Decompress a `gitar` archive.

    tar -xf "somefile.gitar"
    ./gintar.sh

### Benchmarks of gitar.sh hack vs other utilities

#### Environment

* [Tested Repository](https://github.com/tomdalling/opengl-series) with git directories removed.
* 3rd Gen Intel® Core™ i7-3770 (Quad Core, 3.40GHz, 8MB L2)
* 8GB RAM, NON-ECC, 1600MHZ DDR3,2DIMM
* 512GB Samsung 840 Pro Series 2.5" SSD

Some file system stats for my system using `dd`.

    #READ RATE
    $ dd if=./coursematerial.tar.gz of=/dev/null
    1386091+1 records in
    1386091+1 records out
    709678734 bytes (710 MB) copied, 4.02507 s, 176 MB/s
    #WRITE RATE
    $ dd if=/dev/zero of=./test2
    827170+0 records in
    827170+0 records out
    423511040 bytes (424 MB) copied, 18.1395 s, 23.3 MB/s

Now on to the good stuff....

#### Compression ratios
For the ratios I used max compression for all utilities (`gzip -9`, and `bzip -9`, and `compression_level=3` for `gitar.sh`, and `lrztar -z` respectively).

    Size    Name                  Type            % of original size
    132M    opengl-series         Uncompressed    100.0%
    95M     opengl-series.tar     tar             72.0%
    30M     opengl-series.tgz     tar+gzip        22.7%
    27M     opengl-series.tbz2    tar+bzip2       20.5%
    5.9M    opengl-series.gitar   git+tar+bzip2   4.5%
    4.4M    opengl-series.tar.lrz tar+lrzip       3.3%

#### Compression times
I used the `time` utility and took an average of 3 runs for each.

    Name                  Type            real value (from time command)
    opengl-series         Uncompressed    0m0.000s (no command was executed)
    opengl-series.tar     tar             0m0.707s
    opengl-series.tgz     tar+gzip        0m7.200s
    opengl-series.tbz2    tar+bzip2       0m11.521s
    opengl-series.gitar   git+tar+bzip2   0m3.977s
    opengl-series.tar.lrz tar+lrzip       0m24.338s

#### Benchmark Conclusion
If you want the absolute best compression ratio with the best deduplication then `lrzip` is the utility for you.  However, based on my benchmarks `gitar.sh` achieved a similar ratio in less than one sixth of the time.  `gitar.sh` is a little less user friendly and there are some known drawbacks to using it.  However, if none of these known issues are a problem then `gitar.sh` is great for being fast and highly compressed.  When in doubt of any of the known issues or you're looking for the best compression ratios then `lrzip` is the best candidate.
