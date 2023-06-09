#!/usr/bin/env ruby

require 'json'
require 'byebug'
require 'time'


current_file_path = File.expand_path(File.dirname(__FILE__))

def execute_command(command)
	`#{command}`
end

wallet_path = ENV["WL"] || ARGV[0].strip
gql_url = ENV["GQL"] || ARGV[1].strip

out = `fift -s pw-req.fif #{wallet_path} 0:0000000000000000000000000000000000000000000000000000000000000000 0 0`
out[/\(from state-init\)[\s\S]+?(0\:\w+?)\s/]
address = $1
File.delete("pw-query.boc")
execute_command("tonos-cli -u #{gql_url} account -d \"pw-data.boc\" #{address}")
seq_no = `fift -s parse-pw-seqno.fif pw-data.boc`.strip
File.delete("pw-data.boc")
puts seq_no