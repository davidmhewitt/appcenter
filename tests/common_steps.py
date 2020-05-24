import os

from time import time, sleep
from subprocess import Popen, PIPE
from behave import step
from unittest import TestCase
from gi.repository import GLib, Gio

from dogtail.tree import root

# Create a dummy unittest class to have nice assertions
class dummy(TestCase):
    def runTest(self):  # pylint: disable=R0201
        assert True

class App(object):
    """
    This class does all basic events with the app
    """
    def __init__(
        self, appName, shortcut='<Control><Q>', a11yAppName=None,
            forceKill=False, parameters=''):
        """
        Initialize object App
        appName     command to run the app
        shortcut    default quit shortcut
        a11yAppName app's a11y name is different than binary
        forceKill   is the app supposed to be kill before/after test?
        parameters  has the app any params needed to start? (only for startViaCommand)
        """
        self.appCommand = appName
        self.shortcut = shortcut
        self.forceKill = forceKill
        self.parameters = parameters
        self.internCommand = self.appCommand.lower()
        self.a11yAppName = a11yAppName
        self.pid = None

    def isRunning(self):
        """
        Is the app running?
        """
        if self.a11yAppName is None:
            self.a11yAppName = self.internCommand

        # Trap weird bus errors
        for attempt in range(0, 10):
            sleep(1)
            try:
                return self.a11yAppName in [x.name for x in root.applications()]
            except GLib.GError:
                continue
        raise Exception("10 at-spi errors, seems that bus is blocked")

    def quit(self):
        """
        Quit the app via 'Ctrl+Q'
        """
        try:
            keyCombo(self.shortcut)
            if self.isRunning():
                self.kill()
        except:
            pass

    def kill(self):
        try:
            os.system("pkill -9 " + self.appCommand)
        except:
            # Fall back to killall
            Popen("killall " + self.appCommand, shell=True).wait()

    def startViaCommand(self):
        """
        Start the app via command
        """
        if self.forceKill and self.isRunning():
            self.kill()
            assert not self.isRunning(), "Application cannot be stopped"

        self.process = Popen(self.appCommand.split() + self.parameters.split())
        self.pid = self.process.pid

        assert self.isRunning(), "Application failed to start"
        return root.application(self.a11yAppName)

    def closeViaShortcut(self):
        """
        Close the app via shortcut
        """
        if not self.isRunning():
            raise Exception("App is not running")

        keyCombo(self.shortcut)
        assert not self.isRunning(), "Application cannot be stopped"

@step(u'Make sure that {app} is running')
def ensure_app_running(context, app):
    context.app = context.app_class.startViaCommand()
