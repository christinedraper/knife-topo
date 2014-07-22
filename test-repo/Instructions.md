##Setup

Assumptions for this demo: chefDK, Vagrant, VirtualBox and chef-zero

* [chefDK](http://www.getchef.com/downloads/chef-dk/)

* [Vagrant](https://www.vagrantup.com/downloads.html)

* [VirtualBox](https://www.virtualbox.org/wiki/Downloads)

If you have chefDK installed, you can use the embedded chef-zero  at 
`/opt/chefdk/embedded/bin/chef-zero`

or install standalone chef-zero:

	sudo gem install chef-zero


To obtain the test-repo, [download the latest knife-topo release](http://github.com/christinedraper/knife-topo/releases/latest)
and unzip it, e.g.

```
unzip knife-topo-0.0.6.zip -d ~
cd ~/knife-topo-0.0.6/test-repo
```


## Demo 

This demo will create and bootstrap two nodes in a topology called test1,
and configure them with specific versions of software:

* an application server with version of nodejs (0.10.28), running
a test application
* a database server with version of  mongodb (2.6.1)

Each node in the topology will be tagged with 'testsys' and will 
have an 'owner' and 'node_type' normal attribute.
 
The test1 topology will also defines a third node called buildserver01, 
which is not bootstrapped. This node is included to illustrate 
defining a node that:

* Is in a different chef environment compared to other nodes
* Requires a different version of software (mongodb) compared to other nodes
 

### Running the demo

From the test-repo, do the following.  Note: you may be prompted to 
select the network to bridge to.

```
cd ~/knife-topo-0.0.6/test-repo
vagrant up 
```

You will see Vagrant messages about bootstrapping two machines (dbserver
and appserver), ending with something like:

```
==> appserver: Setting hostname...
==> appserver: Configuring and enabling network interfaces...
==> appserver: Mounting shared folders...
    appserver: /vagrant => /home/christine/knife-topo-0.0.6/test-repo
```

This starts the virtual machines on a 
private network using vagrant. Once the virtual machines are created, 
start chef-zero listening on the same private network, e.g.:

  /opt/chefdk/embedded/bin/chef-zero -H 10.0.1.1
  
You should see something like:

```
>> Starting Chef Zero (v2.2)...
>> WEBrick (v1.3.1) on Rack (v1.5) is listening at http://127.0.0.1:8889
>> Press CTRL+C to stop
```

In another terminal, in test-repo:

```
cd ~/knife-topo-0.0.6/test-repo
berks install
berks upload
```

You should see messages such as:

```
Fetching 'testapp' from source at cookbooks/testapp
Fetching cookbook index from https://api.berkshelf.com...
... more messages...
Uploaded yum (3.2.2) to: 'http://10.0.1.1:8889/'
Uploaded yum-epel (0.3.6) to: 'http://10.0.1.1:8889/'
```

To import the topology.json file into your workspace:

  knife topo import 
  
You should see output like:

```
** Creating cookbook testsys_test1
** Creating README for cookbook: testsys_test1
** Creating CHANGELOG for cookbook: testsys_test1
** Creating metadata for cookbook: testsys_test1
** Creating attribute file softwareversion.rb
Import finished
```

The \knife topo import` command has created a topology data bag and cookbook 
in your local workspace. To see these files:

  cat data_bags/topologies/test1.json
  
will show you the data bag item for topology test1 and

  cat cookbooks/testsys_test1/attributes/softwareversion.rb

will show you the generated topology cookbook attributes.

To create and bootstrap the test1 topology:

  knife topo create test1 --bootstrap -x vagrant -P vagrant --sudo

You should see output like:

```
Created topology data bag [topologies]
Creating chef environment test
Uploading testsys_test1  [0.1.0]
Uploaded 1 cookbook.
Bootstrapping node appserver01
... messages from knife bootstrap...
Bootstrapping node dbserver01
... more messages from knife bootstrap...
 Chef Client finished, 18/23 resources updated in 260.75631942 seconds
Node buildserver01 does not have ssh_host specified - skipping bootstrap
Bootstrapped 2 nodes and skipped 1 nodes of 3 in topology topologies/test1
Topology created
```

To confirm that the bootstrap has succeeded, browse to: 
[http://localhost:3031](http://localhost:3031).
You should see a "Congratulations" message.

You can see the results of the plugin on the Chef server using 
standard knife commands, for example:

```
knife node list
knife node show appserver01
knife node show appserver01 -a normal
knife data bag show topologies test1
```
  
You can also try your own modifications to the topologies.json file. To
update the topology with the modified configuration:

```
knife topo import your_topology.json
knife topo update test1
```  


####Troubleshooting the demo

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
