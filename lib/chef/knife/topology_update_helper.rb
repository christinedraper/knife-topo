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

require 'chef/data_bag'
require 'chef/node'
require 'chef/environment'
require 'chef/rest'

class Chef
  class Knife
    # Topology update helpers
    module TopologyUpdateHelper
      # make sure the chef environment exists
      def check_chef_env(chef_env_name)
        return unless chef_env_name
        Chef::Environment.load(chef_env_name) if chef_env_name
      rescue Net::HTTPServerException => e
        raise unless e.to_s =~ /^404/
        ui.info 'Creating chef environment ' + chef_env_name
        chef_env = Chef::Environment.new
        chef_env.name(chef_env_name)
        chef_env.create
        chef_env
      end

      # recursive merge that retains all keys
      def prop_merge!(hash, other_hash)
        return hash unless other_hash
        other_hash.each do |key, val|
          if val.is_a?(Hash) && hash[key]
            prop_merge!(hash[key], val)
          else
            hash[key] = val
          end
        end

        hash
      end

      # Merges topology properties into nodes, returning the merged nodes
      def merge_topo_properties(nodes, topo)
        if nodes && nodes.length > 0
          merged_nodes = nodes ? nodes.clone : []
          merged_nodes.each do |node|
            merge_topo_into_node(node, topo)
          end
        end

        merged_nodes
      end

      def merge_topo_into_node(node, topo)
        normal_defaults = Marshal.load(Marshal.dump(topo['normal'] || {}))
        node['normal'] = prop_merge!(normal_defaults, node['normal'])
        prop_merge!(node['normal'], node['attributes'])
        prop_merge!(node['normal'], 'topo' => { 'name' => topo['name'] })

        if topo['chef_environment']
          node['chef_environment'] ||= topo['chef_environment']
        end

        # merge in the topology tags
        node['tags'] ||= []
        node['tags'] |= topo['tags'] if topo['tags']
      end

      # Update an existing node
      def update_node(node_updates)
        config[:disable_editing] = true

        begin
          # load then update and save the node
          node = Chef::Node.load(node_updates['name'])

          env = node_updates['chef_environment']
          check_chef_env(env) unless env == node['chef_environment']

          do_node_updates(node, node_updates)

        rescue Net::HTTPServerException => e
          raise unless e.to_s =~ /^404/
          # Node has not been created
        end

        node
      end

      def do_node_updates(node, node_updates)
        updated = update_node_with_values(node, node_updates)
        if updated
          ui.info "Updating #{updated.join(', ')} on node #{node.name}"
          node.save
          ui.output(format_for_display(node)) if config[:print_after]
        else
          ui.info "No  updates found for node #{node.name}"
        end
      end

      # Update original node, return list of updated properties.
      def update_node_with_values(node, updates)
        updated = []

        # merge the normal attributes (but not tags)
        updated << 'normal' if update_attrs(node, updates['normal'])

        # update runlist
        updated << 'run_list' if update_runlist(node, updates['run_list'])

        # update chef env
        if update_chef_env(node, updates['chef_environment'])
          updated << 'chef_environment'
        end

        # merge tags
        updated << 'tags' if update_tags(node, updates['tags'])

        # return false if no updates, else return array of property names
        updated.length > 0 && updated
      end

      # Update methods all return true if an actual update is made
      def update_attrs(node, attrs)
        return false unless attrs
        attrs.delete('tags')
        original = node.normal.clone
        prop_merge!(node.normal, attrs)
        original != node.normal
      end

      def update_runlist(node, runlist)
        return false unless runlist && runlist != node.run_list
        updated_run_list = RunList.new
        runlist.each { |e| updated_run_list << e }
        node.run_list(*updated_run_list)
        true
      end

      def update_chef_env(node, env)
        return false unless env && env == node.chef_environment
        node.chef_environment(env)
        true
      end

      def update_tags(node, tags)
        return false unless tags
        orig_num_tags = node.tags.length
        node.tag(*tags)
        node.tags.length > orig_num_tags
      end

      # upload cookbooks - warn and continue if fails (e.g. may be frozen)
      def upload_cookbooks(args)
        run_cmd(KnifeTopo::TopoCookbookUpload, args)
      rescue StandardError
        raise if Chef::Config[:verbosity] == 2
      end
    end
  end
end
