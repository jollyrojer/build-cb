# Recipe cookbook-qubell-build  app  from git , parse war files and copy to cookbook-qubell-build target
#
case node['platform_family']
  when "debian"
    execute "update packages cache" do
      command "apt-get update"
    end
  end

include_recipe "java"
include_recipe "git"
case node['platform_family']
  when "debian"
    include_recipe "apt"
    apt_repository "apache-maven3" do
      uri "http://ppa.launchpad.net/natecarlson/maven3/ubuntu/"
      distribution node['lsb']['codename']
      components   ['main']
      keyserver    'keyserver.ubuntu.com'
      key "3DD9F856"
    end
    package "maven3" do
      action :install
    end
    link "/usr/sbin/mvn" do
      to "/usr/bin/mvn3"
    end
  when "rhel"
    mvn_version = "3.2.1"
    remote_file "/opt/apache-maven.tar.gz" do
      source "http://mirror.olnevhost.net/pub/apache/maven/binaries/apache-maven-#{mvn_version}-bin.tar.gz"
    end

    bash "unpack apache-maven" do
      code <<-EEND
        tar -zxf /opt/apache-maven.tar.gz -C /opt/ && chmod 755 /opt/apache-maven-#{mvn_version}/bin/mvn
      EEND
    end

    link "/usr/sbin/mvn" do
      to "/opt/apache-maven-#{mvn_version}/bin/mvn"
    end
  end

git_url="/tmp/gittest"
new_git_url = "#{node['scm']['repository']}?#{node['scm']['revision']}"
cur_git_url = ""

 directory node['cookbook-qubell-build']['target'] do
   action :create
 end

if File.exist?(git_url)
  cur_git_url = File.read(git_url)
end

if !cur_git_url.eql? new_git_url

  case node['scm']['provider']
    when "git"
      bash "clean #{node['cookbook-qubell-build']['dest_path']}/webapp" do
        code <<-EEND
          rm -rf #{node['cookbook-qubell-build']['dest_path']}/webapp
        EEND
      end
      git "#{node['cookbook-qubell-build']['dest_path']}/webapp" do
        repository node['scm']['repository']
        revision node['scm']['revision']
        action :sync
      end
    when "subversion"
      Chef::Provider::Subversion
    when "remotefile"
      Chef::Provider::RemoteFile::Deploy
    when "file"
      Chef::Provider::File::Deploy
  end

  execute "package" do
    command "cd #{node['cookbook-qubell-build']['dest_path']}/webapp; mvn clean package -Dmaven.test.skip=true" 
end
  execute "copy_wars" do
      command "cd #{node['cookbook-qubell-build']['dest_path']}/webapp; for i in $(find -regex '.*/target/[^/]*.war');do cp $i #{node['cookbook-qubell-build']['target']};done"
      notifies :create, "ruby_block[set attrs]"
  end


  ruby_block "set attrs" do
     block do
        dir = node['cookbook-qubell-build']['target']
        artifacts = (Dir.entries(dir).select {|f| !File.directory? f}).map {|f| "file://" + File.join(dir, f)}
        artifacts = artifacts.sort
        node.set['cookbook-qubell-build']['artifacts'] = artifacts
     end
  end

  File.open(git_url, 'w') { |file| file.write("#{node['scm']['repository']}?#{node['scm']['revision']}") }
end
