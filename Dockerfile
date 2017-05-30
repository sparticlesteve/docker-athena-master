# # 
## A fat container where AtlasOffline is installed and setup
##
FROM cern/slc6-base
MAINTAINER Steve Farrell "steven.farrell@cern.ch"

USER root
ENV USER root
ENV HOME /root
ENV CMAKEPATH /opt/sw/lcg/contrib/CMake/3.8.0/Linux-x86_64/ 
WORKDIR /root

# Patch yum issue
RUN yum install -y yum-plugin-ovl
RUN yum update -y

# Install core system dependencies
RUN yum install -y wget git svn redhat-lsb-core

# Install HEP common libraries
RUN yum install -y HEP_OSlibs_SL6

# Install cmake from source
RUN wget https://cmake.org/files/v3.8/cmake-3.8.0-rc2.tar.gz && \
    tar xzvf cmake-3.8.0-rc2.tar.gz && cd cmake-3.8.0-rc2 && \
    ./bootstrap && \
    gmake && \
    make install

# Install voms client and add voms servers' info
ADD egi-trustanchors /etc/yum.repos.d/egi-trustanchors.repo
RUN yum -y install ca-policy-egi-core voms-clients-cpp
RUN mkdir /etc/grid-security/vomsdir/atlas
WORKDIR /etc/grid-security/vomsdir/atlas
RUN echo "/DC=ch/DC=cern/OU=computers/CN=lcg-voms2.cern.ch" > lcg-voms2.cern.ch.lsc && \
    echo "/DC=ch/DC=cern/CN=CERN Grid Certification Authority" >> lcg-voms2.cern.ch.lsc && \
    echo "/DC=ch/DC=cern/OU=computers/CN=voms2.cern.ch" > voms2.cern.ch.lsc && \
    echo "/DC=ch/DC=cern/CN=CERN Grid Certification Authority" >> voms2.cern.ch.lsc

RUN mkdir /etc/vomses
WORKDIR /etc/vomses
RUN echo '"atlas" "lcg-voms2.cern.ch" "15001" "/DC=ch/DC=cern/OU=computers/CN=lcg-voms2.cern.ch" "atlas" "24"' > atlas-lcg-voms2.cern.ch

# Install ATLAS software
WORKDIR /root
ADD cmakeNightlyInstall.sh cmakeNightlyInstall.sh
RUN ./cmakeNightlyInstall.sh -r master/x86_64-slc6-gcc62-opt/2017-05-28T2225 -d . Athena_22.0.0_x86_64-slc6-gcc62-opt
#RUN ./cmakeNightlyInstall.sh -r master/x86_64-slc6-gcc62-opt/2017-05-28T2225 -d . AthenaExternals_22.0.0_x86_64-slc6-gcc62-opt
#ADD cmakeReleaseInstall.sh cmakeReleaseInstall.sh
#RUN ./cmakeReleaseInstall.sh -d /opt -c /tmp/rpms AtlasOffline_21.0.9_x86_64-slc6-gcc49-opt
#RUN ./cmakeReleaseInstall.sh -d /opt -c /tmp/rpms AtlasSetup || true 

# Set the path to cmake
RUN mkdir -p $CMAKEPATH && \
    cd $CMAKEPATH && \
    ln -s /usr/local/bin/ bin

CMD ["bash"]
