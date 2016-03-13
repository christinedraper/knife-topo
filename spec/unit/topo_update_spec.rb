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

describe KnifeTopo::TopoUpdate do
  before :each do
    Chef::Config[:node_name] = 'christine_test'
    @cmd = KnifeTopo::TopoUpdate.new(%w(knife  topo  update  topo1))

    # setup test data bags
    @topobag_name = 'testsys_test'
    @topo1_name = 'topo1'
    @cmd.config[:data_bag] = @topobag_name

    @topo1_origdata = {
      'id' => 'topo1',
      'name' => 'topo1',
      'nodes' => [
        {
          'name' => 'node1'
        },
        {
          'name' => 'node2',
          'chef_environment' => 'test',
          'normal' => { 'anotherAttr' => 'anotherValue' }
        }
      ]
    }
    @topo1_newdata = {
      'id' => 'topo1',
      'name' => 'topo1',
      'nodes' => [
        {
          'name' => 'node1',
          'run_list' => ['recipe[apt]', 'role[ypo::db]', 'recipe[a::default]'],
          'tags' => ['tag1'],
          'chef_environment' => 'new_test'
        },
        {
          'name' => 'node2',
          'chef_environment' => 'dev',
          'normal' => { 'anotherAttr' => 'newValue' }
        }
      ]
    }
    @topo1_newdata2 = {
      'id' => 'topo1',
      'name' => 'topo1',
      'strategy' => 'direct_to_node',
      'strategy_data' => { 'merge_attrs' => true },
      'nodes' => [
        {
          'name' => 'node1',
          'run_list' => ['recipe[apt]', 'role[ypo::db]', 'recipe[a::default]'],
          'tags' => ['tag1'],
          'chef_environment' => 'new_test'
        },
        {
          'name' => 'node2',
          'chef_environment' => 'dev',
          'normal' => { 'secondAttr' => 'newValue' }
        }
      ]
    }
    @topo1_update = {
      'id' => 'topo1',
      'name' => 'topo1',
      'nodes' => [
        {
          'name' => 'node1',
          'run_list' => ['recipe[apt]', 'role[ypo::db]', 'recipe[a::default]'],
          'tags' => ['tag1'],
          'chef_environment' => 'new_test',
          'normal' => { 'topo' => { 'name' => 'topo1' } }
        },
        {
          'name' => 'node2',
          'chef_environment' => 'dev',
          'normal' => {
            'anotherAttr' => 'newValue',
            'topo' => { 'name' => 'topo1' }
          }
        }
      ]
    }

    @topo_bag = Chef::DataBag.new
    allow(Chef::DataBag).to receive(:new) { @topo_bag }
    allow(Chef::DataBag).to receive(:load).with(@topobag_name) { @topo_bag }

    @orig_item = Chef::Topology.new
    @orig_item.raw_data = @topo1_origdata
    @orig_item.data_bag(@topobag_name)
    @topo1_item = Chef::Topology.new
    @topo1_item.raw_data = @topo1_newdata
    @topo1_item.data_bag(@topobag_name)
    @topo1_item2 = Chef::Topology.new
    @topo1_item2.raw_data = @topo1_newdata2
    @topo1_item2.data_bag(@topobag_name)

    @exception_404 = Net::HTTPServerException.new(
      '404 Not Found', Net::HTTPNotFound.new('1.1', '404', 'Not Found')
    )
  end

  describe '#run' do
    it 'loads topology and updates objects on server' do
      @cmd.name_args = [@topo1_name]

      allow(@cmd).to receive(
        :resource_exists?
      ).with('nodes/node1').and_return(false)
      allow(@cmd).to receive(
        :resource_exists?
      ).with('nodes/node2').and_return(true)
      expect(@cmd).to receive(
        :load_local_topo_or_exit
      ).with(@topo1_name).and_return(@topo1_item)
      expect(@cmd).to receive(
        :load_topo_from_server
      ).with(@topo1_name).and_return(@orig_item)
      expect(@cmd).to receive(:upload_artifacts)

      expect(@topo1_item).to receive(:save)

      expect(@cmd).to receive(:update_node).with(
        @topo1_update['nodes'][0], nil
      )
      expect(@cmd).to receive(:update_node).with(
        @topo1_update['nodes'][1], nil
      )

      @cmd.run
    end

    it 'merges attributes if set in strategy data' do
      @cmd.name_args = [@topo1_name]

      allow(@cmd).to receive(
        :resource_exists?
      ).with('nodes/node1').and_return(false)
      allow(@cmd).to receive(
        :resource_exists?
      ).with('nodes/node2').and_return(true)
      expect(@cmd).to receive(
        :load_local_topo_or_exit
      ).with(@topo1_name).and_return(@topo1_item2)
      expect(@cmd).to receive(
        :load_topo_from_server
      ).with(@topo1_name).and_return(@orig_item)
      expect(@cmd).to receive(:upload_artifacts)

      expect(@topo1_item2).to receive(:save)

      expect(@cmd).to receive(:update_node).with(
        anything, true
      )
      expect(@cmd).to receive(:update_node).with(
        anything, true
      )

      @cmd.run
    end
  end

  describe '#update_node' do
    it 'updates an existing node' do
      node = Chef::Node.new
      expect(Chef::Node).to receive(:load).and_return(node)
      expect(node).to receive(:save)
      expect(@cmd).to receive(:check_chef_env).with('new_test')
      data = @topo1_update['nodes'][0]
      expect(@cmd).to receive(
        :update_node_with_values
      ).with(node, data, false).and_return(
        %w(normal run_list chef_environment tags)
      )
      @cmd.update_node(@topo1_update['nodes'][0])
    end

    it 'doesnt update things unchanged' do
      node = Chef::Node.new
      expect(Chef::Node).to receive(:load).and_return(node)
      @cmd.update_node_with_values(node, @topo1_update['nodes'][0])
      expect(node).not_to receive(:save)
      expect(@cmd).to receive(:check_chef_env).with('new_test')
      @cmd.update_node(@topo1_update['nodes'][0])
    end

    it 'merges attributes when merge is true' do
      node = Chef::Node.new
      node.normal = { 'a' => 1 }
      @cmd.update_node_with_values(node, @topo1_update['nodes'][0], true)
      expect(node.normal['a']).to eq(1)
    end

    it 'sets attributes when merge is false' do
      node = Chef::Node.new
      node.normal = { 'a' => 1 }
      @cmd.update_node_with_values(node, @topo1_update['nodes'][0], false)
      expect(node.normal['a']).not_to have_key('a')
    end
  end

  describe '#update_node_with_values' do
    it 'updates an existing node and reports changes' do
      node = Chef::Node.new

      updated = @cmd.update_node_with_values(node, @topo1_update['nodes'][0])
      expect(updated).to eq(%w(normal  run_list  chef_environment tags))
    end

    it 'doesnt report things unchanged' do
      node = Chef::Node.new
      @cmd.update_node_with_values(node, @topo1_update['nodes'][0])
      updated = @cmd.update_node_with_values(node, @topo1_update['nodes'][0])
      expect(updated).to eq(false)
    end

    it 'merges attributes the right way round' do
      node = Chef::Node.new
      node.normal = { 'attr1' => 'val1' }
      @cmd.update_node_with_values(node, 'normal' => { 'attr1' => 'val2' })
      expect(node['attr1']).to eq('val2')
    end

    it 'detects and saves change in nested attributes' do
      node = Chef::Node.new
      node.normal = { 'level1' => { 'level2' => { 'attr1' => 'val1' } } }
      expect(node).to receive(:save)
      @cmd.do_node_updates(node, 'normal' => { 'level1' =>
        { 'level2' => { 'attr1' => 'val2' } } })
    end
  end
end
