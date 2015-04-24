#! /usr/bin/env ruby
#
#   freenas-alerts
#
# DESCRIPTION:
#   Check health of FreeNAS alerts
#
#   This plugin is based on the uchiwa-health.rb check by Grant Heffernan
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: json
#   gem: uri
#   gem: yaml
#
# USAGE:
#  #YELLOW
#
# NOTES:
#
# LICENSE:
#   Copyright 2014 Grant Heffernan <grant@mapzen.com>
#   Copyright 2015 Matthew Snyder <xsappyx@gmail.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'net/http'
require 'net/https'
require 'json'
require 'uri'
require 'yaml'

class FreenasAlertCheck < Sensu::Plugin::Check::CLI
  option :host,
         short: '-h HOST',
         long: '--host HOST',
         description: 'Your FreeNAS hostname',
         required: true,
         default: 'localhost'

  option :port,
         short: '-P PORT',
         long: '--port PORT',
         description: 'Your FreeNAS port',
         required: true,
         default: 80

  option :username,
         short: '-u USERNAME',
         long: '--username USERNAME',
         description: 'Your FreeNAS username',
         default: 'root',
         required: false

  option :password,
         short: '-p PASSWORD',
         long: '--password PASSWORD',
         description: 'Your FreeNAS password',
         required: false

  def json_valid?(str)
    JSON.parse(str)
    return true
  rescue JSON::ParserError
    return false
  end

  def run
    endpoint = "http://#{config[:host]}:#{config[:port]}"
    url      = URI.parse(endpoint)

    begin
      res = Net::HTTP.start(url.host, url.port) do |http|
        req = Net::HTTP::Get.new('/api/v1.0/system/alert/')
        req.basic_auth config[:username], config[:password] if config[:username] && config[:password]
        http.request(req)
      end
    rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError, Net::HTTPBadResponse,
           Net::HTTPHeaderSyntaxError, Net::ProtocolError, Errno::ECONNREFUSED => e
      critical e
    end

    msg = ""
    level = ""

    for response in YAML.load(res.body)
      if json_valid?(response.to_json)
        json = JSON.parse(response.to_json)
        json.keys.each do |k|
          if k.to_s == 'level'
            case k.to_s
            when 'CRIT'
              level = 'CRIT'
            when 'WARN'
              level = 'WARN' if level != 'CRIT'
            when 'OK'
              level = 'OK' if level != 'CRIT' || level != 'WARN'
            end
          elsif k.to_s == 'message' 
            msg += "\"#{json['message']}\""
          end
        end
      else
        critical 'Response contains invalid JSON'
      end
    end

    message msg
    critical if level == 'CRIT'
    warning if level == 'WARN'
    ok
  end
end
