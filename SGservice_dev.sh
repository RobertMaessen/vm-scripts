#!/usr/bin/env bash

## Just some color settings
RED='\033[0;31m'
GR='\033[0;32m'
NC='\033[0m'

B=$(tput bold)
N=$(tput sgr0)

nginx() {
  PIDF="$SG_HOME/run/nginx.pid"
  NGINXS="$NGX_HOME/sbin/nginx -p $NGX_HOME"
  NGINXST="$NGX_HOME/sbin/nginx -s stop"
  NGINXR="$NGX_HOME/sbin/nginx -p $NGX_HOME -s reload"
  LOGFILE="$SG_HOME/logs/nginx.out"
  start() {
    if [ -f $PIDF ] && kill -0 $(cat $PIDF); then
      echo 'Nginx already running' >&2
    else
      echo 'Starting Nginx' >&2
      nohup $NGINXS >> $LOGFILE 2>&1 &
      sleep 1
      PROCR=$(ps aux | grep "nginx" | grep -v grep | grep ${SG_HOME} | awk '{print $2}' | wc -l)
      if [ $PROCR != 0 ]; then
        echo -e "Nginx start
                                                              ${GR}${B}OK${N}${NC}"
      else
        echo -e "Nginx start
                                                           ${RED}${B}FAILED${N}${NC}"
      fi
    fi
  }
  stop() {
    if [ ! -f $PIDF ] || ! kill -0 $(cat $PIDF); then
      echo 'Nginx not running' >&2
    else
      echo 'Stopping Nginx' >&2
      $NGINXST && rm -f $PIDF
      sleep 1
      PROCR=$(ps aux | grep "nginx: master" | grep -v grep | grep ${SG_HOME} | awk '{print $2}' | wc -l)
      if [ $PROCR == 0 ]; then
        echo -e "Nginx stop
                                                              ${GR}${B}OK${N}${NC}"
      else
        echo -e "Nginx stop
                                                           ${RED}${B}FAILED${N}${NC}"
      fi
    fi
  }
  reload() {
   if [ ! -f $PIDF ] || ! kill -0 $(cat $PIDF); then
      echo 'Nginx not running' >&2
      exit 1
    fi
    echo 'reloading Nginx' >&2
    $NGINXR
    sleep 1
    PROCR=$(ps aux | grep "nginx: master" | grep -v grep | grep ${SG_HOME} | awk '{print $2}' | wc -l)
    if [ $PROCR == 0 ]; then
      echo -e "Nginx reload
                                                              ${GR}${B}OK${N}${NC}"
    else
      echo -e "Nginx reload
                                                           ${RED}${B}FAILED${N}${NC}"
    fi
  }
  case $2 in
  stop)
    stop
    ;;
  start)
    start
    ;;
  restart)
    stop
    start
    ;;
  reload)
    reload
    ;;
  *)
    echo "Usage: $0 nginx {stop|start|restart|reload}"
  esac
}

postgresql() {
    start () {
      if [ -f $PG_DATA/postmaster.pid ]
      then
          echo "Postgres seems to run already"
      else
        if [ -d ${SG_HOME}/share/pdata ]
        then
          $PG_HOME/bin/pg_ctl -D $PG_DATA -l $SG_HOME/logs/psql/logfile.log start &
        else
          echo "Postgres is not installed"
        fi
      fi
    }
    stop () {
      if [ ! -f $PG_DATA/postmaster.pid ]
      then
        echo "Postgres seems to be stopped already"
      else
        $PG_HOME/bin/pg_ctl -D $PG_DATA -l $SG_HOME/logs/psql/logfile stop
      fi
    }
  case $2 in
  start)
    start
  ;;
  stop)
    stop
  ;;
  restart)
    stop
    sleep2
    start
  ;;
  *)
    echo "Usage: $0 postgresql {stop|start|restart}"
  esac
}

