#!/bin/bash

HELM_IMAGE="${GIT_HOME}/helm-image"
DOCKER_URL="192.168.122.72:5000"
NEXUS_URL="http://192.168.122.61:8081/repository/raw_files/APPS"
NEXUS_CUST_URL="http://192.168.122.61:8082"
BASE=$(grep Base ${GIT_HOME}/release-versions/SygnoCore.txt | awk -F ": " '{print $2}' )
APPV="0.0.29" # This needs to be updated before a run... otherwise it will not be installed via helm

B=$(tput bold)
N=$(tput sgr0)
RED='\033[0;31m'
GR='\033[0;32m'
NC='\033[0m'


REL_HOME=${GIT_HOME}/release-versions
cd ${REL_HOME} || exit 1
git pull
git branch -r
RBRANCH=$(git branch | grep \*)
echo -e "${GR}release-versions branch is set to ${RBRANCH}, type 'Y' if that is fine otherwise type in the branch name you want to use${NC}"
read -r branch
case $branch in
  Y|y) echo "we will use $RBRANCH"
  ;;
  *) echo "we will checkout $branch"
    git checkout $branch
    git pull
esac

cd ${GIT_HOME}/helm-image || exit 1
git pull
git branch -r
HBRANCH=$(git branch | grep \*)
echo -e "${GR}helm-image branch is set to ${HBRANCH}, type 'Y' if that is fine otherwise type in the branch name you want to use${NC}"
read -r branch
case $branch in
  Y|y) echo "we will use $HBRANCH"
  ;;
  *) echo "we will checkout $branch"
    git checkout $branch
    git pull
esac


cd ${GIT_HOME}/platform-backend || exit 1
git pull
git branch -r
PBRANCH=$(git branch | grep \*)
echo -e "${GR}platform-backend branch is set to ${PBRANCH}, type 'Y' if that is fine otherwise type in the branch name you want to use${NC}"
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
echo -e "${GR}analytics-backend branch is set to ${ABRANCH}, type 'Y' if that is fine otherwise type in the branch name you want to use${NC}"
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
echo -e "${GR}manager-backend branch is set to ${MBRANCH}, type 'Y' if that is fine otherwise type in the branch name you want to use${NC}"
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
echo -e "${GR}frontend branch is set to ${FBRANCH}, type 'Y' if that is fine otherwise type in the branch name you want to use${NC}"
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
echo -e "${GR}backend-common branch is set to ${CBRANCH}, type 'Y' if that is fine otherwise type in the branch name you want to use ${NC}"
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
echo -e "${GR}analytics-engine branch is set to ${EBRANCH}, type 'Y' if that is fine otherwise type in the branch name you want to use${NC}"
read -r branch
case $branch in
  Y|y) echo "we will use $EBRANCH"
  ;;
  *) echo "we will checkout $branch"
    git checkout $branch
    git pull
esac


mkdir -p /tmp/release/sygno-core
RELEASE_DIR=/tmp/release
cd ${GIT_HOME} || exit 1
rsync -a platform-backend ${RELEASE_DIR}/sygno-core
rsync -a --exclude cypress* frontend ${RELEASE_DIR}/sygno-core
rsync -a analytics-backend ${RELEASE_DIR}/sygno-core
rsync -a manager-backend/manager ${RELEASE_DIR}/sygno-core
rsync -a analytics-engine/src/ ${RELEASE_DIR}/sygno-core/analytics-engine
rsync -a analytics-engine/encrypt.txt ${RELEASE_DIR}/sygno-core
rsync -a backend-common/ ${RELEASE_DIR}/sygno-core/analytics-backend/src/common
rsync -a backend-common/ ${RELEASE_DIR}/sygno-core/platform-backend/src/common
rsync -a backend-common/ ${RELEASE_DIR}/sygno-core/manager/src/common


# Copy files to release dir
cp -r ${HELM_IMAGE}/Dockerfile ${RELEASE_DIR}
cp -r ${HELM_IMAGE}/dockerFiles  ${RELEASE_DIR}
cp -r ${HELM_IMAGE}/bin  ${RELEASE_DIR}
cp -r ${HELM_IMAGE}/spark-image ${RELEASE_DIR}
cp ${REL_HOME}pip.txt ${RELEASE_DIR}/dockerFiles/requirements.txt
cp ${REL_HOME}pip.txt ${RELEASE_DIR}spark-image/etc/requirements.txt

# Docker build sygno-helm image
cd ${RELEASE_DIR} || exit 1
docker build -t ${DOCKER_URL}/sygno-helm-${BASE}:$APPV \
  --build-arg APP_PYTHONVERSION="$(grep PythonVersion ${REL_HOME}/application.txt | awk -F ": " '{print $2}')" \
  --build-arg APP_NODEVERSION="$(grep NodeVersion ${REL_HOME}/application.txt | awk -F ": " '{print $2}')" \
  --build-arg APP_SPARKVERSION="$(grep SparkVersion ${REL_HOME}/application.txt | awk -F ": " '{print $2}')" \
  --build-arg APP_HADOOPVERSION="$(grep PythonVersion ${REL_HOME}/application.txt | awk -F ": " '{print $2}')" \
  --build-arg APP_MSSQLJAR="$(grep MssqlJar ${REL_HOME}/application.txt | awk -F ": " '{print $2}')" \
  --build-arg APP_PSQLJAR="$(grep PsqlJar ${REL_HOME}/application.txt | awk -F ": " '{print $2}')" \
  --build-arg SC_BASE=${BASE} \
  --build-arg SC_APPV=${APPV} \
  --build-arg NEXUS_URL=${NEXUS_URL} \
  --build-arg NEXUS_CUST_URL=${NEXUS_CUST_URL} \
  --secret nexus_user="$(awk -F ":" ~/.nexuspw '{print $1}')" \
  --secret nexus_pass="$(awk -F ":" ~/.nexuspw '{print $2}')" \
  .
# Push the image
docker push ${DOCKER_URL}/sygno-helm-${BASE}:${APPV}

# Docker build sygno-exec image
cd ${RELEASE_DIR}/spark-image || exit 1
docker build -t ${DOCKER_URL}/sygno-exec-${BASE}:$APPV \
  --build-arg APP_PYTHONVERSION="$(grep PythonVersion ${REL_HOME}/application.txt | awk -F ": " '{print $2}')" \
  --build-arg APP_SPARKVERSION="$(grep SparkVersion ${REL_HOME}/application.txt | awk -F ": " '{print $2}')" \
  --build-arg APP_HADOOPVERSION="$(grep PythonVersion ${REL_HOME}/application.txt | awk -F ": " '{print $2}')" \
  --build-arg APP_MSSQLJAR="$(grep MssqlJar ${REL_HOME}/application.txt | awk -F ": " '{print $2}')" \
  --build-arg APP_PSQLJAR="$(grep PsqlJar ${REL_HOME}/application.txt | awk -F ": " '{print $2}')" \
  --build-arg SC_BASE=${BASE} \
  --build-arg SC_APPV=${APPV} \
  --build-arg NEXUS_URL=${NEXUS_URL} \
  --secret id=nexus_user, src="$(awk -F ":" $HOME/.nexuspw '{print $1}')" \
  --secret id=nexus_pass, src="$(awk -F ":" $HOME/.nexuspw '{print $2}')" \
  .

# Push it
docker push ${DOCKER_URL}/sygno-exec-${BASE}:$APPV

# Clean up after build and push
printf "y\n" | docker system prune --all
cd ${GIT_HOME} || exit 1
rm -rf ${RELEASE_DIR}
