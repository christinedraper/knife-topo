#
# Cookbook Name:: testapp
# Recipe:: db
#
# Copyright 2014, ThirdWave Insights
#

include_recipe "mongodb::10gen_repo"
include_recipe "mongodb::default"