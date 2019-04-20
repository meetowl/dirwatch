#!/bin/bash
# Watches a directory, copies to another if a file exists
# Originally meant for photo storage

# TODO add command flags like proper --now support, --no-log, etc.
# TODO port everything to /usr/share or something
# TODO create an install.sh file (interactive and not)
# TODO add status command

# Load configuration variables
if ! source /etc/dirwatch.conf
then
    echo "error: configuration file corrupted or missing"
    exit 1
fi

# Checks if all variables are properly assigned
function init_check(){
    if [[ -d $watch_dir ]] && [[ -w $watch_dir ]]
    then
	if [[ -d $move_to_dir ]] && [[ -w $move_to_dir ]]
	then
	    init_error=0
	else
	    printf "error: $move_to_dir does not exist or is not writable\n"
	    exit 1
	fi
    else
	printf "error: $watch_dir does not exist or is not writable\n"
	exit 1
    fi
    if [[ -z `echo $interval | sed -n '/[0-9]*s/p'` ]]
    then
	printf 'error: $interval is incorrectly set. '
	printf 'Please use a number followed by an \"s\" character.\n'
	exit 1
    fi
    if [[ -z `cat /etc/passwd | 
	          sed -n -E "/^$own_user.*/p"` ]]
    then
	echo "error: user $own_user does not exist"
	exit 1
    fi
    if [[ -z `cat /etc/group |
	   	  	  sed -n -E "/^$own_group.*/p"` ]]
    then
	echo "error: group $own_group does not exist"
	exit 1
    fi
}

# Returns 1 if new file is detected
function detect_new_file(){
    if [[ -z `ls $watch_dir` ]]
    then
	new_file_exists=0
    else
	new_file_exists=1
    fi
}

# Most cameras auto-name files with timestamps, tries to find one
# and use it if possible, otherwise take what's written in stat.
function is_name_usable_for_date(){
    # extracts date from name
    date_in_name=`echo $1 |
	sed -n -E 's/.*(20[0-9]{2}[0-2][0-9][0-3][0-9]).*/\1/p'`
    # if extracted string exists
    if [[ $date_in_name ]] 
    then
	name_usable_for_date="true"
    else
	name_usable_for_date="false"
    fi
}
# Uses ISO date of file to determine which year folder
function sort_file_date(){
    is_name_usable_for_date "$1"
    declare -a month_to_name_array
    month_to_name_array=("lmao arrays don't start at 0 'round here"
			 "1. January" "2. February" "3. March"
			 "4. April" "5. May" "6. June" "7. July"
			 "8. August" "9. September" "10. October"
			 "11. November" "12. December")
    if [[ $name_usable_for_date = "true" ]]
    then
	# The 4 following sed calls simply extract either only print
	# the first 4 numbers for year, or the middle 2 for month
	year=`echo $date_in_name | 
			  sed -E -n 's/^(20[0-9]{2})[0-9]{4}$/\1/p'`

	month=`echo $date_in_name | 
			   sed -n -E 's/^20[0-9]{2}([0-9]{2})[0-9]{2}$/\1/p' |
			   sed 's/^0//'`
	month=${month_to_name_array[$[$month]]}
    else

	    
	year=`stat $1 |
		      sed -n -E 's/Modify: (20[0-9]{2}).*/\1/p'`

	echo "meme"

	month=`stat $1 | sed -n -E 's/Modify: 20[0-9]{2}-([0-9]{2})-.*/\1/p' | sed 's/^0//'`
	echo "meme"

	month=${month_to_name_array[$month]}
    fi

}

function check_duplicates(){
    if [ `ls $move_to_dir/$year/"$month" | grep $1 ` ] 
    then
	# Looks for a number in brackets right before the
	# . extension
	old_dup_number=`echo $1 | 
						sed -n -E 's/.*\(([0-9])\)\.[a-z]*$/\1/p'`
	# If it can't find a "(x)", inserts it's own (1)
	if [[ $old_dup_number = "" ]]
	then
	    # Inserts (1) into filename
	    new_file_name=`echo $1 | 
			   sed -E "s/(\.[a-z]*$)/(1)\1/"`	
	else
	    echo $old_dup_number
	    old_dup_number=$(echo $old_dup_number | sed 's/^0//')
	    new_dup_number=$[$old_dup_number+1]
	    # Since filename already has (x), adds to it and inserts
	    # into filename
	    new_file_name=`echo $1 | 
			   sed -E "s/\([0-9]\)(\.[a-z]*)$/($new_dup_number)\1/"`
	fi

    fi
}

