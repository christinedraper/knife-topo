knife topo
==========

This Chef Knife plugin allows you to create and update topologies 
consisting of multiple nodes. You may find it useful if you are 
regularly updating a system consisting of multiple nodes, and would
like to manage its dynamic configuration (like software versions) 
through a single (json) configuration file. It may also be useful
if you are regularly bringing up multi-node systems with similar 
topologies but differences in their configuration details.

# Installation #

Copy the contents of lib/chef/knife into your plugin directory, e.g.:

	$ mkdir -p ~/.chef/knife/plugins
	$ cp lib/chef/knife/* ~/.chef/knife/plugins

or install knife-topo as a gem

    $ sudo gem install knife-topo

This plugin has been tested with Chef Version 11.12 on Ubuntu 14.04 LTS.

# Usage #

Define one or more topologies in a [topology file](#markdown-header-topology-file). 

Import the topology file into your local chef repo using
[knife topo import](#markdown-header-knife-topo-import). Create and optionally
bootstrap a topology on the Chef server using 
[knife topo create](#markdown-header-knife-topo-create), and update it
using [knife topo update](#markdown-header-knife-topo-update).

# Getting Started #

Try out this plugin using a [test repo](knife-topo/src/master/test-repo) 
which you can download from Github or is included in the installed gem. See the 
[Instructions](knife-topo/src/master/test-repo/Instructions.md) for a
demo script, explanation, and troubleshooting.

The instructions assume you have
 [chefDK](http://www.getchef.com/downloads/chef-dk/)
 or equivalent installed and working with Vagrant and VirtualBox, but
 none of these are requirements for this plugin. 

# Topology File #

See the [example topology file](knife-topo/src/master/test-repo/topology.json)

The topology file contains a single topology, or an array of topologies.
Each topology has some overall properties, an array of nodes and 
an array defining topology cookbook attributes.

## Overall Properties

```json
    {
        "name": "test1",
        "chef_environment": "test",
        "tags": ["system_sys1", "phase_test" ],
        "normal": {
            "owner": {
              "name": "Christine Draper"
            }
        },
        "nodes" : [
          ...
        ],
        "cookbook_attributes" : [
        ]
    },
```
The `name` is how you will refer to the topology in the
`knife topo` subcommands.

The `chef-environment` and `normal` attributes defined
here will be applied to all nodes in the topology, unless alternative
values are provided for a specific node.  The `tags` 
will be added to each node. 
    
## Node List
Each topology contains a list of `nodes`.

```json
    "{
        "name": "test1",
        ...,
        "nodes": {
            "buildserver": {
                "name": "buildserver01",
                "ssh_host": "192.168.1.201",
                "ssh_port": "2224",
                "chef_environment": "dev",
                "run_list": ["role[base-ubuntu]", "ypo::db", "recipe[ypo::appserver]"],
                "normal": {
                  "topo.node_type": "buildserver",
                  "another": "Value 1"
                },
                "tags": ["build"]
            },
            ...
            }
        }
    },
    ...
    ]}
```
Within `nodes`, the `name` field is the node name that will be used in Chef.
The fields `chef_environment`, `run_list`, `tags` and the attributes
within `normal` will also be applied to the node in Chef. All of these
fields are optional. 

The `ssh_host` and `ssh_port` are optional fields that are used to
bootstrap a node.

## Topology Cookbook Attributes

Each topology may have attributes that are set via
an attribute file in a topology-specific cookbook. Each
attribute file is described in an entry in the 'cookbook_attributes'
array.

```json
	"cookbook_attributes": [
		{
			"cookbook": "testsys_test1",
			"filename": "softwareversion",
			"normal": 
			{			
				"nodejs": 
				{
					"version": "0.28"
				},

				"testapp": 
				{
					"version": "0.0.3"
				},

				"mongodb": 
				{
					"package_version": "2.6.1"
				}
			},
			"conditional" : [
				{
					"qualifier": "node_type",
					"value" : "buildserver",
					"normal": 
					{
						"mongodb": 
						{
							"package_version": "2.5.1"
						}
					}
				}
			]
		}
	]
```

Attributes listed directly under an attribute priority (e.g. 'normal'
in the above) will generate an entry in the attribute file such as:

  normal['mongodb'][package_version] = "2.6.1"
  
Attributes listed under the `conditional` property will generate an 
entry in the attribute file such as:

```ruby
  if (node['topo']['node_type'] == "buildserver")
    normal['mongodb'][package_version] = "2.5.1"
  end
```

# Subcommands #

The main subcommands for `knife topo` are:

* `knife topo import` - Import one or more into your workspace/local repo
* `knife topo create` - Create and optionally bootstrap a topology of nodes
* `knife topo update` - Update a topology of nodes

The additional subcommands can also be useful, depending on your
workflow:

* `knife topo bootstrap` - Bootstraps a topology of nodes
* `knife topo cookbook create` - Generate the topology cookbooks
* `knife topo cookbook upload` - Upload the topology cookbooks
* `knife export` - Export data from a topology (or from nodes that you want in a topology)

The topologies are data bag items in the 'topologies' data bag, so 
you can also use knife commands such as:

* `knife data bag show topologies` - List the topologies
* `knife data bag show topologies test1` - Show details of the test1 topology
* `knife data bag delete topologies test1` - Delete the test1 topology 

### Common Options:

The knife topo subcommands support the following common options.

Option        | Description
------------  | -----------
-D, --data-bag DATA_BAG    | The data bag to use for the topologies. Defaults to 'topologies'.

## knife topo bootstrap

	knife topo bootstrap TOPOLOGY

Runs the `knife bootstrap` command for each node in the topology that
has the `ssh_host` attribute. Specified options will be passed through
to `knife bootstrap` and applied to each node.

### Options:

The knife topo bootstrap  subcommand supports the following additional options.

Option        | Description
------------  | -----------
See [knife bootstrap](http://docs.opscode.com/knife_bootstrap.html)  | Options supported by `knife bootstrap` are passed through to the bootstrap command


### Examples:
The following will bootstrap nodes in the test1 topology, using a
user name of vagrant, password of vagrant, and running using sudo.

	$ knife topo bootstrap sys1_test test1 -x vagrant -P vagrant --sudo

## knife topo cookbook create 

	knife topo cookbook create TOPOLOGY

Generates the topology cookbook attribute files and attributes described in the 
'cookbook_attributes' property.

### Options:

The knife topo cookbook create subcommand supports the following additional options.

Option        | Description
------------  | -----------
See [knife cookbook create](http://docs.opscode.com/chef/knife.html#cookbook)  |  

### Examples:
The following will generate the topology cookbook attribute files for
topology test1.

	$ knife topo cookbook create test1

## knife topo cookbook upload 

	knife topo cookbook upload TOPOLOGY

Uploads the topology cookbook attribute files.

### Options:

The knife topo cookbook upload subcommand supports the following additional options.

Option        | Description
------------  | -----------
See [knife cookbook upload](http://docs.opscode.com/chef/knife.html#cookbook)  | 


### Examples:
The following will generate the topology cookbook attribute files for
topology test1.

	$ knife topo cookbook create test1
	
  
## knife topo create 

	knife topo create TOPOLOGY

Creates the specified topology in the chef server as an item in the 
system environment data bag. Creates the chef environment associated
with the system environment, if it does not already exist. Uploads any
topology cookbooks. Creates or 
updates nodes identified in the topology, using information 
specified in the system environment and for the specific node. 

### Options:

The knife topo create subcommand supports the following additional options.

Option        | Description
------------  | -----------
--bootstrap    | Bootstrap the topology (see [topo bootstrap](#markdown-header-knife-topo-bootstrap))
See [knife bootstrap](http://docs.opscode.com/knife_bootstrap.html)  | Options supported by `knife bootstrap` are passed through to the bootstrap command
--no-upload   | Do not upload topology cookbooks

### Examples:
The following will create the 'test1' topology, and bootstrap it.

	$ knife topo create test1 --bootstrap

The following will create the 'test1' topology but will not bootstrap it 
or upload topology cookbooks.

$ knife topo create test1 --no-upload

## knife topo export 

	knife topo export [ TOPOLOGY [ NODE ... ] 

Exports the specified topology as JSON. If the topology does not already exist, 
an outline for a new topology will be exported. The exported JSON
can be used as the basis for a new topology definition.

If nodes are specified, these will be added into the export in addition
to any nodes that are in the topology. 

If no topology is specified, all existing topologies in that environment 
will be exported.

### Examples:
The following will export all topologies to a file called 'sys1_test.json'.

	$ knife topo export sys1_test > sys1_test.json
	
The following will create an outline for a new topology called  'christine_test':

	$ knife topo export christine_test > christine_test.json


## knife topo import 

	knife topo import [ TOPOLOGY_FILE [ TOPOLOGY ... ]] 

Imports the system environment and topologies from a
[topology file](#Topology File) into the local repo. If no topology
file is specified, attempts to read from a file called 'topology.json'
in the current directory. Generates the topology cookbook attribute 
files and attributes described in the 'cookbook_attributes' property.

### Examples:
The following will import all topologies defined in the 'topology.json' file.

	$ knife topo import topology.json

The following will import the 'test1' topology
 defined in the 'topology.json' file.

	$ knife topo import topology.json test1

## knife topo update

	knife topo update [ TOPOLOGY ] 

Updates the specified topology. Creates or updates nodes 
identified in the topology, using information specified in the 
topology for the specific node. 

If no topology is specified, all existing topologies in that environment 
will be updated.

### Examples:
The following will update the 'test1' topology.

	$ knife topo update test1
	
The following will update all topologies in the 'topologies' data bag.

	$ knife topo update
	

# License #

Author:: Christine Draper (christine_draper@thirdwaveinsights.com)

Copyright:: Copyright (c) 2014 ThirdWave Insights, LLC

License:: Apache License, Version 2.0

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
