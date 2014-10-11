# encoding: UTF-8

# this file sets up the basic framework.
# the file then loads all the .rb files from the ./config , ./lib and ./app folders.
# the file sets the default logger

# also set by other files, change to nil to avoid
Encoding.default_internal = 'utf-8'
Encoding.default_external = 'utf-8'

#set up root object, it will be used by the environment and\or the anorexic extension gems.
Root ||= Pathname.new(File.dirname(__FILE__)).expand_path

# ensure development mode? (comment before production, environment dependent)
ENV["RACK_ENV"] ||= "development"

# using bundler to load gems (including the anorexic gem)
require 'bundler'
Bundler.require

# set up Anorexic logs - Heroku logs to STDOUT, this machine logs to log file
Anorexic.create_logger (ENV['DYNO']) ? STDOUT : Root.join('logs','server.log')


# load all config files
Dir[File.join "{config}", "**" , "*.rb"].each {|file| load Pathname.new(file).expand_path}

# load all library files
Dir[File.join "{lib}", "**" , "*.rb"].each {|file| load Pathname.new(file).expand_path}

# load all application files
Dir[File.join "{app}", "**" , "*.rb"].each {|file| load Pathname.new(file).expand_path}