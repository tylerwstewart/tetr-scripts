#!/bin/sh
. ./docker.sh
DOCKER_TETRS="$TAG_DOCKER_CURRENT $TAG_DOCKER_80 $TAG_DOCKER_477 $TAG_DOCKER_80_64"
REPOS="
https://github.com/chazzam/tc-diskless-remaster.git
https://github.com/chazzam/tc-ext-tools.git
https://github.com/chazzam/tc-ext-tools-packages.git
$TETR_REPOS
"
HOST_DLVR=$HOME/tc-deliver
HOST_SRC=$HOME/srctc
HOST_DIRS="$HOST_DLVR $HOST_SRC"
[ -z "$DOCKER_REPO" ] && DOCKER_REPO="https://github.com/chazzam/docker-tetr"
DOCKER_REPO_NAME="$(basename $DOCKER_REPO)"

mkdir_volume_directories() {
  for d in $HOST_DIRS; do
    [ -d "$d" ] || (mkdir -p "$d" && chmod -R u+rwX,g+rwX,o+rwX "$d")
  done
}

clone_git_repos() {
  local r=""
  for r in $REPOS $DOCKER_REPO; do
    [ -d "$HOST_SRC/$(basename ${r%%.git})" ] && continue
    ( cd $HOST_SRC;
      git clone $r
    )
  done
}

docker_pull() {
  local d=""
  local full_tag=""
  for d in $DOCKER_TETRS; do
    update_docker_image "$d";
    docker pull $DOCKER_IMAGE || { \
      printf "\n\n\ndocker image %s not available, trying to build...\n\n" "$DOCKER_IMAGE"; \
      ./buildit -D $d "$HOST_SRC/$DOCKER_REPO_NAME/"; }
  done
}

docker_build() {
  for d in $DOCKER_TETRS; do
    update_docker_image "$d";
    printf "\nBuilding %s\n" "$DOCKER_IMAGE";
    ./buildit -D $d "$HOST_SRC/$DOCKER_REPO_NAME/";
  done
}

if [ "$1" = "-N" ]; then
  shift
  echo "Doing initial setup, pulling docker images"
  mkdir_volume_directories;
  clone_git_repos;
  docker_pull;
elif [ "$1" = "-B" ]; then
  shift
  echo "Doing initial setup, building docker images locally"
  mkdir_volume_directories;
  clone_git_repos;
  docker_build;
else
  echo "Did you mean: $0 -N"
fi

for d in $HOST_DIRS; do
  [ -d "$d" ] || continue
  sudo chown -R 1001:staff "$d"
  sudo chmod -R u+rwX,g+rwX "$d"
done

echo "Exiting"
