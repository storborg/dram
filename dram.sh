dram_version=0.0.1.dev

if [ "$DRAM_PREFIX" = "" ]
then
    DRAM_PREFIX="/dram"
fi

function dram_version () {
    echo "dram version $dram_version"
}

function dram_list () {
    ls $DRAM_PREFIX
}

function dram_create_plain () {
    local dram_path=$1
    echo "Creating plain dram in '$dram_path'."
    mkdir $dram_path/bin
    cat > $dram_path/bin/activate <<EOF
PATH=$dram_path/bin:$dram_path/sbin:\$PATH
DYLD_LIBRARY_PATH=$dram_path/lib
EOF
}

function dram_create_macports () {
    local dram_path=$1
    echo "Creating MacPorts dram in '$dram_path'."

    pushd /tmp
    echo "Downloading MacPorts..."
    rm macports.tar.bz2
    curl -o macports.tar.bz2 https://distfiles.macports.org/MacPorts/MacPorts-2.3.3.tar.bz2
    echo "Extracting..."
    tar xf macports.tar.bz2
    cd MacPorts-2.3.3
    echo "Configuring..."
    ./configure --prefix=$dram_path --with-applications-dir=$dram_path/Applications --enable-readline --with-install-user=$USER --with-install-group=nogroup
    echo "Compiling..."
    make
    echo "Installing..."
    make install
    popd

    echo "Setting up activate script..."
    cat > $dram_path/bin/activate <<EOF
PATH=$dram_path/bin:$dram_path/sbin:\$PATH
#DYLD_LIBRARY_PATH=$dram_path/lib
EOF

    # FIXME may want to add 'startupitem_install no' to macports.conf

    echo "Done."
}

function dram_create_homebrew () {
    local dram_path=$1
    echo "Creating Homebrew dram in '$dram_path'."

    echo "Downloading and extracting..."
    curl -L https://github.com/Homebrew/homebrew/tarball/master | tar xz --strip 1 -C $dram_path

    echo "Setting up activate script..."
    cat > $dram_path/bin/activate <<EOF
PATH=$dram_path/bin:$dram_path/sbin:\$PATH
#DYLD_LIBRARY_PATH=$dram_path/lib
EOF


    echo "Done."
}

function dram_create () {
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

    echo "Creating new dram '$new_dram_name' of type '$new_dram_type'."
    local new_dram_path=$DRAM_PREFIX/$new_dram_name
    mkdir -p $new_dram_path

    case $new_dram_type in
        plain)
            dram_create_plain $new_dram_path
            ;;
        macports)
            dram_create_macports $new_dram_path
            ;;
        homebrew)
            dram_create_homebrew $new_dram_path
            ;;
        *)
            echo "Dram type '$new_dram_type' not supported, giving up."
            ;;
    esac
}

function dram_use () {
    if [[ $# -ne 1 ]]
    then
        echo "Usage: dram use <name>"
        return
    fi

    local new_dram=$1
    local activate_path=$DRAM_PREFIX/$new_dram/bin/activate

    if [[ ! -e "$activate_path" ]]
    then
        echo "A dram named '$new_dram' does not exist."
        return
    fi

    if [[ -n "$DRAM" ]]
    then
        echo "Could not activate dram '$new_dram', alternate dram '$DRAM' is already active."
        return
    fi

    echo "Activating dram '$new_dram'."
    source $activate_path
    DRAM=$new_dram

    # FIXME manipulate prompt to add dram name
}

function dram_destroy () {
    if [[ $# -ne 1 ]]
    then
        echo "Usage: dram destroy <name>"
        return
    fi

    local destroy_dram=$1
    local destroy_path=$DRAM_PREFIX/$destroy_dram

    if [ ! -e "$destroy_path" ]
    then
        echo "A dram named '$new_dram' does not exist."
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

function dram_usage () {
    echo "Available subcommands:"
    echo "  version"
    echo "  list"
    echo "  create"
    echo "  use"
    echo "  destroy"
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
        -h|--help|help)
            dram_help $@
            ;;
        *)
            echo "Unrecognized command."
            dram_usage
            ;;
    esac
}
