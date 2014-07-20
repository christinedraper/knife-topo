#
# Cookbook Name:: testapp
# Recipe:: default
#
# Copyright 2014, ThirdWave Insights
#
#

include_recipe "testapp::db"
include_recipe "testapp::appserver"
include_recipe "testapp::deploy"