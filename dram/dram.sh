dram_version=0.0.3.dev

if [[ "$DRAM_ROOT" = "" ]]
then
    DRAM_ROOT="/dram"
fi

function dram_version () {
    echo "dram version $dram_version"
}

function dram_list () {
    show_info=false
    for arg in "$@" ; do
        case "$arg" in
            -l)
                show_info=true
                ;;
        esac
    done
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
        if [[ $dram_name == $DRAM ]]
        then
            cur_dram="*"
        fi
        dram_info=""
        if [[ $show_info == true ]]
        then
            # Get dram size
            du_output=($(du -hcs $DRAM_ROOT/$dram_name))
            dram_size=${du_output[0]}
            #echo $dram_size
            dram_info=$dram_size
            dram_newline="\n"
        else
            dram_newline=""
        fi
        format_str="%${longest_dram_name}s%s\t%s%b"
        printf "$format_str"  "$dram_name" "$cur_dram" "$dram_info" $dram_newline
    done
    if [[ $show_info != true ]]
    then
        printf "\n"
    fi
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


# Function to setup an alias for sudo for the dram given in $1
function dram_add_sudo_alias() {
    cat >> $1/bin/activate <<EOF
    function sudo() {
        read -p "Dram is active, are you sure you want to run with sudo? [y/N] " confirm
        if [[ "\$confirm" == "y" ]]
        then
            /usr/bin/sudo "\$@"
        fi
    }
EOF
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
    dram_add_sudo_alias $dram_path
}

function dram_create_plain_with_python () {
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

    virtualenv --system-site-packages -p `which python2.7` $dram_path/pyenv
    mkdir -p $dram_path/lib/python2.7
    ln -sf $dram_path/pyenv/lib/python2.7/site-packages $dram_path/lib/python2.7/site-packages

    cat > $dram_path/bin/activate <<EOF
export PATH=$dram_path/bin:$dram_path/sbin:\$PATH

export DRAM_CMAKE_FLAGS="-DCMAKE_INSTALL_PREFIX=$dram_path -DCMAKE_PREFIX_PATH=$dram_path"
export DRAM_CONFIGURE_FLAGS="--prefix=$dram_path"

source $dram_path/pyenv/bin/activate

export $LIB_PATH_VARNAME=$dram_path/lib:\${VIRTUAL_ENV}/lib
EOF
    dram_add_lldb_alias $dram_path
    dram_add_sudo_alias $dram_path
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
    dram_add_sudo_alias $dram_path
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
    dram_add_sudo_alias $dram_path
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
                ;;
            *)
                echo "Unrecognized option '$key'."
                break
                ;;
        esac
        shift
    done

    if [[ $# -ne 1 ]]
    then
        echo "Usage: dram create [-t type] <name>"
        return
    fi
    local new_dram_name="$1"

    local new_dram_path=$DRAM_ROOT/$new_dram_name
    if [[ -d $new_dram_path ]]
    then
        echo "Dram with name '$new_dram_path' already exists!"
        return
    fi

    echo "Creating new dram '$new_dram_name' of type '$new_dram_type'."
    mkdir -p $new_dram_path

    case $new_dram_type in
        plain)
            dram_create_plain $new_dram_path
            ;;
        plain-with-python)
            dram_create_plain_with_python $new_dram_path
            ;;
        macports)
            dram_create_macports $new_dram_path
            ;;
        homebrew)
            dram_create_homebrew $new_dram_path
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

    type dram_hook_postactivate >/dev/null 2>&1
    if [[ $? -eq 0 ]]
    then
        dram_hook_postactivate $new_dram $new_dram_prefix
    fi
}

function dram_destroy () {
    if [[ $# -ne 1 ]]
    then
        echo "Usage: dram destroy <name>"
        return
    fi

    local destroy_dram=$1
    local destroy_path=$DRAM_ROOT/$destroy_dram

    if [[ ! -e $destroy_path ]]
    then
        echo "A dram named '$destroy_dram' does not exist."
        return
    fi

    if [[ $DRAM == $destroy_dram ]]
    then
        echo "Can't destroy currently active dram!"
        return
    fi

    echo "About to destory the dram '$destroy_dram' and wipe out '$destroy_path'."
    read -p "Are you sure? [y/N] " confirm
    if [[ "$confirm" == "y" ]]
    then
        rm -rf $destroy_path
        echo "Destroyed."
    fi
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

    cd "$DRAM_ROOT/$DRAM/source"
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
    echo "  help"
}

function dram_help () {
    dram_version
    dram_usage
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
            dram_cdsource $0
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
