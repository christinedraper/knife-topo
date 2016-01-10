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

require 'rspec'
require 'rspec/mocks'
require File.expand_path('../../spec_helper', __FILE__)
require 'chef/knife/topo_update'

describe 'KnifeTopo attributes' do
  before :each do
    @topo1_data = {
      'id' => 'topo1',
      'name' => 'topo1',
      'nodes' => [
        {
          'name' => 'node1',
          'attributes' => { 'test' => { 'anAttr' => 'value1' } }
        },
        {
          'name' => 'node2',
          'attributes' => { 'test' => { 'anAttr' => 'value2'  } },
          'normal' => { 'test' => { 'anotherAttr' => 'value3'  } }
        }
      ]
    }
  end

  describe 'Topology#raw_data' do
    it 'treats attributes as a synonym for normal' do
      @topo = Chef::Topology.new
      @topo.raw_data = @topo1_data
      expect(@topo.nodes[0]['normal']).to eq(
        'test' => { 'anAttr' => 'value1' }
      )
      expect(@topo.nodes[1]['normal']).to eq(
        'test' => { 'anotherAttr' => 'value3', 'anAttr' => 'value2' }
      )
    end
  end
end
