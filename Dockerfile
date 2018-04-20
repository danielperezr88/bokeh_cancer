FROM danielperezr88/debian:jessie

MAINTAINER danielperezr88 <danielperezr88@gmail.com>

# Install curl
RUN apt-get update && apt-get install -y curl

# Install Tini
# In order to secure this download by checksum checking, on second line, we could add:
#	echo "<checksum> *tini" | sha256sum -c - && \
RUN curl -L https://github.com/krallin/tini/releases/download/v0.6.0/tini > tini && \
    mv tini /usr/local/bin/tini && \
    chmod +x /usr/local/bin/tini

# remove several traces of debian python
RUN apt-get purge -y python.*

# http://bugs.python.org/issue19846
# > At the moment, setting "LANG=C" on a Linux system *fundamentally breaks Python 3*, and that's not OK.
ENV LANG C.UTF-8

# gpg: key F73C700D: public key "Larry Hastings <larry@hastings.org>" imported
RUN gpg --keyserver ha.pool.sks-keyservers.net --recv-keys 97FC712E4C024BBEA48A61ED3A5CA953F73C700D

ENV PYTHON_VERSION 3.4.3

# if this is called "PIP_VERSION", pip explodes with "ValueError: invalid truth value '<VERSION>'"
ENV PYTHON_PIP_VERSION 7.0.3

# Install XZ-Utils
RUN apt-get update && apt-get install -y xz-utils

# Install Zlib
RUN apt-get update && apt-get install -y zlib1g-dev

# Install C/C++ Compilers
RUN apt-get update && apt-get install -y \
		g++ \
		gcc \
		make

RUN apt-get update && apt-get install -y \
	libbz2-dev \
	libssl-dev \
	libmysqlclient-dev \
	libsqlite3-dev

RUN set -x \
	&& mkdir -p /usr/src/python \
	&& curl -SL "https://www.python.org/ftp/python/$PYTHON_VERSION/Python-$PYTHON_VERSION.tar.xz" -o python.tar.xz \
	&& curl -SL "https://www.python.org/ftp/python/$PYTHON_VERSION/Python-$PYTHON_VERSION.tar.xz.asc" -o python.tar.xz.asc \
	&& gpg --verify python.tar.xz.asc \
	&& tar -xJC /usr/src/python --strip-components=1 -f python.tar.xz \
	&& rm python.tar.xz* \
	&& cd /usr/src/python \
	&& ./configure --enable-shared --enable-unicode=ucs4 \
	&& make -j$(nproc) \
	&& make install \
	&& ldconfig \
	&& curl -SL 'https://bootstrap.pypa.io/get-pip.py' | python3 \
	&& pip3 install --no-cache-dir --upgrade pip==$PYTHON_PIP_VERSION \
	&& find /usr/local \
		\( -type d -a -name test -o -name tests \) \
		-o \( -type f -a -name '*.pyc' -o -name '*.pyo' \) \
		-exec rm -rf '{}' + \
	&& rm -rf /usr/src/python

# make some useful symlinks that are expected to exist
RUN cd /usr/local/bin \
	&& ln -s easy_install-3.4 easy_install \
	&& ln -s idle3 idle \
	&& ln -s pydoc3 pydoc \
	&& ln -s python3 python \
	&& ln -s python-config3 python-config

# Install "virtualenv", since the vast majority of users of this image will want itpip
RUN pip install --no-cache-dir virtualenv

# Install main python packages
RUN pip install --upgrade pip && \
	pip install mysqlclient && \
	pip install regex && \
	pip install numpy && \
	pip install pandas && \
	pip install requests && \
	pip install scipy && \
	pip install scikit-learn && \
	pip install jupyter && \
	pip install Flask && \
	pip install bokeh && \
	pip install Tornado-JSON && \
	pip install -U gcloud

RUN apt-get update && apt-get install -y \
    supervisor \
    git
RUN mkdir -p /var/log/supervisor

# Force pip2 installation and creation
RUN curl -SL 'https://bootstrap.pypa.io/get-pip.py' | python2 \
	&& pip2 install --no-cache-dir --upgrade pip==$PYTHON_PIP_VERSION \
	&& cd / \
	&& curl -fSL "https://gist.githubusercontent.com/danielperezr88/c3b7eb74c30d854f6db4b978a2f34582/raw/416a99ebddf210cf6f44173e79faeef98bfeb15d/pip_shebang_patch.txt" \
			-o /pip_shebang_patch.txt \
	&& patch -p1 < pip_shebang_patch.txt

RUN pip2 install supervisor && \
    pip2 install superlance==1.0.0

# Download bokeh_cancer
RUN curl -fSL "https://github.com/danielperezr88/bokeh_cancer/archive/v1.6.tar.gz" -o bokeh_cancer.tar.gz && \
	tar -xf bokeh_cancer.tar.gz -C . && \
	mkdir /app && \
	mv bokeh_cancer-1.6/* /app/ && \
	rm bokeh_cancer.tar.gz && \
	rm -rf bokeh_cancer-1.6 && \
	cp /app/supervisord.conf /etc/supervisor/conf.d/supervisord.conf && \
	rm /app/supervisord.conf
	
# Copy apache config files
#RUN cp /app/apache-proxy-conf-files/000-default.conf /etc/apache2/sites-available/000-default.conf && \
#	cp /app/apache-proxy-conf-files/ports.conf /etc/apache2/ports.conf && \
#	mkdir /var/log/apache2/bokeh

# Download some custom config Gists to be applied to bokeh
RUN curl -fSL "https://gist.githubusercontent.com/danielperezr88/de9ecf70dd556a33f70e728cf58a54aa/raw/afb87786fb104401d42b1b57c3b26955c3fbac19/mod-resources.py" > /usr/local/lib/python3.4/site-packages/bokeh/resources.py && \
	curl -fSL "https://gist.githubusercontent.com/danielperezr88/90cd99575274f542cdb40ed0566fd0b0/raw/8e6b7d6a5ae53074eb5394cc295f8caa15e5f42c/BokehAppIndexTemplate.html" > /usr/local/lib/python3.4/site-packages/bokeh/core/_templates/file.html
	
RUN curl -sSO https://dl.google.com/cloudagents/install-logging-agent.sh -o install-logging-agent.sh && \
	echo "07ca6e522885b9696013aaddde48bf2675429e57081c70080a9a1364a411b395  install-logging-agent.sh" | sha256sum -c -

EXPOSE 5006

WORKDIR /app

CMD ["/usr/bin/supervisord"]