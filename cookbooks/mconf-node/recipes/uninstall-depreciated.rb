#
# Cookbook Name:: mconf-node
# Recipe:: uninstall-depreciated
# Author:: Felipe Cecagno (<felipe@mconf.org>)
# Author:: Mauricio Cruz (<brcruz@gmail.com>)
#
# This file is part of the Mconf project.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

version = nil
if File.exists?("/var/www/bigbluebutton/client/conf/config.xml")
    version = `cat /var/www/bigbluebutton/client/conf/config.xml | grep '<version>' | sed 's:.*<version>\\(.*\\)</version>.*:\\1:g'`.strip!
end

# remove some stuff related to the previous deploy bbb0.8-mconf-0.1
if version == "bbb0.8-mconf-0.1 - Mconf Node (mconf.org)"
    users = `cat /etc/passwd | cut -d: -f1`.split()

    # remove the cron jobs
    users.each do |usr|
      %w{ /usr/bin/live-notes-server.sh ~/tools/nagios-etc/cli/performance_report.py ~/tools/nagios-etc/cli/check_bbb_salt.sh }.each do |cmd|
        execute "remove #{cmd} cronjob as #{usr}" do
          user usr
          command "crontab -l | grep -v '#{cmd}' > /tmp/cron.jobs; crontab /tmp/cron.jobs; rm /tmp/cron.jobs"
          action :run
        end
      end
    end

    # kill the related processes
    %w{ performance_report.py live-notes-server.sh sbt-launch.jar }.each do |proc|
      execute "kill process #{proc}" do
        command "ps ax | grep #{proc} | grep -v grep | awk '{print $1}' | xargs kill; exit 0"
        user "root"
      end
    end

    # remove the applications placed into /usr/bin
    %w{ /usr/bin/sbt-launch.jar /usr/bin/sbt /usr/bin/live-notes-server.sh }.each do |f|
      file f do
        action :delete
      end
    end

    # remove the source folders
    users.each do |usr|
      %w{ tools downloads .ivy2 .sbt }.each do |dir|
        directory "/home/#{usr}/#{dir}/" do
          action :delete
          recursive true
        end
      end
    end
end

if version == "mconf-live0.3.3RC2" or version == "mconf-live0.3.4RC2"
    [ "/var/lib/tomcat6/webapps/demo/mconf_event.jsp", 
      "/var/lib/tomcat6/webapps/demo/mconf_event_conf.jsp"].each do |f|
        file f do
          action :delete
        end
    end

    directory node[:mconf][:live][:deploy_dir] do
      recursive true
      action :delete
    end

    # remove BigBlueButton repo
    apt_repository "bigbluebutton" do
      action :remove
    end

    %w{ red5 bbb-openoffice-headless }.each do |s|
      service s do
        action :stop
      end
    end

    service "live-notes-server" do
      provider Chef::Provider::Service::Upstart
      action [:stop, :disable]
    end

    # TODO remove all files related to the live notes server

    # we need to do it here because the apt-get autoremove mess everything after purge the bigbluebutton package
    remote_file "#{Chef::Config[:file_cache_path]}/#{node[:bbb][:openoffice][:filename]}" do
      source "#{node[:bbb][:openoffice][:repo_url]}/#{node[:bbb][:openoffice][:filename]}"
      action :create_if_missing
    end

    dpkg_package "openoffice" do
      source "#{Chef::Config[:file_cache_path]}/#{node[:bbb][:openoffice][:filename]}"
      action :install
      # removes the old installation of openoffice if this is an update
      notifies :run, 'execute[apt-get autoremove]', :immediately
    end

    %w{ bigbluebutton bbb-freeswitch bbb-playback-slides bbb-demo }.each do |pkg|
      package pkg do
        action :purge
      end
    end
end