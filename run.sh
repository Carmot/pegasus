#!/bin/bash

ROOT=`pwd`
export REPORT_DIR="$ROOT/test_report"
export DSN_ROOT=$ROOT/DSN_ROOT
export LD_LIBRARY_PATH=$DSN_ROOT/lib:$BOOST_DIR/lib:$TOOLCHAIN_DIR/lib64:$LD_LIBRARY_PATH

function usage()
{
    echo "usage: run.sh <command> [<args>]"
    echo
    echo "Command list:"
    echo "   help                      print the help info"
    echo "   build                     build the system"
    echo
    echo "   start_zk                  start local single zookeeper server"
    echo "   stop_zk                   stop local zookeeper server"
    echo "   clear_zk                  stop local zookeeper server and clear data"
    echo
    echo "   start_onebox              start pegasus onebox"
    echo "   stop_onebox               stop pegasus onebox"
    echo "   list_onebox               list pegasus onebox"
    echo "   clear_onebox              clear pegasus onebox"
    echo
    echo "   start_onebox_instance     start pegasus onebox instance"
    echo "   stop_onebox_instance      stop pegasus onebox instance"
    echo "   restart_onebox_instance   restart pegasus onebox instance"
    echo
    echo "   start_kill_test           start pegasus kill test"
    echo "   stop_kill_test            stop pegasus kill test"
    echo "   list_kill_test            list pegasus kill test"
    echo "   clear_kill_test           clear pegasus kill test"
    echo
    echo "   bench                     run benchmark test"
    echo "   shell                     run pegasus shell"
    echo "   migrate_node              migrate primary replicas out of specified node"
    echo
    echo "   test                      run unit test"
    echo
    echo "   pack_server               generate pegasus server package for deploy with minos"
    echo "   pack_client               generate pegasus client package"
    echo "   pack_tools                generate pegasus tools package for shell and benchmark test"
    echo
    echo "   bump_version              change the version of the project"
    echo "Command 'run.sh <command> -h' will print help for subcommands."
}

#####################
## build
#####################
function usage_build()
{
    echo "Options for subcommand 'build':"
    echo "   -h|--help         print the help info"
    echo "   -t|--type         build type: debug|release, default is debug"
    echo "   -g|--git          git source of ext module: github|xiaomi, default is xiaomi"
    echo "   -s|--serialize    serialize type: dsn|thrift|proto, default is thrift"
    echo "   -c|--clear        clear the environment before building"
    echo "   -cc|--half-clear  only clear the environment of replication before building"
    echo "   -j|--jobs <num>   the number of jobs to run simultaneously, default 8"
    echo "   -b|--boost_dir <dir>"
    echo "                     specify customized boost directory,"
    echo "                     if not set, then use the system boost"
    echo "   -w|--warning_all  open all warnings when build, default no"
    echo "   --enable_gcov     generate gcov code coverage report, default no"
    echo "   -v|--verbose      build in verbose mode, default no"
}
function run_build()
{
    BUILD_TYPE="debug"
    GIT_SOURCE="xiaomi"
    CLEAR=NO
    PART_CLEAR=NO
    JOB_NUM=8
    BOOST_DIR=""
    WARNING_ALL=NO
    ENABLE_GCOV=NO
    RUN_VERBOSE=NO
    TEST_MODULE=""
    while [[ $# > 0 ]]; do
        key="$1"
        case $key in
            -h|--help)
                usage_build
                exit 0
                ;;
            -t|--type)
                BUILD_TYPE="$2"
                shift
                ;;
            -g|--git)
                GIT_SOURCE="$2"
                shift
                ;;
            -c|--clear)
                CLEAR=YES
                ;;
            -cc|--part_clear)
                PART_CLEAR=YES
                ;;
            -j|--jobs)
                JOB_NUM="$2"
                shift
                ;;
            -b|--boost_dir)
                BOOST_DIR="$2"
                shift
                ;;
            -w|--warning_all)
                WARNING_ALL=YES
                ;;
            --enable_gcov)
                ENABLE_GCOV=YES
                ;;
            -v|--verbose)
                RUN_VERBOSE=YES
                ;;
            *)
                echo "ERROR: unknown option \"$key\""
                echo
                usage_build
                exit -1
                ;;
        esac
        shift
    done
    if [ "$BUILD_TYPE" != "debug" -a "$BUILD_TYPE" != "release" ]; then
        echo "ERROR: invalid build type \"$BUILD_TYPE\""
        echo
        usage_build
        exit -1
    fi

    if [ ! -d $ROOT/rdsn/include ]; then
        echo "ERROR: rdsn submodule not fetched"
        exit -1
    fi

    export DSN_ROOT=$ROOT/rdsn/builder/output
    if [ ! -e $ROOT/DSN_ROOT ]; then
        ln -s $DSN_ROOT $ROOT/DSN_ROOT
    fi

    echo "INFO: start build rdsn..."
    cd $ROOT/rdsn
    OPT="-t $BUILD_TYPE -g $GIT_SOURCE -j $JOB_NUM"
    if [ "$BOOST_DIR" != "" ]; then
        OPT="$OPT -b $BOOST_DIR"
    fi
    if [ "$CLEAR" == "YES" ]; then
        OPT="$OPT -c"
    fi
    ./run.sh build $OPT
    if [ $? -ne 0 ]; then
        echo "ERROR: build rdsn failed"
        exit -1
    fi

    echo "INFO: start build pegasus..."
    cd $ROOT/src
    BUILD_TYPE="$BUILD_TYPE" CLEAR="$CLEAR" PART_CLEAR="$PART_CLEAR" JOB_NUM="$JOB_NUM" \
        BOOST_DIR="$BOOST_DIR" WARNING_ALL="$WARNING_ALL" ENABLE_GCOV="$ENABLE_GCOV" \
        RUN_VERBOSE="$RUN_VERBOSE" TEST_MODULE="$TEST_MODULE" ./build.sh
    if [ $? -ne 0 ]; then
        echo "ERROR: build pegasus failed"
        exit -1
    fi
}

