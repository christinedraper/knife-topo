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
require 'chef/knife/topo_cookbook_create'
require 'chef/knife'
require 'chef/node'

describe KnifeTopo::TopoCookbookCreate do
  before :each do
    Chef::Config[:node_name]  = 'christine_test'

    @data = {
      'id' => 'topo1',
      'name' => 'topo1',
      'chef_environment' => 'test',
      'tags' => ['topo_tag'],
      'strategy' => 'via_cookbook',
      'strategy_data' => {
        'cookbook' => 'topo_topo1',
        'filename' => 'topologyattr'
      },
      'override' => { 'anAttr' => 'aValue' },
      'normal' => {},
      'nodes' => [
        {
          'name' => 'node1',
          'ssh_host' => '10.0.1.1'
        },
        {
          'name' => 'node2',
          'chef_environment' => 'dev',
          'attributes' => { 'anotherAttr' => 'anotherValue' },
          'tags' => %w(topo_tag  second_tag)
        }
      ]
    }
    @topo1 = Chef::Topology.from_json(@data)
    @cmd = KnifeTopo::TopoCookbookCreate.new(
      ['topo1', "--data-bag=#{@topobag_name}"]
    )
    KnifeTopo::TopoCookbookCreate.load_deps
    allow(@cmd).to receive(:load_topo_from_file_or_exit).and_return(@topo1)
  end

  describe '#run' do
    it 'creates cookbook' do
      expect(Chef::Knife::CookbookCreate).to receive(:new)
      expect(File).to receive(:open)
      expect { @cmd.run }.not_to raise_error
    end
  end
end
