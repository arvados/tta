
# Install service API
pushd arvados/services/api
	bundle install
	cp -i config/environments/production.rb.example config/environments/production.rb
	cp -i config/application.yml.example config/application.yml
	sudo mkdir -p /var/lib/arvados/git
	sudo git clone --bare ../../.git /var/lib/arvados/git/arvados.git
	sed -i "s/secret_token.*$/secret_token: `rake secret`/g" config/application.yml
	sed -i "s/blob_signing_key.*$/blob_signing_key: `rake secret`/g" config/application.yml
	sed -i "s/https:\/\/workbench.*$/https:\/\/workbench.gamma.foo.com/g" config/application.yml
	sed -i "s/bogus/gamma/g" config/application.yml
	sed -n -l 1 's/\(^.*blob_signing_key: \)\(.*\)/\2/p' config/application.yml | uniq > keepstore.key

	echo "deb http://apt.arvados.org/ wheezy main" | sudo tee /etc/apt/sources.list.d/apt.arvados.org.list
 	sudo /usr/bin/apt-key adv --keyserver pool.sks-keyservers.net --recv 1078ECD7
 	sudo /usr/bin/apt-get update
 	sudo /usr/bin/apt-get install keepstore
	keepstore --permission-key-file=keepstore.key &
	
	prefix=`arv --format=uuid user current | cut -d- -f1`
	"Site prefix is '$prefix'"
	read -rd $'\000' keepservice <<EOF; arv keep_service create --keep-service "$keepservice"
		{
		 "service_host":"keep0.gamma.foo.com",
		 "service_port":25107,
		 "service_ssl_flag":false,
		 "service_type":"disk"
		}
	EOF
popd
	
### 3
pushd arvados/services/api
	ruby -e 'puts rand(2**128).to_s(36)'
	# d47b6bmmpmm5hceqwsda9at5x
	sudo -u postgres createuser --createdb --encrypted --pwprompt -R -S arvados
	cp -i config/database.yml.sample config/database.yml
	sed -i "s/xxxxxxxx/d47b6bmmpmm5hceqwsda9at5x/g" config/database.yml
	RAILS_ENV=production bundle exec rake db:setup
	sudo su postgres
	createdb arvados_production -E UTF8 -O arvados
	createdb arvados_development -E UTF8 -O arvados
	exit
	RAILS_ENV=production bundle exec rake db:structure:load	
	RAILS_ENV=production bundle exec rake db:seed
	RAILS_ENV=development bundle exec rake db:structure:load	
	RAILS_ENV=development bundle exec rake db:seed

	cp -i config/initializers/omniauth.rb.example config/initializers/omniauth.rb
	sed -i "s/^\(APP_SECRET = \)\(.*$\)/\1'`ruby -e 'puts rand(2**512).to_s(36)'`'/g" config/initializers/omniauth.rb
	bundle exec rails server --port=3030
popd

## Install Phusion
	sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 561F9B9CAC40B2F7
	sudo apt-get install apt-transport-https ca-certificates
	echo "deb https://oss-binaries.phusionpassenger.com/apt/passenger wheezy main" | sudo tee /etc/apt/sources.list.d/passenger.list
	sudo apt-get update
	sudo apt-get install nginx-extras passenger
	# Edit /etc/nginx/nginx.conf and uncomment passenger_root and passenger_ruby.
popd

## Install workbench
pushd arvados/apps/workbench
	bundle install
	sudo apt-get install \
    bison build-essential gettext libcurl3 libcurl3-gnutls \
    libcurl4-openssl-dev libpcre3-dev libpq-dev libreadline-dev \
    libssl-dev libxslt1.1 sudo wget zlib1g-dev graphviz \
    libsqlite3-dev
    
	cp -i config/environments/production.rb.example config/environments/production.rb
	cp -i config/application.yml.example config/application.yml
	pushd ~/arvados/services/api
	sed -i "s/secret_token.*$/secret_token: `bundle exec rake secret`/g" ~/arvados/apps/workbench/config/application.yml
	popd
	
	# set these
	arvados_login_base: https://prefix_uuid.your.domain/login
	arvados_v1_base: https://prefix_uuid.your.domain/arvados/v1
	