# Checks if watch_directory has the error log ($error_warn),
# sets file_is_error_log
function check_if_error_log(){
    # extracts name of error log file
    if [[ $1 = `echo $error_warn | 
	            sed -E 's|.*\/(.*)$|\1|'` ]]
    then
	file_is_error_log=1
    else
	file_is_error_log=0
    fi
}

# Copies only desired files from watch to move
function copy_files(){
    files_total=`ls $watch_dir | wc -l`
    declare -a files
    i=0
    # lists through files, puts into array
    while [ $i -lt $files_total ]; do
	files[$i]=`ls $watch_dir | sed -n $[$i+1]p `
	((i++))
    done

	
    unset i
    # for{} rotates through files in above array,
    # extracts date, creates directories for date if needed,
    # copies, changes privilegdes, writes to log,
    # deletes everyithing in watch_dir
    for file in ${files[@]}; do


	# Skips if file has same name as $error_warn
	check_if_error_log $file
	if [[ $file_is_error_log = 1 ]]
	then
	    error_file_exists=1
	    continue
	fi

	# function sets $year and $month according to file
	sort_file_date $watch_dir/$file

	
	# if year/month directories don't exist, create them
	if [[ -d $move_to_dir/$year ]]
	then
	    if [[ -d $move_to_dir/$year/"$month" ]]
	    then
		new_file_name=$file
		check_duplicates $file
	    else
		mkdir $move_to_dir/$year/"$month"
		echo made $move_to_dir/$year/"$month" >> $log
	    fi
	else
	    mkdir -p $move_to_dir/$year/"$month"
	    echo made $move_to_dir/$year/"$month" >> $log
	fi

	
	# copies, if error prints log and exits with 1
	if cp --preserve=all -r $watch_dir/$file $move_to_dir/$year/"$month"/"$new_file_name"
	then
	    chown  $own_user:$own_group \
   		   $move_to_dir/$year/"$month"/"$new_file_name"
	    #			chmod  -x  $move_to_dir/$year/"$month"/"$new_file_name"

	    echo "msg: copied $file to storage directory" \
		 >> $log
	else
	    error_msg=`echo "error: $(date "+%D %R") $file copying failed."`
	    echo $error_msg >> $error_warn
	    echo $error_msg >> $log
	    unset error_msg
	    exit 1
	fi
	
    done
    echo "done"
    move_watch_to_trashcan
    #	rm -rf $watch_dir/*

}

function rotate_trash(){
    trash_dir_total=`ls $trash_dir | wc -l`
    declare -a trash_dirs
    i=0
    # lists through files, puts into array
    while [ $i -lt $files_total ]; do
	trash_dirs[$i]=`ls $trash_dir | sed -n $[$i+1]p `
	((i++))
    done
    unset i

    for dir in ${trash_dirs[@]}; do
	mv dir $trash_dir
    done
    
}

function move_watch_to_trashcan(){
    timestamp="010101"

    rotate_trash $timestamp
    mkdir $trash_dir/$timestamp

    mv $watch_dir/* $trash_dir

    echo $(date +%s) >> $trash_dir/.timestamp
    
}


# This function is deprecated in favor of systemd .timer files
# Corrects time so checks start at XX:00 so synchronization
# times are predictable, only run on startup.
# function time_correct(){
#     minute_now=$( date "+%M" )
#     second_now=$( date "+%S" )
#     second_since_hour=$[ ($minute_now * 60) + $second_now ]
#     if [[ $[$second_since_hour % 3600] != 0 ]]
#     then
# 		till_00=$[ 3600 - $second_since_hour]
# 		echo "sleeping for $till_00"
# 		sleep $till_00
#     fi
# }

# Main script
init_check

detect_new_file
if [[ $new_file_exists = 1 ]]
then
    copy_files
fi

exit 0






