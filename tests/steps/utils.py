from behave import step
from dogtail.rawinput import typeText, pressKey, keyCombo
from time import sleep
from subprocess import call, check_output, CalledProcessError, STDOUT

@step('Press {name} key')
def press_key(context, name):
    pressKey(name)

@step('Press key combination {name}')
def press_combo(context, name):
    keyCombo(name)

@step('Wait for command "{cmd}"')
def wait_for_cmd(context, cmd):
    call(cmd, shell=True)
