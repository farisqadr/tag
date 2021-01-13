#!/bin/bash

_new_arguments=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h) help=1; shift ;;
        -1) _1=1; shift ;;
        --all|-a) all=1; shift ;;
        --directory=*|-d=*) directory="${1#*=}"; shift ;;
        --directory|-d) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then directory="$2"; shift; fi; shift ;;
        --dry-run|-n) dry_run=1; shift ;;
        --exclude-dir=*|-x=*) exclude_dir+=("${1#*=}"); shift ;;
        --exclude-dir|-x) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then exclude_dir+=("$2"); shift; fi; shift ;;
        --ignore-case|-i) ignore_case=1; shift ;;
        --preview|-p) preview=1; shift ;;
        --word|-w) word=1; shift ;;
        *) _new_arguments+=("$1"); shift ;;
    esac
done

set -- "${_new_arguments[@]}"

_new_arguments=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -[^-]*) OPTIND=1
            while getopts ":h1ad:nx:ipw" opt; do
                case $opt in
                    h) help=1 ;;
                    1) _1=1 ;;
                    a) all=1 ;;
                    d) directory="$OPTARG" ;;
                    n) dry_run=1 ;;
                    x) exclude_dir+=("$OPTARG") ;;
                    i) ignore_case=1 ;;
                    p) preview=1 ;;
                    w) word=1 ;;
                esac
            done
            shift "$((OPTIND-1))"
            ;;
        *) _new_arguments+=("$1"); shift ;;
    esac
done

set -- "${_new_arguments[@]}"

unset _new_arguments

# Computes the difference of arrays.
#
# Globals:
#   Modified: _return
#
# Arguments:
#   1 = Parameter of the array to compare from.
#   2 = Parameter of the array to compare against.
#
# Returns:
#   None
#
# Example:
#   ```
#   my=("cherry" "manggo" "blackberry" "manggo" "blackberry")
#   yours=("cherry" "blackberry")
#   ArrayDiff my[@] yours[@]
#   # Get result in variable `$_return`.
#   # _return=("manggo" "manggo")
#   ```
ArrayDiff() {
    local e
    local source=("${!1}")
    local reference=("${!2}")
    _return=()
    # inArray is alternative of ArraySearch.
    inArray () {
        local e match="$1"
        shift
        for e; do [[ "$e" == "$match" ]] && return 0; done
        return 1
    }
    if [[ "${#reference[@]}" -gt 0 ]];then
        for e in "${source[@]}";do
            if ! inArray "$e" "${reference[@]}";then
                _return+=("$e")
            fi
        done
    else
        _return=("${source[@]}")
    fi
}
# Removes duplicate values from an array.
#
# Globals:
#   Modified: _return
#
# Arguments:
#   1 = Parameter of the input array.
#
# Returns:
#   None
#
# Example:
#   ```
#   my=("cherry" "manggo" "blackberry" "manggo" "blackberry")
#   ArrayUnique my[@]
#   # Get result in variable `$_return`.
#   # _return=("cherry" "manggo" "blackberry")
#   ```
ArrayUnique() {
    local e source=("${!1}")
    # inArray is alternative of ArraySearch.
    inArray () {
        local e match="$1"
        shift
        for e; do [[ "$e" == "$match" ]] && return 0; done
        return 1
    }
    _return=()
    for e in "${source[@]}";do
        if ! inArray "$e" "${_return[@]}";then
            _return+=("$e")
        fi
    done
}

# Print Short Usage of Command.
#
# Globals:
#   None
#
# Arguments:
#   None
#
# Returns:
#   None
Usage() {
    cat <<- 'EOF'
Usage:
   tag add|a [-n] [-d <n>] <file|STDIN> <tag> [<tag>]...
   tag delete|d [-n] [-d <n>] <file|STDIN> <tag> [<tag>]...
   tag clear|c [-n] [-d <n>] <file|STDIN> [<file>]...
   tag find|f [-1aiwp] [-x <n>] <tag> [<tag>]...

Type --help for more info.

EOF
}

