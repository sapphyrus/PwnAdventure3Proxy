require "bundler/inline"

gemfile do
	source "https://rubygems.org"

	gem "pry"
	gem "socketry"
	gem "event_emitter"
	gem "bindata"
	gem "activesupport", require: ["active_support/core_ext/hash", "active_support/core_ext/string"]

	require "optparse"
	require "socket"
	require "matrix"
end

class AutoReload
	class << self
		@@reloads = []
		@@last_reload = 0
		@@interval = 1

		def reload
			return false unless Time.now.to_f > @@last_reload+@@interval

			@@last_reload = Time.now.to_f
			@@reloads.each do |reload|
				begin
					load reload
				rescue Exception => e
					puts "Reloading #{reload} failed:"
					puts e.full_message
				end
			end
			true
		end

		def require_relative(path)
			fullpath = File.expand_path(path.chomp(".rb") + ".rb")
			load fullpath

			@@reloads << fullpath
		end
	end
end

options = {
	server: "116.203.203.6",
	master_port: 3333,
	game_port: 3000,
	bind: "0.0.0.0"
}

OptionParser.new do |opts|
	opts.banner = "Usage: main.rb [options]"

	opts.on("--server [hostname]", "Set master server IP") do |hostname|
		options[:server] = hostname
	end
	opts.on("--master-port [port]", "Set master server port") do |port|
		options[:master_port] = port
	end
	opts.on("--game-port [port]", "Set game server start port") do |port|
		options[:game_port] = port
	end
	opts.on("--bind [ip]", "Set IP to bind to") do |bind|
		options[:bind] = bind
	end
end.parse!

AutoReload.require_relative "core_ext"
AutoReload.require_relative "parser"
AutoReload.require_relative "proxy"

master_server = TCPServer.new(options[:bind], options[:master_port])
game_servers = options[:game_port].upto(options[:game_port]+5).map{|i| TCPServer.new("0.0.0.0", i)}

servers = [master_server, *game_servers]

loop do
	# select blocks until a server has a new client
	if ios = IO.select(servers, [], [], 10)
		ios.first.each do |acceptor|
			socket = acceptor.accept_nonblock

			# construct socketry socket from raw TCPSocket
			client = Socketry::TCP::Socket.new(socket_class: TCPSocket)
			client.from_socket(socket)

			client.instance_variable_set(:@remote_addr, socket.remote_address.ip_address)
			client.instance_variable_set(:@remote_port, socket.remote_address.ip_port)

			client.instance_variable_set(:@local_addr, socket.local_address.ip_address)
			client.instance_variable_set(:@local_port, socket.local_address.ip_port)

			# create proxy
			if acceptor == master_server
				server = Socketry::TCP::Socket.connect(options[:server], options[:master_port])
				MasterProxy.new(client, server)
			elsif game_servers.include? acceptor
				server = Socketry::TCP::Socket.connect(options[:server], client.local_port)
				GameProxy.new(client, server)
			end
		end
	end
end
