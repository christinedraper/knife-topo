#
# Cookbook Name:: testapp
# Recipe:: deploy
#
# Copyright 2014, ThirdWave Insights
#
#

user = node['testapp']['user'] 
appname = node['testapp']['appname'] 
basepath = node['testapp']['path'] 
fullpath = ::File.join(basepath, appname)

directory fullpath do
  owner user
  group user
  mode 00750
  action :create
end

cookbook_file ::File.join(fullpath, "server.js") do
  source 'server.js' 
  owner user
end

cookbook_file ::File.join(fullpath, "package.json") do
  source 'package.json' 
  owner user
end

cookbook_file ::File.join(fullpath, "index.html") do
  source 'index.html'  
  owner user
end

execute 'install_testapp' do
  # Need to run in login shell to pick up $HOME
  command "su -l -c 'cd #{fullpath} && npm install' #{user}"
end

template "testapp.upstart.conf" do
  path ::File.join("/etc/init", appname + ".conf")
  source 'nodejs.upstart.conf.erb'
  mode '0644'
  variables(
  :user => user,
  :node_dir => '/usr/local',
  :app_dir => basepath,
  :entry => appname
  )
end

service appname do
  provider Chef::Provider::Service::Upstart
  supports :restart => true, :start => true, :stop => true
  action [:restart]
end