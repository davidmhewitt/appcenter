from time import sleep, localtime, strftime
from dogtail.utils import isA11yEnabled, enableA11y
if not isA11yEnabled():
    enableA11y(True)

from common_steps import App, dummy, ensure_app_running
from dogtail.config import config

def before_all(context):
    """Setup stuff
    Being executed once before any test
    """

    try:
        # Skip dogtail actions to print to stdout
        config.logDebugToStdOut = False
        config.typingDelay = 0.1
        config.childrenLimit = 500

        # Include assertion object
        context.assertion = dummy()

        # Store scenario start time for session logs
        context.log_start_time = strftime("%Y-%m-%d %H:%M:%S", localtime())

        context.app_class = App('io.elementary.appcenter')

    except Exception as e:
        print("Error in before_all: %s" % e.message)

