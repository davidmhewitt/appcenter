from behave import step
from dogtail.tree import root
from dogtail.rawinput import typeText, pressKey, keyCombo
from dogtail.predicate import GenericPredicate
from time import sleep
from subprocess import call, check_output, Popen, CalledProcessError, PIPE

from gi.repository import Atspi

@step('Quit AppCenter')
def quit_appcenter(context):
    keyCombo('<Ctrl><Q>')
    counter = 0
    while call('pidof io.elementary.appcenter > /dev/null', shell=True) != 1:
        sleep(0.5)
        counter += 1
        if counter == 100:
            raise Exception("Failed to close AppCenter in 50 seconds")

@step('Search {state} focused')
def search_is_focused(context, state):
    search = context.app.child(roleName="panel").child(name="Search", roleName="text")
    assert search
    if state == "is":
        assert search.getState().contains(Atspi.StateType.FOCUSED)
    elif state == "is not":
        assert search.getState().contains(Atspi.StateType.FOCUSED) == False

@step('Search {state} editable')
def search_is_editable(context, state):
    search = context.app.child(roleName="panel").child(name="Search", roleName="text")
    assert search
    if state == "is":
        assert search.getState().contains(Atspi.StateType.SENSITIVE)
    elif state == "is not":
        assert search.getState().contains(Atspi.StateType.SENSITIVE) == False

@step('Open installed tab')
def open_installed(context):
    installed_button = context.app.child(name="Installed", roleName="toggle button")
    installed_button.click()

@step('Open home tab')
def open_home(context):
    home_button = context.app.child(roleName="panel").child(name="Home", roleName="toggle button")
    home_button.click()

@step('Open {name} category')
def open_category(context, name):
    category_button = context.app.child(roleName="table").child(roleName="label", name=name)
    category_button.parent.parent.parent.get_component_iface().grab_focus()
    pressKey('Enter')


@step('Press back')
def go_back(context):
    header = context.app.child(roleName="panel")
    for button in header.findChildren(GenericPredicate(roleName='push button')):
        if button.name != "Maximize" and button.name != "Close":
            button.click()


@step('AppCenter is not running')
def appcenter_not_running(context):
    assert context.app_class.isRunning() != True, "AppCenter window still visible"
