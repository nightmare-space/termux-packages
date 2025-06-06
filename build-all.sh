#!/bin/bash
# build-all.sh - script to build all packages with a build order specified by buildorder.py

# set -e -u -o pipefail

TERMUX_SCRIPTDIR=$(cd "$(realpath "$(dirname "$0")")"; pwd)

# Store pid of current process in a file for docker__run_docker_exec_trap
source "$TERMUX_SCRIPTDIR/scripts/utils/docker/docker.sh"; docker__create_docker_exec_pid_file


if [ "$(uname -o)" = "Android" ] || [ -e "/system/bin/app_process" ]; then
    echo "On-device execution of this script is not supported."
    exit 1
fi

# Read settings from .termuxrc if existing
test -f "$HOME"/.termuxrc && . "$HOME"/.termuxrc
: ${TERMUX_TOPDIR:="$HOME/.termux-build"}
: ${TERMUX_ARCH:="aarch64"}
: ${TERMUX_DEBUG_BUILD:=""}
: ${TERMUX_INSTALL_DEPS:="-s"}
# Set TERMUX_INSTALL_DEPS to -s unless set to -i

_show_usage() {
    echo "Usage: ./build-all.sh [-a ARCH] [-d] [-i] [-o DIR]"
    echo "Build all packages."
    echo "  -a The architecture to build for: aarch64(default), arm, i686, x86_64 or all."
    echo "  -d Build with debug symbols."
    echo "  -i Build dependencies."
    echo "  -o Specify deb directory. Default: debs/."
    exit 1
}

while getopts :a:hdio: option; do
case "$option" in
    a) TERMUX_ARCH="$OPTARG";;
    d) TERMUX_DEBUG_BUILD='-d';;
    i) TERMUX_INSTALL_DEPS='-i';;
    o) TERMUX_OUTPUT_DIR="$(realpath -m "$OPTARG")";;
    h) _show_usage;;
    *) _show_usage >&2 ;;
esac
done
shift $((OPTIND-1))
if [ "$#" -ne 0 ]; then _show_usage; fi

if [[ ! "$TERMUX_ARCH" =~ ^(all|aarch64|arm|i686|x86_64)$ ]]; then
    echo "ERROR: Invalid arch '$TERMUX_ARCH'" 1>&2
    exit 1
fi

BUILDSCRIPT=$(dirname "$0")/build-package.sh
BUILDALL_DIR=$TERMUX_TOPDIR/_buildall-$TERMUX_ARCH
BUILDORDER_FILE=$BUILDALL_DIR/buildorder.txt
BUILDSTATUS_FILE=$BUILDALL_DIR/buildstatus.txt
IGNORE_FILE="$TERMUX_SCRIPTDIR/ignore.txt"
# 输出日志文件路径信息
echo "========================================"
echo "构建日志将输出到以下位置："
echo "总体输出日志: $BUILDALL_DIR/ALL.out"
echo "总体错误日志: $BUILDALL_DIR/ALL.err"
echo "各包构建日志目录: $BUILDALL_DIR/"
echo "========================================"
echo ""
echo "您可以在另一个终端使用以下命令实时查看日志："
echo "# 查看总体构建输出："
echo "tail -f $BUILDALL_DIR/ALL.out"
echo ""
echo "# 查看总体构建错误："
echo "tail -f $BUILDALL_DIR/ALL.err"
echo ""
echo "# 查看特定包的构建日志（将PKG_NAME替换为实际包名）："
echo "tail -f $BUILDALL_DIR/PKG_NAME.out"
echo "tail -f $BUILDALL_DIR/PKG_NAME.err"
echo ""
echo "# 查看当前正在构建的包的日志："
echo "ls -t $BUILDALL_DIR/*.out | head -1 | xargs tail -f"
echo "========================================"
echo ""
echo "按 Enter 键继续构建，或按 Ctrl+C 取消..."
read -p ""
# 读取忽略列表
declare -A IGNORED_PACKAGES
if [ -f "$IGNORE_FILE" ]; then
    echo "Using ignore list from: $IGNORE_FILE"
    echo "=== Content of ignore file ==="
    cat "$IGNORE_FILE"
    echo "============================"
    
    while read -r pkg; do
        # 调试信息：显示读取的行
        echo "DEBUG: Read line: '$pkg'"
        
        # 处理并跳过空行、以#开头的注释行和以//开头的注释行
        if [ -n "$pkg" ] && [[ ! "$pkg" =~ ^[[:space:]]*# ]] && [[ ! "$pkg" =~ ^[[:space:]]*// ]]; then
            # 去除可能的尾部空格和Windows行尾符号，以及任何非字母数字字符
            pkg=$(echo "$pkg" | tr -d '\r' | sed 's/[^a-zA-Z0-9_-]//g' | xargs)
            IGNORED_PACKAGES["$pkg"]=1
            echo "Package to ignore: '$pkg'"
        else
            echo "DEBUG: Skipping comment or empty line: '$pkg'"
        fi
    done < "$IGNORE_FILE"
    
    # 打印所有被忽略的包
    echo "=== All packages to ignore ==="
    for key in "${!IGNORED_PACKAGES[@]}"; do
        echo "Will ignore: '$key'"
    done
    echo "============================"
else
    echo "No ignore.txt file found at $IGNORE_FILE"
fi

if [ -e "$BUILDORDER_FILE" ]; then
    echo "Using existing buildorder file: $BUILDORDER_FILE"
else
    mkdir -p "$BUILDALL_DIR"
    "$TERMUX_SCRIPTDIR/scripts/buildorder.py" > "$BUILDORDER_FILE"
fi
if [ -e "$BUILDSTATUS_FILE" ]; then
    echo "Continuing build-all from: $BUILDSTATUS_FILE"
fi

exec >	>(tee -a "$BUILDALL_DIR"/ALL.out)
exec 2> >(tee -a "$BUILDALL_DIR"/ALL.err >&2)
trap 'echo ERROR: See $BUILDALL_DIR/${PKG}.err' ERR

while read -r PKG PKG_DIR; do
    # 检查包是否在忽略列表中
    if [ -n "${IGNORED_PACKAGES[$PKG]}" ]; then
        echo "Ignoring $PKG (found in ignore.txt)"
        continue
    fi

    # Check build status (grepping is a bit crude, but it works)
    if [ -e "$BUILDSTATUS_FILE" ] && grep "^$PKG\$" "$BUILDSTATUS_FILE" >/dev/null; then
        echo "Skipping $PKG"
        continue
    fi

    echo -n "Building $PKG... Log $BUILDALL_DIR/${PKG}.out"
    BUILD_START=$(date "+%s")
    bash -x "$BUILDSCRIPT" -a "$TERMUX_ARCH" $TERMUX_DEBUG_BUILD \
        ${TERMUX_OUTPUT_DIR+-o $TERMUX_OUTPUT_DIR} $TERMUX_INSTALL_DEPS "$PKG_DIR" \
        > "$BUILDALL_DIR"/"${PKG}".out 2> "$BUILDALL_DIR"/"${PKG}".err
    BUILD_END=$(date "+%s")
    BUILD_SECONDS=$(( BUILD_END - BUILD_START ))
    echo "done in $BUILD_SECONDS"

    # Update build status
    echo "$PKG" >> "$BUILDSTATUS_FILE"
done<"${BUILDORDER_FILE}"

# Update build status
rm -f "$BUILDSTATUS_FILE"
echo "Finished"