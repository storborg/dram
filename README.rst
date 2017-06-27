Dram - Keeping your package manager packaged
============================================

Author: `Scott Torborg <http://www.scotttorborg.com>`_

Dram is a POSIX-specific tool for managing shell environments. The basic
goal is to make it possible to install new shell-based software, from a number
of different sources, with the confidence that it won't mess up your global
environment.

Currently supported shells are ``bash`` and ``dash``.

Please see `the documentation <http://dram.readthedocs.org/en/latest/>`_.

Quick Start
===========

Clone the git repo to wherever you like::

    $ git clone https://github.com/storborg/dram.git

Set up a directory prefix where you want to put drams::

    $ mkdir /dram

Edit your ``.bashrc`` to configure it and source it::

    $ cat >> ~/.bashrc
    export DRAM_ROOT=/dram
    source $HOME/dram/dram/dram.sh

Start a new shell.

Create a new dram::

    $ dram create -t plain my-first-dram
    $ dram use my-first-dram

Install something with cmake::

    $ dram cdsource
    $ git clone git@github.com:me/coolsoftware.git
    $ cd coolsoftware
    $ mkdir build
    $ dram cmake ..
    $ make && make install

Tip: don't ever use sudo within a dram. This will keep your "base system"
totally pristine.

License
=======

Dram is licensed under an MIT license. Please see the LICENSE file for more
information.
