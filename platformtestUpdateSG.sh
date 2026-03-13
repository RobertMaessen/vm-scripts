#!/usr/bin/env bash


B=$(tput bold)
N=$(tput sgr0)
RED='\033[0;31m'
GR='\033[0;32m'
NC='\033[0m'

SGservice.sh SygnoCore stop

cd ${GIT_HOME}/platform-backend || exit 1
git pull
git branch -r
PBRANCH=$(git branch | grep \*)
echo -e "${GR}platform-backend branch is set to ${RED}${PBRANCH}${GR}, type 'Y' if that is fine otherwise type in the branch name you want to use${NC}"
read -r branch
case $branch in
  Y|y) echo "we will use $PBRANCH"
  ;;
  *) echo "we will checkout $branch"
    git checkout $branch
    git pull
esac

cd ${GIT_HOME}/analytics-backend || exit 1
git pull
git branch -r
ABRANCH=$(git branch | grep \*)
echo -e "${GR}analytics-backend branch is set to ${RED}${ABRANCH}$GR, type 'Y' if that is fine otherwise type in the branch name you want to use${NC}"
read -r branch
case $branch in
  Y|y) echo "we will use $ABRANCH"
  ;;
  *) echo "we will checkout $branch"
    git checkout $branch
    git pull
esac

cd ${GIT_HOME}/manager-backend/manager || exit 1
git pull
git branch -r
MBRANCH=$(git branch | grep \*)
echo -e "${GR}manager-backend branch is set to ${RED}${MBRANCH}${GR}, type 'Y' if that is fine otherwise type in the branch name you want to use${NC}"
read -r branch
case $branch in
  Y|y) echo "we will use $MBRANCH"
  ;;
  *) echo "we will checkout $branch"
    git checkout $branch
    git pull
esac

cd ${GIT_HOME}/frontend || exit 1
git pull
git branch -r
FBRANCH=$(git branch | grep \*)
echo -e "${GR}frontend branch is set to ${RED}${FBRANCH}${GR}, type 'Y' if that is fine otherwise type in the branch name you want to use${NC}"
read -r branch
case $branch in
  Y|y) echo "we will use $FBRANCH"
  ;;
  *) echo "we will checkout $branch"
    git checkout $branch
    git pull
esac

cd ${GIT_HOME}/backend-common || exit 1
git pull
git branch -r
CBRANCH=$(git branch | grep \*)
echo -e "${GR}backend-common branch is set to ${RED}${CBRANCH}${GR}, type 'Y' if that is fine otherwise type in the branch name you want to use ${NC}"
read -r branch
case $branch in
  Y|y) echo "we will use $CBRANCH"
  ;;
  *) echo "we will checkout $branch"
    git checkout $branch
    git pull
esac

cd $GIT_HOME/analytics-engine || exit 1
git  pull
git branch -r
EBRANCH=$(git branch | grep \*)
echo -e "${GR}analytics-engine branch is set to ${RED}${EBRANCH}${GR}, type 'Y' if that is fine otherwise type in the branch name you want to use${NC}"
read -r branch
case $branch in
  Y|y) echo "we will use $EBRANCH"
  ;;
  *) echo "we will checkout $branch"
    git checkout $branch
    git pull
esac

cd ${SG_HOME} || exit 1
rm -rf sygno_core_20*
mv sygno_core sygno_core_$(date +%F)
mkdir sygno_core

cd ${GIT_HOME} || exit 1
rsync -a platform-backend ${SGC_HOME}
rsync -a analytics-backend ${SGC_HOME}
rsync -a manager-backend/manager ${SGC_HOME}
rsync -a frontend ${SGC_HOME}
rsync -a backend-common/ ${SGC_HOME}/analytics-backend/src/common
rsync -a backend-common/ ${SGC_HOME}/platform-backend/src/common
rsync -a backend-common/ ${SGC_HOME}/manager/src/common
cd ${SGC_HOME}/frontend || exit
npm ci
printf "y\n" | npx update-browserslist-db@latest
npm run build

cp ${SRC_FILES}/set_pl.yml ${SGC_HOME}/platform-backend/settings.yml
cp -r ${SRC_FILES}/keys ${SGC_HOME}/platform-backend/
cp ${SRC_FILES}/set_an.yml ${SGC_HOME}/analytics-backend/settings.yml
cp ${SRC_FILES}/set_ma.yml ${SGC_HOME}/manager/settings.yml
cp ${SRC_FILES}/config.json ${SGC_HOME}/frontend/build/

source ${SG_VENV}/bin/activate
cd ${SGC_HOME}/platform-backend/ || exit 1
flask db upgrade
cd ${SGC_HOME}/analytics-backend/ || exit 1
flask db upgrade
cd ${SGC_HOME}/manager/ || exit 1
flask db upgrade

echo " "
echo -e "${GR}Should we start the application (${B}y/n${N})?${NC}"
read -r input
case ${input} in
Y|y) echo -e "OK starting the application after update!"
     SGservice.sh SygnoCore start
;;
N|n) echo -e "OK NOT starting the application"
;;
*) exit 1
esac
