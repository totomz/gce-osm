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

CODENAME=$(lsb_release -sc)		# Version of debian

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


APT_ASSUME_YES=""
yes="yes"
if [ "$SILENT_INSTALL" = "yes" ]
	then
	APT_ASSUME_YES="--assume-yes"
fi

echo "Installing basic tools"
apt-get update && apt-get $APT_ASSUME_YES installp curl pbzip2 python2.7 python-pip

echo "Mounting hd"
gcemount $DISK_SSD1 $MOUNT_SSD1
#gcemount $DISK_SSD2 $MOUNT_SSD2
gcemount $DISK_DATA $MOUNT_DATA

# Change ownership of /data
chown -R $(who am i | awk '{print $1}') $MOUNT_DATA

# Install PostgreSQL
if [ "$SILENT_INSTALL" = "yes" ]
    then
    	yes="yes"
    else
    echo "Can I install PostgreSQL, PostGIS and Python? [yes/No]"
	read yes
fi

if [ "$yes" = "yes" ]
	then

    echo "Adding PostgreSQL repository for $CODENAME"
    echo "deb http://apt.postgresql.org/pub/repos/apt/ $CODENAME-pgdg main" > /etc/apt/sources.list.d/pgdg.list

    echo "Updating the PGP key"
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
    apt-get update

    echo "Installing PostgreSQL and PostGIS"
    apt-get $APT_ASSUME_YES install postgresql-9.3 postgresql-9.3-postgis-2.1 python-psycopg2
fi

# Crete the OSM db
# Switch to user postgresql to execute a Query...
su postgres -c "psql postgres -c 'DROP DATABASE IF EXISTS $DB_NAME'"
su postgres -c "psql postgres -c 'CREATE DATABASE $DB_NAME'"
su postgres -c "psql $DB_NAME -c 'CREATE EXTENSION hstore'"
su postgres -c "psql $DB_NAME -c 'CREATE EXTENSION postgis'"
su postgres -c "psql $DB_NAME -c 'CREATE EXTENSION postgis_topology'"

echo "Installed PostGIS version:"
su postgres -c "psql $DB_NAME -c 'SELECT PostGIS_full_version();' -t -P pager=off"
su postgres -c "createuser $DB_USER --pwprompt"
su postgres -c "psql postgres -c 'GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER'"


# ADD AN USER THAT CAN ACCESS TO THE DATABASE
# Updating pg_hba to allow remote connection
fileFound=$( find / -iname 'pg_hba.conf' | wc -l )
if [ $fileFound -gt 1 ]
	then echo "Warning! Multiple pg_hba.conf file found. You must grant remote connection to this database to user $DB_USER to "
else
	fpath=$( find / -iname 'pg_hba.conf')
	cp $fpath $(dirname $fpath)/pg_hba.conf.original

	echo -e "\n" >> $fpath
	echo -e "#OSM - service user " >> $fpath
	echo -e "host\tall\t\tall\t\tlocalhost\t\ttrust" >> $fpath
	echo -e "host\t$DB_NAME\t\t$DB_USER\t\t$DB_USER_ALLOWED_ADDR\t\tmd5" >> $fpath

fi


echo "***************************************************************"
echo "* WARNING! SYSTEM TUNING!                                     *"
echo "***************************************************************"
echo "* The OSM db requires some fine tuning of postgresql.conf:    *"
echo "* 	1) High memory                                          *"
echo "* 	2) No WAL and big buffer size                           *"
echo "***************************************************************"

if [ "$SILENT_INSTALL" = "yes" ]
    then
    	yes="yes"
    else
    echo "Can I install PostgreSQL, PostGIS and Python? [yes/No]"
	read yes
fi

if [ "$yes" = "yes" ]
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
    sed -i "s/.*random_page_cost.*$/random_page_cost = 1/" $pg_conf_file

    # LOCK management
    sed -i "s/.*deadlock_timeout.*$/deadlock_timeout = 5min/" $pg_conf_file

	# Move pg_data
	sed -i "s/.*data_directory.*$/data_directory='$MOUNT_SSD1/main'/" $pg_conf_file # BUG! va escapato il path!
	cp -r /var/lib/postgresql/9.3/main $MOUNT_SSD1
	chown -R postgres:postgres $MOUNT_SSD1

	mkdir $MOUNT_SSD1/temp && chmod -R 0777 $MOUNT_SSD1/temp # Temp dir for operations
	#chown -R postgres:postgres $MOUNT_SSD2

	service postgresql restart
fi

if [ "$SILENT_INSTALL" = "yes" ]
    then
    	yes="yes"
    else
    echo "Can I install PostgreSQL, PostGIS and Python? [yes/No]"
	read yes
fi

if hash java 2>/dev/null; then
	echo "Java seems to be already installed"
else

	if [ "$yes" = "yes" ]
		then
			echo "Installing java"
			echo "deb http://ppa.launchpad.net/webupd8team/java/ubuntu precise main" | tee /etc/apt/sources.list.d/webupd8team-java.list
			echo "deb-src http://ppa.launchpad.net/webupd8team/java/ubuntu precise main" | tee -a /etc/apt/sources.list.d/webupd8team-java.list
			apt-key adv --keyserver keyserver.ubuntu.com --recv-keys EEA14886
			apt-get update
			apt-get install oracle-java7-installer
	fi
fi

echo "Please run ./osmosis.sh as normal user"