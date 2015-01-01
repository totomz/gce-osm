#!/bin/bash


#######################
# EDIT THESE SETTINGS #
#######################
# DON'T ADD INLINE COMMENTS! Comments only on new lines
# this file is eval() by python

# What to import :)
DATASET="http://download.geofabrik.de/north-america-latest.osm.pbf"

# General settings
# If "yes", enables --assume-yes pr apt-get and do not ask anything (pg+java are installed; pg is configured)
SILENT_INSTALL="yes"

# DB
DB_NAME="osm"
DB_USER="osm"
DB_USER_ALLOWED_ADDR="0.0.0.0/0"

# HD /dev/disk/by-id names and their mount points
DISK_SSD1="google-osm-db-pgdata"

MOUNT_SSD1="/pgdata"
#DISK_SSD2="google-osm-pgdata2"
#MOUNT_SSD2="/pgtbls"
DISK_DATA="google-osm-db-data"
MOUNT_DATA="/osmdata"

# Where the pbf is (temprary) stored
PATH_PLANET="$MOUNT_SSD1/temp"
# Where the dumps will be generated
PATH_DUMPS="$MOUNT_DATA/dumps"

# Settings for huge memory pages
# see http://www.peuss.de/node/67
KERN_SHMMAX=98784247808
KERN_SHMMALL=47104
KERN_NR_HUGEPAGES=47104
LARGEPAGE_GROUP="largemem"
LARGEPAGE_GID=1500


