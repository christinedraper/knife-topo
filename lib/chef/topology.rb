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

require 'chef/data_bag_item'
require 'chef/topo/converter'
require 'chef/mixin/deep_merge'

class Chef
  # Topology
  class Topology < Chef::DataBagItem
    attr_accessor :strategy

    PRIORITIES = %w(
      default force_default normal override force_override
    ).freeze

    # Have to override and say this is a data bag json_class
    # or get error on upload re 'must specify id'
    def to_json(*a)
      result = {
        'name'       => object_name,
        'json_class' => Chef::DataBagItem.name,
        'chef_type'  => 'data_bag_item',
        'data_bag'   => data_bag,
        'raw_data'   => raw_data
      }
      Chef::JSONCompat.to_json(result, *a)
    end

    def self.convert_from(format, data)
      from_json(Chef::Topo::Converter.convert(format, data))
    end

    def self.from_json(data)
      topo = new
      topo.raw_data = data
      topo
    end

    # Make sure the JSON has an id and other expected fields
    def raw_data=(new_data)
      @strategy = new_data['strategy'] || 'direct_to_node'
      new_data['id'] ||= (new_data['name'] || 'undefined')
      new_data['name'] ||= (new_data['id'])
      new_data['nodes'] ||= []
      super(normalize(new_data))
    end

    # clean up some variations so we only have to process one way
    # in particular, allow 'attributes' as a synonym for 'normal'
    def normalize(data)
      data['nodes'] = data['nodes'].map do |n|
        if n.key?('attributes')
          n['normal'] = Chef::Mixin::DeepMerge.merge(
            n['normal'], n['attributes']
          )
          n.delete('attributes')
        end
        n
      end
      data
    end

    def display_info
      buildstamp = raw_data['buildstamp']
      info = buildstamp ? ' buildstamp: ' + buildstamp : ''
      display_name + info
    end

    def display_name
      version = topo_version ? ' version: ' + topo_version : ''
      topo_name + version
    end

    def topo_version
      version = raw_data['version']
      if version
        version = version + '-' + raw_data['buildid'] if raw_data['buildid']
      end
      version
    end

    def topo_name
      raw_data['name']
    end

    def nodes
      raw_data['nodes']
    end

    def merge_attrs
      raw_data['strategy_data'] && raw_data['strategy_data']['merge_attrs']
    end

    # nodes with topo properties merged in
    def merged_nodes
      nodes.map do |n|
        Chef::Mixin::DeepMerge.merge(node_defaults, n)
      end
    end

    def node_defaults
      defaults = {}
      %w(chef_environment tags).each do |k|
        defaults[k] = raw_data[k] if raw_data[k]
      end

      PRIORITIES.reverse_each do |p|
        a = default_attrs(p)
        defaults[p] = a if a
      end
      # Make sure we're not sharing objects
      Mash.from_hash(Marshal.load(Marshal.dump(defaults)))
    end

    def default_attrs(priority)
      return raw_data[priority] unless priority == 'normal'
      add_topo_attrs(raw_data['normal'])
    end

    def add_topo_attrs(attrs)
      a = attrs || {}
      a['topo'] ||= {}
      a['topo']['name'] = topo_name
      a['topo']['node_type'] = a['node_type'] if a['node_type']
      a
    end
  end
end
