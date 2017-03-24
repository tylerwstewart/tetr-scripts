#!/bin/sh

TCUSER=`cat /etc/sysconfig/tcuser`
TCHOME="/home/$TCUSER";
TCSOURCE="$TCHOME/src";
GIT_URL="https://github.com/chazzam"
GIT_REPOS="tc-ext-tools tc-ext-tools-packages tc-diskless-remaster"
PKG_REPOS="tc-ext-tools-packages"
REMASTER_REPO="tc-diskless-remaster"
TET_REPO="tc-ext-tools"
TET="$TCHOME/tc-ext-tools";
TET_PKGS="$TET/packages";
[ -d "$TET_PKGS" ] || mkdir -p "$TET_PKGS";
[ -d "$TCSOURCE" ] || mkdir -p "$TCSOURCE";

exerr() {
  printf $@
  exit 1
}

git_clones() {
  local f;
  [ -z "$GIT_REPOS" ] && exerr "no git repos to clone"
  sudo chmod u+rwX,g+rwX,o+rwX $TCSOURCE
  for f in $GIT_REPOS; do
    [ -d "$TCSOURCE/$f" ] && continue
    local git_repo="$GIT_URL/${f}.git";
    ( cd "$TCSOURCE";
      git clone $git_repo || exit 1;
    )
    [ "$?" -gt 0 ] && exerr "Failed to clone one or more git repos"
  done
}

install_tet() {
  local destdir="$TCHOME/.local"
  local bindir="$destdir/bin"
  local sysconfdir="$destdir/etc"
  local datadir="$destdir/share"
  local confdir="$TCHOME/.config"
  local srcdir="$TCSOURCE/$TET_REPO"
  [ -d "$bindir" ] || mkdir -p "$bindir"
  [ -d "$confdir" ] || mkdir -p "$confdir"
  [ -d "$sysconfdir/init.d" ] || mkdir -p "$sysconfdir/init.d"
  [ -d "$datadir/tet" ] || mkdir -p "$datadir/tet"

  chmod 755 $srcdir/tools/* $srcdir/common/*functions|| exerr "failed to set executable permissions";
  chmod 644 $srcdir/common/config $srcdir/common/build||exerr "failed to set config permissions";

  ln -s $srcdir/tools/* "$bindir/" ||exerr "failed to link executables"
  ln -s $srcdir/common/config "$sysconfdir/tet.conf"||exerr "failed to link configs"
  ln -s $srcdir/common/build "$datadir/tet/build.sample"||exerr "failed to link configs"
  ln -s $srcdir/common/functions "$datadir/tet/functions.sh"||exerr "failed to link configs"
  ln -s $srcdir/common/tet-functions "$sysconfdir/init.d/tet-functions"||exerr "failed to link configs"
  ln -sf $srcdir/common/tet-functions "/etc/init.d/tet-functions"||exerr "failed to link configs"

  # Actually copy the config file so we can edit it as needed.
  install -D -m 644 -o $TCUSER -g staff $srcdir/config.sample "$confdir/tet.conf"||exerr "failed to link configs"

  # source tc-ext-tools shell environment functions in user's b?ashrc
  for shrc in "$TCHOME/.ashrc" "$TCHOME/.bashrc"; do
    [ -f "$shrc" ] || touch "$shrc"
    if ! grep tet-functions $shrc >/dev/null; then
      echo ". /etc/init.d/tet-functions" >> $shrc ||exerr "failed to update shell rc"
    fi
  done
}

add_packages() {
  local d;
  for d in $(find $TCSOURCE/* -maxdepth 0 -type d); do
    local git_pkgs="$d/packages"
    [ -d $git_pkgs ] || continue
    # symlink the packages into the tc-ext-tools directory
    ln -s $git_pkgs/* $TET_PKGS/||exerr "failed to link packages";
    ln -s $(find $d -maxdepth 1 -type f -executable) $TET/
  done
}

install_remaster() {
  local bindir="$TCHOME/.local/bin"
  local confdir="$TCHOME/tc-deliver/remaster/configs"
  [ -d "$bindir" ] || mkdir -p "$bindir"
  [ -d "$confdir" ] || mkdir -p "$confdir"
  ln -s $(find $TCSOURCE/$REMASTER_REPO/ -maxdepth 1 -type f -executable) $bindir
  ln -s $(find $TCSOURCE/$REMASTER_REPO/ -name '*.cfg') $confdir
}

git_clones;
if [ "$1" != "git" ]; then
  install_tet;
  add_packages;
  install_remaster;
fi
