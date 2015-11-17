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


require_relative 'topology_helper'
require 'chef/knife/bootstrap'

class Chef
  class Knife
    class TopoBootstrap < Chef::Knife

      deps do
         Chef::Knife::Bootstrap.load_deps
      end

      banner "knife topo bootstrap TOPOLOGY (options)"

      option :data_bag,
      :short => '-D DATA_BAG',
      :long => "--data-bag DATA_BAG",
      :description => "The data bag the topologies are stored in"
      
      option :overwrite,
      :long => "--overwrite",
      :description => "Whether to overwrite existing nodes",
      :boolean => true

      # Make the base bootstrap options available on topo bootstrap
      self.options = (Chef::Knife::Bootstrap.options).merge(self.options)

      def initialize (args)
        super
        @bootstrap_args = initialize_cmd_args(args, [ 'bootstrap', '' ])

        # All called commands need to accept union of options
        Chef::Knife::Bootstrap.options = options

      end

      def run
        if !@name_args[0]
          show_usage
          ui.fatal("You must specify the name of a topology")
          exit 1
        end

        @bag_name = topo_bag_name(config[:data_bag])
        @topo_name = @name_args[0]

        # get the node names for the topology
        unless topo = load_from_server(@bag_name, @topo_name )
          ui.fatal("Topology #{@bag_name}/#{@topo_name} does not exist on the server - use 'knife topo create' first")
          exit(1)
        end

        # load and bootstrap each node that has a ssh_host
        nodes = merge_topo_properties(topo['nodes'], topo)
          
        bootstrapped = []
        skipped = []
        existed = []
        failed = [] 
          
        if nodes.length > 0
          nodes.each do |node_data|
            node_name = node_data['name']
            exists = resource_exists?("nodes/#{node_name}") 
            if(node_data['ssh_host'] && (config[:overwrite] || !exists))
              if run_bootstrap(node_data, @bootstrap_args, exists)
                bootstrapped << node_name
              else
                failed << node_name
              end
            else
              if(exists)
                existed << node_name
              else
                skipped << node_name
              end
            end
          end
          ui.info("Bootstrapped #{bootstrapped.length} nodes [ #{bootstrapped.join(', ')} ]")
          ui.info("Skipped #{skipped.length} nodes [ #{skipped.join(', ')} ] because they had no ssh_host information") if skipped.length > 0
          if existed.length > 0
            ui.info("Skipped #{existed.length} nodes [ #{existed.join(', ')} ] because they already exist. " +
              "Specify --overwrite to re-bootstrap existing nodes. " +
              "If you are using Chef Vault, you may need to use --bootstrap-vault options in this case.")
          end
          ui.warn("#{failed.length} nodes [ #{failed.join(', ')} ] failed to bootstrap due to errors") if failed.length > 0
        else
          ui.info "No nodes found for topology #{display_name(topo)}"
        end
      end

      include Chef::Knife::TopologyHelper

    end
  end
end
