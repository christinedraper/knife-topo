# See http://docs.opscode.com/config_rb_knife.html for more information on knife configuration options

current_dir = File.dirname(__FILE__)
log_level                :info
log_location             STDOUT
node_name                "workstation"
client_key               "#{current_dir}/dummy.pem"
validation_client_name   "validator"
validation_key           "#{current_dir}/dummy.pem"
chef_server_url          "http://10.0.1.1:8889"
cache_type               'BasicFile'
cache_options( :path => "#{ENV['HOME']}/.chef/checksums" )
cookbook_path            ["#{current_dir}/../cookbooks"]
