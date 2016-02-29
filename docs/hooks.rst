Extending Behavior with Hooks
=============================

You can extend dram to add special user-specific behavior with specially-named
function hooks. To implement a hook, simply define a function with the hook's
name in your shell environment (for example, in ``.bashrc``).

Example
-------

Set the shell prompt to include the name of the activated dram, upon activation::

    function dram_hook_postactivate() {
        local dram_name=$1
        local dram_prefix=$2

        PS1="($local_dram_name) $PS1"
    }

Deactivate a Python ``virtualenv`` before activating a dram, if one is
currently active::

    function deactivate_any_virtualenv () {
        type deactivate >/dev/null 2>&1
        if [ $? -eq 0 ]
        then
            deactivate
        fi
    }

    function dram_hook_preactivate () {
        local dram_name=$1
        local dram_prefix=$2

        deactivate_any_virtualenv
    }


Available Hooks
---------------

Currently available hooks are:

``dram_hook_preactivate``: Called prior to activating a dram, with the name and
path prefix of the dram.

``dram_hook_postactivate``: Called immediately after activating a drone, with
the name and path prefix of the dram.
