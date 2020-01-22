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

$options = {
	master_server: "116.203.203.6",
	master_port: 3333,
	game_port: 3000
}

OptionParser.new do |opts|
	opts.banner = "Usage: main.rb [options]"

	opts.on("-m", "--master-server [hostname]", "Set master server IP") do |hostname|
		$options[:master_server] = hostname
	end
	opts.on("-p", "--master-port [port]", "Set master server port") do |port|
		$options[:master_port] = port
	end
end.parse!

load File.absolute_path("parser.rb")

accept_thread = Thread.new do
	master_server = TCPServer.new("0.0.0.0", $options[:master_port])
	game_servers = (3000..3005).map{|i| TCPServer.new("0.0.0.0", i)}

	servers = [master_server, *game_servers]

	loop do
		if ios = IO.select(servers, [], [], 10)
			ios.first.each do |acceptor|
				socket = acceptor.accept_nonblock
				client = Socketry::TCP::Socket.new(socket_class: TCPSocket)
				client.from_socket(socket)

				client.instance_variable_set(:@remote_addr, socket.remote_address.ip_address)
				client.instance_variable_set(:@remote_port, socket.remote_address.ip_port)

				client.instance_variable_set(:@local_addr, socket.local_address.ip_address)
				client.instance_variable_set(:@local_port, socket.local_address.ip_port)

				if acceptor == master_server
					MasterProxy.new(client)
				elsif game_servers.include? acceptor
					GameProxy.new(client)
				else
					binding.pry
				end
			end
		end
	end
end

sleep
