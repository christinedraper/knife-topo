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

require 'rspec'
require 'rspec/mocks'
require File.expand_path('../../spec_helper', __FILE__)
require 'chef/knife/topo/processor'
require 'chef/topology'

describe KnifeTopo::Processor do
  before do
    @data = {
      'id' => 'topo1',
      'name' => 'topo1',
      'chef_environment' => 'test',
      'tags' => ['topo_tag'],
      'attributes' => { 'anAttr' => 'aValue' },
      'strategy' => 'via_cookbook',
      'strategy_data' => {
        'cookbook' => 'topo_topo1',
        'filename' => 'topologyattr'
      },
      'nodes' => [
        {
          'name' => 'node1',
          'node_type' => 'appserver',
          'ssh_host' => '10.0.1.1',
          'chef_environment' => 'test',
          'tags' => ['topo_tag'],
          'force_override' => {
            'node1Attr' => 'aValue'
          },
          'normal' => {
            'topo' => { 'name' => 'topo1', 'node_type' => 'appserver' }
          }
        },
        {
          'name' => 'node2',
          'chef_environment' => 'dev',
          'tags' => %w(topo_tag  second_tag),
          'force_override' =>
          {
            'anotherAttr' => 'anotherValue'
          },
          'normal' =>
          {
            'topo' => { 'name' => 'topo1' }
          }
        }
      ]
    }
    @topo1 = Chef::Topology.from_json(@data)
    @processor = KnifeTopo::Processor.for_topo(@topo1)
    allow(@processor).to receive(:run_create_cookbook)
    allow(File).to receive(:open) {}
    # Create a dummy calling command with config
    @cmd = Chef::Knife.new
    @cmd.config = { cookbook_copyright: 'MY COPYRIGHT' }
    @processor.generate_artifacts('cmd' => @cmd)
    @contents = @processor.cookbook_contents
  end

  describe 'processor#cookbook_contents' do
    # Improve these tests by using a pattern match
    it 'generates an attribute file' do
      expect(@contents).to include(
        "if node['topo'] && node['topo']['node_type'] == 'appserver'"
      )
      expect(@contents).to include("force_override['node1Attr'] = \"aValue\"")
      expect(@contents).to include("if node.name == 'node2'")
      expect(@contents).to include(
        "force_override['anotherAttr'] = \"anotherValue\""
      )
    end

    it 'generates a  copyright' do
      contents = @processor.cookbook_contents
      expect(contents).to include("Copyright (c) #{Time.now.year} MY COPYRIGHT")
    end
  end
end
