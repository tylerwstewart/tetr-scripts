#!/bin/sh
TETR_477x86="chazzam/tetr:4.7.7-x86"
TETR_72x86="chazzam/tetr:7.2-x86"
TETR_72x86_64="chazzam/tetr:7.2-x86_64"
DOCKER_TETRS="$TETR_72x86_64 $TETR_72x86 $TETR_477x86"
REPOS="
https://github.com/chazzam/tc-diskless-remaster.git
https://github.com/chazzam/tc-ext-tools.git
https://github.com/chazzam/tc-ext-tools-packages.git
$TETR_REPOS
"
HOST_DLVR=$HOME/tc-deliver
HOST_SRC=$HOME/srctc
HOST_DIRS="$HOST_DLVR $HOST_SRC"

mkdir_volume_directories() {
  for d in $HOST_DIRS; do
    [ -d "$d" ] || (mkdir -p "$d" && chmod -R u+rwX,g+rwX,o+rwX "$d")
  done
}

clone_git_repos() {
  local r=""
  for r in $REPOS; do
    [ -d "$HOST_SRC/$(basename ${r%%.git})" ] && continue
    ( cd $HOST_SRC;
      git clone $r
    )
  done
}

docker_pull() {
  local d=""
  for d in $DOCKER_TETRS; do
    docker pull $d
  done
}

if [ "$1" = "-N" ]; then
  shift
  echo "Doing initial setup"
  docker_pull;
  mkdir_volume_directories;
  clone_git_repos;
else
  echo "Did you mean: $0 -N"
fi

for d in $HOST_DIRS; do
  [ -d "$d" ] || continue
  sudo chown -R 1001:staff "$d"
  sudo chmod -R u+rwX,g+rwX "$d"
done

echo "Exiting"
