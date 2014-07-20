#
# Cookbook Name:: testapp
# Recipe:: deploy
#
# Copyright 2014, ThirdWave Insights
#
#

directory "/home/vagrant/ypo" do
  owner "vagrant"
  group "vagrant"
  mode 00750
  action :create
end

cookbook_file "/home/vagrant/ypo/server.js" do
  source 'server.js' 
end

cookbook_file "/home/vagrant/ypo/package.json" do
  source 'package.json' 
end

cookbook_file "/home/vagrant/ypo/index.html" do
  source 'index.html'  
end

execute 'install_ypo' do
  cwd "/home/vagrant/ypo"
  user "vagrant"
  command "npm install"
end

template "ypo.upstart.conf" do
  path "/etc/init/ypo.conf"
  source 'nodejs.upstart.conf.erb'
  mode '0644'
  variables(
  :user => 'vagrant',
  :node_dir => '/usr/local',
  :app_dir => '/home/vagrant',
  :entry => 'ypo'
  )
end

service 'ypo' do
  provider Chef::Provider::Service::Upstart
  supports :restart => true, :start => true, :stop => true
  action [:restart]
end