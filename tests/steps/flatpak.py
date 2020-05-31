from behave import step
from dogtail.tree import root
from dogtail.rawinput import typeText, pressKey, keyCombo
from dogtail.predicate import GenericPredicate
from time import sleep
from subprocess import call, check_output, Popen, CalledProcessError, PIPE

from gi.repository import Atspi

@step('Uninstall button {state} visible')
def uninstall_is_sensitive(context, state):
    uninstall = context.app.child(name="Uninstall", roleName="push button")
    assert uninstall
    if state == "is":
        assert uninstall.showing
    elif state == "is not":
        assert not uninstall.showing