jupyterhub() {
  PYPATH=$(which python 2> /dev/null | grep -c sgvenv)
  if [ $PYPATH == 0 ];then
    source $SG_ENV/sgvenv/bin/activate
  fi
  PIDF="$SG_HOME/run/jupyterHub.pid"
  JUPS="jupyterhub -f $SG_HOME/etc/jupyterhub_config.py"
  LOGFILE="$SG_HOME/logs/jupyterhub.out"
  start() {
    if [ -f $PIDF ] && kill -0 $(cat $PIDF); then
      echo 'JupyterHub already running' >&2
    else
      echo 'Starting JupyterHub' >&2
      nohup ${JUPS} >> $LOGFILE 2>&1 &
      sleep 2
      PROCR=$(ps aux | grep -i "sgvenv/bin/jupyterhub" | grep -v grep | awk '{print $2}' | wc -l)
      if [ $PROCR != 0 ]; then
        echo -e "JupyterHub start
                                                              ${GR}${B}OK${N}${NC}"
      else
        echo -e "JupyterHub start
                                                           ${RED}${B}FAILED${N}${NC}" >&2
      fi
    fi
  }
  stop() {
    if [ ! -f $PIDF ] || ! kill -0 $(cat $PIDF); then
      echo 'JupyterHub not running' >&2
    else
      echo 'Stopping JupyterHub' >&2
      kill $(cat "$PIDF")
      end=$((SECONDS+30))
      while [ $SECONDS -lt $end ]
      do
        alive_pids=()
        for pid in $(ps -ef | grep  "sgvenv/bin/jupyterhub" | grep -v grep | awk '{print $2}')
        do
          kill -0 "$pid" 2>/dev/null \
          && alive_pids+="$pid "
        done
        if [ ${#alive_pids[@]} -eq 0 ]
        then
          break
        fi
        echo "Processes still running ${alive_pids[@]}"
        sleep 2
      done
      if [ ${#alive_pids[@]} -eq 0 ]
      then
        echo -e "Jupyterhub stopped!
                                                              ${GR}${B}OK${N}${NC}"
        rm -f $PIDF $SG_HOME/run/jupyterhub-proxy.pid
      else
        echo -e "Jupyterhub Not stopped!
                                                           ${RED}${B}FAILED${N}${NC}"
        echo -e "${GR}Should we hard kill the remaining processes? ${B}(y/n)${N}${NC}"
        read -r input
        case $input in
        Y|y) echo -e "Oke hard killing the remaining processes"
          kill -9  ${alive_pids[@]}
          rm -f $PIDF $SG_HOME/run/jupyterhub-proxy.pid
          ;;
        N|n) echo -e "Oke not killing the processes"
          echo -e "Bye bye"
          ;;
        *) echo -e "Don't understand $input not doing anything!"
        esac
        rm -f $PIDF $SG_HOME/run/jupyterhub-proxy.pid
      fi
    fi
  }
  case $2 in
  stop)
    stop
    ;;
  start)
    start
    ;;
  restart)
    stop
    sleep 2
    start
    ;;
  *)
    echo "Usage: $0 jupyterhub {stop|start|restart}"
  esac
}

