
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
