# lazarus-docker

Provides a docker file with built FPC and Lazarus sources from Github.

This docker file build FreePascal and Lazarus from their sources. Freepascal 3.2.2 is compiled from git tag 3.2.2 for Linux 64bit, Windows 32 and 64 bit (crosscompilations). Lazarus (lazbuild) is compiled from git main branch also for Linux 64bit, Windows 32 and 64 bit.

* FreePascal 3.2.2
* Lazarus main branch

> The dockerfile is not available from dockerhub!

## Building the image

You can use the following commands to build the image

```sh
docker build . -t lazarus-base
yarn make
npm run make
```

## Run the image with terminal

In this way you can checkout the image first.

```sh
docker run -it lazarus-base /bin/bash
yarn it
npm run it
```

## Using the image

```dockerfile
FROM lazarus-base
RUN mkdir /build
RUN mkdir /project && git clone https://example.com/project
COPY runenv.sh /runenv.sh
RUN chmod 777 /runenv.sh
CMD /runenv.sh
```

For example you can use lazbuild for all OS targets. These are convenient scripts to build.

* `lazbuildl64` for Linux 64bit
* `lazbuildw32` for Windows 32bit
* `lazbuildw64` for Windows 64bit

### runenv.sh

```sh
#!/bin/bash
cd /project
git pull  #update sources since image build
lazbuildl64 myproject.lpr && mkdir -p /build/linux64/ && mv myproject /build/linux64/
lazbuildw32 myproject.lpr && mkdir -p /build/win32/ && mv myproject.exe /build/win32/
lazbuildw64 myproject.lpr && mkdir -p /build/win64/ && mv myproject.exe /build/win64/
```

### Access build directory

You can run your image, compile your project and receive all your built files with this chain of commands:

```sh
rm -rf ./dest_build
docker run --name <your_docker_conainer_name> <your_image>
docker cp <your_docker_conainer_name>:/build ./dest_build
docker container rm <your_docker_conainer_name>
```

## Adding packages

You can add packages that are used by your project in the following way. Third party packages need to be downloaded first.

> Packages of the Lazarus Online Package Manager can be downloaded from <https://packages.lazarus-ide.org>
> You do not need to call `lazbuild --build-ide=` because the IDE is not used.

```sh
# Third party
cd $LAZARUSDIR && ./lazbuild --add-package ../../lnet/lazaruspackage/lnetvisual.lpk --primary-config-path=$LAZARUSDIR --lazarusdir=$LAZARUSDIR

# Standard components
cd $LAZARUSDIR && ./lazbuild --add-package components/opengl/lazopenglcontext.lpk --primary-config-path=$LAZARUSDIR --lazarusdir=$LAZARUSDIR

cd $LAZARUSDIR && ./lazbuild --add-package components/tachart/tachartlazaruspkg.lpk --primary-config-path=$LAZARUSDIR --lazarusdir=$LAZARUSDIR
```

### Dockerfile example

```dockerfile
RUN wget https://packages.lazarus-ide.org/LNet.zip && unzip LNet.zip && rm LNet.zip && \
     cd $LAZARUSDIR && ./lazbuild --add-package ../../lnet/lazaruspackage/lnetvisual.lpk --primary-config-path=$LAZARUSDIR --lazarusdir=$LAZARUSDIR && \
     cd $LAZARUSDIR && ./lazbuild --add-package components/opengl/lazopenglcontext.lpk --primary-config-path=$LAZARUSDIR --lazarusdir=$LAZARUSDIR && \
     cd $LAZARUSDIR && ./lazbuild --add-package components/tachart/tachartlazaruspkg.lpk --primary-config-path=$LAZARUSDIR --lazarusdir=$LAZARUSDIR
```

## lazbuild commands

```sh
$LAZARUSDIR/lazbuild --os=win64 --cpu=x86_64 --primary-config-path=$LAZARUSDIR --lazarusdir=$LAZARUSDIR <lpr file>
$LAZARUSDIR/lazbuild --os=win32 --cpu=i386 --primary-config-path=$LAZARUSDIR --lazarusdir=$LAZARUSDIR <lpr file>
$LAZARUSDIR/lazbuild --os=linux --cpu=x86_64 --primary-config-path=$LAZARUSDIR --lazarusdir=$LAZARUSDIR <lpr file>
```

## Documentation

* <https://www.freepascal.org/>
* <https://wiki.freepascal.org/lazbuild>
* <https://www.getlazarus.org/setup/making/>
* <https://packages.lazarus-ide.org>
* <https://wiki.freepascal.org/Cross_compiling_for_Windows_under_Linux>
* <https://github.com/fpc/FPCSource>
* <https://github.com/fpc/Lazarus>
