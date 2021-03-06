# Installs and configures the New Relic Infrastructure agent on Linux

deb_version_to_codename = {
  10 => 'buster',
  9 => 'stretch',
  8 => 'jessie',
  7 => 'wheezy',
  16 => 'xenial',
  14 => 'trusty',
  12 => 'precise'
}

case node['platform_family']
when 'debian'
  # Add public GPG key
  remote_file '/tmp/newrelic-infra.gpg' do
    source 'https://download.newrelic.com/infrastructure_agent/gpg/newrelic-infra.gpg'
  end
  execute 'add apt key' do
    command 'apt-key add /tmp/newrelic-infra.gpg'
  end

  # Create APT repo file
  apt_repository 'newrelic-infra' do
    uri 'https://download.newrelic.com/infrastructure_agent/linux/apt'
    distribution deb_version_to_codename[node['platform_version'].to_i]
    components ['main']
    arch 'amd64'
  end

  # Update APT repo
	execute 'apt-get update' do
		command 'apt-get update'
	end
when 'rhel'
  # Add Yum repo
  rhel_version = node['platform_version'].to_i
  yum_repository 'newrelic-infra' do
    description "New Relic Infrastructure"
    baseurl "https://download.newrelic.com/infrastructure_agent/linux/yum/el/#{rhel_version}/x86_64"
    gpgkey 'https://download.newrelic.com/infrastructure_agent/gpg/newrelic-infra.gpg'
    gpgcheck true
    repo_gpgcheck true
  end

  # Update Yum repo
  execute 'Update Infra Yum repo' do
    command "yum -q makecache -y --disablerepo='*' --enablerepo='newrelic-infra'"
  end
end


# Detect service provider
if node['platform_family'] == 'rhel' && node['platform_version'] =~ /^7/
  service_provider = Chef::Provider::Service::Systemd
else
  service_provider = Chef::Provider::Service::Upstart
end

case node['platform_family']
when 'debian'
  case node['platform']
  when 'ubuntu'
    case node['platform_version']
    when /^16/
      service_provider = Chef::Provider::Service::Systemd
    when /^14/
      service_provider = Chef::Provider::Service::Upstart
    end
  end
when 'rhel'
  case node['platform_version']
  when /^7/
    service_provider = Chef::Provider::Service::Systemd
  else
    service_provider = Chef::Provider::Service::Upstart
  end   
end

# Install the newrelic-infra agent
package 'newrelic-infra' do
  action node['newrelic-infra']['agent_action']
  version node['newrelic-infra']['agent_version'] unless node['newrelic-infra']['agent_version'].nil?
end


# Setup newrelic-infra service
service "newrelic-infra" do
  provider service_provider
  action [:enable, :start]
end


# Lay down newrelic-infra agent config
template '/etc/newrelic-infra.yml' do
  source 'newrelic-infra.yml.erb'
  owner 'root'
  group 'root'
  mode '00644'
  variables(
    'license_key' => node['newrelic-infra']['license_key']
  )
  notifies :restart, 'service[newrelic-infra]', :delayed
end
