__author__ = 'tommaso doninelli'

import datetime
import time
import logging
import logging.config
import random
import concurrent.futures


LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'standard': {
            'format': '%(asctime)s %(levelname)s: %(message)s ',
            'datefmt': "%Y-%m-%d %H:%M:%S",
        }
    },
    'handlers': {
        'console': {
            'level': 'DEBUG',
            'formatter': 'standard',
            'class': 'logging.StreamHandler',
        },
        'rotate_file': {
            'level': 'DEBUG',
            'formatter': 'standard',
            'class': 'logging.FileHandler',
            'filename': 'osmpy.log',
            'encoding': 'utf8',
            'mode': 'w'
        }
    },
    'loggers': {
        '': {
            'handlers': ['console', 'rotate_file'],
            'level': 'DEBUG',
        },
    }
}
logging.config.dictConfig(LOGGING)

log = logging.getLogger('simpleExample')


class Action():
    """
    An Action is a thread, with some methods for measuring the elapsed time
    Sublcass must override the method execute
    """

    def __init__(self, name):
        super(Action, self).__init__()
        self.name = name

    def run(self):
        start = datetime.datetime.now()
        log.info("     {} starting".format(self.name))
        self.execute()
        elapsed = datetime.datetime.now() - start
        log.info("     {} COMPLETED in {}".format(self.name, str(elapsed)))

        return self.name

class Nop(Action):
    """
    Simple noop task
    """

    def __init__(self, cmd):
        super(Nop, self).__init__(cmd)
        self.cmd = cmd

    def execute(self):
        rnd = random.randint(1, 9)
        print("!!!{} inizio sllep {}".format(self.name, rnd))
        time.sleep(rnd)
        print("!!!{} SVEGLIO".format(self.name))


class Workflow(object):

    """
    A workflow executes threads.
    Several workflow can be organized in groups that are forked and joined
    """

    def __init__(self):
        """
        :return:
        """


    def join(self, name, pool_size, tasks):
        """
        Executes all the threads in the tasks list, each in a separated thread.
        This operation blocks untill all the thread are finished
        :param name:
            The name of this operation
        :param tasks:
            List of Threads
        :return:
            self
        """
        log.info("{} is starting".format(name))
        start = datetime.datetime.now()

        with concurrent.futures.ThreadPoolExecutor(max_workers=pool_size) as executor:
            future_to_url = {executor.submit(task.run): task for task in tasks}
            for future in concurrent.futures.as_completed(future_to_url):
                print("completed: " + future.result())

        # Start all threads
        # [x.start() for x in tasks]

        # Wait for all of them to finish
        #[x.join() for x in tasks]

        finish = datetime.datetime.now() - start
        log.info("{} completed in {}".format(name, str(finish)))

        return self