#####################
## test
#####################
function usage_test()
{
    echo "Options for subcommand 'test':"
    echo "   -h|--help         print the help info"
    echo "   -m|--modules      set the test modules: pegasus_rproxy_test pegasus_function_test"
    echo "   -k|--keep_onebox  whether keep the onebox after the test[default false]"
}
function run_test()
{
    local test_modules=""
    local clear_flags="1"
    while [[ $# > 0 ]]; do
        key="$1"
        case $key in
            -h|--help)
                usage_test
                exit 0
                ;;
            -m|--modules)
                test_modules=$2
                shift
                ;;
            -k|--keep_onebox)
                clear_flags=""
                ;;
            *)
                echo "Error: unknow option \"$key\""
                echo
                usage_test
                exit -1
                ;;
        esac
        shift
    done

    if [ "$test_modules" == "" ]; then
        test_modules="pegasus_rproxy_test pegasus_function_test"
    fi

    ./run.sh clear_onebox #clear the onebox before test
    ./run.sh start_onebox -p 4
    echo "sleep 20 to wait for the onebox to start all partitions ..."
    sleep 20

    for module in `echo $test_modules`; do
        pushd $ROOT/src/builder/bin/$module
        REPORT_DIR=$REPORT_DIR ./run.sh
        popd
    done

    if [ "$clear_flags" == "1" ]; then
        ./run.sh clear_onebox
    fi
}

#####################
## start_zk
#####################
function usage_start_zk()
{
    echo "Options for subcommand 'start_zk':"
    echo "   -h|--help         print the help info"
    echo "   -d|--install_dir <dir>"
    echo "                     zookeeper install directory,"
    echo "                     if not set, then default is './.zk_install'"
    echo "   -p|--port <port>  listen port of zookeeper, default is 22181"
}
function run_start_zk()
{
    INSTALL_DIR=`pwd`/.zk_install
    PORT=22181
    while [[ $# > 0 ]]; do
        key="$1"
        case $key in
            -h|--help)
                usage_start_zk
                exit 0
                ;;
            -d|--install_dir)
                INSTALL_DIR=$2
                shift
                ;;
            -p|--port)
                PORT=$2
                shift
                ;;
            *)
                echo "ERROR: unknown option \"$key\""
                echo
                usage_start_zk
                exit -1
                ;;
        esac
        shift
    done
    INSTALL_DIR="$INSTALL_DIR" PORT="$PORT" ./scripts/start_zk.sh
}

#####################
## stop_zk
#####################
function usage_stop_zk()
{
    echo "Options for subcommand 'stop_zk':"
    echo "   -h|--help         print the help info"
    echo "   -d|--install_dir <dir>"
    echo "                     zookeeper install directory,"
    echo "                     if not set, then default is './.zk_install'"
}
function run_stop_zk()
{
    INSTALL_DIR=`pwd`/.zk_install
    while [[ $# > 0 ]]; do
        key="$1"
        case $key in
            -h|--help)
                usage_stop_zk
                exit 0
                ;;
            -d|--install_dir)
                INSTALL_DIR=$2
                shift
                ;;
            *)
                echo "ERROR: unknown option \"$key\""
                echo
                usage_stop_zk
                exit -1
                ;;
        esac
        shift
    done
    INSTALL_DIR="$INSTALL_DIR" ./scripts/stop_zk.sh
}

#####################
## clear_zk
#####################
function usage_clear_zk()
{
    echo "Options for subcommand 'clear_zk':"
    echo "   -h|--help         print the help info"
    echo "   -d|--install_dir <dir>"
    echo "                     zookeeper install directory,"
    echo "                     if not set, then default is './.zk_install'"
}
function run_clear_zk()
{
    INSTALL_DIR=`pwd`/.zk_install
    while [[ $# > 0 ]]; do
        key="$1"
        case $key in
            -h|--help)
                usage_clear_zk
                exit 0
                ;;
            -d|--install_dir)
                INSTALL_DIR=$2
                shift
                ;;
            *)
                echo "ERROR: unknown option \"$key\""
                echo
                usage_clear__zk
                exit -1
                ;;
        esac
        shift
    done
    INSTALL_DIR="$INSTALL_DIR" ./scripts/clear_zk.sh
}

