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
require 'chef/knife/topo_create'

describe 'KnifeTopo::TopoCreate Overwrite' do
  before :each do
    Chef::Config[:node_name]  = 'christine_test'

    data = UnitTestData.new
    @topobag_name = 'testsys_test'
    @topo1_data = data.topo1
    @merged_data = data.topo1_merged

    @topo_bag = Chef::DataBag.new
    allow(Chef::DataBag).to receive(:new) { @topo_bag }
    allow(@topo_bag).to receive(:create)

    @topo1_item = Chef::Topology.new
    allow(Chef::Topology).to receive(:new) { @topo1_item }

    @topo1_item.raw_data = data.topo1
    @topo1_item.data_bag(@topobag_name)
  end

  it 'bootstraps existing node with --bootstrap and --overwrite '\
    'if it has ssh_host, otherwise update' do
    cmd = KnifeTopo::TopoCreate.new(
      ['topo1', '--bootstrap', '--overwrite', "--data-bag=#{@topobag_name}"]
    )

    expect(cmd).to receive(
      :load_local_topo_or_exit
    ).with('topo1').and_return(@topo1_item)
    allow(cmd).to receive(:upload_artifacts)
    allow(cmd).to receive(:resource_exists?).with(
      'nodes/node1'
    ).and_return(true)
    allow(cmd).to receive(:resource_exists?).with(
      'nodes/node2'
    ).and_return(true)
    allow(cmd).to receive(:check_chef_env).with('test')

    allow(@topo1_item).to receive(:create)

    expect(cmd).to receive(
      :run_bootstrap
    ).with(@merged_data['nodes'][0], anything, true).and_return(true)
    allow(cmd).to receive(
      :update_node
    ).with(@merged_data['nodes'][0]).and_return(nil)
    expect(cmd).to receive(:update_node).with(@merged_data['nodes'][1])

    cmd.run

    expect(cmd.results[:bootstrapped]).to eq(['node1'])
    expect(cmd.results[:skipped]).to eq([])
    expect(cmd.results[:skipped_ssh]).to eq(['node2'])
    expect(cmd.results[:failed]).to eq([])
  end
end
