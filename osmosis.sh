#!/bin/bash

# read the settings
source settings.sh

# Enabling uge pages
echo "Setting Huge memory pages options (these settings are not permanent)"

o_shmmax=$(cat /proc/sys/kernel/shmmax)
o_nr_huge=$(cat /proc/sys/vm/nr_hugepages)
o_gid=$(cat /proc/sys/vm/hugetlb_shm_group)

echo $(KERN_SHMMAX) > /proc/sys/kernel/shmmax
#echo $(KERN_SHMMALL) > /proc/sys/kernel/shmall usually no need to set this...
echo $(KERN_NR_HUGEPAGES) > /proc/sys/vm/nr_hugepages
echo $(LARGEPAGE_GID) > /proc/sys/vm/hugetlb_shm_group

# Settings for osmosis
export JAVACMD_OPTIONS="-server -Djava.io.tmpdir=$MOUNT_SSD1/temp/ -Xms50G -Xmx92G -XX:MaxPermSize=2G -XX:+UseG1GC -XX:-UseAdaptiveSizePolicy -XX:SurvivorRatio=1 -XX:G1HeapRegionSize=32m -XX:+UseLargePages"

# Create a temp dir for storing the planet file
mkdir $PATH_DUMPS

echo "Downlading the dataset"
wget -O $PATH_DUMPS/dataset.osm.pbf $DATASET

echo "Converting the dataset to dumps (dataset will be deleted after this operation)"
osmosis/bin/osmosis --read-pbf-fast file=$PATH_DUMPS/dataset.osm.pbf workers=8 --log-progress interval=30 --buffer \
            --write-pgsql-dump directory=$PATH_DUMPS enableBboxBuilder=yes enableLinestringBuilder=yes \
            nodeLocationStoreType=InMemory && rm $PATH_DUMPS/dataset.osm.pbf

# Disable largepages (PostgreSQL 9.4 *has* largepages..)
echo $(o_shmmax) > /proc/sys/kernel/shmmax
#echo $(KERN_SHMMALL) > /proc/sys/kernel/shmall usually no need to set this...
echo $(o_nr_huge) > /proc/sys/vm/nr_hugepages
echo $(o_gid) > /proc/sys/vm/hugetlb_shm_group

# Create the db schema
psql -U $DB_USER -h localhost -d $DB_NAME -f osmosis/script/pgsnapshot_schema_0.6.sql
psql -U $DB_USER -h localhost -d $DB_NAME -f osmosis/script/pgsnapshot_schema_0.6_linestring.sql
psql -U $DB_USER -h localhost -d $DB_NAME -f osmosis/script/pgsnapshot_schema_0.6_bbox.sql
psql -U $DB_USER -h localhost -d $DB_NAME -f osmosis/script/pgsnapshot_load_0.6.sql

# Copy load scripts in the dump folder
cp *.sql $PATH_DUMPS

# Reboot and change instance type, or execute the workflow!
python3 osm.py
