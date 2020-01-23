class Proxy
	attr_accessor :client
	attr_accessor :server

	def recv_loop
		fds = [@client, @server]
		return if fds.any?{|fd| fd.closed?}
		closed = false
		if ios = IO.select(fds, [], [], 10)
			ios.first.each do |io|
				is_client = io == client
				other = is_client ? server : client
				begin
					# call hooks
					raw = io.readpartial(4096) if raw.nil?

					packets = nil
					if raw == :eof
						closed = true
						return
					else
						packets = Packets.parse(raw, sender: is_client ? :client : :server, channel: self.is_a?(GameProxy) ? :game : :unknown)
					end

					packets.map! do |packet|
						begin
							packet_new = is_client ? server_packet(packet) : client_packet(packet)
							packet = packet_new unless packet_new.nil?

							packet
						rescue StandardError => e
							puts e.full_message
							packet
						end
					end

					packets.select! do |packet|
						![nil, false].include?(packet)
					end

					if is_client
						packets = [*@client_queue_front, *packets, *@client_queue]
						@client_queue = []
						@client_queue_front = []
					else
						packets = [*@server_queue_front, *packets, *@server_queue]
						@server_queue = []
						@server_queue_front = []
					end

					# puts "#{is_client ? "Client" : "Server"} packets: #{packets.inspect}" if self.is_a?(GameProxy)

					data = packets.map(&:to_binary_s).join("")
					data_new = is_client ? client_send(data) : server_send(data)
					data = data_new if !data_new.nil?

					if raw.bytes.to_hex.include?("6565")
						puts raw.bytes.to_hex
						puts is_client
					end

					# binding.pry if data != raw

					other.writepartial(data) if data
				rescue Errno::ECONNRESET, Errno::ECONNABORTED, Errno::ETIMEDOUT
					closed = true
				end
			end
		end

		if closed
			puts "closed"
			fds.each(&:close)
			return
		end
	end

	attr_accessor :client_queue, :server_queue
	attr_accessor :client_queue_front, :server_queue_front

	def initialize(client, server)
		@client = client
		@server = server

		@client_queue = []
		@server_queue = []

		@client_queue_front = []
		@server_queue_front = []

		Thread.new do
			loop do
				recv_loop
			end
		end
	end

	def server_packet(packet); end
	def server_send(packet); end

	def client_packet(packet); end
	def client_send(packet); end
end

class MasterProxy < Proxy
	def initialize(client, server)
		super

		puts "New master server connection"
	end

	def inspect_packet(dir, packet)
		# puts "#{dir} sent: #{packet.inspect}"
		# puts packet.inspect_bytes
	end

	def server_packet(packet)
		inspect_packet("MASTER_SERVER", packet)

		return packet
	end

	def server_packet(packet)
		inspect_packet("MASTER_CLIENT", packet)

		return packet
	end
end

