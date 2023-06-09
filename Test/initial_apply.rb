#!/usr/bin/env ruby


current_file_path = File.expand_path(File.dirname(__FILE__))
STAKE = 11
VOTING_REWARD = 2

def execute_command(command)
	p command
	system("#{command}")
end

eye_addr = ARGV[0].strip
wallet_path = ARGV[1].strip
gql_url = ARGV[2].strip
ITERATIONS = ARGV[3].strip.to_i
FILE_BASE = ARGV[4].strip
p "ruby #{current_file_path}/read_seqno.rb #{wallet_path} #{gql_url}"
start_seq_no = `ruby #{current_file_path}/read_seqno.rb #{wallet_path} #{gql_url}`.strip.to_i

ITERATIONS.times do |num|
	file_base = FILE_BASE + "#{num}/oracle"
	stake = "#{STAKE}.#{num}".to_f
	execute_command("oracle-ctrl init #{file_base}")
	execute_command("oracle-ctrl apply #{file_base} #{stake} #{VOTING_REWARD} #{file_base}.apply")
	execute_command("fift -s pw-req.fif #{wallet_path} #{eye_addr} #{start_seq_no + num} #{stake + VOTING_REWARD + 1} -B #{file_base}.apply.boc #{file_base}.pw")
	execute_command("tonos-cli -u #{gql_url} sendfile #{file_base}.pw.boc")
	p "- 0 - 0 - 0 - 0 - 0 - 0 - 0 -"
	sleep 1.5
end
