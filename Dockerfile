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

# Install system dependencies
RUN yum install -y wget svn redhat-lsb-core
RUN yum install -y gcc krb5-devel bzip2 gcc-c++
RUN yum install -y which ctags libuuid libuuid-devel texinfo

# Install cmake from source
RUN wget https://cmake.org/files/v3.8/cmake-3.8.0-rc2.tar.gz && \
    tar xzvf cmake-3.8.0-rc2.tar.gz && cd cmake-3.8.0-rc2 && \
    ./bootstrap && make -j install && rm ../cmake-3.8.0-rc2.tar.gz

# Set the path to cmake
RUN mkdir -p $CMAKEPATH && \
    cd $CMAKEPATH && \
    ln -s /usr/local/bin/ bin

# Install git from source
RUN yum install -y autoconf curl-devel expat-devel gettext-devel \
    openssl-devel perl-devel zlib-devel
RUN curl https://www.kernel.org/pub/software/scm/git/git-2.13.0.tar.gz \
    -o git-2.13.0.tar.gz && \
    tar xzf git-2.13.0.tar.gz && cd git-2.13.0 && \
    make configure && ./configure --prefix=/usr && \
    make -j all install && rm ../git-2.13.0.tar.gz

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
ADD dependencies dependencies
RUN ./cmakeNightlyInstall.sh -d /opt \
    -r master/x86_64-slc6-gcc62-opt/2017-05-28T2125 \
    $(cat dependencies)

#RUN ./cmakeNightlyInstall.sh -r master/x86_64-slc6-gcc62-opt/2017-05-28T2225 -d . Athena_22.0.0_x86_64-slc6-gcc62-opt
#ADD cmakeReleaseInstall.sh cmakeReleaseInstall.sh
#RUN ./cmakeReleaseInstall.sh -d /opt -c /tmp/rpms AtlasOffline_21.0.9_x86_64-slc6-gcc49-opt
#RUN ./cmakeReleaseInstall.sh -d /opt -c /tmp/rpms AtlasSetup || true 

# Add the ssh config files
ADD sshconfig /root/.ssh/config
ADD sshknownhosts /root/.ssh/known_hosts
RUN chmod 600 /root/.ssh/config && chmod 644 /root/.ssh/known_hosts

# Additional environment settings for building
ENV LCG_RELEASE_BASE /root/sw/lcg/releases
ENV TDAQ_RELEASE_BASE /root

CMD ["bash"]
