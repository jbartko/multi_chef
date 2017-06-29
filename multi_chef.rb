#!/usr/bin/env ruby

require 'chef/config'
require 'English'
require 'ipaddr'
require 'net/https'
require 'optparse'
require 'resolv'
require 'tempfile'
require 'uri'

ARGV << '--help' if ARGV.empty?

options = {
  api_host: ENV['CHEF_HOST'] || 'api.chef.io',
  email: ENV['CHEF_EMAIL'] ||
         begin
           `git config user.email`.chomp
         rescue
           nil
         end,
  home: ENV['CHEF_HOME'] || File.expand_path(File.dirname(__FILE__)),
  mode: ENV['CHEFRC_MODE'] || 'single',
  org: ENV['CHEF_ORG'] || nil,
  user: ENV['CHEF_USER'] || nil
}

repo_path = nil
repo_path_template = '%{home}/hosts/%{host}/%{org}/%{user}'

parser = OptionParser.new do |opts|
  opts.banner = 'Usage: multi_chef.rb [-h|--help]'
  opts.banner += "\nUsage: multi_chef.rb [-m CHEFRC_MODE] [-c CHEF_HOME]"
  opts.banner += ' [-a CHEF_HOST] -o CHEF_ORG -u CHEF_USER [-e CHEF_EMAIL]'

  opts.on('-c', '--chef-home [CHEF_HOME]', 'Chef home',
          '  Default: directory containing multi_chef.rb') do |opt_c|
    begin
      if opt_c.to_s.empty?
        raise 'No argument provided to -c|--chef-home option!'
      else
        unless File.directory?(opt_c)
          raise "CHEF HOME #{opt_c} does not exist!" \
            "\n\nCreate it with:\n\tmkdir -p #{File.expand_path(opt_c)}/.chef"
        end
      end
    rescue
      STDERR.puts $ERROR_INFO.to_s
      exit 1
    end
    options[:home] = File.expand_path(opt_c)
  end

  opts.on('-a', '--api-server [CHEF_HOST]', 'Chef API server hostname or IP',
          '  Default: api.chef.io') do |opt_a|
    begin
      Resolv.getaddress(opt_a)
    rescue
      STDERR.puts "#{opt_a} is not a resolvable FQDN or IP address"
      exit 1
    end
    begin
      uri = URI.parse("https://#{opt_a}/")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      case Chef::Config.ssl_verify_mode
      when :verify_peer
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      when :verify_none
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
      request = Net::HTTP::Get.new(uri.request_uri)
      response = http.request(request)
      unless response['location'] =~ %r{https://#{opt_a}(:#{uri.port})*/(login|signup)/?}
        unless response.body =~ /(Looking For the Chef Server|main endpoint for all of the Chef APIs)/
          raise "#{opt_a} does not appear to be a Chef API service endpoint?"
        end
      end
    rescue
      STDERR.puts $ERROR_INFO.to_s
      exit 1
    end
    options[:api_host] = opt_a
  end

  opts.on('-m', '--mode single|multi', 'Chef repo mode',
          '  Default: single') do |opt_m|
    case opt_m
    when /^multi$|^single$/
      options[:mode] = opt_m
    else
      STDERR.puts "argument to -m|--mode must be either 'single' or 'multi'"
      exit 1
    end
    options[:mode] = opt_m
  end

  opts.on('-o', '--org-name CHEF_ORG',
          'Chef organization name (required)') do |opt_o|
    options[:org] = opt_o
  end

  opts.on('-u', '--chef-user CHEF_USERNAME',
          'Chef username (required)') do |opt_u|
    raise 'No argment provided to -u|--chef-user option!' if opt_u.to_s.empty?

    repo_path = repo_path_template % {
      home: options[:home],
      host: options[:api_host],
      org: options[:org],
      user: options[:mode] == 'single' ? opt_u : ''
    }

    client_key_path = "#{options[:home]}/.chef/hosts/#{options[:api_host]}"
    client_key      = "#{client_key_path}/#{opt_u}.pem"
    mkdir_targets = [
      "#{options[:home]}/{,.chef/}hosts/#{options[:api_host]} \\",
      "#{repo_path}/cookbooks \\", "#{options[:home]}/cookbooks"
    ]
    begin
      raise IOError, "No client key #{client_key}" unless File.exist?(client_key)
      raise IOError, "No repo path #{repo_path}" unless Dir.exist?(repo_path)
    rescue IOError
      STDERR.puts $ERROR_INFO.to_s
      STDERR.puts "\nCreate the directory structure with:"
      STDERR.puts "\tmkdir -p " \
        "#{mkdir_targets.join("\n\t  ").gsub(ENV['HOME'], '~')}"
      unless File.exist?(client_key)
        STDERR.puts "\nThen move #{opt_u}'s client key to:\n\t" \
          "#{client_key.gsub(ENV['HOME'], '~')}"
        if options[:mode] == 'multi'
          STDERR.puts "\nFinally, protect the key:\n\tchmod go-rwx " \
            "#{client_key.gsub(ENV['HOME'], '~')}"
        end
      end
      exit 1
    end
    options[:user] = opt_u
  end

  opts.on('-e', '--chef-email CHEF_EMAIL', 'Chef email address (required)',
          '  Default: git config user.email') do |opt_e|
    options[:email] = opt_e
  end

  opts.on('-h', '--help', 'Show this help') do
    STDERR.puts opts
    exit 1
  end
end

begin
  parser.parse!
  mandatory = [:email, :org, :user]
  missing = mandatory.select { |param| options[param].nil? }
  unless missing.empty?
    STDERR.puts "Missing options: #{missing.join(', ')}"
    STDERR.puts parser
    exit 1
  end
rescue OptionParser::InvalidOption, OptionParser::MissingArgument
  STDERR.puts $ERROR_INFO.to_s
  STDERR.puts parser
  exit 1
end

repo_path = repo_path_template % {
  home: options[:home],
  host: options[:api_host],
  org: options[:org],
  user: options[:mode] == 'single' ? options[:user] : ''
}

multi_chef_path = File.expand_path(__FILE__)
multi_chef_dir = File.dirname(multi_chef_path)
Dir.mkdir "#{ENV['HOME']}/.berkshelf" unless ::Dir.exist?("#{ENV['HOME']}/.berkshelf")
berkshelf_config_path = "#{ENV['HOME']}/.berkshelf/config.json"
berkshelf_config = ::File.open(berkshelf_config_path, 'w')
begin
  berkshelf_config.write <<-EOH.gsub(/^\s{4}/, '')
    {
      "chef": {
        "client_key": "#{options[:home]}/.chef/hosts/#{options[:api_host]}/#{options[:user]}.pem",
        "chef_server_url": "https://#{options[:api_host]}/organizations/#{options[:org]}",
        "node_name": "#{options[:user]}"
      }
    }
  EOH
ensure
  berkshelf_config.close
end

puts <<-EOH.gsub(/^\s{2}/, '')
  export CHEF_EMAIL='#{options[:email]}'
  export CHEF_HOME='#{options[:home]}'
  export CHEF_HOST='#{options[:api_host]}'
  export CHEF_ORG='#{options[:org]}'
  export CHEF_REPO='#{repo_path}'
  export CHEF_USER='#{options[:user]}'
  export CHEFRC_MODE='#{options[:mode]}'
  knife() {
    #{`which knife`.strip} "$@" --config #{multi_chef_dir}/.chef/knife.rb
  }
  chef-switch() {
    #{multi_chef_path} "$@" >/dev/null && eval "$(#{multi_chef_path} \"$@\")"
  }
  echo "CHEF_REPO: $CHEF_REPO"
EOH