#####################
## start_onebox
#####################
function usage_start_onebox()
{
    echo "Options for subcommand 'start_onebox':"
    echo "   -h|--help         print the help info"
    echo "   -m|--meta_count <num>"
    echo "                     meta server count, default is 3"
    echo "   -r|--replica_count <num>"
    echo "                     replica server count, default is 3"
    echo "   -a|--app_name <str>"
    echo "                     default app name, default is temp"
    echo "   -p|--partition_count <num>"
    echo "                     default app partition count, default is 8"
}

function run_start_onebox()
{
    META_COUNT=3
    REPLICA_COUNT=3
    APP_NAME=temp
    PARTITION_COUNT=8
    while [[ $# > 0 ]]; do
        key="$1"
        case $key in
            -h|--help)
                usage_start_onebox
                exit 0
                ;;
            -m|--meta_count)
                META_COUNT="$2"
                shift
                ;;
            -r|--replica_count)
                REPLICA_COUNT="$2"
                shift
                ;;
            -a|--app_name)
                APP_NAME="$2"
                shift
                ;;
            -p|--partition_count)
                PARTITION_COUNT="$2"
                shift
                ;;
            *)
                echo "ERROR: unknown option \"$key\""
                echo
                usage_start_onebox
                exit -1
                ;;
        esac
        shift
    done
    if [ ! -f ${DSN_ROOT}/bin/pegasus_server/pegasus_server ]; then
        echo "ERROR: file ${DSN_ROOT}/bin/pegasus_server/pegasus_server not exist"
        exit -1
    fi
    if ps -ef | grep ' \./pegasus_server config.ini' | grep -E 'app_list meta@|app_list replica@'; then
        echo "ERROR: some onebox processes are running, start failed"
        exit -1
    fi
    ln -s -f ${DSN_ROOT}/bin/pegasus_server/pegasus_server
    run_start_zk
    sed "s/@LOCAL_IP@/`hostname -i`/g;s/@META_COUNT@/${META_COUNT}/g;s/@REPLICA_COUNT@/${REPLICA_COUNT}/g;s/@APP_NAME@/${APP_NAME}/g;s/@PARTITION_COUNT@/${PARTITION_COUNT}/g" \
        ${ROOT}/src/server/config-server.ini >${ROOT}/config-server.ini
    echo "starting server"
    mkdir -p onebox
    cd onebox
    for i in $(seq ${META_COUNT})
    do
        mkdir -p meta$i;
        cd meta$i
        ln -s -f ${DSN_ROOT}/bin/pegasus_server/pegasus_server pegasus_server
        ln -s -f ${ROOT}/config-server.ini config.ini
        echo "cd `pwd` && ./pegasus_server config.ini -app_list meta@$i &>result &"
        ./pegasus_server config.ini -app_list meta@$i &>result &
        PID=$!
        ps -ef | grep ' \./pegasus_server config.ini' | grep "\<$PID\>"
        cd ..
    done
    for j in $(seq ${REPLICA_COUNT})
    do
        mkdir -p replica$j
        cd replica$j
        ln -s -f ${DSN_ROOT}/bin/pegasus_server/pegasus_server pegasus_server
        ln -s -f ${ROOT}/config-server.ini config.ini
        echo "cd `pwd` && ./pegasus_server config.ini -app_list replica@$j &>result &"
        ./pegasus_server config.ini -app_list replica@$j &>result &
        PID=$!
        ps -ef | grep ' \./pegasus_server config.ini' | grep "\<$PID\>"
        cd ..
    done
}

#####################
## stop_onebox
#####################
function usage_stop_onebox()
{
    echo "Options for subcommand 'stop_onebox':"
    echo "   -h|--help         print the help info"
}

function run_stop_onebox()
{
    while [[ $# > 0 ]]; do
        key="$1"
        case $key in
            -h|--help)
                usage_stop_onebox
                exit 0
                ;;
            *)
                echo "ERROR: unknown option \"$key\""
                echo
                usage_stop_onebox
                exit -1
                ;;
        esac
        shift
    done
    ps -ef | grep ' \./pegasus_server config.ini' | grep -E 'app_list meta@|app_list replica@' | awk '{print $2}' | xargs kill &>/dev/null
}

#####################
## list_onebox
#####################
function usage_list_onebox()
{
    echo "Options for subcommand 'list_onebox':"
    echo "   -h|--help         print the help info"
}

