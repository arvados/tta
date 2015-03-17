#/bin/bash
# Install dependencies
sudo apt-get install \
    bison build-essential gettext libcurl3 libcurl3-gnutls \
    libcurl4-openssl-dev libpcre3-dev libpq-dev libreadline-dev \
    libssl-dev libxslt1.1 postgresql git wget zlib1g-dev
### 1

## Install Ruby and Bundler
pushd $HOME
	mkdir -p src
	pushd src
		wget http://cache.ruby-lang.org/pub/ruby/2.1/ruby-2.1.5.tar.gz
		tar xzf ruby-2.1.5.tar.gz
		cd ruby-2.1.5
		./configure
		make
		sudo make install
		sudo gem install bundler
	popd
	rm -rf src/ruby-2.1.5
popd
git clone https://github.com/curoverse/arvados.git
### 2
