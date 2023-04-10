FROM debian:11-slim

LABEL name="FCP Source and Lazarus Git main, Linux64 and Win32, Win64 crosscompile with lazbuild. Debian 11 slim (bullseye)" 
LABEL version="1.1.0"
LABEL author="Christian Wimmer"
LABEL origin="https://github.com/ChrisWiGit/lazarus-docker"
LABEL license="MIT"

# https://wiki.lazarus.freepascal.org/Cross_compiling_for_Windows_under_Linux
ENV FPC_FULLVERSION=3.2.2
ENV LAZARUSDIR=/lazarus
ENV FPCDIR=/fpc

ARG FPC_GIT_TAG=release_3_2_2
ARG FPC_BOOTSTRAP=http://downloads.sourceforge.net/project/lazarus/Lazarus%20Linux%20amd64%20DEB/Lazarus%202.2RC2/fpc-laz_3.2.2-210709_amd64.deb
ARG LAZARUS_BRANCH=main
# Install misc tools for development
RUN apt-get update && \ 
     apt-get install -y wget binutils gcc unzip git \
     # used for opengl lazopenglcontext
     libgl1-mesa-dev libgtk2.0-0 libgtk2.0-dev 
# \
# for docker image development
# psmisc mc

# Clone FPC Branch for compiling our own FPC on linux
# Our plan would be to create a cross platform compiler ppcrossx64 (win64) and ppcross386 (win32) but 
# these compilers do not support -WG (Specify graphic type application (Windows)) or any -Wx parameter. BUG?
# ppcross386 -WG
# Error: Illegal parameter: -WG
# This bug may hit when compiling lazarus IDE.
RUN mkdir $FPCDIR && \
     git clone https://github.com/fpc/FPCSource.git --branch $FPC_GIT_TAG $FPCDIR
# Clone latest lazarus
RUN mkdir $LAZARUSDIR && \
     git clone https://gitlab.com/freepascal.org/lazarus/lazarus.git --branch $LAZARUS_BRANCH $LAZARUSDIR

# Install latest FPC version that is known to work with building lazarus (or lazbuild).
RUN mkdir temp && cd temp && \ 
     wget $FPC_BOOTSTRAP && \
     dpkg -i `echo $(ls *.deb | head -n1)` 

# make Win64 FPC that is runnable from Linux (but still missing -WG)
RUN cd $FPCDIR && \
     make crossinstall OS_TARGET=win64 CPU_TARGET=x86_64 INSTALL_PREFIX=$FPCDIR/x86_64-win64 
# make Win32 FPC that is runnable from Linux (but still missing -WG)
RUN cd $FPCDIR && \
     make crossinstall OS_TARGET=win32 CPU_TARGET=i386 INSTALL_PREFIX=$FPCDIR/i386-win32
# make Linux FPC - make this last, otherwise units must be recompiled when building lazbuild
# https://www.getlazarus.org/setup/making/
RUN cd $FPCDIR && \
     make install OS_TARGET=linux CPU_TARGET=x86_64 INSTALL_PREFIX=$FPCDIR/x86_64-linux 

# remove FPC installed by debkg
RUN dpkg --remove fpc-laz

# This will link all compiled units from above into /fpc/units/[i386-win32 | x86_64-linux | x86_64-win64]
RUN mkdir $FPCDIR/units && \
     ln -sf $FPCDIR/x86_64-linux/lib/fpc/$FPC_FULLVERSION/units/x86_64-linux $FPCDIR/units/x86_64-linux && \
     ln -sf $FPCDIR/x86_64-win64/lib/fpc/$FPC_FULLVERSION/units/x86_64-win64 $FPCDIR/units/x86_64-win64 && \
     ln -sf $FPCDIR/i386-win32/lib/fpc/$FPC_FULLVERSION/units/i386-win32 $FPCDIR/units/i386-win32