function run_list_onebox()
{
    while [[ $# > 0 ]]; do
        key="$1"
        case $key in
            -h|--help)
                usage_list_onebox
                exit 0
                ;;
            *)
                echo "ERROR: unknown option \"$key\""
                echo
                usage_list_onebox
                exit -1
                ;;
        esac
        shift
    done
    ps -ef | grep ' \./pegasus_server config.ini' | grep -E 'app_list meta@|app_list replica@' | sort -k11
}

#####################
## clear_onebox
#####################
function usage_clear_onebox()
{
    echo "Options for subcommand 'clear_onebox':"
    echo "   -h|--help         print the help info"
}

function run_clear_onebox()
{
    while [[ $# > 0 ]]; do
        key="$1"
        case $key in
            -h|--help)
                usage_clear_onebox
                exit 0
                ;;
            *)
                echo "ERROR: unknown option \"$key\""
                echo
                usage_clear_onebox
                exit -1
                ;;
        esac
        shift
    done
    run_stop_onebox
    run_clear_zk
    rm -rf onebox *.log *.data config-*.ini &>/dev/null
}

#####################
## start_onebox_instance
#####################
function usage_start_onebox_instance()
{
    echo "Options for subcommand 'start_onebox_instance':"
    echo "   -h|--help         print the help info"
    echo "   -m|--meta_id <num>"
    echo "                     meta server id"
    echo "   -r|--replica_id <num>"
    echo "                     replica server id"
}

function run_start_onebox_instance()
{
    META_ID=0
    REPLICA_ID=0
    while [[ $# > 0 ]]; do
        key="$1"
        case $key in
            -h|--help)
                usage_start_onebox_instance
                exit 0
                ;;
            -m|--meta_id)
                META_ID="$2"
                shift
                ;;
            -r|--replica_id)
                REPLICA_ID="$2"
                shift
                ;;
            *)
                echo "ERROR: unknown option \"$key\""
                echo
                usage_start_onebox_instance
                exit -1
                ;;
        esac
        shift
    done
    if [ $META_ID = "0" -a $REPLICA_ID = "0" ]; then
        echo "ERROR: no meta_id or replica_id set"
        exit -1
    fi
    if [ $META_ID != "0" -a $REPLICA_ID != "0" ]; then
        echo "ERROR: meta_id and replica_id can only set one"
        exit -1
    fi
    if [ $META_ID != "0" ]; then
        dir=onebox/meta$META_ID
        if [ ! -d $dir ]; then
            echo "ERROR: invalid meta_id"
            exit -1
        fi
        if ps -ef | grep ' \./pegasus_server config.ini' | grep "app_list meta@$META_ID\>" ; then
            echo "INFO: meta@$META_ID already running"
            exit -1
        fi
        cd $dir
        echo "cd `pwd` && ./pegasus_server config.ini -app_list meta@$META_ID &>result &"
        ./pegasus_server config.ini -app_list meta@$META_ID &>result &
        PID=$!
        ps -ef | grep ' \./pegasus_server config.ini' | grep "\<$PID\>"
        cd ..
        echo "INFO: meta@$META started"
    fi
    if [ $REPLICA_ID != "0" ]; then
        dir=onebox/replica$REPLICA_ID
        if [ ! -d $dir ]; then
            echo "ERROR: invalid replica_id"
            exit -1
        fi
        if ps -ef | grep ' \./pegasus_server config.ini' | grep "app_list replica@$REPLICA_ID\>" ; then
            echo "INFO: replica@$REPLICA_ID already running"
            exit -1
        fi
        cd $dir
        echo "cd `pwd` && ./pegasus_server config.ini -app_list replica@$REPLICA_ID &>result &"
        ./pegasus_server config.ini -app_list replica@$REPLICA_ID &>result &
        PID=$!
        ps -ef | grep ' \./pegasus_server config.ini' | grep "\<$PID\>"
        cd ..
        echo "INFO: replica@$REPLICA_ID started"
    fi
}

#####################
## stop_onebox_instance
#####################
function usage_stop_onebox_instance()
{
    echo "Options for subcommand 'stop_onebox_instance':"
    echo "   -h|--help         print the help info"
    echo "   -m|--meta_id <num>"
    echo "                     meta server id"
    echo "   -r|--replica_id <num>"
    echo "                     replica server id"
}

