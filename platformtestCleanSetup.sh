#!/usr/bin/env bash
SGservice.sh SygnoCore stop

GIT_HOME="/home/sguser/git/sygno_core"
sqlcmd -S s02.sygno.com,1433 -U uat_user -P HRJ_Sygno2025! -C -Q "alter database [sygno_core_ds] set single_user with rollback immediate"
sqlcmd -S s02.sygno.com,1433 -U uat_user -P HRJ_Sygno2025! -C -Q "alter database [sygno_core_ma] set single_user with rollback immediate"
sqlcmd -S s02.sygno.com,1433 -U uat_user -P HRJ_Sygno2025! -C -Q "drop database sygno_core_ds"
sqlcmd -S s02.sygno.com,1433 -U uat_user -P HRJ_Sygno2025! -C -Q "drop database sygno_core_ma"
sqlcmd -S s02.sygno.com,1433 -U uat_user -P HRJ_Sygno2025! -C -Q "alter database [sygno_core_pl] set single_user with rollback immediate"
sqlcmd -S s02.sygno.com,1433 -U uat_user -P HRJ_Sygno2025! -C -Q "drop database sygno_core_pl"
sqlcmd -S s02.sygno.com,1433 -U uat_user -P HRJ_Sygno2025! -C -Q "alter database [sygno_core_an] set single_user with rollback immediate"
sqlcmd -S s02.sygno.com,1433 -U uat_user -P HRJ_Sygno2025! -C -Q "drop database sygno_core_an"
sqlcmd -S s02.sygno.com,1433 -U uat_user -P HRJ_Sygno2025! -C -Q "create database sygno_core_an"
sqlcmd -S s02.sygno.com,1433 -U uat_user -P HRJ_Sygno2025! -C -Q "create database sygno_core_pl"
sqlcmd -S s02.sygno.com,1433 -U uat_user -P HRJ_Sygno2025! -C -Q "create database sygno_core_ma"
sqlcmd -S s02.sygno.com,1433 -U uat_user -P HRJ_Sygno2025! -C -Q "create database sygno_core_ds"

rm -rf /opt/platformtest/sygno_core/*
rm -rf /opt/platformtest/inputs/*
rm -rf /opt/platformtest/outputs/*

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
rsync -a analytics-backend/src/ ${SGC_HOME}/analytics-backend
rsync -a manager-backend/manager ${SGC_HOME}
rsync -a frontend ${SGC_HOME}
rsync -a backend-common/ ${SGC_HOME}/analytics-backend/src/common
rsync -a backend-common/ ${SGC_HOME}/platform-backend/src/common
rsync -a backend-common/ ${SGC_HOME}/manager/src/common
cd ${SGC_HOME}/frontend || exit
npm ci
printf "y\n" | npx update-browserslist-db@latest
npm run build

# cp -r ~/settings_save ~/settings
cp ~/settings/set_pl.yml $SGC_HOME/platform-backend/settings.yml
cp ~/settings/scoring_settings.yml $SGC_HOME/platform-backend
cp -r  ~/settings/keys $SGC_HOME/platform-backend
cp ~/settings/set_an.yml $SGC_HOME/analytics-backend/settings.yml
cp ~/settings/set_ma.yml $SGC_HOME/manager/settings.yml
cp ~/settings/set_ane.yml $SGC_HOME/analytics-engine/settings.yml

source /opt/platformtest/sgenv/sgvenv/bin/activate || exit
cd ${SGC_HOME}/platform-backend
flask db upgrade
flask create-token an-backend > /tmp/antoken
TOKEN=$(tail -1 /tmp/antoken)
sed -i "/server_token: /c\\server_token: \'${TOKEN}\'" ${SGC_HOME}/analytics-backend/settings.yml
flask create-token an-engine > /tmp/anetoken
STOKEN=$(tail -1 /tmp/anetoken)
sed -i "/server_token: /c\\server_token: \'${STOKEN}\'" ${ANE_HOME}/settings.yml
flask create-token platform > /tmp/pltoken
PTOKEN=$(tail -1 /tmp/pltoken)
sed -i "/server_token: /c\\server_token: \'${PTOKEN}\'" ${SGC_HOME}/platform-backend/settings.yml
flask create-token manager > /tmp/matoken
MTOKEN=$(tail -1 /tmp/matoken)
sed -i "/server_token: /c\\server_token: \'${MTOKEN}\'" ${SGC_HOME}/manager/settings.yml
flask create-initial-user admin@sygno.com --pw WeCanChangeIt!
rm -f /tmp/sgatoken
rm -f /tmp/antoken
rm -f /tmp/pltoken
rm -f /tmp/matoken
cd ${SGC_HOME}/analytics-backend
flask db upgrade
cd ${SGC_HOME}/platform-backend
flask db upgrade
cd ${SGC_HOME}/manager
flask db upgrade
cd ${SGC_HOME}/frontend
npm ci
printf "y\n" |  npx update-browserslist-db@latest
npm run build

cp ~/settings/config.json $SGC_HOME/frontend/build
SGservice.sh SygnoCore start