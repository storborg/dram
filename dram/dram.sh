dram_version=0.0.3.dev

orig_cmake=$(which cmake)
orig_sudo=$(which sudo)

if [[ "$DRAM_ROOT" = "" ]]
then
    DRAM_ROOT="/dram"
fi

function dram_version () {
    local DIR="$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)"
    if [[ "$(command -v git)" == "" ]]
    then
        local COMMIT="git not available, unable to determine dev version"
    else
        local COMMIT="$(git -C $DIR rev-parse HEAD 2> /dev/null || echo Release)"
    fi
    echo "dram version $dram_version - $COMMIT"
}

function dram_list () {
    local GREEN='\033[0;32m' # Green
    local NC='\033[0m' # No Color
    show_info=false
    for arg in "$@" ; do
        case "$arg" in
            -l)
                show_info=true
                ;;
        esac
    done
    # Set glob to nullglob so we don't show stuff when DRAM_ROOT
    # is empty
    shopt -s nullglob

    # need to iterate through 2x to find the longest dram name
    # so we can print a nice table output
    longest_dram_name=0
    if [[ $show_info == true ]]
    then
        for dram_dir in $DRAM_ROOT/*; do
            dram_name=$(basename $dram_dir)
            name_len=${#dram_name}
            longest_dram_name=$(($name_len>$longest_dram_name?$name_len:$longest_dram_name))
        done
    fi
    for dram_dir in $DRAM_ROOT/*; do
        dram_name=$(basename $dram_dir)
        cur_dram=""
        color_start=""
        color_end=""
        if [[ $dram_name == $DRAM ]]
        then
            cur_dram="*"
            color_start="${GREEN}"
            color_end="${NC}"
        fi
        dram_info=""
        if [[ $show_info == true ]]
        then
            # Get dram size
            du_output=($(du -hcs $DRAM_ROOT/$dram_name))
            dram_size=${du_output[0]}
            #echo $dram_size
            dram_info=$dram_size
        fi
        format_str="${color_start}%${longest_dram_name}s%s\t%s%b${color_end}"
        printf "$format_str"  "$dram_name" "$cur_dram" "$dram_info" "\n"
    done

    # Unset nullglob
    shopt -u nullglob
}

# Function to setup an alias for lldb for the dram given in $1
function dram_add_lldb_alias() {
    # if os x and version is at least 10.11 (darwin version 15)
    if [[ "$(uname -s)" == "Darwin" ]]
    then
        # this only applies to versions >= 10.11
        local darwin_version=$(uname -r)
        if [[ ${darwin_version:0:2} -ge 15 ]]
        then
            printf "Setting up alias for lldb\n"
            # SIP prevents /usr/bin/lldb from picking up the DYLD_LIBRARY_PATH
            # This alias points to the actual executable and forwards the
            # DYLD_LIBRARY_PATH so lldb can actually be used
            printf "alias lldb=\"DYLD_LIBRARY_PATH=\$DYLD_LIBRARY_PATH /Applications/Xcode.app/Contents/Developer/usr/bin/lldb\"\n" >> $1/bin/activate
        fi
    fi
}


function dram_confirm_unsafe() {
    local orig_path=$1
    read -p "Dram is active, are you sure you want to execute $orig_path? [y/N] " confirm
    if [[ "$confirm" == "y" ]]
    then
        shift
        $orig_path "$@"
    fi
}

function dram_add_info_str() {
    local dram_path=$1
    local dram_name=$(basename $dram_path)
    local dram_type=$2
    local created_by=$(whoami)
    local creation_hostname=$(hostname)
    local creation_time=$(date)
    local YELLOW='\033[0;33m' # Yellow
    local NC='\033[0m' # No Color
    # Remove extra spaces in dram type
    dram_type=$(echo "$dram_type" | tr -s " ")
    echo "echo -e \"[Activated dram, name:$YELLOW$dram_name$NC, type:$YELLOW$dram_type$NC, path:$YELLOW$dram_path$NC, creator:$YELLOW$created_by$NC, creation time:$YELLOW$creation_time$NC, creation hostname:$YELLOW$creation_hostname$NC]\"" >> $1/bin/activate
}

function dram_create_plain () {
    local dram_path=$1
    local platform=$(uname)
    echo "Creating plain dram in '$dram_path'."
    mkdir $dram_path/bin
    mkdir $dram_path/source

    if [[ $platform == "Darwin" ]]
    then
        LIB_PATH_VARNAME="DYLD_LIBRARY_PATH"
    else
        LIB_PATH_VARNAME="LD_LIBRARY_PATH"
    fi

    cat > $dram_path/bin/activate <<EOF
export PATH=$dram_path/bin:$dram_path/sbin:\$PATH

export DRAM_CMAKE_FLAGS="-DCMAKE_INSTALL_PREFIX=$dram_path -DCMAKE_PREFIX_PATH=$dram_path"
export DRAM_CONFIGURE_FLAGS="--prefix=$dram_path"

export $LIB_PATH_VARNAME=$dram_path/lib
EOF

    dram_add_lldb_alias $dram_path
    dram_add_info_str $dram_path "plain"
}

function dram_create_plain_with_python () {
    local dram_path=$1
    # drop the dram path arg so we can do the rest
    # of the argument parsing without worrying about it
    shift
    local platform=$(uname)

    # Parse the python version and system-site-packages options
    local python_version_opt=""
    local system_site_packages_opt=""

    local opts=`getopt -o p: --long python:,system-site-packages -n 'dram' -- "$@"`

    if [ $? != 0 ] ; then echo "Failed parsing options." >&2 ; exit 1 ; fi

    eval set -- "$opts"
    while true; do
    case "$1" in
        -p | --python )
            python_version_opt="-p $2"
            shift
            shift
            ;;
        --system-site-packages )
            system_site_packages_opt="--system-site-packages"
            shift
            ;;
        -- )
            shift
            break
            ;;
        * )
            break
            ;;
    esac
    done

    echo "Creating plain dram in '$dram_path'."
    mkdir $dram_path/bin
    mkdir $dram_path/source

    if [[ $platform == "Darwin" ]]
    then
        LIB_PATH_VARNAME="DYLD_LIBRARY_PATH"
    else
        LIB_PATH_VARNAME="LD_LIBRARY_PATH"
    fi

    local dram_base_name=`basename $dram_path`
    virtualenv $system_site_packages_opt $python_version_opt --prompt="($dram_base_name) " $dram_path/pyenv
    # figure out exactly what python version got used
    local exact_python_version=""
    for entry in "$dram_path"/pyenv/lib/*
    do
        local entry_base=`basename $entry`
        if [[ $entry_base =~ ^python.* ]]
        then
            exact_python_version=$entry_base
            break
        fi
    done
    local python_exe_location=`readlink -f python`

    local YELLOW='\033[0;33m' # Yellow
    local NC='\033[0m' # No Color
    echo -e "Using python version ${YELLOW}'$exact_python_version'${NC} located at ${YELLOW}'$python_exe_location'${NC}"
    mkdir -p $dram_path/lib/$exact_python_version
    ln -sf $dram_path/pyenv/lib/$exact_python_version/site-packages $dram_path/lib/$exact_python_version/site-packages

    cat > $dram_path/bin/activate <<EOF
export PATH=$dram_path/bin:$dram_path/sbin:\$PATH

export DRAM_CMAKE_FLAGS="-DCMAKE_INSTALL_PREFIX=$dram_path -DCMAKE_PREFIX_PATH=$dram_path"
export DRAM_CONFIGURE_FLAGS="--prefix=$dram_path"

source $dram_path/pyenv/bin/activate

export $LIB_PATH_VARNAME=$dram_path/lib:\${VIRTUAL_ENV}/lib
EOF
    dram_add_lldb_alias $dram_path
    dram_add_info_str $dram_path "plain-with-python $system_site_packages_opt $python_version_opt"
}

function dram_create_macports () {
    local dram_path=$1
    echo "Creating MacPorts dram in '$dram_path'."

    pushd /tmp
    echo "Downloading MacPorts..."
    rm -f macports-dram.tar.bz2
    curl -o macports-dram.tar.bz2 https://distfiles.macports.org/MacPorts/MacPorts-2.3.4.tar.bz2
    echo "Extracting..."
    tar xf macports-dram.tar.bz2
    cd MacPorts-2.3.4
    echo "Configuring..."
    ./configure --prefix=$dram_path --with-applications-dir=$dram_path/Applications --enable-readline --with-install-user=$USER --with-install-group=nogroup
    echo "Compiling..."
    make
    echo "Installing..."
    make install
    popd

    echo "Setting up activate script..."
    cat > $dram_path/bin/activate <<EOF
export PATH=$dram_path/bin:$dram_path/sbin:\$PATH
export MANPATH=$dram_path/share/man:\$MANPATH
#export DYLD_LIBRARY_PATH=$dram_path/lib
EOF

    # FIXME may want to add 'startupitem_install no' to macports.conf

    echo "Done."
    dram_add_lldb_alias $dram_path
    dram_add_info_str $dram_path "macports"
}

function dram_create_homebrew () {
    local dram_path=$1
    echo "Creating Homebrew dram in '$dram_path'."

    echo "Downloading and extracting..."
    curl -L https://github.com/Homebrew/homebrew/tarball/master | tar xz --strip 1 -C $dram_path

    echo "Setting up activate script..."
    cat > $dram_path/bin/activate <<EOF
export PATH=$dram_path/bin:$dram_path/sbin:\$PATH
#export DYLD_LIBRARY_PATH=$dram_path/lib
EOF


    echo "Done."
    dram_add_lldb_alias $dram_path
    dram_add_info_str $dram_path "homebrew"
}

function dram_create () {

    if [[ -n $DRAM ]]
    then
        echo "Already in a dram ('$DRAM'), unable to create new dram!"
        return
    fi
    # Defaults
    local new_dram_type=plain
    # Parse args
    while [[ $# > 1 ]]
    do
        local key="$1"
        case $key in
            -t|--type)
                local new_dram_type="$2"
                shift
                shift
                break
                ;;
            *)
                echo "Unrecognized option '$key'."
                break
                ;;
        esac
        shift
    done

    # Check if we didn't get anything after the type
    if [[ $# -lt 1 ]]
    then
        echo "Usage: dram create [-t type] <name>"
        return
    fi

    # Otherwise, assume that the last thing is the name and everything
    # else is args for the specific dram ctor function
    local new_dram_name="${@: -1}"

    # Remove the name from the args so that it doesn't trip up the
    # later functions
    local extra_dram_args="${@:1:$(($#-1))}"

    local new_dram_path=$DRAM_ROOT/$new_dram_name
    if [[ -d $new_dram_path ]]
    then
        echo "Dram with name '$new_dram_path' already exists!"
        return
    fi

    local dram_name_regex="^[a-z0-9][a-z0-9-]*$"
    if [[ $new_dram_name =~ $dram_name_regex ]]
    then
        # this is the noop command in bash
        :
    else
        echo "Invalid name for new dram '$new_dram_name'!"
        return
    fi

    echo "Creating new dram '$new_dram_name' of type '$new_dram_type'."
    mkdir -p $new_dram_path

    case $new_dram_type in
        plain)
            dram_create_plain $new_dram_path $extra_dram_args
            ;;
        plain-with-python)
            dram_create_plain_with_python $new_dram_path $extra_dram_args
            ;;
        macports)
            dram_create_macports $new_dram_path $extra_dram_args
            ;;
        homebrew)
            dram_create_homebrew $new_dram_path $extra_dram_args
            ;;
        *)
            echo "Dram type '$new_dram_type' not supported, giving up."
            return
            ;;
    esac

    dram_use $new_dram_name
}

function dram_use () {
    if [[ $# -ne 1 ]]
    then
        echo "Usage: dram use <name>"
        return
    fi

    local new_dram=$1
    local new_dram_prefix=$DRAM_ROOT/$new_dram
    local activate_path=$new_dram_prefix/bin/activate

    if [[ ! -e "$activate_path" ]]
    then
        echo "A dram named '$new_dram' does not exist."
        return
    fi

    if [[ -n "$DRAM" ]]
    then
        if [["$DRAM" == "$new_dram" ]]
        then
            echo "Dram '$DRAM' is already active."
        else
            echo "Could not activate dram '$new_dram', alternate dram '$DRAM' is already active."
        fi
        return
    fi

    type dram_hook_preactivate >/dev/null 2>&1
    if [[ $? -eq 0 ]]
    then
        dram_hook_preactivate $new_dram $new_dram_prefix
    fi

    echo "Activating dram '$new_dram'."
    source $activate_path
    DRAM=$new_dram
    DRAM_PREFIX=$new_dram_prefix

    if [[ $DRAM_NO_WARNINGS -ne 1 ]]
    then
        # override sudo, cmake, and possibly others to warn before use
        alias sudo="dram_confirm_unsafe $orig_sudo"
        alias cmake="dram_confirm_unsafe $orig_cmake"
    fi

    type dram_hook_postactivate >/dev/null 2>&1
    if [[ $? -eq 0 ]]
    then
        dram_hook_postactivate $new_dram $new_dram_prefix
    fi

    if [[ -n $DRAM_AUTO_CDSOURCE ]]
    then
        cd "$DRAM_ROOT/$DRAM/source"
    fi
}

function dram_destroy () {
    if [[ $# -lt 1 ]]
    then
        echo "Usage: dram destroy [-f] <names>"
        return
    fi

    local drams_to_destroy=""
    local force_delete=false

    local opts=`getopt -o f -l force -n 'dram' -- "$@"`
    eval set -- "$opts"
    while true; do
    case "$1" in
        -f | --force)
            force_delete=true
            shift
            ;;
        -- )
            shift;
            break
            ;;
        * )
            break
            ;;
    esac
    done

    for dram_name in "$@"
    do
        local destroy_path=$DRAM_ROOT/$dram_name
        if [[ ! -e $destroy_path ]]
        then
            echo "A dram named '$dram_name' does not exist."
            return
        fi

        if [[ $DRAM == $dram_name ]]
        then
            echo "Can't destroy currently active dram!"
            return
        fi

        if [[ "$drams_to_destroy" =~ (^| )$dram_name( |$) ]]
        then
            echo "Dram '$dram_name' specified multiple times!"
            return
        fi

        drams_to_destroy="$dram_name $drams_to_destroy"

    done

    for dram_name in $drams_to_destroy
    do
        local destroy_path=$DRAM_ROOT/$dram_name
        confirm="y"
        if [[ $force_delete == false ]]
        then
            echo "About to destory the dram '$dram_name' and wipe out '$destroy_path'."
            read -p "Are you sure? [y/N] " confirm
        fi
        if [[ "$confirm" == "y" ]]
        then
            rm -rf $destroy_path
            echo "Destroyed '$dram_name'."
        fi
    done
}

function dram_promote () {
    if [[ $# -ne 1 ]]
    then
        echo "Usage: dram promote <name>"
        return
    fi

    if [[ -z "$DRAM" ]]
    then
        echo "No dram activated."
        return
    fi

    local promote_executable=$1
    local promote_path=`which $1`
    local dram_prefix="$DRAM_ROOT/$DRAM"
    local symlink_path="/usr/local/bin/$promote_executable"

    if [[ -e "$symlink_path"  ]] || [[ -h "$symlink_path" ]]
    then
        echo "Something already exists at $symlink_path, refusing to promote."
        return
    fi

    if [[ -z "$promote_path" ]]
    then
        echo "No executable found for $promote_executable."
        return
    fi

    if [[ $promote_path != $dram_prefix* ]]
    then
        echo "Resolved path for $promote_executable is not inside the current dram, refusing to promote."
        return
    fi

    echo "Symlinking $promote_path to $symlink_path."
    sudo ln -s $promote_path $symlink_path
}

function dram_demote () {
    if [[ $# -ne 1 ]]
    then
        echo "Usage: dram demote <name>"
        return
    fi

    if [[ -z "$DRAM" ]]
    then
        echo "No dram activated."
        return
    fi

    local demote_executable=$1
    local demote_path="/usr/local/bin/$demote_executable"
    local dram_prefix="$DRAM_ROOT/$DRAM"
    local target_path="$(readlink $demote_path)"

    if [[ ! -h "$demote_path" ]]
    then
        echo "$demote_path is not a symlink, refusing to demote."
        return
    fi

    if [[ $target_path != $dram_prefix* ]]
    then
        echo "$demote_path points to $target_path, which is not inside this dram. Refusing to demote."
        return
    fi

    echo "Removing symlink at $demote_path."
    sudo rm $demote_path
}

function dram_cdsource () {
    if [[ -z "$DRAM" ]]
    then
        echo "No dram activated."
        return
    fi

    if [[ $# -gt 0 ]]
    then
        local source_dir_name=$1
        for _dir in $DRAM_ROOT/$DRAM/source/*"${source_dir_name}"*; do
            [ -d "${_dir}" ] && local dir="${_dir}" && break
        done
        if [[ -z $dir ]]
        then
            echo "No matching source directory found"
        else
            cd "$dir"
        fi
    else
        cd "$DRAM_ROOT/$DRAM/source"
    fi
}

function dram_cmake () {
    if [[ -z "$DRAM" ]]
    then
        echo "No dram activated."
        return
    fi

    local dram_prefix="$DRAM_ROOT/$DRAM"
    local cwd=$(pwd)
    if [[ $cwd != $dram_prefix* ]]
    then
        read -p "Your current working directory is not inside the active dram. Are you sure you wish to run cmake? [y/N] " confirm
        if [[ "$confirm" != "y" ]]
        then
            return
        fi
    fi

    cmake $DRAM_CMAKE_FLAGS $@
}

function dram_configure () {
    if [[ -z "$DRAM" ]]
    then
        echo "No dram activated."
        return
    fi

    local dram_prefix="$DRAM_ROOT/$DRAM"
    local cwd=$(pwd)
    if [[ $cwd != $dram_prefix* ]]
    then
        read -p "Your current working directory is not inside the active dram. Are you sure you wish to run ./configure? [y/N] " confirm
        if [[ "$confirm" != "y" ]]
        then
            return
        fi
    fi

    ./configure $DRAM_CONFIGURE_FLAGS $@
}

function dram_usage () {
    echo "Available subcommands:"
    echo "  version"
    echo "  list"
    echo "  create"
    echo "  use"
    echo "  destroy"
    echo "  promote"
    echo "  demote"
    echo "  cdsource"
    echo "  configure"
    echo "  cmake"
    echo "  help"
}

function dram_help () {
    dram_version
    case $1 in
        version)
            printf "usage: dram version\n"
            printf "Print the current dram version\n"
        ;;

        list)
            printf "usage: dram list\n"
            printf "List current drams\n"
            printf "\n"
            printf "  -l\tShow size of drams\n"
        ;;
        create)
            printf "usage: dram create -t <type> <name>\n"
            printf "Create a new dram with the given name and type and use it\n"
            printf "\n"
            printf "  -t,--type\tSpecify dram type (plain, plain-with-python, macports, homebrew), required option\n"
        ;;
        use)
            printf "usage: dram use <name>\n"
            printf "Use the dram with the given name\n"
        ;;
        destroy)
            printf "usage: dram destroy [-f] <names>\n"
            printf "Deletes the given drams. Must not be the currently active dram\n"
            printf "  -f\tDon't ask before destroying drams\n"
        ;;
        promote)
            printf "usage: dram promote <name>\n"
            printf "Create a symlink for the given executable from the active dram to the global environment\n"

        ;;
        demote)
            printf "usage: dram demote <name>\n"
            printf "Remove a symlink for the given executable from the active dram to the global environment\n"

        ;;
        cdsource)
            printf "usage: dram cdsource\n"
            printf "Change to the source directory of the active dram\n"

        ;;
        configure)
            printf "usage: dram configure\n"
            printf "Run ./configure in the current directory with the correct arguments for the dram, all other arguments are passed through\n"

        ;;
        cmake)
            printf "usage: dram cmake\n"
            printf "Run cmake in the current directory with the correct arguments for the dram, all other arguments are passed through\n"
        ;;
        *)
            dram_usage
        ;;
    esac
}


function dram () {
    local subcommand=$1
    shift

    case $subcommand in
        version)
            dram_version $@
            ;;
        list)
            dram_list $@
            ;;
        ls)
            dram_list $@
            ;;
        create)
            dram_create $@
            ;;
        use)
            dram_use $@
            ;;
        destroy)
            dram_destroy $@
            ;;
        promote)
            dram_promote $@
            ;;
        demote)
            dram_demote $@
            ;;
        cdsource)
            dram_cdsource $@
            ;;
        cmake)
            dram_cmake $@
            ;;
        configure)
            dram_configure $@
            ;;
        -h|--help|help)
            dram_help $@
            ;;
        *)
            echo "Unrecognized command."
            dram_usage
            ;;
    esac
}

# tab completion for dram
_dram() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    optsnohelp="version list create use destroy promote demote cdsource cmake configure"
    opts="$optsnohelp help"

    if [[ ${prev} == "dram" ]]
    then
        # if the user has already typed dram, then complete subcommands
        COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
        return 0
    fi
    if [[ ${prev} == "use" ||  ${prev} == "destroy" || ${COMP_WORDS[1]} == "destroy" ]]
    then
        # Get list of drams here
        local drams_list=$(ls --color=never $DRAM_ROOT)
        COMPREPLY=( $(compgen -W "${drams_list}" -- ${cur}) )
        return 0
    fi
    if [[ ${prev} == "cdsource" &&  -n ${DRAM} ]]
    then
        local dram_source_dirs=$(ls --color=never $DRAM_ROOT/$DRAM/source)
        COMPREPLY=( $(compgen -W "${dram_source_dirs}" -- ${cur}) )
        return 0
    fi
    if [[ ${prev} == "-t" ]]
    then
        local dram_types="plain plain-with-python macports hombrew"
        COMPREPLY=( $(compgen -W "${dram_types}" -- ${cur}) )
        return 0
    fi
    if [[ ${prev} == "-p" && ${COMP_WORDS[1]} == "create" && " ${COMP_WORDS[@]} " =~ "plain-with-python" ]]
    then
        local installed_pythons=$(compgen -c python | grep --color=never -P "^python(\d(\.\d)?)?m?$")
        COMPREPLY=( $(compgen -W "${installed_pythons}" -- ${cur}) )
        return 0
    fi
    if [[ ${prev} == "help" ]]
    then
        # if the user has already typed dram help, then complete subcommands except for help
        COMPREPLY=( $(compgen -W "${optsnohelp}" -- ${cur}) )
        return 0
    fi

}
complete -F _dram dram