# Print Help.
#
# Globals:
#   None
#
# Arguments:
#   None
#
# Returns:
#   None
Help() {
    cat <<- 'EOF'
Usage: tag <command> [arguments|STDIN]

Available Commands
   add        Add tag(s) to the file (Alias: a)
   delete     Delete tag(s) from the file (Alias: d)
   clear      Clear all the tag(s) from the file (Alias: c)
   find       Find tag by text or word (Alias: f)

Format Command
   tag add|a [-n] [-d <n>] <file|STDIN> <tag> [<tag>]...
   tag delete|d [-n] [-d <n>] <file|STDIN> <tag> [<tag>]...
   tag clear|c [-n] [-d <n>] <file|STDIN> [<file>]...
   tag find|f [-1aiwp] [-x <n>] <tag> [<tag>]...

Options for Add, Delete, and Clear command
   -n, --dry-run
        Perform a trial run with no changes made
   -d, --directory
        Set the directory if file argument is not relative to $PWD.

Options for Find command
   -1   Find in starting point directory level depth only and no recursive.
        This is equals to `maxdepth 1` in find command.
   -a, --all
        Do not exclude directory starting with .
   -i, --ignore-case
        Ignore case distinctions.
   -w, --word
        Find tag by word. Default is find tag by containing text
   -p, --preview
        Preview find command without execute it
   -x, --exclude-dir=<dir>
        Skip directory and all files inside them. Repeat option to skip other
        directory

Example
   tag add love rock "November Rain.mp3"
   ls *.jpg | tag add trip 2021

Tagging directory.
   - Tag the directory doesn't rename the directory name.
   - Tag the directory will create a `.tag` file inside the directory and put
     the tags inside that file.

EOF
}

# Mencetak error ke STDERR kemudian exit.
#
# Globals:
#   None
#
# Arguments:
#   $1: String yang akan dicetak
#
# Returns:
#   None
Die() {
    Error "$1"
    exit 1
}

# Mencetak error ke STDERR.
#
# Globals:
#   None
#
# Arguments:
#   $1: String yang akan dicetak
#
# Returns:
#   None
Error() {
    echo -e "\e[91m""$1""\e[39m" >&2
}

# Function yang terdiri dari berbagai validasi.
#
# Globals:
#   None
#
# Arguments:
#   $1: Command
#   $*: Argument untuk command.
#
# Returns:
#   None
Validate() {
    case $1 in
        minimal-arguments)
            if [[ $3 -lt $2 ]];then
                Die "$4"
            fi
            ;;
    esac
}

# Populate variable tentang path.
#
# Globals:
#   Used: directory
#   Modified: full_path, dirname, basename, extension, filename
#
# Arguments:
#   $1: Path Relative
#
# Returns:
#   None
PathInfo() {
    if [[ ! $directory == '' ]];then
        if [[ $directory =~ \/$ ]];then
            full_path="$directory$1"
        else
            full_path="${directory}/$1"
        fi
    else
        full_path=$(realpath "$1")
    fi
    dirname=$(dirname "$full_path")
    basename=$(basename -- "$full_path")
    extension="${basename##*.}"
    filename="${basename%.*}"
}

# Modifikasi tags terhadap file.
#
# Globals:
#   Used: full_path, dirname, basename, extension, filename
#         dry_run
#
# Arguments:
#   None
#
# Returns:
#   None
#
# Output:
#   Mencetak output jika eksekusi move berhasil.
TagFile() {
    local tags tags_new tags_new_filtered
    local tags_new_filtered_stringify tags_new_stringify
    local basename_new full_path_new output

    # Mencari informasi tag dari filename.
    #
    # Globals:
    #   Used: filename
    #   Modified: tags, filename
    #
    # Arguments:
    #   1: filename (basename tanpa extension)
    #
    # Returns:
    #   None
    tagInfo() {
        local _tags
        # Contoh:
        # grep -o -E '\[\]$' <<< "filename[]"
        # []
        _tags=$(echo "$1" | grep -o -E '\[\]$')
        if [[ ! $_tags == "" ]];then
            filename=$(echo "$1" | sed 's/\[\]$//g')
        fi
        # Contoh:
        # grep -o -E '\[[^\[]+\]$' <<< "trans[por[ta]si]"
        # [ta]si]
        _tags=$(echo "$1" | grep -o -E '\[[^\[]+\]$')
        if [[ ! $_tags == "" ]];then
            # anu=(echo "$1" | sed -i "s/\]$/g")
            filename=$(echo "$1" | sed -E 's/\[[^\[]+\]$//g')
            _tags=${_tags##\[}
            _tags=${_tags%%\]}
            tags=($_tags)
        fi
    }

    tagInfo "$filename"
    case $command in
        add|a)
            tags_new=("${tags[@]}" "${tags_arguments[@]}")
            tags_new_filtered=($(echo "${tags_new[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
            tags_new_filtered_stringify=$(printf %s "$f" "${tags_new_filtered[@]/#/ }" | cut -c2-)
            basename_new="${filename}[${tags_new_filtered_stringify}].$extension"
        ;;
        delete|d)
            ArrayDiff tags[@] tags_arguments[@]
            tags_new=("${_return[@]}")
            tags_new_stringify=$(printf %s "$f" "${tags_new[@]/#/ }" | cut -c2-)
            if [[ ! "$tags_new_stringify" == "" ]];then
                basename_new="${filename}[${tags_new_stringify}].$extension"
            else
                basename_new="${filename}.$extension"
            fi
        ;;
        clear|c)
            basename_new="${filename}.$extension"
    esac
    if [[ ! "$basename_new" == "" && ! "$basename" == "$basename_new" ]];then
        full_path_new="${dirname}/${basename_new}"
        if [[ "$dirname" == "$PWD" ]];then
            output="$basename_new"
        else
            output="$full_path_new"
        fi
        if [[ ! $dry_run == 1 ]];then
            mv "$full_path" "$full_path_new" && echo "$output"
        else
            echo "$output"
        fi
    fi
}

