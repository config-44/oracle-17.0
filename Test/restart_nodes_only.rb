#!/usr/bin/env ruby


current_file_path = File.expand_path(File.dirname(__FILE__))

def execute_command(command)
	p command
	system("#{command}")
end

ITERATIONS = ARGV[0].strip.to_i
DATA_PATH = "#{current_file_path}/data/oracle_"
NODE_START_COMMAND = "oracle-swift --env development"

# START NODES 
p 'START NODES'
if `uname -s`.strip == 'Darwin'
	system("pkill SCREEN || true && screen -wipe || true && pkill -9 -f oracle-swift")
else
	system("pkill screen || true && screen -wipe || true && pkill -9 -f oracle-swift")
end
screen_names = {}
ITERATIONS.times do |i|
	screen_name = "#{i}_oracle_node"
	system("screen -Sdm #{screen_name}")
	list = `screen -list`
	list[/(\d+\.#{screen_name})/]
	new_name = $1
	screen_names[i] = new_name
end

screen_names.sort.to_h.each do |key, value|
	system("screen -S #{value} -p 0 -X exec bash -lc 'cd #{DATA_PATH}#{key} && #{NODE_START_COMMAND}'")
	sleep 0.3
	if `uname -s`.strip == 'Darwin'
		`osascript -e 'tell application "Terminal" to activate' -e 'tell application "System Events" to tell process "Terminal" to keystroke "t" using command down' -e 'tell application "Terminal" to do script "screen -r #{value}" in selected tab of the front window'`
	end
end















