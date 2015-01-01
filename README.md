gce-osm
=======

A set of bash/python scripts to perform an unmanaged installation of a brand-new OSM database in a [Google Cloud Engine](https://cloud.google.com/compute/) instance
 The bash scripts installs the tools (PostgreSQL+PostGIS, Java+osmosis) and perform the basic tuning of the system/db.
These scripts were created to perform an import of a full OSM planet dump in a postgis db, in the most efficient way. The original import
process requires manual intervention, and is not multi-threaded (specially during the creation of the indexes)

There are the following scripts:
* `setup.sh` - install the needed software (db, java), mounts the hd and tune the os and the db (some user interaction required here)
* `osm.py` - contains a simple fork-and-join python script that download the osm planet file and creates and import the data in the db

# Hardware requirements
These scripts are intended to be used to import a full planet db. 
To import a full planet, you need the following instance:
* n1-highmem-16 (16cpu, 104GB ram)
* 2x 500GB SSD (for db)
* 1x300GB Standard (for root system)
* 1x1000GB for holding temporary data
(Actually, the n1-highmem-16 is needed only for converting the planet to sql dumps; after this operation, you may scale to n1-highmem-8, or even n1-standard-8)

The script enables large memory pages for java, to boost the performance
The scripts automajically format and mount and the HDs.

# Utilization

> Read the scripts before executing them!

First of all, you need to enable large memory pages for your account (you need to logout and login again to make the changes permanent).
```
# groupadd -g <GID> <LARGE_PAGE_GROUP>
# sudo usermod -a -G <LARGE_PAGE_GROUP> <YOUR_USER>

```


./pippo.sh |& tee -a log.txt

Take note of GID and group, because you need to add them to setup.sh

Clone this repo `sudo apt-get update && sudo apt-get install git && git clone https://github.com/totomz/gce-osm`

Edit the settings in `settings.sh`.

Then, execute as sudo `setup.sh`

Creates the dump using `osmosis.sh` 

Import the dumps using `python osm.py` (EDIT DB CONNECTION CONFIG!)

At 30/12/2014, the resulting db has the following size 
           relation            |  size
-------------------------------|---------
 public.nodes                  | 257 GB
 public.way_nodes              | 152 GB
 public.ways                   | 143 GB
 public.pk_way_nodes           | 92 GB
 public.pk_nodes               | 55 GB
 pg_toast.pg_toast_17968       | 6215 MB
 public.pk_ways                | 5631 MB
 public.relation_members       | 1870 MB
 public.pk_relation_members    | 1027 MB
 public.relations              | 512 MB
 pg_toast.pg_toast_17968_index | 164 MB
 public.pk_relations           | 64 MB
 public.users                  | 15 MB
 public.pk_users               | 10 MB
 public.spatial_ref_sys        | 3184 kB
 pg_toast.pg_toast_17962       | 1944 kB
 pg_toast.pg_toast_17977       | 1360 kB
 pg_toast.pg_toast_2618        | 344 kB
 public.spatial_ref_sys_pkey   | 144 kB
 pg_toast.pg_toast_1255        | 64 kB
 
 
 # Bibliography
 * http://wiki.openstreetmap.org/wiki/Osmosis
 * http://www.paulnorman.ca/blog/2011/11/loading-a-pgsnapshot-schema-with-a-planet-take-2/
 