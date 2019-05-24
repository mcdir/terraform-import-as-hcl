#!/usr/bin/env ruby

# This script imports a Terraform resource into .tfstate AND creates an HCL resource definition in .tf file.
# The implementation is super naive and more than likely to have bugs and corner cases.
# For a proper solution, follow: https://github.com/hashicorp/terraform/issues/15608

def usage
  puts <<EOF
Usage:
  #{__FILE__} resource_type.resource_name resource_id [other parameters]
Equivalent of:
  terraform resource_type.resource_name resource_id [other parameters]
EOF
  exit 1
end

resource_key = ARGV.shift || usage
resource_type, resource_name = resource_key.split('.')
resource_id = ARGV.shift || usage

require 'justrun'
status = JustRun.command "terraform import #{resource_type}.#{resource_name} #{resource_id}" do |line, type|
  out = type == 'stdout' ? $stdout : $stderr
  out.puts line
end

if status != 0
  puts "Terraform run not successful - exit status #{status}. Aborting."
  exit 2
end

require 'json'
state = JSON.load File.read 'terraform.tfstate'
attributes = state['modules'][0]['resources'][resource_key]['primary']['attributes']

resource = {}

attributes.each do |attr, value|
  if attr.include? '.#'
    attr_array, _ = attr.split '.#'
    resource[attr_array] = []
    attributes.keys.select { |e| e.start_with? "#{attr_array}." }.each do |key|
      next if key == attr
      resource[attr_array] << attributes[key]
    end
  elsif attr.include? '.%'
    attr_array, _ = attr.split '.%'
    resource[attr_array] = {}
    attributes.keys.select { |e| e.start_with? "#{attr_array}." }.each do |key|
      next if key == attr
      new_key = key[attr_array.size + 1 .. -1]
      resource[attr_array][new_key] = attributes[key]
    end
  elsif attr.include? '.'
    next
  # elsif attr == 'id'
  #   next
  else
    resource[attr] = value
  end
end

def escape val
  if val == ''
    '""'
  elsif val == 'true'
    'true'
  elsif val == 'false'
    'false'
  elsif val.is_a? Array
    val
  elsif val.is_a? Hash
    if val.empty?
      '{}'
    else
      ret = '{ '
      ret << val.map { |k, v| "#{k} = #{escape v}" }.join(', ')
      ret << ' }'
    end
  elsif val.to_i.to_s == val
    val
  else
    "\"#{val}\""
  end
end


hcl = "resource \"#{resource_type}\" \"#{resource_name}\" {\n"
resource.each do |key, val|
  hcl << "  #{key} = #{escape val}\n"
end
hcl << "}\n"

resource_file = "#{resource_type}_#{resource_name}.tf"
require 'fileutils'
if File.exist? resource_file
  FileUtils.mv resource_file, "#{resource_file}.backup"
end
File.write resource_file, hcl
