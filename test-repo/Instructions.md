##Setup

This example assumes you have chefDK, Vagrant, VirtualBox and chef-zero.
You can download the first three from the following links:

* [chefDK](https://downloads.chef.io/chef-dk/)

* [Vagrant](https://www.vagrantup.com/downloads.html)

* [VirtualBox](https://www.virtualbox.org/wiki/Downloads)

chefDK provides chef-zero. As long as you have followed the instructions
to [add the embedded chefDK binaries to your path](https://docs.chef.io/install_dk.html#add-ruby-to-path), 
you should be able to run it using `chef-zero`. 

To obtain the sample test-repo, 
[download the latest knife-topo release](http://github.com/christinedraper/knife-topo/releases/latest)
and unzip it, e.g.

```
unzip knife-topo-2.0.1.zip -d ~
cd ~/knife-topo-2.0.1/test-repo
```


## Example

This example will create and bootstrap two nodes in a topology called test1,
and configure them with specific versions of software:

* an application server with version of nodejs (0.10.40), running
a test application
* a database server with version of  mongodb (2.6.1)

Both nodes in the topology will be tagged with 'testsys' and will 
have an 'owner' attribute, and will be in the 'test' chef environment.
 
The test1 topology will also defines a third node called buildserver01, 
which is not bootstrapped. This node is included to illustrate 
defining a node that:

* Is in a different chef environment compared to other nodes
* Requires a different version of software (mongodb) compared to other nodes
 

### Instructions

From the test-repo, do the following.  Note: you may be prompted to 
select the network to bridge to.

```
cd ~/knife-topo-2.0.1/test-repo
vagrant up 
```

You will see Vagrant messages about bootstrapping two machines (dbserver
and appserver), ending with something like:

```
==> appserver: Setting hostname...
==> appserver: Configuring and enabling network interfaces...
==> appserver: Mounting shared folders...
    appserver: /vagrant => /home/christine/knife-topo-2.0.1/test-repo
```

This starts the virtual machines on a 
private network using vagrant. Once the virtual machines are created, 
start chef-zero listening on the same private network, e.g.:

  chef-zero -H 10.0.1.1
  
You should see something like:

```
>> Starting Chef Zero (v4.3.2)...
>> WEBrick (v1.3.1) on Rack (v1.6.4) is listening at http://10.0.1.1:8889
>> Press CTRL+C to stop
```

In another terminal, in test-repo:

```
cd ~/knife-topo-2.0.1/test-repo
berks install
berks upload
```

You should see messages such as:

```
Fetching 'testapp' from source at cookbooks/testapp
Fetching cookbook index from https://api.berkshelf.com...
... more messages...
Uploaded yum (3.8.2) to: 'http://10.0.1.1:8889/'
Uploaded yum-epel (0.6.5) to: 'http://10.0.1.1:8889/'
```

To import the topology json file into your workspace:

```
  knife topo import test1.json
```

You should see output like:

```
** Creating cookbook topo_test1 in in /home/christine/knife-topo-2.0.1/test-repo/cookbooks
** Creating README for cookbook: topo_test1
** Creating CHANGELOG for cookbook: topo_test1
** Creating metadata for cookbook: topo_test1
** Creating attribute file: topology
Import finished
```

The `knife topo import` command has created a topology data bag and cookbook 
in your local workspace. To see these files:

```
  cat data_bags/topologies/test1.json
```

will show you the data bag item for topology test1 and

```
  cat cookbooks/topo_test1/attributes/topology.rb
```

will show you the generated topology cookbook attributes.

To create and bootstrap the test1 topology:

```
  knife topo create test1 --bootstrap -x vagrant -P vagrant --sudo
```

You should see output like:

```
Created topology data bag [topologies]
Creating chef environment test
Uploading topo_test1  [0.1.0]
Uploaded 1 cookbook.
Bootstrapping node appserver01
... messages from knife bootstrap...
Bootstrapping node dbserver01
... more messages from knife bootstrap...
10.0.1.2 Chef Client finished, 20 resources updated
Bootstrapped 2 nodes [ appserver01, dbserver01 ]
Did not bootstrap 1 nodes [ buildserver01 ] because they do not have an ssh_host
Topology: test1
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
```

You can use the knife topo list and search commands:

```
knife topo list
knife topo search --topo=test1
```
  
You can also try your own modifications to the topology json file. To
update the topology with the modified configuration:

```
knife topo import your_test1.json
knife topo update test1
```  


####Troubleshooting the example

If you are having trouble with berks (`read server certificate B: 
certificate verify failed (Faraday::SSLError)`
try following the instructions 
[here](https://gist.github.com/fnichol/867550#the-manual-way-boring) 
to add CA certificates for OpenSSL

If `knife topo create` fails with 'ERROR: 412 "Precondition Failed"', make sure
you have run `berks upload` since you started chef-zero.

If `knife topo create` fails with:
```
WARNING: bootstrap of node appserver01 exited with error
ERROR: Net::SSH::HostKeyMismatch: fingerprint fc:d2:14:8f:5b:21:1e:37:ef:85:bd:fd:fe:e4:ba:91 does not match for "10.0.1.3"
```
It is probably because you have destroyed and recreated the Vagrant
machines, and a new SSH key has been recreated. Delete the entries for
10.0.1.2 and 10.0.1.3 in ~/.ssh/known_hosts and try again.

I encountered some problems getting chef-zero to run on a private network
on Windows 8.1 (it responded really really slowly). 
If you have similar problems, you can use hosted Chef
(sign up for a free account [here](https://manage.chef.io/signup))
or your own Chef server. Copy your knife settings and certificates (e.g.,
the contents of chef-repo/.chef in the "Getting Started" download) into
test-repo/.chef, and replace the Vagrantfile in test-repo with 
Vagrantfile_bridged (which will allow the VMs to connect to addresses 
outside of the host).

If you modify the cookbook_attributes for mongodb and this causes
a downgrade, the Chef run may fail to converge. 
Run the following to remove the installed mongodb and then retry the 
knife topo bootstrap:

```
  vagrant ssh dbserver -c 'sudo apt-get remove mongodb'
```

If you have changed the nodejs version, you need to also change the
SHA256 checksum. This can be found at
http://nodejs.org/dist/v0.xx.xx/SHASUMS256.txt. The one you want is
for 'node-v0.xx.xx-linux-x64.tar.gz'
