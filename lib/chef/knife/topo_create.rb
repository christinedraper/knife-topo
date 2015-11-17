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
        Chef::Knife::Bootstrap.load_deps
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
      
      option :overwrite,
      :long => "--overwrite",
      :description => "Whether to overwrite existing nodes",
      :boolean => true
            
      # Make called command options available
      opts = self.options
      self.options = (Chef::Knife::Bootstrap.options).merge(Chef::Knife::TopoCookbookUpload.options)
      self.options.merge!(opts)

      def initialize (args)
        super
        @bootstrap_args  = initialize_cmd_args(args, [ 'bootstrap', '' ])
        @topo_upload_args  = initialize_cmd_args(args, [ 'topo', 'cookbook', 'upload', @name_args[0] ])

        # All called commands need to accept union of options
        Chef::Knife::Bootstrap.options = options
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
          msg = "Topology #{topo_name} already exists - do you want to update it"
          msg = msg + " to version " + format_topo_version(topo) if topo['version']
          ui.confirm(msg, true, false)
          topo.save
        end

        # make sure env and cookbooks are in place
        check_chef_env(topo['chef_environment']) if topo['chef_environment']
        upload_cookbooks(@topo_upload_args) if (!config[:disable_upload])  

        # update any existing nodes
        topo_hash = topo.raw_data
        nodes = merge_topo_properties(topo_hash['nodes'], topo_hash)
        config[:disable_editing] = true
        
        bootstrapped = []
        updated = []
        skipped = []
        failed = [] 
        
        if nodes && nodes.length > 0
                 
          nodes.each do |node_data|
            node_name = node_data['name']
            
            exists = resource_exists?("nodes/#{node_name}") 
            if(node_data['ssh_host'] && config[:bootstrap] && (config[:overwrite] || !exists))
              if run_bootstrap(node_data, @bootstrap_args, exists)
                bootstrapped << node_name
              else
                failed << node_name
              end
            else
              if(exists)
                updated << node_name
                node = update_node(node_data)                  
              else
                skipped << node_name
              end
            end
          end
  
          ui.info("Topology #{display_name(topo_hash)} created, containing #{nodes.length} nodes")
          ui.info("Build information: " + topo_hash['buildstamp']) if topo_hash['buildstamp']
          
          if(config[:bootstrap])
            ui.info("Bootstrapped #{bootstrapped.length} nodes [ #{bootstrapped.join(', ')} ]")
            if updated.length > 0
              ui.info("Updated #{updated.length} nodes [ #{updated.join(', ')} ] because they already exist. " +
                "Specify --overwrite to re-bootstrap existing nodes. " +
                "If you are using Chef Vault, you may need to use --bootstrap-vault options in this case.")
            end
            ui.info("Skipped #{skipped.length} nodes [ #{skipped.join(', ')} ] because they had no ssh_host information") if skipped.length > 0
          else
            ui.info("Updated #{updated.length} nodes [ #{updated.join(', ')} ]")
            ui.info("Skipped #{skipped.length} nodes [ #{skipped.join(', ')} ] because they do not exist") if skipped.length > 0
          end
          
          ui.warn("#{failed.length} nodes [ #{failed.join(', ')} ] failed to bootstrap due to errors") if failed.length > 0
               
        else
          ui.info "No nodes found for topology #{display_name(topo_hash)}"
        end
             
      end

      include Chef::Knife::TopologyHelper      

    end
  end
end
