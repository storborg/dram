Basics
======

Concepts
--------

Each new sandboxed environment is referred to as a *dram*.

The environment variable ``DRAM_ROOT`` is the root directory where all drams
are kept. Each dram is a subdirectory.

.. warning::

    Root privileges should generally not be necessary to install anything into
    a dram. Avoid the temptation to use ``sudo``. You may wish to consider
    changing the ownership of your ``/usr/local`` directory to root in order to
    prevent any dram usage from "spilling" into the global environment.

Dram Types
----------

* **Plain** drams are intended for installing most open source "directly", via
  a ``./configure`` script or similar mechanism. They are not populated with
  any initial files or directories, but set up environment variables that will 

* **Plain-with-python** drams are the same as Plain drams with the addition of
  an integrated python virtual environment for the dram.

* **Homebrew** drams populate an instance of `Homebrew <http://brew.sh/>`_.

* **Macports** drams populate an instance of `MacPorts <https://www.macports.org/>`_.

Command-Line Usage
------------------

Dram includes a command-line utility which is the expected entry point for most
usage. Some examples are below. You can also see the utility itself for more
info::

    $ dram help

Creating a New Dram
-------------------

This will create a new dram you can then install stuff into.::

    $ dram create example

To create a dram of a particular type::

    $ dram create -t macports example

When creating a dram of type ``plain-with-python`` you can also pass the
``-p`` and ``--system-site-packages`` flags and they will be passed through
to the virtual environement when it is created for that dram.

Using The Dram
--------------

Creating a dram automatically switches to it, but if you want to switch to an already created dram::

    $ dram use example

Note that if you have set the ``DRAM_AUTO_CDSOURCE`` environment variable, then dram will automatically 
switch to the source directory of the activated dram whenever you do ``dram use <dram name>``

Listing Drams
-------------

List all the current drams in your root::

    $ dram list

If the ``-l`` flag is passed to ``dram list``, then the size of each dram on disk will be printed as well.

Destroying a Dram
-----------------

Wipe out any traces of a current dram::

    $ dram destroy example
