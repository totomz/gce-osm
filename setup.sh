#!/bin/bash

# This script install the prerequsites for importing a planet osm
# It runs on debian/bubuntu
# Requirements: to achieve the best performances, the db should be splitted on several hd
# EXEC
if [ "$UID" -ne 0 ]
  then echo "Please run as root (sudo -s) "
  exit
fi

# Read the settings
source settings.sh

# Format and mounts a gce-disk $1 disk-by-id; $2 mount point
function gcemount {
	parted -s /dev/disk/by-id/$1 mktable gpt
	parted -s /dev/disk/by-id/$1 mkpart primary ext4 0% 100%
	sleep 5
	mkfs.ext4 /dev/disk/by-id/$1-part1 -L pgdata
	sleep 2
	mkdir $2
	echo "/dev/disk/by-id/$1-part1 $2 ext4 noatime,data=writeback,barrier=0,nobh 0 2" >> /etc/fstab
	mount -a
}

echo "Installing basic tools"
apt-get update && apt-get install dialog curl pbzip2 python2.7 python-pip

echo "Mounting hd"
gcemount $DISK_SSD1 $MOUNT_SSD1
#gcemount $DISK_SSD2 $MOUNT_SSD2
gcemount $DISK_DATA $MOUNT_DATA

# Change ownership of /data
chown -R $(who am i | awk '{print $1}') $MOUNT_DATA
# Install PostgreSQL
dialog --title "Databse setup"  --yesno "I can install PostgreSQL and create a PostGIS db.\nCan I proceed?" 10 40
if [ "$?" = "0" ]
	then

    echo "Adding PostgreSQL repository for $CODENAME"
    echo "deb http://apt.postgresql.org/pub/repos/apt/ $CODENAME-pgdg main" > /etc/apt/sources.list.d/pgdg.list

    echo "Updating the PGP key"
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
    apt-get update

    echo "Installing PostgreSQL and PostGIS"
    apt-get install postgresql-9.3 postgresql-9.3-postgis-2.1 python-psycopg2

    dialog \
	  --title "DB Creation" \
	  --inputbox "Please add the name for the db\n(will be DROPPED if exists)" \
		10 60 "$DB_NAME" 2> $TMP_DIALOG
	DB_NAME=$(cat $TMP_DIALOG)

	# Switch to user postgresql to execute a Query...
	su postgres -c "psql postgres -c 'DROP DATABASE IF EXISTS $DB_NAME'"
	su postgres -c "psql postgres -c 'CREATE DATABASE $DB_NAME'"
	su postgres -c "psql $DB_NAME -c 'CREATE EXTENSION hstore'"
	su postgres -c "psql $DB_NAME -c 'CREATE EXTENSION postgis'"
	su postgres -c "psql $DB_NAME -c 'CREATE EXTENSION postgis_topology'"

	echo "Installed PostGIS version:"
	su postgres -c "psql $DB_NAME -c 'SELECT PostGIS_full_version();' -t -P pager=off"
fi

# ADD AN USER THAT CAN ACCESS TO THE DATABASE
dialog --title "DB setup"  --yesno \
	"You need an user to access the db from remote.\nCan I create it for you? " 15 60
if [ "$?" = "0" ]
	then
	# Ask for a username
	dialog \
	  --title "DB Setup" \
	  --inputbox "username" \
		20 60 "$DB_USER" 2> $TMP_DIALOG
	DB_USER=$(cat $TMP_DIALOG)

	su postgres -c "createuser $DB_USER --pwprompt"
	su postgres -c "psql postgres -c 'GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER'"

	#Now, some magic - add the entry to pg_hba
	dialog \
	  --title "DB Setup" \
	  --inputbox "Remote address from which the user can connect\n(it will be added to pg_hba.conf)" \
		20 60 "$DB_USER_ALLOWED_ADDR" 2> $TMP_DIALOG

	DB_USER_ALLOWED_ADDR=$(cat $TMP_DIALOG)

	# Updating pg_hba to allow remote connection
	fileFound=$( find / -iname 'pg_hba.conf' | wc -l )
	if [ $fileFound -gt 1 ]
		then echo "Warning! Multiple pg_hba.conf file found. You must grant remote connection to this database to user $DB_USER to "
	else
		fpath=$( find / -iname 'pg_hba.conf')
		cp $fpath $(dirname $fpath)/pg_hba.conf.original

		echo -e "\n" >> $fpath
		echo -e "#OSM - service user " >> $fpath
		echo -e "host\t$DB_NAME\t\t$DB_USER\t\tlocalhost\t\ttrust" >> $fpath
		echo -e "host\t$DB_NAME\t\t$DB_USER\t\t$DB_USER_ALLOWED_ADDR\t\tmd5" >> $fpath

	fi
	PG_HBA_PATH=$find
