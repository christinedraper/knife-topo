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

require 'chef/node'
require 'chef/run_list'
require 'chef/mixin/deep_merge'
require 'chef/rest'

module KnifeTopo
  # Node update helper for knife topo
  module NodeUpdateHelper
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
        ui.info "No updates found for node #{node.name}"
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
      node.normal = Chef::Mixin::DeepMerge.merge(node.normal, attrs)
      original != node.normal
    end

    def update_runlist(node, runlist)
      # node.run_list MUST be lhs of != to use override operator
      return false unless runlist && node.run_list != runlist
      updated_run_list = Chef::RunList.new
      runlist.each { |e| updated_run_list << e }
      node.run_list(*updated_run_list)
      true
    end

    def update_chef_env(node, env)
      return false unless env && env != node.chef_environment
      node.chef_environment(env)
      true
    end

    def update_tags(node, tags)
      return false unless tags
      orig_num_tags = node.tags.length
      node.tag(*tags)
      node.tags.length > orig_num_tags
    end
  end
end
