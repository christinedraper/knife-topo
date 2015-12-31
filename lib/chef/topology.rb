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

class Chef
  # Topology
  class Topology < Chef::DataBagItem
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
    
    def self.from_json(data)
      topo = new
      topo.raw_data = clean_topo_data(data)
      topo
    end

    # Make sure the JSON has an id and other expected fields
    def self.clean_topo_data(data)
      topo_name = data['name'] || data['id']
      data['id'] ||= topo_name
      data['name'] ||= topo_name
      data
    end

    def display_info
      info = buildstamp ? ' buildstamp: ' + buildstamp : ''
      display_name + info
    end

    def display_name
      version = topo_version ? ' version: ' + topo_version : ''
      raw_data['name'] + version
    end
    
    # Topology version
    def topo_version
      version = raw_data['version']
      if version
        version = version + '-' + buildid if buildid
      end
      version
    end
    
    def chef_environment
      raw_data['chef_environment']
    end
    
    def buildid
      raw_data['buildid']
    end
    
    def buildstamp
      raw_data['buildstamp']
    end
    
    def nodes
      raw_data['nodes']
    end
  end
end
