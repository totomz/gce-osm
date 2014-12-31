#!/bin/bash


#######################
# EDIT THESE SETTINGS #
#######################

DATASET=http://download.geofabrik.de/north-america-latest.osm.pbf # What to import :)

# DB
DB_NAME=osm
DB_USER=osm
DB_USER_ALLOWED_ADDR=172.16.3.0/24

# HD settings
DISK_SSD1=google-osm-pgdata1
#DISK_SSD2=google-osm-pgdata2 #Not used yet
DISK_DATA=google-osm-tempdata
PATH_PLANET=$MOUNT_SSD1/temp    # Where the pbf is (temprary) stored
PATH_DUMPS=$MOUNT_DATA/dumps    # Where the dumps will be generated

MOUNT_SSD1=/pgdata	# Mount point for pg_data
#MOUNT_SSD2=/pgtbls  # Mount point for some tables/indexes
MOUNT_DATA=/osmdata

# Settings for huge memory pages
# see
KERN_SHMMAX=57982058496
KERN_SHMMALL=100
KERN_NR_HUGEPAGES=100
LARGEPAGE_GROUP=largemem
LARGEPAGE_GID=1999


# Other stuff (no need to change)
CODENAME=$(lsb_release -sc)		# Version of debian
TMP_DIALOG=/tmp/ptv-optima-installer-db.dialog

