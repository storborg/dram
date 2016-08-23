from __future__ import print_function

import sys
import os
import argparse
import pkg_resources
from datetime import datetime

from six.moves import input


__version__ = '0.0.3.dev'

DEFAULT_ROOT = '/dram'


def yesno(prompt):
    while True:
        resp = input(prompt + ' [Y/n] ')
        resp = resp.strip().lower()
        if resp in ('y', 'yes', ''):
            return True
        elif resp in ('n', 'no'):
            return False


def check_for_existing():
    existing = False
    for key in os.environ:
        if key.startswith('DRAM'):
            print("Warning: found existing environment variable %s" % key)
            existing = True
    return existing


def check_writeable(path):
    return os.access(path, os.W_OK | os.X_OK)


bashrc_templ = '''

# Configuration written by dram-install on %(date)s
export DRAM_ROOT=%(root)s
source %(script_path)s
'''


def install(argv=sys.argv):
    p = argparse.ArgumentParser(
        description='Initial setup tool to configure bash to use dram.')
    p.add_argument('--noninteractive', action='store_true')
    p.add_argument('--root', type=str)

    opts = p.parse_args(argv[1:])

    print("This script will add new lines to your bashrc to configure dram.")
    print("")

    # check to see if dram is already installed by looking for DRAM environment
    # variables. prompt to proceed.
    existing = check_for_existing()
    if existing and not opts.noninteractive:
        print("Existing dram install detected.")
        abort = yesno('Abort?')
        if abort:
            return -1

    # get desired dram root path if not specified on command line
    if opts.root:
        root = opts.root
    else:
        if opts.noninteractive:
            root = DEFAULT_ROOT
        else:
            print("What path would you like to use for the dram root?")
            root = input('[%s] ' % DEFAULT_ROOT)
            root = root.strip()
            if not root:
                root = DEFAULT_ROOT

    # create dram root
    if not os.path.exists(root):
        os.makedirs(root)
    else:
        if not check_writeable(root):
            print("Warning: dram root already exists and is not writable!")

    # write the DRAM_ROOT var and source the script inside .bashrc
    script_path = pkg_resources.resource_filename('dram', 'dram.sh')
    date = '%s UTC' % datetime.utcnow()
    bashrc_s = bashrc_templ % dict(date=date,
                                   root=root,
                                   script_path=script_path)
    bashrc_path = os.path.join(os.path.expanduser('~'), '.bashrc')
    with open(bashrc_path, 'a') as f:
        f.write(bashrc_s)

    print("")
    print("Installation completed. You should restart your shell now.")
