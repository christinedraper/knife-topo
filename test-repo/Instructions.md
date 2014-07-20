##Setup

Assumptions for this demo: chefDK, Vagrant, VirtualBox and chef-zero

* [chefDK](http://www.getchef.com/downloads/chef-dk/)

* [Vagrant](https://www.vagrantup.com/downloads.html)

* [VirtualBox](https://www.virtualbox.org/wiki/Downloads)

If you have chefDK installed, you can use the embedded chef-zero  at 
/opt/chefdk/embedded/bin/chef-zero

or install it:

	sudo gem install chef-zero

Copy `test-repo` into a working directory, either downloading it from 
github or copying it from the installed knife-topo gem. You can use:

	gem env

to get the path to your gems and then

```
  cp -R <gem-path>/gems/knife-topo/test-repo ~
  cd ~/test-repo
```

## Demo 

This demo will create and bootstrap two nodes in a topology called test1:

* an application server with a specific version of nodejs (0.10.28), running
a test application
* a database server with a specific version of  mongodb (2.6.1)

Each node in the topology will be tagged with 'testsys' and will 
have an 'owner' and 'node_type' normal attribute.
 
The test1 topology will also contain a third node called buildserver01, 
which is created but not bootstrapped. This node:

* Is in a different chef environment ('dev')
* Requires a different version of mongodb
 
In this demo

### Running the demo

From the test-repo, do the following.  Note: you may be prompted to select the network to bridge to

	vagrant up 

This will start the virtual machines on a 
private network using vagrant. Once the virtual machines are created, 
start chef-zero listening on the same private network:

	chef-zero -H 10.0.1.1

In another terminal, in test-repo:

```
	berks install
	berks upload
```

To create and bootstrap the test1 topology:

```
	knife topo import topology.json
	knife topo create test1 --bootstrap -x vagrant -P vagrant --sudo
```

To check the bootstrap has succeeded, browse to: 
[http://localhost:3031](http://localhost:3031).
You should see a "Welcome" message.

You can see the results on the Chef server
using standard knife commands, for example:

```
  knife node list
  knife node show appserver01
  knife node show appserver01 -a normal
  knife data bag show topologies test1
```
  
You can try your own modifications to the topologies.json file. To
update the topology with the modified configuration:

```
  knife topo import your_topology.json
  knife topo update test1
```  


####Troubleshooting

If you are having trouble with berks (`read server certificate B: 
certificate verify failed (Faraday::SSLError)`
try following the instructions 
[here](https://gist.github.com/fnichol/867550#the-manual-way-boring) 
to add CA certificates for OpenSSL

If the bootstrap fails with 'ERROR: 412 "Precondition Failed"', make sure
you have run `berks upload` since you started chef-zero.

I encountered some problems getting chef-zero to run on a private network
on Windows 8.1 (it responded really really slowly). 
If you have similar problems, you can use hosted Chef
(sign up for a free account [here](https://manage.opscode.com/signup))
or your own Chef server. Copy your knife settings and certificates (e.g.,
the contents of chef-repo/.chef in the "Getting Started" download) into
test-repo/.chef, and replace the Vagrantfile in test-repo with 
Vagrantfile_bridged (which will allow the VMs to connect to addresses 
outside of the host).

If you modify the cookbook_attributes for mongodb and this causes
a downgrade, the Chef run may fail to converge. 
There is an [issue](https://github.com/edelight/chef-mongodb/pull/305) 
in the current cookbook which has been fixed but
not released (as of 19 July 2014). Run the following to remove the
installed mongodb and then retry the knife topo bootstrap:

  vagrant ssh dbserver -c 'sudo apt-get remove mongodb'

If you have changed the nodejs version, you need to also change the
SHA256 checksum. This can be found at
http://nodejs.org/dist/v0.xx.xx/SHASUMS256.txt. The one you want is
for 'node-v0.xx.xx-linux-x64.tar.gz'
