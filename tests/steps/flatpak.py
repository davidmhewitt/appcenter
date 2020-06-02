from behave import step
from dogtail.tree import root
from dogtail.rawinput import typeText, pressKey, keyCombo
from dogtail.predicate import GenericPredicate
from time import sleep
from subprocess import call, check_output, Popen, CalledProcessError, PIPE

from gi.repository import Atspi

