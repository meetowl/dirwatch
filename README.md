## dirwatch.sh 
The idea behind this is to have a simpler time with self-organized 
photo storage, where you have a dedicated file used for dropping in random 
pictures that you want to save in a hierarchial directory structure ordered 
by Year/Month
<br>
## Example
Watch directory: /srv/photo-drop 
Tree directory: /srv/photo 
```
Drop a file into the watch directory
Every hour, it gets filtered through a bash script and ends up in 
"/srv/photo/YEAR/MONTH", where YEAR and MONTH are extracted from either the 
file name, modified date or other means necessary. The file is then moved to
a "recycle bin" from the watch directory, and deleted after 2 weeks.
```
## Prerequisites
This is currently only compatible with GNU/Linux based systems running 
systemd. <br>
Most of the work is done by you (directory creation and maintenance), this
is a script which I use for sorting exclusively.

## Install 
Please note that this is work-in-progress, and an install script has not been
made.
1. Clone the repository
```
    git clone https://gitlab.com/meetowl/dirwatch.git
```

2. Edit configuration file 
You need to edit the configuration file to your liking, where:
    - `watch_dir` is the directory where the files will be dropped
    - `move_to_dir` is the directory where the files will be moved to
    - `trash_dir` is the directory which the files in watch_dir will be
       moved to after synchronizing (this can be in `watch_dir`)
    - `trash_interval` is how often the trash is erased
    - `log` needs to be a file, which all non-error events are logged
    - `error_warn` needs to be a file, which all error-related events are logged
    - `own_user` is a user that will be run the file (a new seperate user is 
       recommended)
    - `own_group` is a group that will own all the directories, and people in
       that group will be allowed to read/write/execute everything. (add your 
        user to this group)
```
    $ nano ./dirwatch.conf.default
```

3. Move some things around
``` 
    # cp ./dirwatch.conf.default /etc/dirwatch.conf
    # cp ./dirwatch.{service,timer} /etc/systemd/sytem
    # cp ./dirwatch.sh /usr/bin
```
4. Test out the configuration
    - Make sure all directories have correct permissions
    - Put a file into your `watch_dir` and run `# dirwatch.sh` as the 
      programs `own_user` and see if it works as intended

5. Reload and enable the systemd timer for periodic synchonization
```
    # systemctl daemon-reload
    # systemctl enable dirwatch.timer
    # systemctl start dirwatch.timer
```

And you're done!
This process is going to be automated at some point(TM)