SygnoCore(){
  PYPATH=$(which python 2> /dev/null | grep -c sgvenv)
  if [ $PYPATH == 0 ];then
    source $SG_ENV/sgvenv/bin/activate
  fi
  # analytics backend
  PIDA="$SG_HOME/run/an_backend.pid"
  PIDP="$SG_HOME/run/pl_backend.pid"
  PIDF="$SG_HOME/run/frontend.pid"
  PIDM="$SG_HOME/run/ma_backend.pid"
  RUNF="node index.js"
  LOGFILEF="$SG_HOME/logs/frontend.out"

  stop() {
    if [ ! -f $PIDF ] || ! kill -0 $(cat $PIDF); then
      echo 'Frontend not running' >&2
    else
      echo 'Stopping frontend' >&2
      kill  $(ps -ef | grep "node index.js" | grep -v grep | awk '{print $2}')
      sleep 2
      rm -f $PIDF
      PROCR=$(ps aux | grep "node index.js" | grep -v grep | awk '{print $2}' | wc -l)
      if [ $PROCR == 0 ]; then
        echo -e "Frontend stop
                                                              ${GR}${B}OK${N}${NC}"
      else
        echo -e "Frontend stop
                                                           ${RED}${B}FAILED${N}${NC}"
      fi
    fi

    if [ ! -f $PIDP ] || ! kill -0 $(cat $PIDP); then
      echo 'Platform backend not running' >&2
    else
      echo 'Stopping platform backend' >&2
      kill -15 $(cat "$PIDP") && rm -f $PIDP
      sleep 2
      PROCR=$(ps aux | grep "gunicorn" | grep -v grep  | grep -c 5000)
      if [ $PROCR == 0 ]; then
        echo -e "Platform backend stop
                                                              ${GR}${B}OK${N}${NC}"
      else
        echo -e "Platform backend stop
                                                           ${RED}${B}FAILED${N}${NC}"
      fi
   fi

   if [[ ${ANALYTICS} == TRUE ]] 2> /dev/null
   then
     if [ ! -f $PIDA ] || ! kill -0 $(cat $PIDA); then
        echo 'Analytics backend not running' >&2
     else
       echo 'Stopping analytics backend' >&2
       kill -15 $(cat "$PIDA") && rm -f $PIDA
       sleep 4
       PROCR=$(ps aux | grep "gunicorn" | grep -v grep | grep -c 5001)
       if [ $PROCR == 0 ]; then
         echo -e "Analytics backend stop
                                                              ${GR}${B}OK${N}${NC}"
       else
         echo -e "Analytics backend stop
                                                           ${RED}${B}FAILED${N}${NC}"
       fi
     fi
   fi
   if [[ ${MANAGER} == TRUE ]] 2> /dev/null
     then
       if [ ! -f $PIDM ] || ! kill -0 $(cat $PIDM); then
          echo 'Manager backend not running' >&2
       else
         echo 'Stopping Manager backend' >&2
         kill -15 $(cat "$PIDM") && rm -f $PIDM
         sleep 4
         PROCR=$(ps aux | grep "gunicorn" | grep -v grep | grep -c 5002)
         if [ $PROCR == 0 ]; then
           echo -e "Manager backend stop
                                                              ${GR}${B}OK${N}${NC}"
         else
           echo -e "Manager backend stop
                                                           ${RED}${B}FAILED${N}${NC}"
         fi
       fi
     fi
  }
  start() {
    source ${HOME}/.bashrc
   PYPATH=$(which python 2> /dev/null | grep -c sgvenv)
   if [ $PYPATH == 0 ];then
     source $SG_VENV/bin/activate || exit 1
   fi
   PIDP="$SG_HOME/run/pl_backend.pid"
   if [ -f $PIDP ] && kill -0 $(cat $PIDP) 2> /dev/null; then
       echo " platform backend seems to be running. Not starting" >&2
   else
     cd $SGC_HOME/platform-backend/src || exit 1
     nohup gunicorn -b 127.0.0.1:5000 --workers=2 --timeout 120 -c gunicorn_config.py --chdir ../ 'app:create_app()' >> ${LOGDIR}/pl_backend.out 2>> ${LOGDIR}/pl_backend.err.out &
     sleep 2
     PROCR=$(ps aux | grep "gunicorn" | grep -v grep | grep -c "5000")
     if [ $PROCR != 0 ]
     then
       pid=$(ps aux | grep "gunicorn" | grep -v grep | grep  "5000" | head -1 | awk '{print $2}')
       echo $pid > $PIDP
       SECONDS=0
       while [ $SECONDS -lt 30 ]
       do
         PLRUN=$(curl --no-progress-meter 'http://127.0.0.1:5000/pl/heartbeat' | grep -i -c true)
         if [ $PLRUN != 2 ]
         then
           echo -e "${GR}Platform backend started, waiting on initialisation!${NC}"
           echo " "
         fi
         if  [ $PLRUN == 2 ]
         then
           echo -e "Platform backend start
                                                              ${GR}${B}OK${N}${NC}"
           break
           fi
           sleep 2
         done
         if [ $SECONDS -ge 30 ]; then
         echo -e "Platform initialisation failed
                                                           ${RED}${B}FAILED${N}${NC}"
         fi
     else
       echo -e "Platform backend start
                                                           ${RED}${B}FAILED${N}${NC}"
     fi
   fi

   if [[ ${ANALYTICS} == TRUE ]] 2> /dev/null
   then
     PYPATH=$(which python 2> /dev/null | grep -c sgvenv)
     if [ $PYPATH == 0 ];then
       source $SG_VENV/bin/activate || exit 1
     fi

     PIDA="$SG_HOME/run/an_backend.pid"
     if [ -f $PIDA ] && kill -0 $(cat $PIDA) 2> /dev/null; then
         echo " analytics backend seems to be running. Not starting" >&2
     else
       cd $SGC_HOME/analytics-backend/src || exit 1
       nohup gunicorn -b 127.0.0.1:5001 --workers=2 --timeout 120 -c gunicorn_config.py --chdir ../ 'app:create_app()' >> ${LOGDIR}/an_backend.out 2>> ${LOGDIR}/an_backend.err.out &
       sleep 2
       PROCR=$(ps aux | grep "gunicorn" | grep -v grep | grep -c "5001")
       if [ $PROCR != 0 ]
       then
         pid=$(ps aux | grep "gunicorn" | grep -v grep | grep  "5001" | head -1 | awk '{print $2}')
         echo $pid > $PIDA
         SECONDS=0
         while [ $SECONDS -lt 30 ]
         do
           PLRUN=$(curl --no-progress-meter 'http://127.0.0.1:5001/an/heartbeat' | grep -i -c true)
           if [ $PLRUN != 2 ]
           then
             echo -e "${GR}Analytics backend started, waiting on initialisation!${NC}"
             echo " "
           fi
           if  [ $PLRUN == 2 ]
           then
             echo -e "Analytics backend start
                                                              ${GR}${B}OK${N}${NC}"
             break
             fi
             sleep 2
           done
           if [ $SECONDS -ge 30 ]; then
           echo -e "Analytics initialisation failed
                                                           ${RED}${B}FAILED${N}${NC}"
           fi
       else
         echo -e "Analytics backend start
                                                           ${RED}${B}FAILED${N}${NC}"
       fi
     fi
   fi

   if [[ ${MANAGER} == TRUE ]] 2> /dev/null
   then
     PYPATH=$(which python 2> /dev/null | grep -c sgvenv)
     if [ $PYPATH == 0 ];then
       source $SG_VENV/bin/activate || exit 1
     fi

     PIDM="$SG_HOME/run/ma_backend.pid"
     if [ -f $PIDM ] && kill -0 $(cat $PIDM) 2> /dev/null; then
         echo " Manager backend seems to be running. Not starting" >&2
     else
       cd $SGC_HOME/manager/src || exit 1
       nohup gunicorn -b 127.0.0.1:5002 --workers=2 --timeout 120 -c gunicorn_config.py --chdir ../ 'app:create_app()' >> ${LOGDIR}/ma_backend.out 2>> ${LOGDIR}/ma_backend.err.out &
       sleep 2
       PROCR=$(ps aux | grep "gunicorn" | grep -v grep | grep -c "5002")
       if [ $PROCR != 0 ]
       then
         pid=$(ps aux | grep "gunicorn" | grep -v grep | grep  "5002" | head -1 | awk '{print $2}')
         echo $pid > $PIDM
         SECONDS=0
         while [ $SECONDS -lt 30 ]
         do
           PLRUN=$(curl --no-progress-meter 'http://127.0.0.1:5002/mg/heartbeat' | grep -i -c true)
           if [ $PLRUN != 2 ]
           then
             echo -e "${GR}Manager backend started, waiting on initialisation!${NC}"
             echo " "
           fi
           if  [ $PLRUN == 2 ]
           then
             echo -e "Manager backend start
                                                              ${GR}${B}OK${N}${NC}"
             break
             fi
             sleep 2
           done
           if [ $SECONDS -ge 30 ]; then
           echo -e "Manager initialisation failed
                                                           ${RED}${B}FAILED${N}${NC}"
           fi
       else
         echo -e "Manager backend start
                                                           ${RED}${B}FAILED${N}${NC}"
       fi
     fi
   fi

    if [ -f $PIDF ] && kill -0 $(cat $PIDF); then
      echo 'Frontend already running' >&2
    else
      echo 'Starting frontend' >&2
      cd $SGC_HOME/frontend || exit 1
      nohup $RUNF >> $LOGFILEF 2>&1 &
      sleep 2
      pid=$(ps aux | grep "node index.js" | grep -v grep | awk '{print $2}')
      echo $pid > $PIDF
      PROCR=$(ps aux | grep "node index.js" | grep -v grep | awk '{print $2}' | wc -l)
      if [ $PROCR != 0 ]; then
        echo -e "Frontend start
                                                              ${GR}${B}OK${N}${NC}"
      else
        echo -e "Frontend start
                                                           ${RED}${B}FAILED${N}${NC}"
      fi
    fi
  }
  case $2 in
  stop)
    stop
    ;;
  start)
    start
    ;;
  restart)
    stop
    sleep 2
    start
    ;;
  *)
    echo "Usage: $0 SygnoCore {stop|start|restart}"
  esac
}

