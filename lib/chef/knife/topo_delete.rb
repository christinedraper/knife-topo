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
require_relative 'topology_loader'
require_relative 'topology_helper'

module KnifeTopo
  # knife topo delete
  class TopoDelete < Chef::Knife
    deps do
      require 'chef/data_bag'
    end

    banner 'knife topo delete TOPOLOGY (options)'

    option(
      :data_bag,
      short: '-D DATA_BAG',
      long: '--data-bag DATA_BAG',
      description: 'The data bag the topologies are stored in'
    )

    include Chef::Knife::TopologyHelper
    include Chef::Knife::TopologyLoader

    def run
      validate_args
      config[:disable_editing] = true

      # remove each node
      @topo = load_topo_from_server(@topo_name)
      unless @topo
        ui.info "Topology #{topo_bag_name}/#{@topo_name} does not " \
          'exist on server'
        exit(0)
      end

      confirm_and_delete_nodes
      delete_topo
    end

    def validate_args
      unless @name_args[0]
        show_usage
        ui.fatal('You must specify the name of a topology')
        exit 1
      end
      @topo_name = @name_args[0]
    end

    def confirm_and_delete_nodes
      confirm("Do you want to delete topology #{@topo_name} - " \
        'this does not delete nodes')
      @topo['nodes'].each do |node|
        remove_node_from_topology(node['name'])
      end if @topo['nodes']
    end

    def delete_topo
      @topo.destroy(topo_bag_name, @topo_name)
      ui.info "Deleted topology #{@topo_name}"
    end

    # Remove the topo name attribute from all nodes, so topo search
    # knows they are not in the topology
    def remove_node_from_topology(node_name)
      # load then update and save the node
      node = Chef::Node.load(node_name)

      if node['topo'] && node['topo']['name'] == @topo_name
        node.rm('topo', 'name')
        ui.info "Removing node #{node.name} from topology"
        node.save
      end
      node

    rescue Net::HTTPServerException => e
      raise unless e.to_s =~ /^404/
      # Node has not been created
    end
  end
end
