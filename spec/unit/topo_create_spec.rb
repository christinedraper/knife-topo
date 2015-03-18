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

require 'rspec'
require 'rspec/mocks'
require File.expand_path('../../spec_helper', __FILE__)
require 'chef/knife/topo_create'
require 'chef/node'

#Chef::Knife::TopoCreate.load_deps

describe Chef::Knife::TopoCreate do
  before :each do
    Chef::Config[:node_name]  = "christine_test"
    @cmd = Chef::Knife::TopoCreate.new(  [ 'topo1' ] )

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
      "name" => "node1"
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

    @topo1_item = Chef::DataBagItem.new
    @topo1_item.raw_data = @cmd.loader.object_from_file(@topo1_file.path)
    @topo1_item.data_bag(@topobag_name)

    @exception_404 =   Net::HTTPServerException.new("404 Not Found", Net::HTTPNotFound.new("1.1", "404", "Not Found"))

  end
  describe "#run" do
    it "loads from bag files and creates objects on server" do
      @cmd.name_args = [@topo1_name]
      @cmd.config[:data_bag] = @topobag_name

      bag = Chef::DataBag.new
      allow(Chef::DataBag).to receive(:new) { bag }
      expect(bag).to receive(:create)

      expect(@cmd).to receive(:load_from_file).with(@topobag_name, @topo1_name).and_return(@topo1_item)
      expect(@cmd).to receive(:upload_cookbooks)
      expect(@cmd).to receive(:check_chef_env).with("test")

      expect(@topo1_item).to receive(:create)

      expect(@cmd).to receive(:update_node).with(@merged_data['nodes'][0])
      expect(@cmd).to receive(:update_node).with(@merged_data['nodes'][1])

      @cmd.run

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

      item = @cmd.load_from_file(@topobag_name, @topo1_name)
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