fi

echo "***************************************************************"
echo "* WARNING! SYSTEM TUNING!                                     *"
echo "***************************************************************"
echo "* The OSM db requires some fine tuning of postgresql.conf:    *"
echo "* 	1) High memory                                          *"
echo "* 	2) No WAL and big buffer size                           *"
echo "***************************************************************"
echo "Can I tune the db for you? [yes/No]"
read executeTuner

if [ "$executeTuner" = "yes" ]
	then

	# Search for postgresql.conf
    pg_conf_file=$(find / -iname 'postgresql.conf' | wc -l)

    if [ $pg_conf_file -gt 1 ]
        then
            echo "Too much postgresql.conf file found. Quitting"
    fi

    pg_conf_file=$(find / -iname 'postgresql.conf')

    now=$(date +"%s")
    cp $pg_conf_file $pg_conf_file.$now

    # Allowing remote connection
    sed -i "s/.*listen_addresses.*$/listen_addresses = '*'/" $pg_conf_file

    # Memory management
    sed -i "s/.*shared_buffers.*$/shared_buffers = 2GB/" $pg_conf_file
    sed -i "s/.*temp_buffers.*$/temp_buffers = 256MB/" $pg_conf_file
    sed -i 's/.*[^_]work_mem.*$/work_mem = 256MB/' $pg_conf_file
    sed -i 's/.*maintenance_work_mem.*$/maintenance_work_mem = 4096MB/' $pg_conf_file

    # Disabling WAL
    sed -i "s/.*wal_level.*$/wal_level = minimal/" $pg_conf_file
    sed -i "s/.*fsync.*=.*on.*$/fsync = off/" $pg_conf_file
    sed -i "s/.*full_page_writes.*$/full_page_writes = off/" $pg_conf_file
    sed -i "s/.*checkpoint_segments.*$/checkpoint_segments = 64/" $pg_conf_file
    sed -i "s/.*checkpoint_timeout.*$/checkpoint_timeout = 35min/" $pg_conf_file
    sed -i "s/.*checkpoint_completition_target.*$/checkpoint_completition_target = 0.8/" $pg_conf_file

    # Query tuning
    sed -i "s/.*random_page_cost.*$/random_page_cost = 2.5/" $pg_conf_file

    # LOCK management
    sed -i "s/.*deadlock_timeout.*$/deadlock_timeout = 5min/" $pg_conf_file

	# Move pg_data
	sed -i "s/.*data_directory.*$/data_directory='$MOUNT_SSD1/main'/" $pg_conf_file # BUG! va escapato il path!
	cp -r /var/lib/postgresql/9.3/main $MOUNT_SSD1
	chown -R postgres:postgres $MOUNT_SSD1
	mkdir $MOUNT_SSD1/temp && chmod -R 0777 $MOUNT_SSD1/temp # Temp dir for operations

	#chown -R postgres:postgres $MOUNT_SSD2

	echo "Can I restart PostgreSQL service now? [yes/No]"
	read restart
	if [ "$restart" = "yes" ]
		then
			service postgresql restart
	fi
fi\

echo "Installing java"
echo "deb http://ppa.launchpad.net/webupd8team/java/ubuntu precise main" | tee /etc/apt/sources.list.d/webupd8team-java.list
echo "deb-src http://ppa.launchpad.net/webupd8team/java/ubuntu precise main" | tee -a /etc/apt/sources.list.d/webupd8team-java.list
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys EEA14886
apt-get update
apt-get install oracle-java7-installer


echo "Setting Huge memory pages options (these settings are not permanent)"
echo $(KERN_SHMMAX) > /proc/sys/kernel/shmmax
#echo $(KERN_SHMMALL) > /proc/sys/kernel/shmall usually no need to set this...
echo $(KERN_NR_HUGEPAGES) > /proc/sys/vm/nr_hugepages
echo $(LARGEPAGE_GID) > /proc/sys/vm/hugetlb_shm_group

