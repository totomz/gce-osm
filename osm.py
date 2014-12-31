__author__ = 'tommaso'

# Imports OSM dumps in a db - in a multi threaded way :O

from workflows import Workflow
import psycopg2
import subprocess


DB_NAME = "osm"
DB_USER = "osm"
DUMP_PATHS = "/osmdata/dumps"

class SQLQuery(Workflow.Action):

    def __init__(self, query):
        super(SQLQuery, self).__init__(query)
        self.query = query

    def execute(self):
        conn = psycopg2.connect(host="localhost", database=DB_NAME, user=DB_USER)
        cur = conn.cursor()
        cur.execute(self.query)
        cur.close()
        conn.close()
        # time.sleep(random.random() * 10)
        # return ""

class Command(Workflow.Action):

    def __init__(self, command):
        super(Command, self).__init__(command)
        self.command = command

    def execute(self):
        subprocess.Popen(self.command)


Workflow.Workflow()\
    .join("Loading dumps", 2, [
        Command("psql -U {} -h localhost -d {} -f {} ".format(DB_USER, DB_NAME, DUMP_PATHS+"/copy_users.sql")),
        Command("psql -U {} -h localhost -d {} -f {} ".format(DB_USER, DB_NAME, DUMP_PATHS+"/copy_nodes.sql")),
        Command("psql -U {} -h localhost -d {} -f {} ".format(DB_USER, DB_NAME, DUMP_PATHS+"/copy_ways.sql")),
        Command("psql -U {} -h localhost -d {} -f {} ".format(DB_USER, DB_NAME, DUMP_PATHS+"/copy_way_nodes.sql")),
        Command("psql -U {} -h localhost -d {} -f {} ".format(DB_USER, DB_NAME, DUMP_PATHS+"/copy_relations.sql")),
        Command("psql -U {} -h localhost -d {} -f {} ".format(DB_USER, DB_NAME, DUMP_PATHS+"/copy_relation_members.sql"))]) \
    .join("Creating constraints", 3, [
        SQLQuery("ALTER TABLE ONLY nodes ADD CONSTRAINT pk_nodes PRIMARY KEY (id);"),
        SQLQuery("ALTER TABLE ONLY ways ADD CONSTRAINT pk_ways PRIMARY KEY (id);"),
        SQLQuery("ALTER TABLE ONLY way_nodes ADD CONSTRAINT pk_way_nodes PRIMARY KEY (way_id, sequence_id);"),
        SQLQuery("ALTER TABLE ONLY relations ADD CONSTRAINT pk_relations PRIMARY KEY (id);"),
        SQLQuery("ALTER TABLE ONLY relation_members ADD CONSTRAINT pk_relation_members PRIMARY KEY (relation_id, sequence_id);")
    ]) \
    .join("Creating indexes", 3, [
        SQLQuery("CREATE INDEX idx_nodes_geom ON nodes USING gist (geom);"),
        SQLQuery("CREATE INDEX idx_way_nodes_node_id ON way_nodes USING btree (node_id);"),
        SQLQuery("CREATE INDEX idx_relation_members_member_id_and_type ON relation_members USING btree (member_id, member_type);"),
        SQLQuery("CREATE INDEX idx_ways_bbox ON ways USING gist (bbox);"),
        SQLQuery("CREATE INDEX idx_ways_linestring ON ways USING gist (linestring);")])\
    .join("Updating clusters", 2 [
        SQLQuery("CLUSTER nodes USING idx_nodes_geom;"),\
        SQLQuery("CLUSTER ways USING idx_ways_linestring;")])\
    .join("Vacuum", 1, [SQLQuery("VACUUM ANALYZE;")])
