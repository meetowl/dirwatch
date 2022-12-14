#!/bin/bash
# Watches a directory, copies to another if a file exists
# Originally meant for photo storage

# TODO create an install.sh file (interactive and not)
# TODO add ability to control fate of duplicates
# TOOD start basing where to put directories based on the contents inside,
#      rather than their stat output.
# Checks if all variables are properly assigned
function init_check(){
	# watch_dir exists and is writable
    if [[ ! -d $watch_dir ]] || [[ ! -w $watch_dir ]]
    then
		print_to_error "error: $watch_dir does not exist or is not writable." 

		exit 1
	fi

	# move_to_dir exists and is writable
	if [[ ! -d $move_to_dir ]] || [[ ! -w $move_to_dir ]]
	then
		print_to_error "error: $move_to_dir does not exist or is not writable."
		exit 1
	fi

	# trash_dir exists
	if [[ ! -d $trash_dir ]]
	then
		if ! mkdir $trash_dir &> $log
		then
			print_to_error "error: cannot create $trash_dir."
		fi
	fi

	if [[ ! -w $trash_dir ]]
	then
		print_to_error "error: $trash_dir is not writable."
	fi

	# user exists
    if [[ -z `cat /etc/passwd | 
	          sed -n -E "/^$own_user.*/p"` ]]
    then
		print_to_error "error: user $own_user does not exist" 
		exit 1
    fi

	# group exists
    if [[ -z `cat /etc/group |
	   	  	  sed -n -E "/^$own_group.*/p"` ]]
    then
		print_to_error "error: group $own_group does not exist" 
		exit 1
    fi

	# trash_interval is in the correct format
	if [[ $(echo $trash_interval | sed -E 's/^[0-9]+$//') ]]
	then
		print_to_error "error: trash interval ($trash_interval) is not an integer."
		exit 1
	fi
	
}

# Simplifies writing to error log
function print_to_error(){
	echo $1 >> /dev/stderr 
	echo $1 >> $error_warn
	echo $1 >> $log
}

# Sets new_file_exists to 1 if new file is detected
function detect_new_file(){
    if [[ `ls $watch_dir` ]]
    then
		new_file_exists=1
    fi
}
                                                                                

# Contains all ways I thought of to get the creation date
function get_date_of_file(){
	# YYYYMMDD
	date_of_file=$(echo $1 | 
	sed -n -E 's/.*(20[0-9]{2}[0-2][0-9][0-3][0-9]).*/\1/p')


	# YYYY-MM-DD
	if [[ -z $date_of_file ]]
	then
	   date_of_file=$(echo $1 | 
	   sed -n -E 's/.*(20[0-9]{2}-[0-2][0-9]-[0-3][0-9]).*/\1/p')		
	fi

	# Stat command output
	if [[ -z $date_of_file ]]
	then
		date_of_file=$(stat "$1" |
		sed -n -E 's/Modify: (20[0-9]{2}-[0-1][0-9]-[0-3][0-9]).*/\1/p')
	fi

	if [[ -z $date_of_file ]]
	then
		print_to_error "error: unable to find date of $1."
		exit 1
	fi
	

	# Transforms to consistent YYYY-MM-DD format for easier interpretation
	date_of_file=`echo $date_of_file |
	sed -E 's/(20[0-9]{2})([0-1][0-9])([0-3][0-9])/\1-\2-\3/'`

}

# Uses ISO date of file to determine which year folder
function get_year_and_month(){

    declare -a month_to_name_array
    month_to_name_array=("$1 has selected month 0"
						 "1. January" "2. February" "3. March"
						 "4. April" "5. May" "6. June" "7. July"
						 "8. August" "9. September" "10. October"
						 "11. November" "12. December")

	get_date_of_file "$1"

	year=`echo $date_of_file | 
		  sed -E 's/^([0-9]{4})-.*/\1/'`

	month=`echo $date_of_file | 
		   sed -E 's/.+-([0-9]{2})-.+/\1/'`
	month=$(echo $month |
				sed -E 's/^0([1-9]+)$/\1/')
	month=${month_to_name_array[$[$month]]}
}

