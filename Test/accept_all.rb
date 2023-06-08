#!/usr/bin/env ruby

require 'json'
require 'byebug'
require 'time'


current_file_path = File.expand_path(File.dirname(__FILE__))
ITERATIONS = 7

start_seq_no = ARGV[0].strip.to_i
eye_addr = ARGV[1].strip
wallet_path = ARGV[2].strip
gql_url = ARGV[3].strip
master_file_base = ARGV[4].strip

def execute_command(command)
	p command
	`#{command}`
end

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

# p json
# ITERATIONS.times do |num|
# 	file_base = FILE_BASE + "#{num}/oracle"
# 	execute_command("oracle-ctrl init #{file_base}")
# 	execute_command("oracle-ctrl apply #{file_base} #{stake} #{VOTING_REWARD} #{file_base}.apply")
# 	execute_command("fift -s pw-req.fif #{wallet_path} #{eye_addr} #{start_seq_no + num} #{stake + VOTING_REWARD + 1} -B #{file_base}.apply.boc #{file_base}.pw")
# 	execute_command("tonos-cli -u #{gql_url} sendfile #{file_base}.pw.boc")
# 	p "- 0 - 0 - 0 - 0 - 0 - 0 - 0 -"
# 	sleep 1.5
# end
