#!/bin/bash

# read the settings
source settings.sh

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

# Create the db schema
psql -U $DB_USER -h localhost -d $DB_NAME -f osmosis/script/pgsnapshot_schema_0.6.sql
psql -U $DB_USER -h localhost -d $DB_NAME -f osmosis/script/pgsnapshot_schema_0.6_linestring.sql
psql -U $DB_USER -h localhost -d $DB_NAME -f osmosis/script/pgsnapshot_schema_0.6_bbox.sql
psql -U $DB_USER -h localhost -d $DB_NAME -f osmosis/script/pgsnapshot_load_0.6.sql

# Copy load scripts in the dump folder
cp *.sql $PATH_DUMPS

# Bashmajic... configuring the python script!
sed -i "s/DB_NAME.*$/DB_NAME = \"$DB_NAME\"/" osm.py
sed -i "s/DB_USER.*$/DB_USER = \"$DB_USER\"/" osm.py
sed -i "s/DUMP_PATHS.*$/DUMP_PATHS = \"$PATH_DUMPS\"/" osm.py

# Reboot and change instance type, or execute the workflow!
python osm.py