function run_stop_onebox_instance()
{
    META_ID=0
    REPLICA_ID=0
    while [[ $# > 0 ]]; do
        key="$1"
        case $key in
            -h|--help)
                usage_stop_onebox_instance
                exit 0
                ;;
            -m|--meta_id)
                META_ID="$2"
                shift
                ;;
            -r|--replica_id)
                REPLICA_ID="$2"
                shift
                ;;
            *)
                echo "ERROR: unknown option \"$key\""
                echo
                usage_stop_onebox_instance
                exit -1
                ;;
        esac
        shift
    done
    if [ $META_ID = "0" -a $REPLICA_ID = "0" ]; then
        echo "ERROR: no meta_id or replica_id set"
        exit -1
    fi
    if [ $META_ID != "0" -a $REPLICA_ID != "0" ]; then
        echo "ERROR: meta_id and replica_id can only set one"
        exit -1
    fi
    if [ $META_ID != "0" ]; then
        dir=onebox/meta$META_ID
        if [ ! -d $dir ]; then
            echo "ERROR: invalid meta_id"
            exit -1
        fi
        if ! ps -ef | grep ' \./pegasus_server config.ini' | grep "app_list meta@$META_ID\>" ; then
            echo "INFO: meta@$META_ID is not running"
            exit -1
        fi
        ps -ef | grep ' \./pegasus_server config.ini' | grep "app_list meta@$META_ID\>" | awk '{print $2}' | xargs kill &>/dev/null
        echo "INFO: meta@$META_ID stopped"
    fi
    if [ $REPLICA_ID != "0" ]; then
        dir=onebox/replica$REPLICA_ID
        if [ ! -d $dir ]; then
            echo "ERROR: invalid replica_id"
            exit -1
        fi
        if ! ps -ef | grep ' \./pegasus_server config.ini' | grep "app_list replica@$REPLICA_ID\>" ; then
            echo "INFO: replica@$REPLICA_ID is not running"
            exit -1
        fi
        ps -ef | grep ' \./pegasus_server config.ini' | grep "app_list replica@$REPLICA_ID\>" | awk '{print $2}' | xargs kill &>/dev/null
        echo "INFO: replica@$REPLICA_ID stopped"
    fi
}

#####################
## restart_onebox_instance
#####################
function usage_restart_onebox_instance()
{
    echo "Options for subcommand 'restart_onebox_instance':"
    echo "   -h|--help         print the help info"
    echo "   -m|--meta_id <num>"
    echo "                     meta server id"
    echo "   -r|--replica_id <num>"
    echo "                     replica server id"
    echo "   -s|--sleep <num>"
    echo "                     sleep time in seconds between stop and start, default is 1"
}

function run_restart_onebox_instance()
{
    META_ID=0
    REPLICA_ID=0
    SLEEP=1
    while [[ $# > 0 ]]; do
        key="$1"
        case $key in
            -h|--help)
                usage_restart_onebox_instance
                exit 0
                ;;
            -m|--meta_id)
                META_ID="$2"
                shift
                ;;
            -r|--replica_id)
                REPLICA_ID="$2"
                shift
                ;;
            -s|--sleep)
                SLEEP="$2"
                shift
                ;;
            *)
                echo "ERROR: unknown option \"$key\""
                echo
                usage_restart_onebox_instance
                exit -1
                ;;
        esac
        shift
    done
    if [ $META_ID = "0" -a $REPLICA_ID = "0" ]; then
        echo "ERROR: no meta_id or replica_id set"
        exit -1
    fi
    if [ $META_ID != "0" -a $REPLICA_ID != "0" ]; then
        echo "ERROR: meta_id and replica_id can only set one"
        exit -1
    fi
    run_stop_onebox_instance -m $META_ID -r $REPLICA_ID
    echo "sleep $SLEEP"
    sleep $SLEEP
    run_start_onebox_instance -m $META_ID -r $REPLICA_ID
}

#####################
## start_kill_test
#####################
function usage_start_kill_test()
{
    echo "Options for subcommand 'start_kill_test':"
    echo "   -h|--help         print the help info"
    echo "   -m|--meta_count <num>"
    echo "                     meta server count, default is 3"
    echo "   -r|--replica_count <num>"
    echo "                     replica server count, default is 5"
    echo "   -a|--app_name <str>"
    echo "                     app name, default is temp"
    echo "   -p|--partition_count <num>"
    echo "                     app partition count, default is 16"
    echo "   -t|--kill_type <str>"
    echo "                     kill type: meta | replica | all, default is all"
    echo "   -s|--sleep_time <num>"
    echo "                     max sleep time before next kill, default is 10"
    echo "                     actual sleep time will be a random value in range of [1, sleep_time]"
    echo "   -w|--worker_count <num>"
    echo "                     worker count for concurrently setting value, default is 10"
}

function run_start_kill_test()
{
    META_COUNT=3
    REPLICA_COUNT=5
    APP_NAME=temp
    PARTITION_COUNT=16
    KILL_TYPE=all
    SLEEP_TIME=10
    THREAD_COUNT=10
    while [[ $# > 0 ]]; do
        key="$1"
        case $key in
            -h|--help)
                usage_start_kill_test
                exit 0
                ;;
            -m|--meta_count)
                META_COUNT="$2"
                shift
                ;;
            -r|--replica_count)
                REPLICA_COUNT="$2"
                shift
                ;;
            -a|--app_name)
                APP_NAME="$2"
                shift
                ;;
            -p|--partition_count)
                PARTITION_COUNT="$2"
                shift
                ;;
            -t|--kill_type)
                KILL_TYPE="$2"
                shift
                ;;
            -s|--sleep_time)
                SLEEP_TIME="$2"
                shift
                ;;
            -w|--worker_count)
                THREAD_COUNT="$2"
                shift
                ;;
            *)
                echo "ERROR: unknown option \"$key\""
                echo
                usage_start_kill_test
                exit -1
                ;;
        esac
        shift
    done

    run_start_onebox -m $META_COUNT -r $REPLICA_COUNT -a $APP_NAME -p $PARTITION_COUNT
    echo

    cd $ROOT
    CONFIG=config-kill-test.ini
    sed "s/@LOCAL_IP@/`hostname -i`/g" ${ROOT}/src/test/kill_test/config.ini >$CONFIG
    ln -s -f ${DSN_ROOT}/bin/pegasus_kill_test/pegasus_kill_test
    echo "./pegasus_kill_test $CONFIG &>/dev/null &"
    ./pegasus_kill_test $CONFIG &>/dev/null &
    sleep 0.2
    echo

    run_list_kill_test
}