class GameProxy < Proxy
	def initialize(client, server)
		super

		@game = client
		@game_server = server

		@entities = Hash.new
		@aimbot_on = false
		@mana = 100

		puts "New game server connection on #{@game.local_port}"

		Thread.new do
			loop do
				think
			end
		end
	end

	def inspect_packet(dir, packet)
		return if (packet.type == :noop && dir == "SERVER") || (packet.class == Packets::Position && packet.ent == 0) || packet.type == :noop
		# puts "#{dir} sent: #{packet.inspect}"
		puts packet.to_hex if packet.type == :pickup_item
	end

	def recv_loop
		AutoReload.reload

		super
	end

	def think
		sleep 2
	end

	def server_packet(packet)
		inspect_packet("GAME_CLIENT", packet)

		if packet.type == :send_message
			message = packet.message
			if message.start_with? "."
				if message == ".tp"
					position = Packets::Position.new
					position.x = 0
					position.y = 0
					position.z = 0
					client.writepartial(position.to_binary_s)
				elsif message == ".mana"
					update_mana = Packets::UpdateMana.new
					update_mana.mana = 999999999999999
					@server_queue << update_mana
				elsif message == ".hp"
					update_health = Packets::UpdateHealth.new
					update_health.health = 999999999999999
					@server_queue << update_health
				end
				packet = false
			end
		elsif packet.type == :sneak
			if packet.unsneak == 0
				@aimbot_on = !@aimbot_on
				puts "Aimbot: #{@aimbot_on}"
			end
		elsif packet.type == :position
			# puts packet.pitch
			@mana ||= 100
			@last_attack ||= Hash.new
			if @aimbot_on && @mana > 30
				#{:weapon_name_length=>16, :weapon_name=>"GreatBallsOfFire", :pitch=>0.4791368246078491, :yaw=>-86.497314453125}
				local_ent = @entities[0]
				local_pos = Vector[local_ent[:x], local_ent[:y], local_ent[:z]+42]

				targets = @entities.select{|index, ent| ent[:name] == "GiantRat" && (ent[:health].nil? || (ent[:health] != 0 && ent[:health] != 65516))}

				max_dist = 5000

				target_dist = Hash[targets.map{|index, ent| [index, (Vector[ent[:x], ent[:y], ent[:z]]-local_pos).magnitude]}]
				targets.select!{|index, target| target_dist[index] < max_dist}
				targets.select!{|index, ent| !@last_attack.key?(index) || Time.now.to_f > @last_attack[index]+2+10*(target_dist[index]/max_dist)}
				targets = targets.sort_by{|index, target| target_dist[index]}

				if target_ent = targets.first
					index, target = target_ent
					aim = local_pos.vector_angles(Vector[target[:x], target[:y], target[:z]])

					puts target.inspect

					fire = Packets::Fire.new
					fire.weapon_name_length = 16
					fire.weapon_name = "GreatBallsOfFire"
					# fire.weapon_name_length = 6
					# packet.weapon_name = "Pistol"
					fire.pitch = -aim.x
					fire.yaw = aim.y

					packet.pitch = (-aim.x/90*(2^14)).to_i
					packet.yaw = (aim.y/180*(2^15)).to_i

					@last_attack[index] = Time.now.to_f

					@client_queue << fire
				end
			end
		end

		if packet.type == :position
			@entities[0] ||= {}
			if @entities.key? packet.ent
				@entities[packet.ent][:x] = packet.x
				@entities[packet.ent][:y] = packet.y
				@entities[packet.ent][:z] = packet.z
			end
		end

		return packet
	end

	def client_packet(packet)
		inspect_packet("GAME_SERVER", packet) unless packet.type == :position

		if packet.type == :update_mana
			@mana = packet.mana
			# packet.mana = 999999999999999
		elsif packet.type == :entity
			# ENTITY (size: 49, {:ent=>1, :unk1=>0, :unk2=>0, :unk3=>0, :unk4=>0, :entity_name_length=>16, :entity_name=>"GreatBallsOfFire", :x=>-43655.0, :y=>-55820.0, :z=>322.0, :unk5=>2147483648, :unk6=>6553600})
			ent = {
				name: packet.entity_name,
				x: packet.x,
				y: packet.y,
				z: packet.z
			}
			@entities[packet.ent] = ent

			if !ent[:name].nil? && ent[:name].end_with?("Drop")
				puts "Picking up #{ent[:name]} (#{packet.ent})"
				pickupitem = Packets::PickupItem.new
				pickupitem.ent = packet.ent
				@client_queue_front << pickupitem
			end
		elsif packet.type == :entity_remove
			@entities.delete packet.ent
		elsif packet.type == :update_health
			if @entities.key? packet.ent
				@entities[packet.ent][:health] = packet.health
			end
		elsif packet.type == :entity_position
			# ENTITY_POSITION (size: 28, {:ent=>2299, :unk1=>0, :x=>-46151.265625, :y=>-34657.20703125, :z=>410.65216064453125, :unk2=>3221618688, :unk3=>0, :unk4=>65411})
			if @entities.key? packet.ent
				@entities[packet.ent][:x] = packet.x
				@entities[packet.ent][:y] = packet.y
				@entities[packet.ent][:z] = packet.z
			end
		end

		return packet
	end
end
