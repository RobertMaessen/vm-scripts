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
[ -d src ] && mv src analytics-engine &&  touch /tmp/RENAME
rsync -rogu  analytics-engine ${SGC_HOME}
[ -f /tmp/RENAME ] && mv analytics-engine src && rm -f /tmp/RENAME
cd $GIT_HOME/frontend
git pull
cd $GIT_HOME
rsync -rogu platform-backend $SGC_HOME
rsync -rogu analytics-backend $SGC_HOME
rsync -rogu manager-backend/manager $SGC_HOME
rsync -rogu frontend $SGC_HOME

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