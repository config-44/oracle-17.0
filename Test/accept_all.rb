#!/usr/bin/env ruby

require 'json'
require 'byebug'
require 'time'


current_file_path = File.expand_path(File.dirname(__FILE__))

def execute_command(command)
	p command
	system("#{command}")
end

eye_addr = ARGV[0].strip
master_file_base = ARGV[1].strip
wallet_path = ENV["WL"] || ARGV[2].strip
gql_url = ENV["GQL"] || ARGV[3].strip
start_seq_no = `ruby #{current_file_path}/read_seqno.rb #{wallet_path} #{gql_url}`.strip.to_i


info = `oracle-ctrl info #{eye_addr}`
info[/PROPOSAL_LIST\n.+\[oracle_ctrl\]\s+?(\[.+?\])/]
json = $1
json = JSON.parse(json)

json.select! do |el| 
	el['valid_until'][/^(\d+)/]
	time_stamp = $1.to_i
	(time_stamp - 60 * 5) > Time.new.to_i	
end

json.each_with_index do |proposal, index|
	execute_command("oracle-ctrl master #{master_file_base} #{proposal['pidx']} master.body")
	execute_command("fift -s pw-req.fif #{wallet_path} #{eye_addr} #{start_seq_no + index} 2 -B master.body.boc master.pw")
	execute_command("tonos-cli -u #{gql_url} sendfile master.pw.boc")
	File.delete("master.body.boc")
	File.delete("master.pw.boc")
	p "- 0 - 0 - 0 - 0 - 0 - 0 - 0 -"
	sleep 1.5
end

