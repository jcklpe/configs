import ranger.api
import subprocess
from ranger.api.commands import *

original_hook_init = ranger.api.hook_init


def hook_init(func):
    def update_jump(signal):
        subprocess.call(["jump", "chdir", signal.new.path])

    func.signal_bind("cd", update_jump)
    original_hook_init(func)


ranger.api.hook_init = hook_init


class j(Command):
    """:j
    Jump to a directory with fuzzy input.
    """

    def execute(self):
        jump_command = ["jump", "cd"]
        jump_command.extend(self.args)

        directory = subprocess.check_output(jump_command)
        directory = directory.decode("utf-8", "ignore")
        directory = directory.rstrip('\n')

        self.fm.execute_console("cd " + directory)
