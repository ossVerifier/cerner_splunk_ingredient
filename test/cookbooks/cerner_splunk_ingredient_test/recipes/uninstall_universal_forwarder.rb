splunk_install 'universal_forwarder' do
  install_dir node['splunk']['install_dir']
  action :uninstall
end
