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
require 'chef/knife/topo_export'
require 'chef/node'

describe KnifeTopo::TopoExport do
  before(:each) do
    Chef::Config[:node_name] = 'christine_test'
  end

  describe '#run' do
    it 'exports a template for an unknown topology' do
      @cmd = KnifeTopo::TopoExport.new(
        %w(topo  export  --min-priority=default)
      )
      allow(@cmd).to receive(:load_topo_from_server).and_return(nil)
      expect { @cmd.run }.not_to raise_error
      output = @cmd.load_or_initialize_topo
      expect(output['nodes'].length).to eq(1)
      expect(output['nodes'][0]['name']).to eq('node1')
    end

    it 'exports a template for a defined topology' do
      @cmd = KnifeTopo::TopoExport.new(
        %w(topo  export --topo=test1 --min-priority=default)
      )
      item = Chef::DataBagItem.new
      item.raw_data = { 'id' => 'test1', 'name' => 'test1', 'nodes' => [] }
      allow(@cmd).to receive(
        :load_topo_from_server
      ).with('test1').and_return(item)
      @cmd.run
      output = @cmd.load_or_initialize_topo
      expect(output['name']).to eq('test1')
      expect(output['nodes'].length).to eq(0)
    end

    it 'exports a node for a new topology' do
      @cmd = KnifeTopo::TopoExport.new(
        %w(topo  export  appserver1  --min-priority=default)
      )
      allow(@cmd).to receive(:load_topo_from_server).and_return(nil)
      node = Chef::Node.new
      node.name('appserver1')
      allow(Chef::Node).to receive(:load).with('appserver1').and_return(node)
      @cmd.run
      output = @cmd.load_or_initialize_topo
      expect(output['name']).to eq('topo1')
      expect(output['nodes'][0]['name']).to eq('appserver1')
    end
  end
end