function check_duplicates(){
	# If there exists a file with the same name as in watch_dir
    if [ `ls $move_to_dir/$year/"$month" | grep $1` ] 
    then
		# If "x" followed by ".format"
		if [[ "$1" =~ .*\.[a-z]+ ]]
		then
			# Looks for a number in brackets right before the
			# . extension
			old_dup_number=$(echo $1 |
								 sed -n -E 's/.*\(([0-9]+)\)\.[a-z]*$/\1/p')
		else
			old_dup_number=$(echo $1 |
								 sed -n -E 's/\(([0-9]+)\)$/\1/p')
			no_dot_extension=1
		fi

		# If it can't find a "(x)", inserts it's own (1)
		if [[ -z $old_dup_number ]]
		then
			# Inserts (1) into filename
			if [[ $no_dot_extension = 1 ]]
			then
				new_file_name=$(echo $1 |
									sed -E 's/$/(1)/')
			else
				new_file_name=$(echo $1 | 
							   sed -E "s/(\.[a-z]*$)/(1)\1/")
			fi
		else
			old_dup_number=$(echo $old_dup_number | sed 's/^0//')
			new_dup_number=$[$old_dup_number+1]

			if [[ $no_dot_extension = 1 ]]
			then
				new_file_name=$(echo $1 |
									sed -E "s/\(0-9\)$/($new_dup_number)/")
			else
			# Since filename already has (x), adds to it and inserts
			# into filename
			new_file_name=`echo $1 | 
			   sed -E "s/\([0-9]\)(\.[a-z]*)$/($new_dup_number)\1/"`
			fi
		fi

    fi
	unset old_dup_number new_dup_number no_dot_extension
}

# Checks if the passed filename matches the error log name
# sets file_is_error_log
function check_if_error_log(){
    if [[ "$watch_dir/$1" =  $error_warn ]]
    then
		file_is_error_log=1
	else
		file_is_error_log=0
	fi
}

# Checks if passed file name is the error log ($error_warn),
# sets $file_is_log
function check_if_log(){
	if [[ "watch_dir/$1" = $log ]]
	then
		# message
		echo "detected"
		file_is_log=1
	else
		file_is_log=0
	fi
}

# Copies only desired files from watch to move
function copy_files(){
    files_total=`ls $watch_dir | wc -l`
    declare -a files
    i=0
    # lists through files, puts into array
    while [ $i -lt $files_total ];
	do

		files[$i]="$(ls $watch_dir | sed -n $[$i+1]p)"
		((i++))
    done
    unset i files_total
	
    # for{} rotates through files in above array,
    # extracts date, creates directories for date if needed,
    # copies, changes privilegdes, writes to log,
    # deletes everyithing in watch_dir
    for file in "${files[@]}"; do
		# Skips if file has same name as $error_warn
		check_if_error_log $file
		if [[ $file_is_error_log = 1 ]]
		then
			error_log_in_watch_dir=1
			continue
		fi

		check_if_log $file
		if [[ $file_is_log = 1 ]]
		then
			log_in_watch_dir=1
			continue
		fi
		
		
		# function sets $year and $month according to file
		get_year_and_month "$watch_dir/$file"
		
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
		if cp --preserve=timestamps -r "$watch_dir/$file" "$move_to_dir/$year/$month/$new_file_name"
		then
			chown  $own_user:$own_group \
   				   $move_to_dir/$year/"$month"/"$new_file_name"
			chmod 770 $move_to_dir/$year/"$month"/"$new_file_name"

			echo "msg: copied $file to storage directory" \
				 >> $log
		else
			error_msg=`echo "error: $(date "+%D %R") $file copying failed."`
			print_to_error $error_msg
			exit 1
		fi

		move_to_trash "$file"
    done
}

function rotate_trash(){
    trash_dir_total=`ls $trash_dir | wc -l`
    declare -a trash_dirs

    i=0

    # lists through files, puts into array
    while [ $i -lt $trash_dir_total ]
	do
		trash_dirs[$i]=`ls $trash_dir | sed -n $[$i+1]p `
		((i++))
    done
    unset i
    for dir in ${trash_dirs[@]}; do
		if [[ $dir < $(expr $(date +%s) - $trash_interval) ]]
		then
			rm -rf "$trash_dir/$dir"
		fi
    done
}

# Moves passed file to trash
function move_to_trash(){
	# Makes timestamp for trash collection
	if [[ $trash_dir_created != 1 ]]
	then
		timestamp="$(date +%s)"
		rotate_trash $timestamp
		mkdir $trash_dir/$timestamp
		trash_dir_created=1
	fi
	   
    if ! mv "$watch_dir/$1" $trash_dir/$timestamp 
	then
		print_to_error "error: failed to move $1 to trash."
		exit 1
	fi

	if [[ $file_is_error_log = 1 ]]
	then
		erlog_name=$(echo $error_warn | sed -E 's|.*\/(.*)$|\1|')
		mv $trash_dir/$timestamp/$erlog_name $watch_dir
	fi

	if [[ $file_is_log = 1 ]]
	then
		# message
		echo "detected"
		log_name=$(echo $log | sed -E 's|.*\/(.*)$|\1|')
		mv $trash_dir/$timestamp/$log_name $watch_dir
	fi
}


# Main script
if ! source /home/meetowl/program/dirwatch//dirwatch.conf 
then
    echo "error: configuration file corrupted or missing."
    exit 1
fi

init_check

if [[ -f $error_warn ]]
then
	print_to_error "error: error file $error_warn exists and error may have occurred last run, delete file to continue regular usage."
	exit 1
fi



detect_new_file
if [[ $new_file_exists = 1 ]]
then
    copy_files
fi

exit 0






