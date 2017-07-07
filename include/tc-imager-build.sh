#! /bin/sh

# tet <package>
# <image config> # for tc-diskless-remaster

TCUSER=`cat /etc/sysconfig/tcuser`
TCHOME="/home/$TCUSER"
TCSOURCE="$TCHOME/src"
TCBIN="$TCHOME/.local/bin"
TET="$TCHOME/tc-ext-tools"
TETPKG="$TET/packages"
TETSTORE="$TET/storage"
DELIVER="$TCHOME/tc-deliver"
REMASTER="$DELIVER/remaster"
PACKAGES="$DELIVER/packages"
SUBMITS="$DELIVER/submits"

exerr() {
  echo;echo;
  echo "$@"
  echo;echo;
  exit 1
}

verify_git() {
  $TCBIN/install.sh git
}

update_git() {
  # Make sure git repo's are up to date
  #~ (cd ${TCSOURCE}/;
  local d;
    for d in $(find $TCSOURCE/* -maxdepth 0 -type d); do
      ( cd $d;
        [ -d .git ] && printf "%s: " ${d##$TCSOURCE/} && git pull;
      );
    done;
  #~ )
}

update_packages() {
  local d;
  for d in $(find $TCSOURCE/* -maxdepth 0 -type d); do
    local git_pkgs="$d/packages"
    [ -d $git_pkgs ] || continue
    # symlink the packages into the tc-ext-tools directory
    ln -s $git_pkgs/* $TETPKG/ 2>/dev/null;
    local exes="$(find $d -maxdepth 1 -type f -executable)"
    [ -z "$exes" ] || ln -s $exes $TET/ 2>/dev/null
  done
}

tet() {
  # TODO: add support for specifying a version on the fly
  # build the requested package(s)
  cd ${TETPKG}/ || exerr "No TET packages available"
  ${TCBIN}/update-tet-database || exerr "No TET database"
  ${TCBIN}/buildit $1 2>&1 |tee /tmp/tet-log-$1.txt || exerr "Couldn't build TET package"
  PACKAGES_DIR="$PACKAGES/$PACKAGE_SUBDIR"
  SUBMITS_DIR="$SUBMITS/$PACKAGE_SUBDIR"
  local print_cmd=""
  if [ ! -z "$(grep failed /tmp/tet-log-$1.txt)" ]; then
    print_cmd="$(grep 'buildit --print' /tmp/tet-log-$1.txt| egrep -o 'buildit --print [a-z]+\s*$')"
    $print_cmd
    exerr "Couldn't build TET package"
  fi
  [ -d "${PACKAGES_DIR}" ] || \
    sudo mkdir -p "${PACKAGES_DIR}" || \
    exerr "Couldn't make packages directory"
  [ -d "${SUBMITS_DIR}" ] || \
    sudo mkdir -p "${SUBMITS_DIR}" || \
    exerr "Couldn't make Submittables directory"
  sudo chown -R $TCUSER:staff ${DELIVER}
  sudo chmod -R u+rwX,g+rwX,o+rwX ${DELIVER}

  printf "\nCopying generated deliverables to destinations...\n"
  # Copy packages to src volume
  sudo cp -fLap ${TETSTORE}/*/pkg/*/*.tcz* ${PACKAGES_DIR}/|| exerr "Couldn't copy package deliverables"
  sudo cp -fLap ${TETSTORE}/*/pkg/*.bfe ${SUBMITS_DIR}/||true
}

tetiff() {
  . /etc/init.d/tet-functions
  tetinfo $1 >/dev/null 2>&1
  [ "$?" -eq "0" ] && tet $1
}

tettest() {
  [ -d $PACKAGES/PACKAGE_SUBDIR ] || exerr "No built packages"
  . /etc/init.d/tet-functions
  tetinfo $1 >/tmp/info.txt || exerr "Couldn't find package $1"
  (
    . /tmp/info.txt;
    cd $PACKAGES/PACKAGE_SUBDIR;
    for e in $EXTENSIONS; do
      EXTS="$EXTS $(find -name ${e}.tcz)";
    done;
    tce-load -ic $EXTS || exerr "Couldn't load extensions from $1";
  )
  exit $?
}

search_config() {
  local dir="$1"
  local term="$2"
  local results=""
  results=$(
    find "$dir" -type f -name "${term}*" \
    -exec grep -Iq . \{\} \; -and -print 2>/dev/null|\
    head -n1
  )
  echo "$results"
}

tc_remaster() {
  # TODO: add support for specifying a version string to add to the name of the output
  [ -d "${REMASTER}/" ] || mkdir -p "${REMASTER}/" || exerr "Couldn't make remaster directory"
  TC_PYTHON_35="python3.5.tcz"
  tce-load -wic $TC_PYTHON_35 || \
    { tet python3.5; tce-load -ic python3.5; } || \
    exerr "Couldn't load Python 3.5"
  [ -f /usr/local/bin/python3 ] || sudo ln -s $(which python3.5) /usr/local/bin/python3
  CONFIG="$1"
  [ -r "$1" ] || CONFIG=$(search_config "$REMASTER" "$1")
  [ -z "$CONFIG" ] && CONFIG=$(search_config "$REMASTER" "$(basename $1)")
  [ -z "$CONFIG" ] && CONFIG=$(search_config "$TCSOURCE" "$(basename $1)")
  [ -z "$CONFIG" ] && exerr "Couldn't find config: $1"
  [ ! -r "$CONFIG" ] && exerr "Couldn't read config: $CONFIG"
  shift;
  [ ! -z "$TCMIRROR" ] && TC_MIRROR_RUN="-m $TCMIRROR"
  sudo ${TCBIN}/tc-diskless-remaster.py $CONFIG \
    -t $TC_VER -a $TC_ARCH -k "$(uname -r)" \
    -o $REMASTER/ $TC_MIRROR_RUN \
    -E $PACKAGES/${TC_VER}.x/$TC_ARCH/tcz/ $@ ||\
    exerr "Failed to create remastered image(s)"
}

TC_VER=$(. /etc/init.d/tc-functions; getMajorVer)
TC_ARCH=$(file -b /bin/busybox|cut -d, -f1|egrep -o [0-9]{2})
[ -z "$TC_VER" ] && exerr "No TC Major Version"
[ -z "$TC_ARCH" ] && exerr "No TC Arch"
[ "$TC_ARCH" = "32" ] && TC_ARCH="x86"
[ "$TC_ARCH" = "64" ] && TC_ARCH="x86_64"
PACKAGE_SUBDIR="${TC_VER}.x/$TC_ARCH/tcz"

verify_git;

. ${TCHOME}/.profile $TCHOME/.ashrc
[ ! -z "$TCMIRROR" ] && echo "$TCMIRROR" > /opt/tcemirror
if [ "$1" = "git" ]; then
  update_git;
  shift;
fi
update_packages;
if [ "$1" = "tet" ]; then
  shift;
  tet $@
elif [ "$1" = "tetiff" ]; then
  shift;
  tetiff $@
elif [ "$1" = "tettest" ]; then
  shift;
  tettest $@
else
  tc_remaster $@
fi;