TagDirectory() {
    local e tags
    echo -n

    # Rebuild PathInfo()
    dirname="$full_path"
    full_path="${dirname}/.tag"
    basename=""
    filename=""
    extension="tag"

    tagInfo() {
        if [ -f "$1" ];then
            while IFS="" read -r p || [ -n "$p" ]
            do
              tags+=("$(printf '%s\n' "$p")")
            done < "$1"
        fi
    }

    tagInfo "$full_path"

    case $command in
        add|a)
            ArrayDiff tags_arguments[@] tags[@]
            tags_new=("${_return[@]}")
            if [[ ${#tags_new[@]} -gt 0 ]];then
                if [[ $dry_run == 1 ]];then
                    string=$(<"$full_path")
                    echo "$string"
                    for e in "${tags_new[@]}"; do
                        string="${string}"$'\n'"$e"
                    done
                    echo "$string"
                else
                    # Add EOL in end of file.
                    # https://unix.stackexchange.com/a/161853
                    if [ -f "$full_path" ];then
                        tail -c1 < "$full_path"  | read -r _ || echo >> "$full_path"
                    fi
                    for e in "${tags_new[@]}"; do
                        echo "$e" >> "$full_path"
                    done
                    cat "$full_path"
                fi
            fi
        ;;
        delete|d)
            if [ -f "$full_path" ];then
                ArrayDiff tags[@] tags_arguments[@]
                if [[ ! ${#tags[@]} == ${#_return[@]} ]];then
                    if [[ $dry_run == 1 ]];then
                        echo -n
                        string=$(<"$full_path")
                        echo "$string"
                        for e in "${tags_arguments[@]}"; do
                            # sed -i "/^${e}$/d" "$full_path"
                            string=$(echo "$string"| sed  "/^${e}$/d")
                        done
                        echo "$string"
                    else
                        for e in "${tags_arguments[@]}"; do
                            sed -i "/^${e}$/d" "$full_path"
                        done
                        cat "$full_path"
                    fi
                fi
            fi
        ;;
        clear|c)
            if [ -f "$full_path" ];then
                cat "$full_path" >&2
                echo -ne "\e[93m"
                read -rsn1 -p 'File .tag will be delete. Are you sure [y/n]: ' option
                echo -ne "\e[39m"
                if [[ $option == y ]];then
                    if [[ ! $dry_run == 1 ]];then
                        rm "$full_path" && echo Deleted.
                    else
                        echo Deleted.
                    fi
                else
                    echo Canceled.
                fi
            fi
    esac

}

# Generator find command dan mengekseskusinya (optional).
#
# Globals:
#   Used: tags_arguments,
#         _1, all, ignore_case, preview, word, exclude_dir
#
# Arguments:
#   None
#
# Returns:
#   None
#
# Output:
#   Mencetak output jika eksekusi move berhasil.
FindGenerator() {
    local command
    local find_command
    local directory_exclude directory_exclude_default=() _directory_exclude
    local find_directory='.'
    local find_arg
    local find_arg_maxdepth
    local find_arg_directory_exclude
    local find_arg_filename
    local find_parameter_name='-name'
    local is_recursive=1
    local _tags_arguments
    local while_lopping_command
    local grep_command grep_arg_E grep_arg_i grep_arg_w grep_arg
    if [[ $_1 == 1 ]];then
        is_recursive=0
        find_directory='.'
        find_arg_maxdepth=' -maxdepth 1'
    fi
    if [[ $ignore_case == 1 ]];then
        find_parameter_name='-iname'
    fi
    if [[ $is_recursive == 1 ]];then
        if [[ ! $all == 1 ]];then
            directory_exclude_default=(".*")
            find_directory='"$PWD"'
        fi
        directory_exclude=("${directory_exclude_default[@]}" "${exclude_dir[@]}")
        _directory_exclude=()
        for e in "${directory_exclude[@]}"; do
            _directory_exclude+=("-name \"${e}\"")
        done
        find_arg_directory_exclude=$(printf "%s" "${_directory_exclude[@]/#/ -o }" | cut -c5-)
        if [[ ${#directory_exclude[@]} -gt 1 ]];then
            find_arg_directory_exclude="\( $find_arg_directory_exclude \)"
        fi
        if [[ ${#directory_exclude[@]} -gt 0 ]];then
            find_arg_directory_exclude=" -type d ${find_arg_directory_exclude} -prune -false -o"
        fi
    fi
    find_arg=" ${find_directory}"
    _tags_arguments=()
    for e in "${tags_arguments[@]}"; do
        e='*\[*'"$e"'*\]*'
        _tags_arguments+=("${find_parameter_name} \"${e}\"")
    done
    find_arg_filename=$(printf "%s" "${_tags_arguments[@]/#/ -o }" | cut -c5-)
    if [[ ${#tags_arguments[@]} -gt 1 ]];then
        find_arg_filename="\( $find_arg_filename \)"
    fi
    find_arg_filename=" -type f ${find_arg_filename}"
    find_command="find${find_arg}${find_arg_maxdepth}${find_arg_directory_exclude}${find_arg_filename}"
    if [[ $find_directory == '"$PWD"' ]];then
        find_command+=" -exec sh -c 'echo \$0 | sed \"s|^\$PWD|.|\"' {} \;"
    fi
    grep_arg_E=
    grep_arg_i=
    grep_arg_w=
    grep_arg=$(printf "%s" "${tags_arguments[@]/#/\|}"  | cut -c2-)
    if [[ ${#tags_arguments[@]} -gt 1 ]];then
        grep_arg=" \"($grep_arg)\""
        grep_arg_E=' -E'
    else
        grep_arg=" $grep_arg"
    fi
    if [[ $is_recursive == 1 ]];then
        grep_arg_i=' -i'
    fi
    if [[ $word == 1 ]];then
        grep_arg_w=' -w'
    fi
    grep_command="grep${grep_arg_E}${grep_arg_i}${grep_arg_w}${grep_arg}"
    while_lopping_command=
    while_lopping_command+='echo "$path" | sed -E "s|.*\[(.*)\].[^.]+$|\1|"'
    while_lopping_command+=" | $grep_command"
    # syntax [[ ]] hanya ada pada bash dan tidak dikenal oleh sh, sehingga
    # execute command ini menggunakan bash
    while_lopping_command='[[ $('"$while_lopping_command"') ]] && echo "$path";'
    while_lopping_command="while IFS= read -r path; do $while_lopping_command done"
    command="${find_command} | ${while_lopping_command}"
    if [[ $preview == 1 ]];then
        echo "$command"
    else
        echo "$command" | bash
    fi
}

# Variable.
command=
files_arguments=()
tags_arguments=()

if [[ $help == 1 ]];then
    Help
    exit 1
fi

if [[ $1 == '' ]];then
    Usage
    exit 1
fi

command="$1";
case $command in
    add|a) shift ;;
    delete|d) shift ;;
    clear|c) shift ;;
    find|f) shift ;;
    *) Die "Command unknown. Type --help for more info."
esac

if [ -t 0 ]; then
    # Jika dari terminal.
    case $command in
        find|f)
            Validate minimal-arguments 1 $# "Tag(s) not defined."
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    *) tags_arguments+=("$1")
                    shift
                esac
            done
        ;;
        clear|c)
            Validate minimal-arguments 1 $# "File not defined."
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    *) files_arguments+=("$1")
                    shift
                esac
            done
        ;;
        *)
            Validate minimal-arguments 1 $# "File not defined."
            Validate minimal-arguments 2 $# "Tag(s) not defined."
            files_arguments+=("$1");
            shift
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    *) tags_arguments+=("$1")
                    shift
                esac
            done
    esac
else
    # Jika dari standard input.
    while read _each; do
        files_arguments+=("$_each")
    done </dev/stdin
    case $command in
        find|f)
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    *) tags_arguments+=("$1")
                    shift
                esac
            done
            Validate minimal-arguments 1 ${#tags_arguments[@]} "Tag(s) not defined."
        ;;
        clear|c)
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    *) files_arguments+=("$1")
                    shift
                esac
            done
            Validate minimal-arguments 1 ${#files_arguments[@]} "File not defined."
        ;;
        *)
            Validate minimal-arguments 1 $# "Tag(s) not defined."
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    *) tags_arguments+=("$1")
                    shift
                esac
            done
            Validate minimal-arguments 1 ${#files_arguments[@]} "File not defined."
    esac
fi

ArrayUnique tags_arguments[@]
tags_arguments=("${_return[@]}")

case $command in
    find|f) FindGenerator ;;
    *) set -- "${files_arguments[@]}"
        while [[ $# -gt 0 ]]; do
            PathInfo "$1"
            if [ -d "$full_path" ];then
                TagDirectory
            elif [ -f "$full_path" ];then
                TagFile
            else
                Error "File not found: ${basename}."
            fi
            shift
        done
esac

