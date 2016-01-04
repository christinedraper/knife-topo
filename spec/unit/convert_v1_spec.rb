#
# Author:: Christine Draper (<christine_draper@thirdwaveinsights.com>)
# Copyright:: Copyright (c) 2014 ThirdWave Insights LLC
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the 'License');
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an 'AS IS' BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

#
# These tests are in need of cleaning up - big time!
#

require 'rspec'
require 'rspec/mocks'
require File.expand_path('../../spec_helper', __FILE__)
require 'chef/topology'

describe 'Chef::Topo::TopoV1Converter' do
  describe '#convert' do
    before do
      @topo1_data = {
        'name' => 'topo1',
        'chef_environment' => 'test',
        'tags' => ['topo_tag'],
        'normal' => { 'anAttr' => 'aValue' },
        'nodes' => [
          {
            'name' => 'node1',
            'ssh_host' => '10.0.1.1'
          },
          {
            'name' => 'node2',
            'chef_environment' => 'dev',
            'normal' => {
              'anotherAttr' => 'anotherValue',
              'topo' => { 'node_type' => 'appserver' }
            },
            'tags' => %w(topo_tag  second_tag)
          }
        ]
      }
      @topo = Chef::Topology.convert_from('topo_v1', @topo1_data)
    end

    it 'sets the id' do
      expect(@topo['id']).to eq(@topo1_data['name'])
    end

    it 'sets the strategy' do
      expect(@topo['strategy']).to eq('direct_to_node')
    end

    it 'sets the node_type' do
      expect(@topo['nodes'][0]).not_to have_key('node_type')
      expect(@topo['nodes'][1]['node_type']).to eq('appserver')
    end
  end

  describe '#convert to cookbook strategy' do
    before do
      @topo2_data = {
        'name' => 'topo2',
        'chef_environment' => 'test',
        'tags' => ['topo_tag'],
        'normal' => { 'anAttr' => 'aValue' },
        'nodes' => [
          {
            'name' => 'node1',
            'ssh_host' => '10.0.1.1'
          },
          {
            'name' => 'node2',
            'chef_environment' => 'dev',
            'normal' => { 'anotherAttr' => 'anotherValue' },
            'tags' => %w(topo_tag  second_tag)
          }
        ],
        'cookbook_attributes' => [
          {
            'cookbook' => 'topo_topo2',
            'filename' => 'topo',
            'default' => {
              'anotherAttr' => 'cbValue_default'
            },
            'override' => {
              'anotherAttr' => 'cbValue_override'
            },
            'normal' => {
              'anotherAttr' => 'cbValue_normal'
            }
          },
          {
            'cookbook' => 'duff',
            'normal' => { 'topo' => { 'name' => 'duff' } }
          }
        ]
      }
      @topo2 = Chef::Topology.convert_from('topo_v1', @topo2_data)
    end

    it 'sets the strategy to via cookbook' do
      expect(@topo2['strategy']).to eq('via_cookbook')
    end

    it 'sets the strategy data' do
      expect(@topo2['strategy_data']).to eq(
        'cookbook' => 'topo_topo2',
        'filename' => 'topo'
      )
    end

    it 'merges cookbook into node' do
      expect(@topo2['nodes'][1]['override']).to eq(
        'anotherAttr' => 'cbValue_override'
      )
    end

    it 'cleans out v1 fields' do
      expect(@topo2).not_to have_key('cookbook_attributes')
    end
  end

  describe '#convert all conditional' do
    before do
      @topo3_data = {
        'name' => 'topo3',
        'chef_environment' => 'test',
        'tags' => ['topo_tag'],
        'normal' => { 'anAttr' => 'aValue' },
        'nodes' => [
          {
            'name' => 'node1',
            'ssh_host' => '10.0.1.1',
            'normal' => {
              'topo' => { 'node_type' => 'appserver' }
            }
          },
          {
            'name' => 'node2',
            'chef_environment' => 'dev',
            'normal' => { 'anotherAttr' => 'anotherValue' },
            'tags' => %w(topo_tag  second_tag)
          }
        ],
        'cookbook_attributes' => [
          {
            'cookbook' => 'topo_topo3',
            'filename' => 'topo',
            'conditional' => [{
              'qualifier' => 'node_type',
              'value' => 'appserver',
              'default' => {
                'anotherAttr' => 'cbValue_default'
              },
              'override' => {
                'anotherAttr' => 'cbValue_override'
              },
              'normal' => {
                'anotherAttr' => 'cbValue_normal'
              }
            }]
          }
        ]
      }
      @topo3 = Chef::Topology.convert_from('topo_v1', @topo3_data)
    end

    it 'sets the strategy to via cookbook' do
      expect(@topo3['strategy']).to eq('via_cookbook')
    end

    it 'merges conditional attributes into one node' do
      expect(@topo3['nodes'][0]['override']).to eq(
        'anotherAttr' => 'cbValue_override'
      )
    end

    it 'doesnt merge conditional attributes into other node' do
      expect(@topo3['nodes'][1]).not_to have_key('override')
    end
  end
end