#####################
## stop_kill_test
#####################
function usage_stop_kill_test()
{
    echo "Options for subcommand 'stop_kill_test':"
    echo "   -h|--help         print the help info"
}

function run_stop_kill_test()
{
    while [[ $# > 0 ]]; do
        key="$1"
        case $key in
            -h|--help)
                usage_stop_kill_test
                exit 0
                ;;
            *)
                echo "ERROR: unknown option \"$key\""
                echo
                usage_stop_kill_test
                exit -1
                ;;
        esac
        shift
    done

    ps -ef | grep ' \./pegasus_kill_test ' | awk '{print $2}' | xargs kill &>/dev/null
    run_stop_onebox
}

#####################
## list_kill_test
#####################
function usage_list_kill_test()
{
    echo "Options for subcommand 'list_kill_test':"
    echo "   -h|--help         print the help info"
}

function run_list_kill_test()
{
    while [[ $# > 0 ]]; do
        key="$1"
        case $key in
            -h|--help)
                usage_list_kill_test
                exit 0
                ;;
            *)
                echo "ERROR: unknown option \"$key\""
                echo
                usage_list_kill_test
                exit -1
                ;;
        esac
        shift
    done
    echo "------------------------------"
    run_list_onebox
    ps -ef | grep ' \./pegasus_kill_test ' | grep -v grep
    echo "------------------------------"
    echo "Server dir: ./onebox"
    echo "Client dir: ./pegasus_kill_test.data"
    echo "Kill   log: ./kill_history.txt"
    echo "------------------------------"
}

#####################
## clear_kill_test
#####################
function usage_clear_kill_test()
{
    echo "Options for subcommand 'clear_kill_test':"
    echo "   -h|--help         print the help info"
}

function run_clear_kill_test()
{
    while [[ $# > 0 ]]; do
        key="$1"
        case $key in
            -h|--help)
                usage_clear_kill_test
                exit 0
                ;;
            *)
                echo "ERROR: unknown option \"$key\""
                echo
                usage_clear_kill_test
                exit -1
                ;;
        esac
        shift
    done
    run_stop_kill_test
    run_clear_onebox
    rm -rf kill_history.txt *.data config-*.ini &>/dev/null
}

#####################
## bench
#####################
function usage_bench()
{
    echo "Options for subcommand 'bench':"
    echo "   -h|--help            print the help info"
    echo "   -c|--config <path>   config file path, default './config-bench.ini'"
    echo "   -t|--type            benchmark type, supporting:"
    echo "                          fillseq_pegasus, fillrandom_pegasus, filluniquerandom_pegasus,"
    echo "                          readrandom_pegasus, deleteseq_pegasus, deleterandom_pegasus"
    echo "                        default is 'fillseq_pegasus,readrandom_pegasus'"
    echo "   -n <num>             number of key/value pairs, default 100000"
    echo "   --cluster <str>      cluster meta lists, default '127.0.0.1:34601,127.0.0.1:34602,127.0.0.1:34603'"
    echo "   --app_name <str>     app name, default 'temp'"
    echo "   --thread_num <num>   number of threads, default 1"
    echo "   --key_size <num>     key size, default 16"
    echo "   --value_size <num>   value size, default 100"
    echo "   --timeout <num>      timeout in milliseconds, default 10000"
}

