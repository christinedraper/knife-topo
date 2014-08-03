#
# Author:: Christine Draper (<christine_draper@thirdwaveinsights.com>)
# Copyright:: Copyright (c) 2014 ThirdWave Insights LLC
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'chef/knife'
require_relative 'topology_helper'
require_relative 'topo_bootstrap'
require_relative 'topo_cookbook_upload'

class Chef
  class Knife
    class TopoCreate < Chef::Knife
      
      deps do
        Chef::Knife::TopoCookbookUpload.load_deps
        Chef::Knife::TopoBootstrap.load_deps
      end

      banner "knife topo create TOPOLOGY (options)"

      option :data_bag,
      :short => '-D DATA_BAG',
      :long => "--data-bag DATA_BAG",
      :description => "The data bag the topologies are stored in"

      option :bootstrap,
      :long => "--bootstrap",
      :description => "Whether to bootstrap newly created nodes",
      :boolean => true

      option :disable_upload,
      :long => "--disable-upload",
      :description => "Do not upload topo cookbooks",
      :boolean => true
            
      # Make called command options available
      opts = self.options
      self.options = (Chef::Knife::TopoBootstrap.options).merge(Chef::Knife::TopoCookbookUpload.options)
      self.options.merge!(opts)

      def initialize (args)
        super
        @topo_bootstrap_args  = initialize_cmd_args(args, [ 'topo', 'bootstrap', @name_args[0] ])
        @topo_upload_args  = initialize_cmd_args(args, [ 'topo', 'cookbook', 'upload', @name_args[0] ])

        # All called commands need to accept union of options
        Chef::Knife::TopoBootstrap.options = options
        Chef::Knife::TopoCookbookUpload.options = options
      end
      
      def run
        if !@name_args[0]
          show_usage
          ui.fatal("You must specify the name of a topology")
          exit 1
        end

        bag_name = topo_bag_name(config[:data_bag])
        topo_name = @name_args[0]

        # Load the topology data & create the topology bag
        unless topo = load_from_file(bag_name, topo_name )
          ui.fatal("Topology file #{topologies_path}/#{bag_name}/#{topo_name}.json not found - use 'knife topo import' first")
          exit(1)
        end
        @data_bag = create_bag(bag_name)
        
        # Add topology item to the data bag on the server
        begin
          topo.create
         rescue Net::HTTPServerException => e
          raise unless e.to_s =~ /^409/
          ui.confirm("Topology already exists - do you want to re-create it", true, false)
          topo.save
        end

        # make sure env and cookbooks are in place
        check_chef_env(topo['chef_environment']) if topo['chef_environment']
        upload_cookbooks(@topo_upload_args) if (!config[:disable_upload])  

        # update any existing nodes
        topo_hash = topo.raw_data
        nodes = merge_topo_properties(topo_hash['nodes'], topo_hash)
        config[:disable_editing] = true
        
        if nodes && nodes.length > 0
          nodes.each do |updates|
            node_name = updates['name']
            node = update_node(updates)
          end
          # if bootstrap is specified, run the bootstrap command
          run_cmd(Chef::Knife::TopoBootstrap, @topo_bootstrap_args) if config[:bootstrap]
        else
          ui.info "No nodes found for topology #{topo_hash['name']}"
        end
           
        ui.info("Topology created")
              
      end
      



      include Chef::Knife::TopologyHelper      

    end
  end
end
