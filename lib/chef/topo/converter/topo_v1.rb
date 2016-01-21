#
# Author:: Christine Draper (<christine_draper@thirdwaveinsights.com>)
# Copyright:: Copyright (c) 2015 ThirdWave Insights LLC
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

#
# Converts data in a given format into V2 topo JSON format
#
require 'chef/mixin/deep_merge'
require 'chef/topo/converter'

class Chef
  module Topo
    # Convert V1 topology JSON to V2
    class TopoV1Converter < Chef::Topo::Converter
      PRIORITIES = %w(default force_default normal override force_override)

      register_converter('topo_v1', name)

      def convert(data = nil)
        @input = data if data
        @output = @input.dup
        determine_strategy
        @output['nodes'] = []
        @input['nodes'].each do |n|
          @output['nodes'] << convert_node(n)
        end
        cleanup_output
      end

      def convert_node(n)
        combined = merge_cookbook_attrs(n)
        type = node_type(n)
        combined['node_type'] ||= type if type
        combined
      end

      def determine_strategy
        @output['strategy'] = 'direct_to_node'
        cookbooks = @input['cookbook_attributes']
        return unless cookbooks && cookbooks.length > 0

        cookbooks.each do |cb|
          cond = cb['conditional'] || []
          next unless !cond.empty? || PRIORITIES.any? { |k| cb.key?(k) }
          via_cookbook_strategy(cb)
          break
        end
      end

      def via_cookbook_strategy(cb)
        @output['strategy'] = 'via_cookbook'
        @output['strategy_data'] = {
          'cookbook' => cb['cookbook'] || @output['name'],
          'filename' => cb['filename'] || 'attributes'
        }
      end

      # move source[p] contents and merge into dest[p]
      def merge_copy(dest, source)
        # Go in reverse order so higher priority attrs are at top
        PRIORITIES.reverse_each do |p|
          if source.key?(p)
            dest[p] = Chef::Mixin::DeepMerge.merge(dest[p], source[p])
          end
        end
      end

      # Combine cookbook attributes into node
      def merge_cookbook_attrs(node)
        cb_attr_array = @input['cookbook_attributes']
        combined = node.dup
        return combined unless cb_attr_array

        # merge unqualified attributes into node
        cb_attr_array.each do |cb_attrs|
          merge_copy(combined, cb_attrs)

          # find qualified attributes for node
          cond = cb_attrs['conditional']
          next unless cond

          merge_copy_cond_attrs(combined, cond)
        end

        combined
      end

      def merge_copy_cond_attrs(combined, cond)
        topo = (combined['normal'] || {})['topo'] || {}
        cond.each do |cond_attrs|
          if topo[cond_attrs['qualifier']] == cond_attrs['value']
            merge_copy(combined, cond_attrs)
          end
        end
        combined
      end

      def node_type(node)
        return node['node_type'] if node['node_type']
        return nil unless node['normal'] && node['normal']['topo']
        node['normal']['topo']['node_type']
      end

      def cleanup_output
        @output.delete('cookbook_attributes')
        @output
      end
    end
  end
end
