#!/bin/bash
#
# Installtion script of ATLAS CMake nightly RPMs
# Author: Johannes Elmsheuser, Attila Krasznahorkay 
# Date: April 2016

# Function showing the usage help
show_help() {
    echo "Usage: cmakeNightlyInstall.sh -r nightlyVer -d installDir -t dateString pkg1 pkg2..."
    echo "Example:"
    echo "   ./cmakeNightlyInstall.sh -r 21.0.X-VAL/x86_64-slc6-gcc49-opt/rel_2 -d $HOME/opt -t 2016-06-20T1650 AtlasOffline*"
    echo "   ./cmakeNightlyInstall.sh -r 21.0/x86_64-slc6-gcc62-opt/2017-04-25T2130 -d ./opt Athena_21.0.22_x86_64-slc6-gcc62-opt"
    echo "   ./cmakeNightlyInstall.sh -r master/x86_64-slc6-gcc62-opt/2017-04-16T2225 -d . Athena_22.0.0_x86_64-slc6-gcc62-opt"
    echo "  To reuse the .rpmdb file from CVMFS use: -l"
}

# Stop on errors:
set -e

# Parse the command line arguments:
OPTIND=1
while getopts ":r:d:t:l" opt; do
    case "$opt" in
	     h|\?)
	         show_help
	         exit 0
	         ;;
	     r)
	         NIGHTLYVER=$OPTARG
	         ;;
	     d)
	         INSTALLDIR=`readlink -f $OPTARG`
	         ;;
        t)
            DATEDIR=$OPTARG
            ;;
        l)
            RPMDBUSE=true
            ;;
    esac
done
shift $((OPTIND-1))
PROJECTS=$@

if [ ! -d "$TMPDIR" ]; then 
   if [ -d "/tmp/$USER" ]; then 
      export TMPDIR=/tmp/$USER
   else 
      export TMPDIR=$HOME
   fi
fi

# ayum directory
AYUMDIR=$TMPDIR
# Directory name with the date
if [ -z "$DATEDIR" ]; then
    DATEDIR=`date "+%FT%H%M"`
fi

echo "#############################################"
echo "Installing project(s) $PROJECTS"
echo "  from nightly  : $NIGHTLYVER"
echo "  into directory: $INSTALLDIR/$DATEDIR"
echo "  AYUM directory: $AYUMDIR"
echo "#############################################"
echo

# Check that everything was specified:
if [ -z "$NIGHTLYVER" ] || [ -z "$INSTALLDIR" ] || \
    [ -z "$PROJECTS" ]; then
    show_help
    exit 1
fi

# Create RPM directory:
if [ ! -d "$INSTALLDIR" ]; then
    echo "Creating directory $INSTALLDIR"
    mkdir -p $INSTALLDIR
fi

# Get the branch name only and then the main base from it
# Following will not work for e.g. master/git releases
# so switching off by default and it can be enabled by using -l
if [ x$RPMDBUSE = x"true" ]; then
    echo "RPMDB from CVMFS will be reused"
    NIGHTLYBRANCH=`echo $NIGHTLYVER |cut -d'/' -f 1 |cut -d'-' -f 1`
    MAINBASEREL=`echo $NIGHTLYBRANCH | sed '/^[^\.]\+\.[^\.]\+\./!d;s,^\([^\.]\+\.[^\.]\+\)\..*$,\1,'`
    if [ X`echo $NIGHTLYBRANCH | sed '/^[0-9][0-9]\.[^\.]\+\.[^\.]\+$/!d;s,\..*$,,'` = "X" ]; then
   ####  $NIGHTLYBRANCH is not 3 digit
        if ! [ -d "/cvmfs/atlas.cern.ch/repo/sw" ]; then
            echo "ERROR: /cvmfs/atlas.cern.ch not availabel. That is needed for a cache nightly rpm install"
	          exit 1
        fi
   # temporary fix to allow e.g. master/git installations 
        if [ -z ${MAINBASEREL} ]; then
            MAINBASEREL=21.0
        fi
        if ([ ! -d "/cvmfs/atlas.cern.ch/repo/sw/software/${MAINBASEREL}" ] || [ -z ${MAINBASEREL} ]); then
#      echo "ERROR: main base release /cvmfs/atlas.cern.ch/repo/sw/software/$MAINBASEREL can not be found."
            exit 1
        fi
        cp -a /cvmfs/atlas.cern.ch/repo/sw/software/$MAINBASEREL/.rpmdb $INSTALLDIR
    fi
fi

#### else $NIGHTLYBRANCH is 3 digit do not do anything special


# Set up ayum from scratch in the current directory:
CURDIR=$PWD
cd $AYUMDIR
rm -rf ayum/
git clone https://gitlab.cern.ch/rhauser/ayum.git
cd ayum
# Uncomment next line if used on CC7 docker image (needs additional packages)
#make -C src/rpmext clean all
./configure.ayum -i $INSTALLDIR -D > yum.conf

# Remove the unnecessary line from the generated file:
sed 's/AYUM package location.*//' yum.conf > yum.conf.fixed
mv yum.conf.fixed yum.conf

# Configure the ayum repositories:
cat - >./etc/yum.repos.d/lcg.repo <<EOF
[lcg-repo]
name=LCG Repository
baseurl=http://lcgpackages.web.cern.ch/lcgpackages/rpms
prefix=${INSTALLDIR}/sw/lcg/releases
enabled=1
EOF

cat - >./etc/yum.repos.d/tdaq-nightly.repo <<EOF
[tdaq-nightly]
name=nightly snapshots of TDAQ releases
baseurl=http://cern.ch/atlas-tdaq-sw/yum/tdaq/nightly
enabled=1
EOF

cat - >./etc/yum.repos.d/tdaq-testing.repo <<EOF
[tdaq-testing]
name=non-official updates and patches for TDAQ releases
baseurl=http://atlas-tdaq-sw.web.cern.ch/atlas-tdaq-sw/yum/tdaq/testing
enabled=1 

[dqm-common-testing]
name=dqm-common projects
baseurl=http://atlas-tdaq-sw.web.cern.ch/atlas-tdaq-sw/yum/dqm-common/testing
enabled=1

[tdaq-common-testing]
name=non-official updates and patches for TDAQ releases
baseurl=http://atlas-tdaq-sw.web.cern.ch/atlas-tdaq-sw/yum/tdaq-common/testing
enabled=1 
EOF

cat - >./etc/yum.repos.d/atlas-offline-data.repo <<EOF
[atlas-offline-data]
name=ATLAS offline data packages
baseurl=http://cern.ch/atlas-software-dist-eos/RPMs/data
enabled=1
EOF

cat - >./etc/yum.repos.d/atlas-offline-nightly.repo <<EOF
[atlas-offline-nightly]
name=ATLAS offline nightly releases
baseurl=http://cern.ch/atlas-software-dist-eos/RPMs/nightlies/${NIGHTLYVER}
prefix=${INSTALLDIR}/${DATEDIR}
enabled=1
EOF

# Tell the user what happened:
echo "Configured AYUM"

# Setup environment to run the ayum command:
shopt -s expand_aliases
source ./setup.sh
cd $CURDIR

# First try to reinstall the project. Assuming that a previous version
# of it is already installed. If it's not, then simply install it.
ayum -y reinstall $PROJECTS || ayum -y install $PROJECTS