spark() {
  SPARKR="$SPARK_HOME/sbin/start-all.sh"
  SPARKS="$SPARK_HOME/sbin/stop-all.sh"
  LOGFILE="$SG_HOME/logs/spark.out"
  start() {
   PROC=$(ps aux | grep "spark.deploy" | grep -v grep | grep -v history | grep -v SparkSubmit | awk '{print $2}' | wc -l)
   SPARKR="$SPARK_HOME/sbin/start-all.sh"
   if [ $PROC != 0 ]; then
    echo " Spark seems to be running. Not starting"
   else
     $SPARKR > $SG_HOME/logs/spark.out 2>&1 &
     sleep 1
     PROCR=$(ps aux | grep "spark.deploy" | grep -v grep | grep -v history | grep -v SparkSubmit | awk '{print $2}' | wc -l)
     if [ $PROCR != 0 ]; then
       echo -e "Spark start
                                                              ${GR}${B}OK${N}${NC}"
     else
       echo -e "Spark start
                                                           ${RED}${B}FAILED${N}${NC}"
     fi
   fi

   PROC=$(ps aux | grep "spark.deploy.history" | grep -v grep | awk '{print $2}' | wc -l)
   SPARKH="$SPARK_HOME/sbin/start-history-server.sh"
   if [ $PROC != 0 ]; then
     echo " Spark History Server seems to be running. Not starting"
   else
     $SPARKH > $SG_HOME/logs/spark.out 2>&1 &
     sleep 1
     PROCR=$(ps aux | grep "spark.deploy.history" | grep -v grep | awk '{print $2}' | wc -l)
     if [ $PROCR != 0 ]; then
       echo -e "Spark history server start
                                                              ${GR}${B}OK${N}${NC}"
     else
       echo -e "Spark history server start
                                                           ${RED}${B}FAILED${N}${NC}"
     fi
   fi
  }
  stop() {
   SPARKS="$SPARK_HOME/sbin/stop-all.sh"
   PROC=$(ps aux | grep "spark.deploy" | grep -v grep | grep -v history | grep -v SparkSubmit | awk '{print $2}' | wc -l)
   if [ $PROC == 0 ]; then
     echo 'Spark not running' >&2
   else
     echo 'Stopping Spark' >&2
     $SPARKS
     sleep 3
     PROCR=$(ps aux | grep "spark.deploy" | grep -v grep | grep -v history | grep -v SparkSubmit | awk '{print $2}' | wc -l)
     if [ $PROCR == 0 ]; then
       echo -e "Spark stop
                                                              ${GR}${B}OK${N}${NC}"
     else
       echo -e "Spark stop
                                                           ${RED}${B}FAILED${N}${NC}"
     fi
   fi

   SPARKH="$SPARK_HOME/sbin/stop-history-server.sh"
   PROC=$(ps aux | grep "spark.deploy.history" | grep -v grep | awk '{print $2}' | wc -l)
   if [ $PROC == 0 ]; then
     echo 'Spark history server not running' >&2
   else
     echo 'Stopping Spark history server' >&2
     $SPARKH
     sleep 3
     PROCR=$(ps aux | grep "spark.deploy.history" | grep -v grep | awk '{print $2}' | wc -l)
       if [ $PROCR == 0 ]; then
         echo -e "Spark history server stop
                                                              ${GR}${B}OK${N}${NC}"
       else
         echo -e "Spark history server stop
                                                           ${RED}${B}FAILED${N}${NC}"
       fi
   fi
  }
  case $2 in
  stop)
    stop
    ;;
  start)
    start
    ;;
  restart)
    stop
    sleep 2
    start
    ;;
  *)
    echo "Usage: $0 spark {stop|start|restart}"
  esac
}


all() {
  start() {
    $SG_HOME/bin/startALL.sh
  }
  stop() {
    $SG_HOME/bin/stopALL.sh
  }
  case $2 in
  stop)
    stop
    ;;
  start)
    start
    ;;
  restart)
    stop
    sleep 2
    start
    ;;
  *)
    echo "Usage: $0 all {stop|start|restart}"
  esac
}

case "$1" in
  nginx)
    nginx echo $2
    ;;
  spark)
    if [[ ${ANALYTICS} == TRUE ]] 2> /dev/null
    then
      spark echo $2
    else
      echo "Spark is not available when only the Manager is used"
    fi
    ;;
  SygnoCore)
    SygnoCore echo $2
    ;;
 postgresql)
   postgresql echo $2
     ;;
  all)
    all echo $2
    ;;
  *)
    if [[ ${ANALYTICS} == TRUE ]]
    then
        echo "Usage: $0 {nginx|SygnoCore|spark|postgresql|all}"
    else
        echo "Usage: $0 {nginx|SygnoCore|postgresql|all}"
    fi
esac
