import datetime

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
        print.info("     {} starting".format(self.name))
        self.execute()
        elapsed = datetime.datetime.now() - start
        print.info("     {} COMPLETED in {}".format(self.name, str(elapsed)))

