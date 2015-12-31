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

# NOTE: This command exports to stdout

module KnifeTopo
  # knife topo export
  class TopoExport < Chef::Knife
    deps do
    end

    banner 'knife topo export [ NODE ... ] (options)'

    option(
      :data_bag,
      short: '-D DATA_BAG',
      long: '--data-bag DATA_BAG',
      description: 'The data bag the topologies are stored in'
    )

    option(
      :min_priority,
      long: '--min-priority PRIORITY',
      default: 'default',
      description: 'Export attributes with this priority or above'
    )

    option(
      :topo,
      long: '--topo TOPOLOGY',
      description: 'Name to use for the topology',
      default: 'topo1'
    )

    include Chef::Knife::TopologyLoader

    def most_common(vals)
      return if vals.length == 0
      vals.group_by do |val|
        val
      end.values.max_by(&:size).first
    end

    def run
      unless %w(default normal override).include?(config[:min_priority])
        ui.warn("--min-priority should be one of 'default', "\
          "'normal' or 'override'")
      end
      @topo_name = config[:topo]
      @node_names = @name_args
      output(Chef::JSONCompat.to_json_pretty(load_or_initialize_topo))
    end

    def load_or_initialize_topo
      topo = load_topo_from_server(@topo_name)
      if topo
        export = topo.raw_data
        update_nodes!(export['nodes'])
      else
        export = new_topo
      end
      export
    end

    def new_topo
      topo = empty_topology
      update_nodes!(topo['nodes'])

      # pick an topo environment based on the nodes
      return topo if @node_names.length == 0
      env = pick_env(topo['nodes'])
      topo['chef_environment'] = env if env
      topo
    end

    def pick_env(nodes)
      envs = []
      nodes.each do |node|
        envs << node['chef_environment'] if node['chef_environment']
      end
      most_common(envs)
    end

    # give user a template to get started
    def empty_topology
      {
        'id' => @topo_name || 'topo1',
        'name' => @topo_name || 'topo1',
        'chef_environment' => '_default',
        'tags' => [],
        'nodes' => @node_names.length == 0 ? [empty_node('node1')] : [],
        'cookbook_attributes' => [{
          'cookbook' =>  @topo_name || 'topo1',
          'filename' => 'topology'
        }]
      }
    end

    def empty_node(name)
      {
        'name' => name,
        'run_list' => [],
        'ssh_host' => name,
        'ssh_port' => '22',
        'normal' => {},
        'tags' => []
      }
    end

    # get actual node properties for export
    def node_export(node_name)
      load_node_data(node_name)
    rescue Net::HTTPServerException => e
      raise unless e.to_s =~ /^404/
      empty_node(node_name)
    end

    def load_node_data(node_name)
      node_data = {}
      node = Chef::Node.load(node_name)
      %w(name tags chef_environment run_list).each do |key|
        node_data[key] = node.send(key)
      end

      %w(default normal override).each do |key|
        node_data[key] = node.send(key) if meets_min(key)
      end
      node_data
    end

    def meets_min(pri)
      min = config[:min_priority]
      pri == 'override' ||
        (pri == 'normal' && min == 'default') ||
        pri == min
    end

    # put node details in node array, overwriting existing details
    def update_nodes!(nodes)
      @node_names.each do |node_name|
        # find out if the node is already in the array
        found = nodes.index { |n| n['name'] == node_name }
        if found.nil?
          nodes.push(node_export(node_name))
        else
          nodes[found] = node_export(node_name)
        end
      end
    end
  end
end