popd

## Install SSO
pushd $HOME
	git clone https://github.com/curoverse/sso-devise-omniauth-provider.git
	pushd sso-devise-omniauth-provider
		bundle install
		RAILS_ENV=production bundle exec rake db:create
		RAILS_ENV=production bundle exec rake db:migrate
		RAILS_ENV=development bundle exec rake db:create
		RAILS_ENV=development bundle exec rake db:migrate
		cp -i config/initializers/secret_token.rb.example config/initializers/secret_token.rb
		sed -i "s/^\(.*secret_token = \).*/\1'`bundle exec rake secret`'/g" config/initializers/secret_token.rb
# review http://doc.arvados.org/install/install-sso.html
# https://console.developers.google.com/project/foo-arvados/apiui/credential#
		cp -i config/environments/production.rb.example config/environments/production.rb
		cp -i config/environments/production.rb config/environments/development.rb
		openssl req -nodes -newkey rsa:2048 -keyout foo.key -x509 -days 3650 -out foo.cer
		
		# RAILS_ENV=production bundle exec rails console
		RAILS_ENV=production bundle exec rails console
	popd
popd

unset ARVADOS_API_HOST_INSECURE
export ARVADOS_API_HOST=localhost:3030
export ARVADOS_API_HOST_INSECURE=1
export ARVADOS_API_TOKEN=3baqay8azvan45u7gpduetzd8g1dml8n17sp7znn4ij3dblq39
prefix=`arv --format=uuid user current | cut -d- -f1` && echo "Site prefix is '$prefix'"
read -rd $'\000' keepservice <<EOF; arv keep_service create --keep-service "$keepservice"
{
 "service_host":"keep0.gamma.foo.com",
 "service_port":25107,
 "service_ssl_flag":false,
 "service_type":"disk"
}
EOF


export ARVADOS_API_HOST=workbench.gamma.foo.com
export ARVADOS_API_TOKEN=3baqay8azvan45u7gpduetzd8g1dml8n17sp7znn4ij3dblq39
export ARVADOS_API_HOST=workbench.gamma.foo.com:3030
export ARVADOS_API_HOST_INSECURE=1

read -rd $'\000' keepservice <<EOF; arv keep_service create --keep-service "$keepservice"
{
 "service_host":"workbench.gamma.foo.com",
 "service_port":443,
 "service_ssl_flag":true,
 "service_type":"proxy"
}
EOF

echo "deb http://apt.arvados.org/ wheezy main" | sudo tee /etc/apt/sources.list.d/apt.arvados.org.list
sudo /usr/bin/apt-get install keepproxy

export ARVADOS_API_HOST=workbench.gamma.foo.com
export ARVADOS_API_TOKEN=3baqay8azvan45u7gpduetzd8g1dml8n17sp7znn4ij3dblq39
export ARVADOS_API_HOST=workbench.gamma.foo.com:3030
export ARVADOS_API_HOST_INSECURE=1

read -rd $'\000' newjob <<EOF; arv job create --job "$newjob"
{"script_parameters":{"input":"a7f932428b30582f54ea26084813eb7b3e8f3251"},
 "script_version":"master",
 "script":"hash",
 "repository":"arvados"}
EOF

sudo apt-get install libjson-perl libio-socket-ssl-perl libwww-perl libipc-system-simple-perl
cd ~/arvados/sdk/perl
perl Makefile.PL
sudo make install
sudo apt-get install libnet-ssleay-perl
sudo apt-get install libcrypt-ssleay-perl
perl -MArvados -e ''

perl <<'EOF'
use Arvados;
my $arv = Arvados->new('apiVersion' => 'v1');
my $me = $arv->{'users'}->{'current'}->execute;
print ("arvados.v1.users.current.full_name = '", $me->{'full_name'}, "'\n");
EOF

sudo apt-get install python-pip python-dev libattr1-dev libfuse-dev pkg-config python-yaml
sudo pip install arvados-python-client
pip install --upgrade pyvcf
adduser crunch