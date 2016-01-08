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
require File.expand_path('../data', __FILE__)
require 'chef/knife/topo/processor'
require 'chef/knife/topo_create'
require 'chef/knife'
require 'chef/node'

describe KnifeTopo::TopoCreate do
  before :each do
    Chef::Config[:node_name]  = 'christine_test'
    data = UnitTestData.new
    @merged_data = data.topo1_merged
    @topo1_data = data.topo1
    @topo1_name = 'topo1'
    @topobag_name = 'testsys_test'

    # setup test data bags
    @tmp_dir = Dir.mktmpdir
    @topo_dir = File.join(@tmp_dir, 'data_bags', @topobag_name)
    FileUtils.mkdir_p(@topo_dir)
    @topo1_file = File.new(File.join(@topo_dir, 'topo1.json'), 'w')
    @topo1_file.write(@topo1_data.to_json)
    @topo1_file.flush

    @topo_bag = Chef::DataBag.new
    allow(Chef::DataBag).to receive(:new) { @topo_bag }
    allow(@topo_bag).to receive(:create)

    @cmd = KnifeTopo::TopoCreate.new(['topo1', "--data-bag=#{@topobag_name}"])
    data = @cmd.loader.object_from_file(@topo1_file.path)
    @topo1_item = Chef::Topology.from_json(data)
    @topo1_item.data_bag(@topobag_name)
    allow(Chef::Topology).to receive(:new) { @topo1_item }

    allow(@cmd).to receive(:get_local_topo_path).and_return(@topo1_file.path)

    @topo1_item.raw_data = @cmd.loader.object_from_file(@topo1_file.path)

    @exception_404 =   Net::HTTPServerException.new(
      '404 Not Found', Net::HTTPNotFound.new('1.1', '404', 'Not Found')
    )
  end

  describe '#run' do
    it 'loads from bag files and creates objects on server' do
      allow(@cmd).to receive(:resource_exists?).with(
        'nodes/node1'
      ).and_return(false)
      allow(@cmd).to receive(:resource_exists?).with(
        'nodes/node2'
      ).and_return(true)

      expect(@cmd.name_args).to eq([@topo1_name])
      expect(@topo1_item).to receive(:create)
      expect(@cmd).to receive(:upload_artifacts)
      expect(@cmd).to receive(:check_chef_env).with('test')

      expect(@cmd).not_to receive(:run_bootstrap)
      node1 = @merged_data['nodes'][0]
      node2 = @merged_data['nodes'][1]
      expect(@cmd).to receive(:update_node).with(node1).and_return(nil)
      expect(@cmd).to receive(:update_node).with(node2).and_return(true)

      @cmd.run
      expect(@cmd.results[:bootstrapped]).to eq([])
      expect(@cmd.results[:skipped]).to eq(['node1'])
      expect(@cmd.results[:existed]).to eq(['node2'])
      expect(@cmd.results[:failed]).to eq([])
    end
  end

  ## Following is testing function in topology_helper
  describe '#check_chef_env' do
    it 'checks that a chef env exists and creates it if not' do
      env = Chef::Environment.new
      expect(Chef::Environment).to receive(
        :load
      ).with('test').and_raise(@exception_404)
      allow(Chef::Environment).to receive(:new).and_return(env)
      allow(env).to receive(:create)

      item = @cmd.check_chef_env('test')
      expect(item.name).to eq('test')
    end
  end

  describe '#load_from_file' do
    it 'loads from bag files' do
      expect(@cmd.loader).to receive(
        :file_exists_and_is_readable?
      ).at_least(:once).and_return(true)
      expect(@cmd.loader).to receive(
        :object_from_file
      ).and_return(@cmd.loader.object_from_file(@topo1_file.path))

      item = @cmd.load_local_topo_or_exit(@topo1_name)
      expect(item.raw_data).to eq(@topo1_data)
    end
  end

  describe '#update_node' do
    it 'does not create node' do
      expect(Chef::Node).to receive(:load).and_raise(@exception_404)
      expect(@cmd).not_to receive(:create_object)

      @cmd.update_node(@topo1_data['nodes'][1])
    end
  end

  describe '#merge_topo_properties' do
    it 'merges topo properties into a node' do
      @processor = KnifeTopo::Processor.for_topo(@topo1_item)

      nodes = @processor.generate_nodes
      expect(nodes).to eq(@merged_data['nodes'])
    end
  end
end
