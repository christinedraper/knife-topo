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

#
# These tests are in need of cleaning up - big time!
#

require 'rspec'
require 'rspec/mocks'
require File.expand_path('../../spec_helper', __FILE__)
require 'chef/knife/topo_create'
require 'chef/knife'
require 'chef/node'

#KnifeTopo::TopoCreate.load_deps

describe KnifeTopo::TopoCreate do
  before :each do
    Chef::Config[:node_name]  = "christine_test"

    # setup test data bags
    @tmp_dir = Dir.mktmpdir
    @topobag_name = 'testsys_test'
    @topo1_name = "topo1"
    @topo_dir = File.join(@tmp_dir, 'data_bags', @topobag_name)
    FileUtils.mkdir_p(@topo_dir)
    @topo1_file = File.new(File.join(@topo_dir, @topo1_name + ".json"), "w")
    @topo1_data = {
       "id" => "topo1",
       "name" => "topo1",
      "chef_environment" => "test",
      "tags" => [ "topo_tag" ],
      "normal" => { "anAttr" => "aValue" },
      "nodes" => [
      {
      "name" => "node1",
      "ssh_host" => "10.0.1.1"
      },
      {
      "name" => "node2",
      "chef_environment" => "dev",
      "normal" => { "anotherAttr" => "anotherValue" },
      "tags" => [ "topo_tag", "second_tag" ]
      }]
    }
    @merged_data = {
      "id" => "topo1",
      "name" => "topo1",
     "chef_environment" => "test",
      "tags" => [ "topo_tag" ],
      "normal" => { "anAttr" => "aValue" },
       "nodes" => [
      {
      "name" => "node1",
        "ssh_host" => "10.0.1.1",
      "chef_environment" => "test",
      "normal" => {
      "anAttr" => "aValue",
      "topo" => { "name" => "topo1" }
      },
      "tags" => [ "topo_tag" ]
      },
      {
      "name" => "node2",
      "chef_environment" => "dev",
      "normal" => {
      "anAttr" => "aValue",
      "anotherAttr" => "anotherValue",
      "topo" => { "name" => "topo1" }
      },
      "tags" => [ "topo_tag", "second_tag" ],

      }]
    }
    @topo1_file.write(@topo1_data.to_json)
    @topo1_file.flush

    @topo_bag = Chef::DataBag.new
    allow(Chef::DataBag).to receive(:new) { @topo_bag }
    allow(Chef::DataBag).to receive(:load).with(@topobag_name) { @topo_bag }
      
    @topo1_item = Chef::Topology.new
    allow(Chef::Topology).to receive(:new) { @topo1_item }
    @cmd = KnifeTopo::TopoCreate.new(['topo1', "--data-bag=#{@topobag_name}"])
    allow(@cmd).to receive(:get_local_topo_path).and_return(@topo1_file.path)

    @topo1_item.raw_data = @cmd.loader.object_from_file(@topo1_file.path)
    @topo1_item.data_bag(@topobag_name)

    @exception_404 =   Net::HTTPServerException.new("404 Not Found", Net::HTTPNotFound.new("1.1", "404", "Not Found"))

  end
  describe "#run" do
    it "loads from bag files and creates objects on server" do
      allow(@cmd).to receive(:resource_exists?).with("nodes/node1").and_return(false)
      allow(@cmd).to receive(:resource_exists?).with("nodes/node2").and_return(true)

      expect(@cmd.name_args).to eq([@topo1_name])
      expect(@topo1_item).to receive(:create)
      expect(@cmd).to receive(:upload_cookbooks)
      expect(@cmd).to receive(:check_chef_env).with("test")

      expect(@cmd).not_to receive(:run_bootstrap)
      expect(@cmd).to receive(:update_node).with(@merged_data['nodes'][0]).and_return(nil)
      expect(@cmd).to receive(:update_node).with(@merged_data['nodes'][1]).and_return(true)

      @cmd.run
      expect(@cmd.results[:bootstrapped]).to eq([])
      expect(@cmd.results[:skipped]).to eq(['node1'])
      expect(@cmd.results[:existed]).to eq(['node2'])
      expect(@cmd.results[:failed]).to eq([])

    end
    
    it "disables upload and only bootstraps new nodes with --bootstrap and not --overwrite" do
      
      cmd = KnifeTopo::TopoCreate.new([ 'topo1', '--bootstrap', '--disable-upload', "--data-bag=#{@topobag_name}" ])
    
      allow(cmd).to receive(:get_local_topo_path).and_return(@topo1_file.path)
      allow(cmd).to receive(:resource_exists?).with("nodes/node1").and_return(false)
      allow(cmd).to receive(:resource_exists?).with("nodes/node2").and_return(true)
      allow(cmd).to receive(:check_chef_env).with("test")
      allow(@topo1_item).to receive(:create)

      expect(cmd).not_to receive(:upload_cookbooks)
      expect(cmd).to receive(:run_bootstrap).with(@merged_data['nodes'][0], anything(), false).and_return(true)
      expect(cmd).not_to receive(:run_bootstrap).with(@merged_data['nodes'][1], anything(), anything())
      expect(cmd).not_to receive(:update_node).with(@merged_data['nodes'][0])
      expect(cmd).to receive(:update_node).with(@merged_data['nodes'][1]).and_return(true)
    
      cmd.run
  #    expect(cmd.results[:bootstrapped]).to eq(['node1'])
      expect(cmd.results[:failed]).to eq([])
      expect(cmd.results[:existed]).to eq(['node2'])
  #    expect(cmd.results[:skipped]).to eq([])
    
    end
    
    it "bootstraps existing node with --bootstrap and --overwrite if it has ssh_host, otherwise update" do
      
      cmd = KnifeTopo::TopoCreate.new(  [ 'topo1', '--bootstrap', '--overwrite', "--data-bag=#{@topobag_name}" ] )

      allow(cmd).to receive(:get_local_topo_path).and_return(@topo1_file.path)
      allow(cmd).to receive(:upload_cookbooks)
      allow(cmd).to receive(:resource_exists?).with("nodes/node1").and_return(true)
      allow(cmd).to receive(:resource_exists?).with("nodes/node2").and_return(true)
      allow(cmd).to receive(:check_chef_env).with("test")
    
      allow(@topo1_item).to receive(:create)
    
      expect(cmd).to receive(:run_bootstrap).with(@merged_data['nodes'][0], anything(), true).and_return(true)
      allow(cmd).to receive(:update_node).with(@merged_data['nodes'][0]).and_return(nil)
      expect(cmd).to receive(:update_node).with(@merged_data['nodes'][1])
    
      cmd.run
      
      expect(cmd.results[:bootstrapped]).to eq(['node1'])
      expect(cmd.results[:skipped]).to eq([])
      expect(cmd.results[:existed]).to eq(['node2'])
      expect(cmd.results[:failed]).to eq([])
    
    end
  end

  ## Following is testing function in topology_helper

  describe "#check_chef_env" do
    it "checks that a chef env exists and creates it if not" do

      env = Chef::Environment.new()
      expect(Chef::Environment).to receive(:load).with("test").and_raise(@exception_404)
      allow(Chef::Environment).to receive(:new).and_return(env)
      allow(env).to receive(:create)

      item = @cmd.check_chef_env("test")
      expect(item.name).to eq("test")
 
    end
  end

  describe "#load_from_file" do
    it "loads from bag files" do

      expect(@cmd.loader).to receive(:file_exists_and_is_readable?).and_return(true)
      expect(@cmd.loader).to receive(:object_from_file).and_return(@cmd.loader.object_from_file(@topo1_file.path))

      item = @cmd.load_local_topo_or_exit(@topo1_name)
      expect(item.raw_data).to eq(@topo1_data)

    end
  end

  describe "#update_node" do
    it "does not create node" do

      expect(Chef::Node).to receive(:load).and_raise(@exception_404)
      expect(@cmd).not_to receive(:create_object)

      @cmd.update_node(@topo1_data["nodes"][1])

    end
  end
  
  describe "#merge_topo_properties" do
    it "merges topo properties into a node" do

     nodes = @cmd.merge_topo_properties(@topo1_item.raw_data[nodes], @topo1_item.raw_data)
     expect(nodes).to eq(@merged_data[:nodes])

    end
  end

end

