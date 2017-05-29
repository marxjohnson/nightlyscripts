#!/bin/bash
################################
#SiteId=behat_whole_suite_m_parallel
OutputFormat=moodle_progress
################################
# Optional Params.
if [ -z "${BehatProfileToUseOnDay}" ]; then
    BehatProfileToUseOnDay="chrome-linux default default default default default default"
fi
if [ -z "${SELENIUMPORT}" ]; then
    SELENIUMPORT=5555
fi
if [ -z "${PARALLELPROCESS}" ]; then
    PARALLELPROCESS=3
fi
if [ -z "${PHPPORT}" ]; then
    PHPPORT=8000
fi
if [ -z "${PHAHNTOMJSPORT}" ]; then
    PHPPORT=4443
fi

################################

homedir=/store
moodledir="${homedir}/moodle"
datadir=/store/moodledata
moodledatadir="${datadir}/data"

#export DISPLAY=:99

cd $moodledir
# Remove Old logs
$homedir/scripts/delete_old_logs.sh

# Start phpserver and selenium instance
#for ((i=0;i<$PARALLELPROCESS;i+=1)); do
for ((i=0;i<1;i+=1)); do
   # if [ "$behatprofiletouse" = "phantomjs-selenium-linux" ]; then
        echo "Starting SeleniumServer at port: $(($SELENIUMPORT+$i))"
        $homedir/scripts/selenium.sh start $(($SELENIUMPORT+$i)) > /dev/null 2>&1 &
   # fi
    if [ "$behatprofiletouse" = "phantomjs-linux" ]; then
        echo "Starting phantomjs at port: $(($SELENIUMPORT+$i))"
        $homedir/scripts/phantomjs.sh start $(($SELENIUMPORT+$i)) > /dev/null 2>&1 &
    fi
    sleep 10
done;

cd -

workspacedir="${SiteId}"
if [ ! -d "${homedir}/workspace/UNIQUESTRING_${workspacedir}" ]; then
    mkdir -p ${homedir}/workspace/UNIQUESTRING_${workspacedir}
    chmod 775 ${homedir}/workspace/UNIQUESTRING_${workspacedir}
fi
if [ ! -d "${homedir}/workspace/UNIQUESTRING_${workspacedir}/junit_reports" ]; then
    mkdir -p ${homedir}/workspace/UNIQUESTRING_${workspacedir}/junit_reports
    chmod 775 ${homedir}/workspace/UNIQUESTRING_${workspacedir}/junit_reports
fi

#junitreportspath="${homedir}/workspace/UNIQUESTRING_${workspacedir}/junit_reports/${BUILD_ID}"
#echo "JUnit reports path: $junitreportspath"

# Find which profile to use.
dayoftheweek=`date +"%u"`
BehatProfileToUseOnDay=(`echo ${BehatProfileToUseOnDay}`);
behatprofiletouse=${BehatProfileToUseOnDay[ $(( ${dayoftheweek} - 1 )) ]}

# Run tests.
cd $moodledir/$SiteId
echo "Changing dir $moodledir/$SiteId"
php admin/tool/behat/cli/run.php --profile="${behatprofiletouse}{runprocess}" --replace="{runprocess}" --format="$OutputFormat" --out=std  #--format="junit" --out="$junitreportspath"
exitcode=${PIPESTATUS[0]}

echo "Exit code is ${exitcode}...... Going to try rerun\n"
sleep 300

# Re-run failed scenarios, to ensure they are true fails.
if [ "${exitcode}" -ne 0 ]; then
    newexitcode=0
    for ((i=1;i<=$PARALLELPROCESS;i+=1)); do
        status=$((1 << $i-1))
        if ((($status & $exitcode) != 0)); then
    	    echo "---Running behat Process ${i} again for failed steps---"
            
	    sleep 5
	    if [ ! -L $moodledir/$SiteId/behatrun$i ]; then
                ln -s $moodledir/$SiteId $moodledir/$SiteId/behatrun$i
            fi
    	    vendor/bin/behat --config $moodledatadir/behat_$SiteId/behatrun${i}/behat/behat.yml --format $OutputFormat --out std --profile="${behatprofiletouse}${i}" --verbose --rerun
	    newexitcode=$(($newexitcode+${PIPESTATUS[0]}))
            rm $moodledir/$SiteId/behatrun$i
	fi
    done;
fi
#for ((i=0;i<$PARALLELPROCESS;i+=1)); do
for ((i=0;i<1;i+=1)); do
    if [ "$behatprofiletouse" = "phantomjs-selenium-linux" ]; then
        echo "Stopping SeleniumServer at port: $(($SELENIUMPORT+$i))"
        $homedir/scripts/selenium.sh stop $(($SELENIUMPORT+$i))
    fi
    if [ "$behatprofiletouse" = "phantomjs-linux" ]; then
        echo "Stopping phantomjs at port: $(($SELENIUMPORT+$i))"
        $homedir/scripts/phantomjs.sh stop $(($SELENIUMPORT+$i))
    fi
    sleep 5
done;
exit $newexitcode
