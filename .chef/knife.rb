chef_user   = (ENV['CHEF_USER'] || ENV['USER'] || ENV['USERNAME']).downcase
chef_home   = ENV['CHEF_HOME']
chef_org    = ENV['CHEF_ORG']
chef_host   = ENV['CHEF_HOST']

chef_server_url         "https://#{chef_host}/organizations/#{chef_org}"
log_level               :info
log_location            STDOUT

node_name               chef_user
client_key              "#{chef_home}/.chef/hosts/#{chef_host}/#{chef_user}.pem"

validation_client_name  "#{chef_org}-validator"
validation_key          "#{chef_home}/.chef/hosts/" \
                        "#{chef_host}/#{validation_client_name}.pem"
cache_type              'BasicFile'
cache_options(path:     "#{chef_home}/.chef/#{chef_host}/#{chef_org}/checksums")

base_path               "#{chef_home}/hosts/#{chef_host}/#{chef_org}"
chefrc_cookbooks_path   "#{chef_home}/cookbooks"

case ENV['CHEFRC_MODE']
when 'multi'
  chef_repo_path        base_path
  cookbook_path         [chefrc_cookbooks_path, "#{base_path}/cookbooks"]
when 'single'
  chef_repo_path        "#{base_path}/#{chef_user}"
  cookbook_path         [chefrc_cookbooks_path,
                         "#{base_path}/#{chef_user}/cookbooks"]
end

# For overrides and additional knife config, i.e. *_proxy directives
knife_override = "#{chef_home}/.chef/knife_override.rb"
if ::File.exist?(knife_override)
  instance_eval(IO.read(knife_override), knife_override, 1)
end
