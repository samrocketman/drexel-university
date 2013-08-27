# Munin Plugins

This is a set of munin plugins which I wrote or coauthored.

---
## java\_vm\_time

This script uses [parsegarbagelogs.py](https://github.com/sag47/drexel-university/blob/master/icinga/plugins/jvm_health/).  To set this plugin up you must first get `parsegarbagelogs.py` working.  From there you must use symlinks to execute the different plugin types for monitoring Java with munin.

    #e.g. let's say we place it at /usr/share/munin/plugins/java_vm_time
    source="/usr/share/munin/plugins/java_vm_time"
    ln -s $source /etc/munin/plugins/java_graph
    ln -s $source /etc/munin/plugins/java_vm_threads
    ln -s $source /etc/munin/plugins/java_vm_time
    ln -s $source /etc/munin/plugins/java_vm_uptime
