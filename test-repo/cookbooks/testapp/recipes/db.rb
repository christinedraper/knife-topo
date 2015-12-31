#
# Cookbook Name:: testapp
# Recipe:: db
#
# Copyright 2014, ThirdWave Insights
#

# Workaround as in https://github.com/edelight/chef-mongodb/issues/316 to force recipe to use mongodb not mongod service (!)
node.override['mongodb']['default_init_name'] = 'mongod'
  
include_recipe 'mongodb::mongodb_org_repo'
include_recipe 'mongodb::default'