function run_bench()
{
    CONFIG=${ROOT}/config-bench.ini
    CONFIG_SPECIFIED=0
    TYPE=fillseq_pegasus,readrandom_pegasus
    NUM=100000
    CLUSTER=127.0.0.1:34601,127.0.0.1:34602,127.0.0.1:34603
    APP=temp
    THREAD=1
    KEY_SIZE=16
    VALUE_SIZE=100
    TIMEOUT_MS=10000
    while [[ $# > 0 ]]; do
        key="$1"
        case $key in
            -h|--help)
                usage_bench
                exit 0
                ;;
            -c|--config)
                CONFIG="$2"
                CONFIG_SPECIFIED=1
                shift
                ;;
            -t|--type)
                TYPE="$2"
                shift
                ;;
            -n)
                NUM="$2"
                shift
                ;;
            --cluster)
                CLUSTER="$2"
                shift
                ;;
            --app_name)
                APP="$2"
                shift
                ;;
            --thread_num)
                THREAD="$2"
                shift
                ;;
            --key_size)
                KEY_SIZE="$2"
                shift
                ;;
            --value_size)
                VALUE_SIZE="$2"
                shift
                ;;
            --timeout)
                TIMEOUT_MS="$2"
                shift
                ;;
            *)
                echo "ERROR: unknown option \"$key\""
                echo
                usage_bench
                exit -1
                ;;
        esac
        shift
    done

    if [ ${CONFIG_SPECIFIED} -eq 0 ]; then
        sed "s/@CLUSTER@/$CLUSTER/g" ${ROOT}/src/config-bench.ini >${CONFIG}
    fi

    cd ${ROOT}
    ln -s -f ${DSN_ROOT}/bin/pegasus_bench/pegasus_bench
    ./pegasus_bench --pegasus_config=${CONFIG} --benchmarks=${TYPE} --pegasus_timeout_ms=${TIMEOUT_MS} \
        --key_size=${KEY_SIZE} --value_size=${VALUE_SIZE} --threads=${THREAD} --num=${NUM} \
        --pegasus_cluster_name=mycluster --pegasus_app_name=${APP} --stats_interval=1000 --histogram=1 \
        --compression_type=none --compression_ratio=1.0
}

#####################
## shell
#####################
function usage_shell()
{
    echo "Options for subcommand 'shell':"
    echo "   -h|--help            print the help info"
    echo "   -c|--config <path>   config file path, default './config-shell.ini'"
    echo "   --cluster <str>      cluster meta lists, default '127.0.0.1:34601,127.0.0.1:34602,127.0.0.1:34603'"
    echo "   -n <cluster-name>    cluster name. Will try to get a cluster ip_list"
    echo "                        from your MINOS-config(through \$MINOS_CONFIG_FILE) or"
    echo "                        from [uri-resolve.dsn://<cluster-name>] of your config-file"
}

function run_shell()
{
    CONFIG=${ROOT}/config-shell.ini
    CONFIG_SPECIFIED=0
    CLUSTER=127.0.0.1:34601,127.0.0.1:34602,127.0.0.1:34603
    CLUSTER_SPECIFIED=0
    CLUSTER_NAME=mycluster
    CLUSTER_NAME_SPECIFIED=0
    while [[ $# > 0 ]]; do
        key="$1"
        case $key in
            -h|--help)
                usage_shell
                exit 0
                ;;
            -c|--config)
                CONFIG="$2"
                CONFIG_SPECIFIED=1
                shift
                ;;
            -m|--cluster)
                CLUSTER="$2"
                CLUSTER_SPECIFIED=1
                shift
                ;;
            -n|--cluster_name)
                CLUSTER_NAME="$2"
                CLUSTER_NAME_SPECIFIED=1
                shift
                ;;
            *)
                echo "ERROR: unknown option \"$key\""
                echo
                usage_shell
                exit -1
                ;;
        esac
        shift
    done

    if [ ${CLUSTER_SPECIFIED} -eq 1 -a ${CLUSTER_NAME_SPECIFIED} -eq 1 ]; then
        echo "ERROR: can not specify both cluster and cluster_name at the same time"
        echo
        usage_shell
        exit -1
    fi

    if [ $CLUSTER_NAME_SPECIFIED -eq 1 ]; then
        meta_section="/tmp/minos.config.cluster.meta.section.$UID"
        pegasus_config_file=$(dirname $MINOS_CONFIG_FILE)/xiaomi-config/conf/pegasus/pegasus-${CLUSTER_NAME}.cfg
        if [ -f $pegasus_config_file ]; then
            meta_section_start=$(grep -n "\[meta" $pegasus_config_file | head -1 | cut -d":" -f 1)
            meta_section_end=$(grep -n "\[replica" $pegasus_config_file | head -1 | cut -d":" -f 1)
            sed -n "${meta_section_start},${meta_section_end}p" $pegasus_config_file > $meta_section
            if [ $? -ne 0 ]; then
                echo "write $pegasus_config_file meta_info to $meta_section failed"
            else
                base_port=$(grep "base_port=" $meta_section | cut -d"=" -f2)
                hosts_list=$(grep " host\.[0-9]*" $meta_section | grep -oh "[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*")
                if [ ! -z "$base_port" ] && [ ! -z "$hosts_list" ]; then
                    meta_list=()
                    for h in $hosts_list; do
                        meta_list+=($h":"$[ $base_port + 1 ])
                    done
                    OLD_IFS="$IFS"
                    IFS="," && CLUSTER="${meta_list[*]}" && IFS="$OLD_IFS"
                    echo "parse meta_list $CLUSTER from $pegasus_config_file"
                    # TODO: remove cluster_name from pegasus_shell
                    CLUSTER_NAME="mycluster"
                else
                    echo "parse meta_list from $pegasus_config_file failed"
                fi
            fi
        else
            echo "can't find file $pegasus_config_file, please check you env \$MINOS_CONFIG_FILE"
        fi
    fi

    if [ ${CONFIG_SPECIFIED} -eq 0 ]; then
        sed "s/@CLUSTER@/$CLUSTER/g" ${ROOT}/src/shell/config.ini >${CONFIG}
    fi

    cd ${ROOT}
    ln -s -f ${DSN_ROOT}/bin/pegasus_shell/pegasus_shell
    ./pegasus_shell config-shell.ini $CLUSTER_NAME
}

