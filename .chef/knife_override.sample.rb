cookbook_copyright  'YOUR ORGANIZATION'
cookbook_license    'reserved'

knife[:vault_mode] = 'solo'

knife[:aws_config_file] = File.join(ENV['HOME'], '/.aws/configuration')
knife[:aws_credential_file] = File.join(ENV['HOME'], '/.aws/credentials')

knife[:openstack_auth_url] = "#{ENV['OS_AUTH_URL']}/tokens"
knife[:openstack_username] = ENV['OS_USERNAME']
knife[:openstack_password] = ENV['OS_PASSWORD'].inspect
knife[:openstack_tenant] = ENV['OS_TENANT_NAME']

knife[:vsphere_host] = ENV['VSPHERE_HOST']
knife[:vsphere_user] = ENV['VSPHERE_USER']
knife[:vsphere_pass] = ENV['VSPHERE_PASS']
knife[:vsphere_dc] = ENV['VSPHERE_DC']
knife[:vsphere_insecure] = ENV['VSPHERE_INSECURE']