# Create bin folder and link all binary files of FPC into their specific platform folders /fpc/bin/[i386-win32 | x86_64-linux | x86_64-win64]
# Also create links of the binaries to /usr/bin/
RUN mkdir $FPCDIR/bin && \
     mkdir $FPCDIR/bin/x86_64-linux && \
     ln -sf $FPCDIR/x86_64-linux/bin/* $FPCDIR/bin/x86_64-linux/ && \ 
     ln -sf $FPCDIR/x86_64-linux/lib/fpc/$FPC_FULLVERSION/ppcx64 $FPCDIR/bin/x86_64-linux/ppcx64 && \
     ln -sf $FPCDIR/bin/x86_64-linux/ppcx64 /usr/bin/ppcx64 && \
     ln -sf $FPCDIR/bin/x86_64-linux/fpc /usr/bin/fpc && \ 
     ln -sf $FPCDIR/bin/x86_64-linux/fpcmkcfg /usr/bin/fpcmkcfg && \ 
     mkdir $FPCDIR/bin/x86_64-win64 && \
     ln -sf $FPCDIR/x86_64-win64/lib/fpc/$FPC_FULLVERSION/ppcrossx64 $FPCDIR/bin/x86_64-win64/ppcrossx64 && \
     ln -sf $FPCDIR/bin/x86_64-win64/ppcrossx64 /usr/bin/ppcrossx64 && \
     # the res compiler of linux can be used for win64
     ln -sf $FPCDIR/bin/x86_64-linux/fpcres /usr/bin/x86_64-win64-fpcres && \
     mkdir $FPCDIR/bin/i386-win32 && \ 
     ln -sf $FPCDIR/i386-win32/lib/fpc/$FPC_FULLVERSION/ppcross386 $FPCDIR/bin/i386-win32/ppcross386 && \
     ln -sf $FPCDIR/bin/i386-win32/ppcross386 /usr/bin/ppcross386 && \
     # the res compiler of linux can be used for win32
     ln -sf $FPCDIR/bin/x86_64-linux/fpcres /usr/bin/i386-win32-fpcres

# Set unit path relative to /fpc and make it globally known to future fpc calls
RUN fpcmkcfg -d basepath=$FPCDIR -o /etc/fpc.cfg    

# create lazbuild only
#  otherwise lazarus IDE will be build that fails with cross-compiler (-WG illegal parameter)
# https://wiki.freepascal.org/lazbuild
RUN cd $LAZARUSDIR && \
     make lazbuild OS_TARGET=linux CPU_TARGET=x86_64
# Cross compilations of lazbuild if ncessary
# RUN make lazbuild OS_TARGET=win64 CPU_TARGET=x86_64 && mv lazbuild.exe lazbuild64.exe && \
#      make lazbuild OS_TARGET=win32 CPU_TARGET=i386 && mv lazbuild.exe lazbuild32.exe

# # add here additional libraries to be used
# # We don't --buid-ide= because this is not necessary for just compiling, and Lazarus compiles with parameter -WG that is not supported with cross compiler (BUG?)

# Use improved forked version of LNET
RUN  echo "git clone https://github.com/PascalCorpsman/lnet.git /lnet && \
     cd $LAZARUSDIR && ./lazbuild --add-package /lnet/lazaruspackage/lnetvisual.lpk --primary-config-path=$LAZARUSDIR --lazarusdir=$LAZARUSDIR" > /install_corpsman_lnet.sh

# Original Version of LNET
RUN  echo "wget https://packages.lazarus-ide.org/LNet.zip && unzip LNet.zip && rm LNet.zip && \
     cd $LAZARUSDIR && ./lazbuild --add-package ../../lnet/lazaruspackage/lnetvisual.lpk --primary-config-path=$LAZARUSDIR --lazarusdir=$LAZARUSDIR" > /install_original_lnet.sh

RUN chmod o+x /install_*_lnet.sh

RUN  cd $LAZARUSDIR && ./lazbuild --add-package components/opengl/lazopenglcontext.lpk --primary-config-path=$LAZARUSDIR --lazarusdir=$LAZARUSDIR && \
     cd $LAZARUSDIR && ./lazbuild --add-package components/tachart/tachartlazaruspkg.lpk --primary-config-path=$LAZARUSDIR --lazarusdir=$LAZARUSDIR

# make some aliases: lazbuildl64 for linux, lazbuildw32 for win32 and lazbuildw64 for win64
RUN echo "$LAZARUSDIR/lazbuild --os=linux --cpu=x86_64 --primary-config-path=$LAZARUSDIR --lazarusdir=$LAZARUSDIR --compiler=/usr/bin/ppcx64 \$*" > /usr/bin/lazbuildl64 && \
     echo "$LAZARUSDIR/lazbuild --os=win32 --cpu=i386 --primary-config-path=$LAZARUSDIR --lazarusdir=$LAZARUSDIR --compiler=/usr/bin/ppcross386 --widgetset=win32 \$*" > /usr/bin/lazbuildw32 && \
     echo "$LAZARUSDIR/lazbuild --os=win64 --cpu=x86_64 --primary-config-path=$LAZARUSDIR --lazarusdir=$LAZARUSDIR --compiler=/usr/bin/ppcrossx64 --widgetset=win32 \$*" > /usr/bin/lazbuildw64 && \
     echo "printf \"Use lazbuildXX with l64 for Linux and w32,w64 for Windows\n\"" > /usr/bin/lazbuild && \
     chmod 777 /usr/bin/lazbuild*

# CLEANUP
RUN rm /temp/fpc-laz_3.2.2-210709_amd64.deb && \
     rm -rf /var/lib/apt/lists/*
