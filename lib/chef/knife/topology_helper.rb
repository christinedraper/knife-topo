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

require 'chef/data_bag'
require 'chef/node'
require 'chef/encrypted_data_bag_item'
require 'chef/environment'
require 'chef/knife/core/object_loader'
require 'chef/rest'

class Chef
  class Knife
    module TopologyHelper
      
      # load one or more topologies from file
      def load_topologies(topology_file_path)

        if ! topology_file_path.end_with?('.js', '.json')
          show_usage
          ui.fatal "TOPOLOGY_FILE must be a '.js' or '.json' file"
          exit(1)
        end

        topologies = loader.object_from_file(topology_file_path)
        topologies = [topologies] if !topologies.kind_of?(Array)
        
        topologies
      end
      
      # create the topology data bag
      def create_bag(bag_name)
        # check that the name is valid
        begin
          Chef::DataBag.validate_name!(bag_name)
        rescue Chef::Exceptions::InvalidDataBagName => e
          ui.fatal(e.message)
          exit(1)
        end

        # create the data bag
        begin
          data_bag = Chef::DataBag.new
          data_bag.name(bag_name)
          data_bag.create
          ui.info("Created topology data bag [#{bag_name}]")
        rescue Net::HTTPServerException => e
          raise unless e.to_s =~ /^409/
          data_bag  = Chef::DataBag.load(bag_name)
          ui.info("Topology data bag #{bag_name} already exists")
        end

        data_bag
      end

        # make sure the chef environment exists
      def check_chef_env(chef_env_name)

        if chef_env_name
          begin
            chef_env = Chef::Environment.load(chef_env_name)
          rescue Net::HTTPServerException => e
            raise unless e.to_s =~ /^404/
            ui.info "Creating chef environment " + chef_env_name
            chef_env = Chef::Environment.new()
            chef_env.name(chef_env_name)
            chef_env.create
          end
        end

        chef_env
      end
      
      # recursive merge that retains all keys
      def prop_merge!(hash, other_hash)
        other_hash.each do |key, val|
          if val.kind_of?(Hash) && hash[key]
            prop_merge!(hash[key], val)
          else
            hash[key] = val
          end
        end
        
        hash
      end   

      # Merges topology properties into nodes, returning the merged nodes
      def merge_topo_properties(nodes, topo_hash)

        if nodes && nodes.length > 0
          merged_nodes = nodes ? nodes.clone : []
          merged_nodes.each do |nodeprops|

            normal_defaults = topo_hash['normal'] ? 
              Marshal.load(Marshal.dump(topo_hash['normal'])) : {}
            nodeprops['normal'] ||= {}
            nodeprops['normal'] = prop_merge!(normal_defaults, nodeprops['normal'])
            nodeprops['normal'] = prop_merge!(nodeprops['normal'], nodeprops['attributes']) if nodeprops['attributes']
            nodeprops['normal']  = prop_merge!(nodeprops['normal'], { "topo" => { "name" => topo_hash['name'] }})

            nodeprops['chef_environment'] ||=  topo_hash['chef_environment'] if topo_hash['chef_environment']

            # merge in the topology tags
            nodeprops['tags'] ||= []
            nodeprops['tags'] |= topo_hash['tags'] if topo_hash['tags'] && topo_hash['tags'].length > 0
 
          end
        end

        merged_nodes

      end

      
    # Update an existing node
    def update_node(node_updates)
    
      config[:disable_editing] = true
    
      node_name = node_updates['name']
      begin
        
        # load then update and save the node
        node = Chef::Node.load(node_name)
        
        if node_updates['chef_environment'] && node_updates['chef_environment'] != node['chef_environment']
          check_chef_env(node_updates['chef_environment']) 
        end
        
        if updated_values = update_node_with_values(node, node_updates)
          ui.info "Updating #{updated_values.join(', ')} on node #{node.name}"
          node.save
          ui.output(format_for_display(node)) if config[:print_after]
        else
          ui.info "No  updates found for node #{node.name}"
        end

      rescue Net::HTTPServerException => e
        raise unless e.to_s =~ /^404/
        # Node has not been created
      end
      
      return node
    end

      # Make updates into the original node, returning the list of updated properties.
      def update_node_with_values(node, updates)
        updated_properties = []
        
        # merge the normal attributes (but not tags)
        normal_updates = updates['normal'] || {}
        normal_updates.delete('tags')
        original_normal = node.normal.clone()
        prop_merge!(node.normal, normal_updates) 
        updated_properties << 'normal' if (original_normal != node.normal)

        # merge with existing runlist
        if updates['run_list']
          updated_run_list = RunList.new
          updates['run_list'].each { |e| updated_run_list << e }
          if (updated_run_list != node.run_list)
            updated_properties << 'run_list'
            node.run_list(*updated_run_list)
          end
        end

        # update chef env
        new_chef_environment = updates['chef_environment']
        if new_chef_environment && new_chef_environment != node.chef_environment
          updated_properties << 'chef_environment'
          node.chef_environment(new_chef_environment)
        end

        # merge tags
        orig_num_tags = node.tags.length
        updates['tags'] ||= [] # make sure tags are initialized
        node.tag(*updates['tags'])
        updated_properties << 'tags' if node.tags.length > orig_num_tags

        # return false if no updates, else return array of property names
        updated_properties.length > 0 && updated_properties
      end

      # Load a topology from local data bag item file
      def load_from_file(bag_name, topo_name)
        
        topo_file = File.join(Dir.pwd, "#{topologies_path}", bag_name, topo_name + '.json')
        return unless (loader.file_exists_and_is_readable?(topo_file))
 
        item_data = loader.object_from_file(topo_file)
        item_data = if use_encryption
          secret = read_secret
          Chef::EncryptedDataBagItem.encrypt_data_bag_item(item_data, secret)
        else
          item_data
        end
        item = Chef::DataBagItem.new
        item.data_bag(bag_name)
        item.raw_data = item_data
        item
      end

      # read in the topology bag item
      def load_from_server(bag_name, item_name = nil)
        begin
          if (item_name)
            item = Chef::DataBagItem.load(bag_name, item_name)
            item = Chef::EncryptedDataBagItem.new(item.raw_data, read_secret) if use_encryption
          else
            item = Chef::DataBag.load(bag_name)
          end
        rescue Net::HTTPServerException => e
          raise unless e.to_s =~ /^404/
        end
        item
      end

      # Replace existing run list in a node
      def set_run_list(node, entries)
        node.run_list.run_list_items.clear
        entries.each { |e| node.run_list << e }
      end

      # Name of the topology bag
      def topo_bag_name(name=nil)
        @topo_bag_name = name if (name)
        @topo_bag_name ||= "topologies"
      end

      # Path for the topologies data bags.
      # For now, use the standard data_bags path for our topologies bags
      def topologies_path
        @topologies_path ||= "data_bags"
      end

      # Loader to get data bag items from file
      def loader
        @loader ||= Knife::Core::ObjectLoader.new(DataBagItem, ui)
      end

      # Determine if the bag items are/should be encrypted on server
      # NOTE: This option isnt currently enabled
      def use_encryption
        if config[:secret] && config[:secret_file]
          ui.fatal("please specify only one of --secret, --secret-file")
          exit(1)
        end
        config[:secret] || config[:secret_file]
      end

      # Return the secret key to encrypt/decrypt data bag items
      def read_secret
        if config[:secret]
          config[:secret]
        else
          Chef::EncryptedDataBagItem.load_secret(config[:secret_file])
        end
      end
      
      # initialize args for another knife command
      def initialize_cmd_args(args, new_name_args)
        args = args.dup
        args.shift(2 + @name_args.length) 
        cmd_args  = new_name_args + args
      end

      # run another knife command
      def run_cmd(command_class, args)        
        command = command_class.new(args)
        command.config[:config_file] = config[:config_file]
        command.configure_chef
        command.run
        
        command
      end
      
      # upload cookbooks - will warn and continue if upload fails (e.g. may be frozen)
      def upload_cookbooks(args)      
        begin
          run_cmd(Chef::Knife::TopoCookbookUpload, args)
        rescue Exception => e
            raise if Chef::Config[:verbosity] == 2
        end        
      end
      
      def display_name (topo)
        topo['name'] + ((topo['version']) ? " version " + format_topo_version(topo) : "")
      end

      # Topology version
      def format_topo_version(topo)
        version = nil
        if topo['version'] 
          version = topo['version']
          version = version + '-' + topo['buildid'] if (topo['buildid'])
        end
        
        version
      end
      
      # check if resource exists
      def resource_exists?(relative_path)
        rest.get_rest(relative_path)
        true
      rescue Net::HTTPServerException => e
        raise unless e.response.code == "404"
        false
      end
      
      # Setup the bootstrap args and run the bootstrap command
      def run_bootstrap(node_data, bootstrap_args, overwrite=false)
        node_name = node_data['name']
          
        args = bootstrap_args
        
        # We need to remove the --bootstrap option, if it exists, because its not valid for knife bootstrap
        args -= ['--bootstrap']
          
        # And set up the node-specific data
        args += ['-N', node_name] if(node_name)
        args += ['-E', node_data['chef_environment']] if(node_data['chef_environment'])
        args[1] = node_data['ssh_host']
        args += [ '--ssh-port', node_data['ssh_port']] if node_data['ssh_port']
        args += [ '--run-list' , node_data['run_list'].join(',')] if node_data['run_list']
        args += [ '--json-attributes' , node_data['normal'].to_json] if node_data['normal']
        
        if overwrite
          ui.info("Node #{node_name} exists and will be overwritten")
          # delete node first so vault refresh does not pick up existing node
          begin
            rest.delete("nodes/#{node_name}")
            rest.delete("clients/#{node_name}")
          rescue Net::HTTPServerException => e
            raise unless e.response.code == "404"
          end
        end
      
        ui.info "Bootstrapping node #{node_name}"
        begin
          run_cmd(Chef::Knife::Bootstrap, args)
          true
        rescue Exception => e
          raise if Chef::Config[:verbosity] == 2
          ui.warn "bootstrap of node #{node_name} exited with error"
          humanize_exception(e)
          false
        end
      end

    end
  end
end
