FROM mcr.microsoft.com/dotnet/core/aspnet:3.1-buster-slim

#Install dependencies used by gdal and ora2pg
RUN apt-get update && apt-get install -y -q --no-install-recommends \
    libc-bin unzip ca-certificates libaio1 wget libtiff-dev libcurl4-openssl-dev \
    #Package manager for installing Oracle
    alien \
    # Install postgresql
    postgresql-client \
    # Used for the POSTGRES_HOME variable
    libpq-dev \
    #Package manager used for installation of perl database drivers
    cpanminus \
    # Proj build
    libsqlite3-dev sqlite3 pkg-config g++ make \
    unzip

#Setup PROJ
WORKDIR /opt
ENV PROJ_VERSION 7.1.1
RUN wget https://download.osgeo.org/proj/proj-${PROJ_VERSION}.tar.gz && \
    tar -zxf proj-*.tar.gz && \
    rm *.tar.gz
WORKDIR /opt/proj-${PROJ_VERSION}
RUN ./configure --prefix=/usr --disable-static --enable-lto
RUN make && make install

#Install Oracle
WORKDIR /opt
RUN wget https://download.oracle.com/otn_software/linux/instantclient/213000/oracle-instantclient-basic-21.3.0.0.0-1.x86_64.rpm && \
    wget https://download.oracle.com/otn_software/linux/instantclient/213000/oracle-instantclient-sqlplus-21.3.0.0.0-1.x86_64.rpm &&  \
    wget https://download.oracle.com/otn_software/linux/instantclient/213000/oracle-instantclient-devel-21.3.0.0.0-1.x86_64.rpm
RUN alien -i oracle-instantclient-basic-21.3.0.0.0-1.x86_64.rpm && \
    alien -i oracle-instantclient-sqlplus-21.3.0.0.0-1.x86_64.rpm && \ 
    alien -i oracle-instantclient-devel-21.3.0.0.0-1.x86_64.rpm && \
    rm *.rpm

#Fix SDK folder 
RUN wget https://download.oracle.com/otn_software/linux/instantclient/213000/instantclient-sdk-linux.x64-21.3.0.0.0.zip
RUN unzip instantclient-sdk-linux.x64-21.3.0.0.0.zip -d /tmp/ && mv /tmp/instantclient_21_3/sdk /usr/lib/oracle/21/client64 && rm -r /tmp/instantclient_21_3 && rm *.zip

#Setup oracle variables
ENV LD_LIBRARY_PATH=/usr/local/lib:/usr/lib/oracle/21/client64/lib/${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
ENV ORACLE_HOME=/usr/lib/oracle/21/client64
RUN ln -s /usr/include/oracle/21/client64 $ORACLE_HOME/include
ENV PATH=$PATH:$ORACLE_HOME/bin
RUN ldconfig

#Setup SQLite variables
ENV SQLITE3_INCLUDE_DIR=/usr/include/
ENV SQLITE3_LIBRARY=/usr/lib/x86_64-linux-gnu/

#Install Postgres en Oracle drivers for perl, ora2pg  
RUN cpanm DBD::Oracle && cpanm DBD::Pg

#Setup gdal
ENV GDAL_VERSION 3.2.2
WORKDIR /opt
RUN wget https://github.com/OSGeo/gdal/archive/refs/tags/v${GDAL_VERSION}.tar.gz && \ 
    tar -xzf v${GDAL_VERSION}.tar.gz && \
    rm *.tar.gz
WORKDIR /opt/gdal-${GDAL_VERSION}/gdal
RUN ./configure --with-oci=yes --with-oci-lib=${ORACLE_HOME}/lib --with-oci-include=${ORACLE_HOME}/sdk/include --with-pg=yes
RUN make && make install

# small fixes
RUN ln -s /usr/lib/libgdal.so /usr/lib/libgdal.so.1 && /sbin/ldconfig
