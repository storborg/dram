Dram - Keep Your Package Manager Packaged
=========================================

Author: `Scott Torborg <http://www.scotttorborg.com>`_

Dram is a POSIX-specific tool for managing shell environments. The basic goal
is to make it possible to install new shell-based software, from a number of
different sources, with the confidence that it won't mess up your global
environment.

Instead of simply installing new software into ``/usr/local``, you can quickly
activate a new "dram", and install it there. If something goes wrong, no
problem: just delete the entire dram.

You can also create new drams that contain an instance of Homebrew or Macports.
This makes it easy to use both Homebrew and Macports at the same time, or
multiple instances of either. Again, if somsething goes wrong, nothing to worry
about: just delete the dram.

Contents
========

.. toctree::
    :maxdepth: 2

    basics
    contributing

Indices and Tables
==================

* :ref:`genindex`
* :ref:`modindex`
