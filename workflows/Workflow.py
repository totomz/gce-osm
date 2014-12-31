__author__ = 'tommaso doninelli'

import datetime
import threading
import logging
import logging.config

logging.config.fileConfig('logging.yaml')
log = logging.getLogger('simpleExample')


class Action(threading.Thread):
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

        # Start all threads
        [x.start() for x in tasks]

        # Wait for all of them to finish
        [x.join() for x in tasks]

        finish = datetime.datetime.now() - start
        log.info("{} completed in {}".format(name, str(finish)))

        return self