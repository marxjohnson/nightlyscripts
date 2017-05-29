#!/bin/bash
################################
#!# SiteId=behat_whole_suite_m
#!# OutputFormat=moodle_progress,junit
################################
# Optional Params.
if [ -z "${BehatProfileToUseOnDay}" ]; then
    BehatProfileToUseOnDay="phantomjs-linux phantomjs-selenium-linux chrome-linux phantomjs-linux chrome-linux phantomjs-selenium-linux phantomjs-linux"
fi
if [ -z "${SELENIUMPORT}" ]; then
    SELENIUMPORT=4444
fi
if [ -z "${PARALLELPROCESS}" ]; then
    PARALLELPROCESS=1
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
rerunfile="$moodledatadir/$SiteId-rerunlist"

#export DISPLAY=:99
# Start phpserver and selenium instance
cd $moodledir
for ((i=0;i<1;i+=1)); do
    echo "Starting SeleniumServer at port: $(($SELENIUMPORT+$i))"
    $homedir/scripts/selenium.sh start $(($SELENIUMPORT+$i))
    sleep 20
done;
cd -

workspacedir=$SiteId
if [ ! -d "${homedir}/workspace/UNIQUESTRING_${workspacedir}" ]; then
    mkdir -p ${homedir}/workspace/UNIQUESTRING_${workspacedir}
    chmod 775 ${homedir}/workspace/UNIQUESTRING_${workspacedir}
fi
if [ ! -d "${homedir}/workspace/UNIQUESTRING_${workspacedir}/junit_reports" ]; then
    mkdir -p ${homedir}/workspace/UNIQUESTRING_${workspacedir}/junit_reports
    chmod 775 ${homedir}/workspace/UNIQUESTRING_${workspacedir}/junit_reports
fi
for ((i=1;i<=$PARALLELPROCESS;i+=1)); do
    if [ -e "${rerunfile}${i}.txt" ]; then
        rm $rerunfile$i.txt
    fi
done;
junitreportspath="${homedir}/workspace/UNIQUESTRING_${workspacedir}/junit_reports/${BUILD_ID}"
echo "JUnit reports path: $junitreportspath"

# Find which profile to use.
dayoftheweek=`date +"%u"`
BehatProfileToUseOnDay=(`echo ${BehatProfileToUseOnDay}`);
behatprofiletouse=${BehatProfileToUseOnDay[ $(( ${dayoftheweek} - 1 )) ]}

# Run tests.
cd $moodledir/$SiteId

php admin/tool/behat/cli/run.php --format="$OutputFormat" --out=",$junitreportspath" --rerun="$rerunfile{runprocess}.txt" --replace="{runprocess}" --profile=$behatprofiletouse
exitcode=${PIPESTATUS[0]}

# Re-run failed scenarios, to ensure they are true fails.
if [ "${exitcode}" -ne 0 ]; then
    exitcode=0
    for ((i=1;i<=$PARALLELPROCESS;i+=1)); do
    	thisrerunfile="$rerunfile$i.txt"
    	if [ -e "${thisrerunfile}" ]; then
        	if [ -s "${thisrerunfile}" ]; then
	    		echo "---Running behat again for failed steps---"
			if [ ! -L $moodledir/$SiteId/behatrun$i ]; then
                            ln -s $moodledir/$SiteId $moodledir/$SiteId/behatrun$i
                        fi
    		        vendor/bin/behat --config $moodledatadir/behat_$SiteId$i/behat/behat.yml --format $OutputFormat --out ','$junitreportspath --profile $behatprofiletouse --verbose --rerun $thisrerunfile
		        exitcode=$(($exitcode+${PIPESTATUS[0]}))
	        fi
        	rm $thisrerunfile
    	fi
    done;
fi
for ((i=0;i<1;i+=1)); do
    $homedir/scripts/selenium.sh stop $(($SELENIUMPORT+$i)) > /dev/null 2>&1 &
done;
exit $exitcode
