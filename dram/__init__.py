from __future__ import print_function

import sys
import os
import argparse
from datetime import datetime


__version__ = '0.0.1.dev'

DEFAULT_ROOT = '/dram'


if sys.version_info[0] > 2:
    def input_compat(prompt):
        return input(prompt)
else:
    def input_compat(prompt):
        return raw_input(prompt)


def yesno(prompt):
    resp = input_compat(prompt + ' [Y/n] ')
    resp = resp.strip().lower()
    return resp in ('y', 'yes')


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

    # check to see if dram is already installed by looking for DRAM environment
    # variables. prompt to proceed.
    existing = check_for_existing()
    if existing and not opts.noninteractive:
        abort = yesno('Existing dram install detected.\nAbort?')
        if abort:
            return -1

    # tell the user what this script will do
    print("This script will add new lines to your bashrc to configure dram.")
    print("")

    # get desired dram root path if not specified on command line
    if not opts.root:
        if opts.noninteractive:
            root = DEFAULT_ROOT
        else:
            print("What path would you like to use for the dram root?")
            root = input_compat('[%s] ' % DEFAULT_ROOT)
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
    script_path = pkg_resouces.resource_filename('dram', 'dram.sh')
    date = '%s UTC' % datetime.utcnow()
    bashrc_s = bashrc_templ % dict(date=date,
                                   root=root,
                                   script_path=script_path)
    with open('bashrc_s', 'a') as f:
        f.write(bashrc_s)
