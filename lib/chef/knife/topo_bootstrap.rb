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
        @failed = []
        skipped = 0
        succeeded = 0
        if nodes.length > 0
          nodes.each do |node_data|
            if node_data['ssh_host']
              run_bootstrap(node_data)
              succeeded += 1             
            else
              ui.info "Node #{node_data['name']} does not have ssh_host specified - skipping bootstrap"
              skipped += 1
            end

          end
          ui.info "Bootstrapped #{nodes.length - (@failed.length + skipped)} nodes and skipped #{skipped} nodes of #{nodes.length} in topology #{@bag_name}/#{@topo_name}"
          ui.warn "#{@failed.length} nodes [ #{@failed.join(', ')} ] failed to bootstrap" if @failed.length > 0
        else
          ui.info "No nodes found for topology #{@topo_name}"
        end
      end

      # Setup the bootstrap args and run the bootstrap command
      def run_bootstrap(node_data)
        node_name = node_data['name']
        args = @bootstrap_args
        args += ['-N', node_name] if(node_name)
        args += ['-E', node_data['chef_environment']] if(node_data['chef_environment'])
        args[1] = node_data['ssh_host']
        args += [ '--ssh-port', node_data['ssh_port']] if node_data['ssh_port']
        args += [ '--run-list' , node_data['run_list'].join(',')] if node_data['run_list']

        ui.info "Bootstrapping node #{node_name}"
        begin
          run_cmd(Chef::Knife::Bootstrap, args)
        rescue Exception => e
          raise if Chef::Config[:verbosity] == 2
          @failed << node_name
          ui.warn "bootstrap of node #{node_name} exited with error"
          humanize_exception(e)
        end
      end

      include Chef::Knife::TopologyHelper

    end
  end
end