#####################
## migrate_node
#####################
function usage_migrate_node()
{
    echo "Options for subcommand 'migrate_node':"
    echo "   -h|--help            print the help info"
    echo "   -c|--cluster <str>   cluster meta lists"
    echo "   -n|--node <str>      the node to migrate primary replicas out, should be ip:port"
    echo "   -a|--app <str>       the app to migrate primary replicas out, if not set, means migrate all apps"
    echo "   -t|--type <str>      type: test or run, default is test"
}

function run_migrate_node()
{
    CLUSTER=""
    NODE=""
    APP="*"
    TYPE="test"
    while [[ $# > 0 ]]; do
        key="$1"
        case $key in
            -h|--help)
                usage_migrate_node
                exit 0
                ;;
            -c|--cluster)
                CLUSTER="$2"
                shift
                ;;
            -n|--node)
                NODE="$2"
                shift
                ;;
            -a|--app)
                APP="$2"
                shift
                ;;
            -t|--type)
                TYPE="$2"
                shift
                ;;
            *)
                echo "ERROR: unknown option \"$key\""
                echo
                usage_migrate_node
                exit -1
                ;;
        esac
        shift
    done

    if [ "$CLUSTER" == "" ]; then
        echo "ERROR: no cluster specified"
        echo
        usage_migrate_node
        exit -1
    fi

    if [ "$NODE" == "" ]; then
        echo "ERROR: no node specified"
        echo
        usage_migrate_node
        exit -1
    fi

    if [ "$TYPE" != "test" -a "$TYPE" != "run" ]; then
        echo "ERROR: invalid type $TYPE"
        echo
        usage_migrate_node
        exit -1
    fi

    echo "CLUSTER=$CLUSTER"
    echo "NODE=$NODE"
    echo "APP=$APP"
    echo "TYPE=$TYPE"
    echo
    cd ${ROOT}
    echo "------------------------------"
    ./scripts/migrate_node.sh $CLUSTER $NODE "$APP" $TYPE
    echo "------------------------------"
    echo
    if [ "$TYPE" == "test" ]; then
        echo "The above is sample migration commands."
        echo "Run with option '-t run' to do migration actually."
    else
        echo "Done."
        echo "You can run shell command 'nodes -d' to check the result."
        echo
        echo "The cluster's auto migration is disabled now, you can run shell command 'set_meta_level lively' to enable it again."
    fi
}

####################################################################

if [ $# -eq 0 ]; then
    usage
    exit 0
fi
cmd=$1
case $cmd in
    help)
        usage
        ;;
    build)
        shift
        run_build $*
        ;;
    start_zk)
        shift
        run_start_zk $*
        ;;
    stop_zk)
        shift
        run_stop_zk $*
        ;;
    clear_zk)
        shift
        run_clear_zk $*
        ;;
    start_onebox)
        shift
        run_start_onebox $*
        ;;
    stop_onebox)
        shift
        run_stop_onebox $*
        ;;
    clear_onebox)
        shift
        run_clear_onebox $*
        ;;
    list_onebox)
        shift
        run_list_onebox $*
        ;;
    start_onebox_instance)
        shift
        run_start_onebox_instance $*
        ;;
    stop_onebox_instance)
        shift
        run_stop_onebox_instance $*
        ;;
    restart_onebox_instance)
        shift
        run_restart_onebox_instance $*
        ;;
    start_kill_test)
        shift
        run_start_kill_test $*
        ;;
    stop_kill_test)
        shift
        run_stop_kill_test $*
        ;;
    list_kill_test)
        shift
        run_list_kill_test $*
        ;;
    clear_kill_test)
        shift
        run_clear_kill_test $*
        ;;
    bench)
        shift
        run_bench $*
        ;;
    shell)
        shift
        run_shell $*
        ;;
    migrate_node)
        shift
        run_migrate_node $*
        ;;
    test)
        shift
        run_test $*
        ;;
    pack_server)
        shift
        PEGASUS_ROOT=$ROOT ./scripts/pack_server.sh $*
        ;;
    pack_client)
        shift
        PEGASUS_ROOT=$ROOT ./scripts/pack_client.sh $*
        ;;
    pack_tools)
        shift
        PEGASUS_ROOT=$ROOT ./scripts/pack_tools.sh $*
        ;;
    bump_version)
        shift
        ./scripts/bump_version.sh $*
        ;;
    *)
        echo "ERROR: unknown command $cmd"
        echo
        usage
        exit -1
esac

