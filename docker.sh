#!/bin/sh
HOST_DLVR="$HOME/tc-deliver"
HOST_SRCS="$HOME/srctc"
HOST_DIRS="$HOST_DLVR $HOST_SRCS"
TC_DLVR="/home/tc/tc-deliver"
TC_RCONF="$TC_DLVR/remaster/configs"

TETR_TAG="7.2-x86"
DOCKER_IMAGE="chazzam/tetr:$TETR_TAG"
DOCKER_VOL_DLVR="-v $HOST_DLVR:$TC_DLVR:rw"
DOCKER_VOL_SRCS="-v $HOST_SRCS:/home/tc/src:rw"
DOCKER_VOLUMES="$DOCKER_VOL_DLVR $DOCKER_VOL_SRCS"
DOCKER_ENVS="-e TCMIRROR=http://pecan.digium.internal:81/tinycore-testing/"

DOCKER_ARGS="--rm $DOCKER_VOLUMES $DOCKER_ENVS $DOCKER_IMAGE"

# For python script to handle using Docker.io for building and remastering
# https://wiki.python.org/moin/PortingToPy3k/BilingualQuickRef
#~ from __future__ import absolute_import, division, print_function, unicode_literals
# http://python-future.org/compatible_idioms.html
# Python 2.7+ and 3.3+
# Python 2 and 3 (after ``pip install configparser``):
#~ from configparser import ConfigParser
# Python 2.7 and above
#~ from collections import Counter, OrderedDict

exerr() {
  echo;echo;
  echo "$@"
  echo;echo;
  [ ! -z "$pkg" ] && cat<<EOF

To troubleshoot this failed tet build of $pkg:
  docker run -it --entrypoint sh $DOCKER_ARGS --login
    cd ~/tc-ext-tools/packages/$pkg
    buildit

EOF
  [ ! -z "$REMASTER" ] && cat<<EOF

To troubleshoot this failed remaster of $REMASTER:
  docker run -it --entrypoint sh $DOCKER_ARGS --login
    tc-diskless-remaster -n $REMASTER

EOF
  exit 1
}

update_docker_image() {
  local tetr_tag=$TETR_TAG
  [ -z "$1" ] || tetr_tag="$1"
  DOCKER_IMAGE="chazzam/tetr:$tetr_tag"
  DOCKER_ARGS="--rm $DOCKER_VOLUMES $DOCKER_ENVS $DOCKER_IMAGE"
}

mkdir_volume_directories() {
  for d in $HOST_DIRS; do
    [ -d "$d" ] || (mkdir -p "$d" && chmod -R u+rwX,g+rwX,o+rwX "$d")
  done
}

docker_build() {
  local build_args=""
  build_args="$(echo $DOCKER_ENVS|sed -e 's/-e /--build-arg /g')"
  ( cd ..;
    docker build $build_args -t $DOCKER_IMAGE .
  )
}

echo_shell() {
  echo docker run -it --entrypoint sh $DOCKER_ARGS $@
}

docker_shell() {
  mkdir_volume_directories;
  docker run -it --entrypoint sh $DOCKER_ARGS $@
}

build_packages() {
  mkdir_volume_directories;
  local do_update=""
  # TODO: add support for -v <version>
  if [ "$1" = "-git" ]; then
    do_update="git"
    shift
  fi
  for pkg in $@; do
    docker run $DOCKER_ARGS $do_update tet $pkg || exerr "Error building package $pkg";
  done
}

test_extensions() {
  mkdir_volume_directories;
  for pkg in $@; do
    docker run $DOCKER_ARGS tettest $pkg || exerr "Error testing package $pkg";
  done
}

remaster() {
  unset pkg
  mkdir_volume_directories;
  REMASTER="$1"
  shift
  docker run $DOCKER_ARGS "$REMASTER" $@ \
    || exerr "Error bundling remastered image for $REMASTER";
}
