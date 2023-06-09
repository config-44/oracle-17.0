#!/usr/bin/env ruby


current_file_path = File.expand_path(File.dirname(__FILE__))

def execute_command(command)
	p command
	system("#{command}")
end

ITERATIONS = ARGV[0].strip.to_i
EYE_CONTRACT_ADDR = ARGV[1].strip
WALLET_PATH = ENV["WL"] || ARGV[2].strip
GQL_URL = ENV["GQL"] || ARGV[3].strip
START_PORT = 44550
ENV_FILE_NAME = ".env.development"
DATA_PATH = "#{current_file_path}/data/oracle_"
MASTER_FILE_BASE = "#{current_file_path}/master/keys"
NODE_START_COMMAND = "oracle-swift --env development"

env_file = {
	"VAPOR_IP" => "127.0.0.1",
	"SERVER_IP" => "127.0.0.1",
	"GQL_WSS_ENDPOINT" => GQL_URL.sub(/https:\/\//, 'wss://'),
	"GQL_HTTPS_ENDPOINT" => GQL_URL.sub(/\/graphql/, '').sub(/wss:\/\//, 'https://'),
	"EYE_CONTRACT" => EYE_CONTRACT_ADDR,
	"LAST_TX_FILE_DB_PATH" => "last_tx_db.txt",
	"NEW_ACCOUNTS_TIMEOUT" => 10,
	"BROADCUST_REPEAT" => 4,
	"REQUEST_BUILDER_TIMEOUT" => 3600
}


# # CREATE ENV FILES
# p 'CREATE ENV FILES'
# start_port = START_PORT
# ITERATIONS.times do |i|
# 	env_file["VAPOR_PORT"] = start_port + i
# 	env_file["SERVER_PORT"] = start_port + 1 + i
# 	start_port = env_file["SERVER_PORT"]
# 	env_file["FILE_BASE"] = "#{DATA_PATH}#{i}/oracle"

# 	File.delete("#{DATA_PATH}#{i}/#{ENV_FILE_NAME}") if File.exist?("#{DATA_PATH}#{i}/#{ENV_FILE_NAME}")
# 	`mkdir -p #{DATA_PATH}#{i}`
# 	env_file.each do |key, value|
# 		File.write("#{DATA_PATH}#{i}/#{ENV_FILE_NAME}", "#{key}=#{value}\n", mode: 'a+')
# 	end
# end

# # MAKE SEED FILES
# p 'MAKE SEED FILES'
# execute_command("ruby initial_apply.rb #{EYE_CONTRACT_ADDR} #{WALLET_PATH} #{GQL_URL} #{ITERATIONS} #{DATA_PATH}")

# # START NODES 
# p 'START NODES'
# if `uname -s`.strip == 'Darwin'
# 	system("pkill SCREEN")
# 	system("screen -wipe")
# 	system("pkill -9 -f oracle")
# else
# 	system("pkill screen")
# end
# screen_names = {}
# ITERATIONS.times do |i|
# 	screen_name = "#{i}_oracle_node"
# 	system("screen -Sdm #{screen_name}")
# 	list = `screen -list`
# 	list[/(\d+\.#{screen_name})/]
# 	new_name = $1
# 	screen_names[i] = new_name
# end

# screen_names.sort.to_h.each do |key, value|
# 	system("screen -S #{value} -p 0 -X exec bash -lc 'cd #{DATA_PATH}#{key}; cd #{DATA_PATH}#{key} && #{NODE_START_COMMAND}'")
# 	sleep 0.3
# 	`osascript -e 'tell application "Terminal" to activate' -e 'tell application "System Events" to tell process "Terminal" to keystroke "t" using command down' -e 'tell application "Terminal" to do script "screen -r #{value}" in selected tab of the front window'`
# end

p 'ACCEPT ALL'
sleep(6)
execute_command("ruby accept_all.rb #{EYE_CONTRACT_ADDR} #{MASTER_FILE_BASE} #{WALLET_PATH} #{GQL_URL}")














