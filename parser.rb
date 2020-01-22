$VERBOSE = nil

class Array
	def inspect_bytes
		self.map{|byte| sprintf("0x%02X", byte)}.join(" ")
	end
end

class Numeric
	def to_hex
		"%x" % self
	end
end

module Math
	def self.radians(val)
		val * Math::PI / 180.0
	end

	def self.degrees(val)
		val / Math::PI * 180.0
	end
end

class Vector
	def x
		self[0]
	end

	def y
		self[1]
	end

	def z
		self[2]
	end

	def vector_angles(other)
		delta = other-self
		if delta.x == 0 && delta.y == 0
			return Vector[delta.z > 0 ? -90 : 90, 0]
		end

		yaw = Math.degrees(Math.atan2(delta.y, delta.x))
		hyp = Math.sqrt(delta.x*delta.x + delta.y*delta.y)
		pitch = Math.degrees(Math.atan2(-delta.z, hyp))

		puts pitch

		Vector[pitch, yaw]
	end
end

Object.send(:remove_const, :Packets) rescue nil
module Packets
	TYPES = {
		0x0000 => :noop,
		0x0200 => :auth,
		0x1600 => :spawnpos_1,
		0x1700 => :spawnpos_2,
		0x2300 => :spawnpos_3,
		0x232a => :send_message,
		0x233e => :send_answer,
		0x2366 => :finish_dialog,
		0x2373 => :send_dialog,
		0x2462 => :purchase_item,
		0x2a69 => :fire,
		0x2b2b => :update_health,
		0x3003 => :spawnpos_4,
		0x3031 => :activate_logic_gate,
		0x3206 => :spawnpos_5,
		0x4103 => :spawnpos_6,
		0x5e64 => :remove_quest,
		0x6368 => :change_location,
		0x6370 => :new_item,
		0x6565 => :pickup_item,
		0x6576 => :event,
		0x6674 => :fast_travel,
		0x6a70 => :jump,
		0x6d61 => :update_mana,
		0x6d6b => :entity,
		0x6d76 => :position,
		0x6e71 => :new_quest,
		0x7073 => :entity_position,
		0x7075 => :achievement,
		0x7076 => :pvp_state,
		0x713d => :quest_select,
		0x713e => :quest_complete,
		0x726d => :remove_item,
		0x726e => :sneak,
		0x7273 => :respawn,
		0x7274 => :teleport,
		0x7374 => :state,
		0x7472 => :attack_state,
		0x7878 => :entity_remove,
		0x733D => :slot,
		0x7665 => :event
	}

	def self.parse(str, sender: nil)
		packets = []
		io = StringIO.new(str)

		while !io.eof?
			packet = nil
			start_pos = io.pos
			begin
				identifier = BinData::Uint16be.read(io)
				io.seek(start_pos)

				if TYPES_TO_CLASS.key?(TYPES[identifier])
					packet = TYPES_TO_CLASS[TYPES[identifier]].read(io)
				elsif TYPES[identifier].nil?
					puts "#{identifier.to_hex} (#{identifier})"
				end
			rescue StandardError => e
				puts "Failed to create packet: #{e.message} (#{e.class})"
				puts e.backtrace
			end

			if packet.nil?
				io.seek(start_pos)
				packet = UnimplementedPacket.read(io)
			end
			packets << packet
		end

		return packets
	end

	class BasePacket < BinData::Record
		def initialize_instance
			super

			if type = TYPES_TO_CLASS.invert[self.class]
				if identifier = TYPES.invert[type]
					self[:identifier] = identifier
				end
			end
		end

		endian :little
		int16be :identifier

		attr_accessor :source

		def type
			TYPES[identifier]
		end

		def name
			type.to_s.upcase
		end

		def inspect
			"#{name} (size: #{num_bytes}#{field_names.empty? ? "" : (", " + Hash[field_names.select{|key| key != :identifier}.map{|key| [key, self[key]]}].inspect)})"
		end

		def inspect_fields_hex
			arr1 = []
			arr2 = []

			field_names.each do |field_name|
				field_value = self[field_name].to_hex
				len = [field_name.length, field_value.length].max
				arr1 << field_name.to_s.ljust(len, " ")
				arr2 << field_value.ljust(len, " ")
			end

			[arr1.join(" "), arr2.join(" ")]
		end
	end

	class UnimplementedPacket
		attr_accessor :raw, :source

		def self.read(str_or_io)
			instance = new
			instance.raw = str_or_io.respond_to?(:read) ? str_or_io.read : str_or_io.to_s
			instance
		end

		def identifier
			@raw.unpack("s>").first
		end

		def type
			TYPES[identifier]
		end

		def name
			begin
				if TYPES.key?(identifier)
					"UNIMPLEMENTED_#{TYPES[identifier].to_s}"
				else
					"UNKNOWN_#{sprintf("%02X", identifier)}#{source.nil? ? "" : "-#{source}"}"
				end
			rescue => e
				puts @raw.inspect
			end
		end

		def inspect
			"#{name} (size: #{num_bytes}, #{to_hex})"
		end

		def num_bytes
			@raw.length
		end

		def to_binary_s
			@raw
		end

		def to_hex
			@raw.bytes.map{|byte| sprintf("%02X", byte)}.join("")
		end
	end

	class Actor < BinData::Record
	end

	class Coord < BinData::Record
	end

	class Vec3 < BinData::Record
	end

	class Sneak < BasePacket
		uint8be :unsneak
	end

	class Jump < BasePacket
		uint8le :jump, initial_value: 0
	end

	class Slot < BasePacket
		int8 :slot
	end

	class Noop < BasePacket
	end

	class Event < BasePacket
		uint16le :top_length
		string :top, read_length: :top_length
		uint16le :bottom_length
		string :bottom, read_length: :bottom_length
	end

	class Entity < BasePacket
		uint16 :ent
		uint16 :unk1
		uint16 :unk2
		uint16 :unk3
		uint8 :unk4
		uint16 :entity_name_length
		string :entity_name, read_length: :entity_name_length

		# -53505.12 / -42306.52 / 578.94

		float :x
		float :y
		float :z

		uint32 :unk5
		uint32 :unk6
	end

	class EntityPosition < BasePacket
		uint16 :ent

		uint16 :unk1

		float :x
		float :y
		float :z

		uint32 :unk2
		uint32 :unk3
		uint16 :unk4
	end

	class EntityRemove < BasePacket
		uint16 :ent
	end

	class Position < BasePacket
		float :x
		float :y
		float :z

		uint16 :pitch
		uint16 :yaw

		uint16 :ent

		int8 :forward
		int8 :side

		# def inspect
		# 	"pos: %.2f / %.2f / %.2f, view: %.2f / %.2f, forward: %1d, side: %1d" % [self[:x], self[:y], self[:z], self[:pitch], self[:yaw], self[:forward], self[:side]]
		# end
	end

	class Fire < BasePacket
		uint16le :weapon_name_length
		string :weapon_name, read_length: :weapon_name_length

		float :pitch
		float :yaw

		uint32 :unk1

		# sbit :pad, nbits: 12
	end

	class SendMessage < BasePacket
		uint16le :message_length
		# string :message, read_length: :message_length

		def inspect
			puts self.inspect_fields_hex
			super
		end
	end

	class UpdateMana < BasePacket
		int32 :mana
	end

	class UpdateHealth < BasePacket
		int16 :ent
		uint16 :unk1
		uint16 :health
	end

	TYPES_TO_CLASS = Hash[self.constants.map{|name| self.const_get(name)}.select{|c| c.is_a?(Class)}.map{|c|
		if type = TYPES.values.select{|_type| _type.to_s.classify == c.name.demodulize}.first
			[type, c]
		end
	}]
end

# puts Packets::EntityPosition.read("\0"*50).num_bytes

# class Packet

# 	attr_accessor :raw, :data, :identifier, :type

# 	def initialize(io: nil, type: nil, sender: nil, parsed: true)
# 		@sender = sender
# 		if !type.nil?
# 			@parsed = true
# 			@type = type

# 			@identifier = TYPES.invert[@type]
# 			@data = Hash.new
# 		elsif !io.nil?
# 			@parsed = false
# 			# parse packet header (identifier)
# 			@identifier = io.read(2).unpack("S>").first
# 			@type = TYPES[@identifier]

# 			pos_pre = io.pos

# 			# parse packet contents
# 			@data = Hash.new
# 			if parsed
# 				case @type
# 				when :noop
# 				when :position
# 					@data[:x] = io.read(4).unpack("f").first
# 					@data[:y] = io.read(4).unpack("f").first
# 					@data[:z] = io.read(4).unpack("f").first

# 					@data[:pitch] = io.read(2).unpack("s_").first/(2**14).to_f
# 					@data[:yaw] = io.read(2).unpack("s_").first/(2**15).to_f

# 					@data[:unk1], @data[:unk2] = io.read(2).unpack("CC")

# 					forwardmove = io.read(1).bytes.first
# 					forwardmoves = {
# 						0x00 => 0,
# 						0x7F => 1,
# 						0x81 => -1
# 					}
# 					@data[:forwardmove] = forwardmoves[forwardmove]

# 					sidemove = io.read(1).bytes.first
# 					sidemoves = {
# 						0x00 => 0,
# 						0x7f => 1,
# 						0x81 => -1
# 					}

# 					@data[:sidemove] = sidemoves[sidemove]

# 					puts "known forwardmove: #{forwardmoves[forwardmove].inspect}, unk1 #{@data[:unk1]}, unk2 #{@data[:unk2]}"

# 					if forwardmove == 0xc0 || forwardmove == 0x08
# 						@data[:unk3], @data[:unk4] = io.read(2).bytes
# 					end

# 					# binding.pry if @data[:forwardmove].nil? || @data[:sidemove].nil?
# 				when :jump
# 					@data[:jump] = io.read(1).bytes.first != 0
# 				when :sneak
# 					@data[:sneak] = io.read(1).bytes.first != 0
# 				when :entity
# 					@data[:ent], _, _, _, @data[:a], @data[:length], _ = io.read(11).unpack("ssssccc")
# 					@data[:name] = io.read(@data[:length])
# 					@data[:x], @data[:y], @data[:z] = io.read(22).unpack("fff")
# 				when :slot
# 					@data[:slot] = io.read(1).bytes[0]
# 				when :pickup_item
# 					@data[:item] = io.read(4).unpack("s").first
# 				when :update_mana
# 					@data[:mana] = io.read(4).unpack("l").first
# 				when :update_health
# 					@data[:ent] = io.read(4).unpack("l").first
# 					@data[:health] = io.read(4).unpack("l").first
# 				when :state
# 					# puts "STATE #{raw.inspect}"
# 					@data[:ent], @data[:length] = io.read(6).unpack("ls")
# 					@data[:state] = io.read(@data[:length]+1)
# 				when :enemy_position
# 					raw = io.read(28)
# 					@data[:ent], @data[:x], @data[:y], @data[:z] = raw.unpack("lfff")
# 				when :fire
# 					@data[:length] = io.read(2).unpack("s").first
# 					@data[:weapon] = io.read(@data[:length])
# 					io.read(12)
# 				else
# 					parsed = false
# 					puts "unhandled packet #{name}, reading #{io.pos-pos_pre} bytes"
# 					io.seek(pos_pre-2)
# 					puts io.read(20).bytes.inspect_bytes
# 				end
# 			end

# 			if !parsed
# 				io.read
# 			end

# 			binding.pry if @type == :sneak

# 			# save packet size
# 			@size = io.pos-pos_pre

# 			# save raw contents
# 			io.seek(pos_pre)
# 			@raw = io.read(@size)
# 			@parsed = parsed

# 			if parsed
# 				puts "#{io.length-io.pos} bytes left after parsing #{@type.inspect} with size #{@size.inspect}" if io.length-io.pos > 0 && @type != :enemy_position

# 				raw = [@identifier].pack("S>") + @raw
# 				generated = generate()

# 				if raw != generated
# 					puts "Different raw and generated packet:"
# 					puts raw.inspect
# 					puts generated.inspect
# 				end
# 			end
# 		end
# 	end

# 	def inspect
# 		data_text = data.empty? ? "" : data.map{|k, v| "#{k}: #{v.inspect}"}.join(", ")

# 		if @parsed
# 			case @type
# 			when :position
# 				data_text = "pos: %.2f / %.2f / %.2f, forward: %1d, side: %1d, view: %.2f / %.2f" % [data[:x], data[:y], data[:z], data[:forwardmove], data[:sidemove], data[:pitch], data[:yaw]]
# 			end
# 		end

# 		"#{name} (size: #{@size}#{data_text == "" ? "" : ", #{data_text}"})"
# 	end

# 	def inspect_bytes
# 		bytes.map{|byte| sprintf("0x%02X", byte)}.join(" ")
# 	end

# 	def name
# 		return @type.to_s.upcase if !@type.nil?

# 		"UNK [#{@sender.nil? ? "" : "#{@sender} => "}#{sprintf("0x%02X", @identifier)}]"
# 	end

# 	def generate
# 		binding.pry if @identifier.nil?
# 		result = [@identifier].pack("S>")

# 		generated = @parsed == true
# 		if generated
# 			begin
# 				case @type
# 				when :noop
# 				when :positionasd
# 					forwardmoves = {
# 						0 => 0x00,
# 						1 => 0x7F,
# 						-1 => 0x81,
# 					}
# 					sidemoves = {
# 						0 => 0x00,
# 						1 => 0x7f,
# 						-1 => 0x81
# 					}
# 					# puts data.inspect
# 					result << [
# 						data[:x],
# 						data[:y],
# 						data[:z],
# 						(data[:pitch]*2**14).to_i,
# 						(data[:yaw]*2**15).to_i,
# 						data[:unk1],
# 						data[:unk2],
# 						forwardmoves[data[:forwardmove]],
# 						sidemoves[data[:sidemove]]
# 					].pack("fffssCCCC")
# 				when :jump
# 					result << (data[:jump] ? 1 : 0).chr
# 				when :update_mana
# 					result << [data[:mana]].pack("l")
# 				# when :update_health
# 				# 	result << [data[:ent], data[:health]].pack("ll")
# 				else
# 					generated = false
# 				end
# 			rescue StandardError => e
# 				puts "Failed to generate #{@type}: #{e.message} (#{e.class})"
# 				puts e.backtrace
# 				generated = false
# 			end
# 		end

# 		if !generated
# 			return if @raw.nil?
# 			result = [@identifier].pack("S>") + @raw
# 		end

# 		# if @type == :update_mana
# 		# 	puts "generated?: #{generated}"
# 		# 	puts "RES: " + result.inspect
# 		# 	puts "GEN: " + ([@identifier].pack("S>") + [data[:mana]].pack("l")).inspect
# 		# end

# 		result
# 	end

# 	def bytes
# 		generate.bytes
# 	end
# end

$last_load = Time.now.to_f

class Proxy
	include EventEmitter

	attr_accessor :client
	attr_accessor :server

	def recv_loop
		fds = [@client, @server]
		closed = false
		if ios = IO.select(fds, [], [], 10)
			ios.first.each do |io|
				is_client = io == client
				other = is_client ? server : client
				begin
					# call hooks
					raw = io.readpartial(4096) if raw.nil?

					if self.is_a?(GameProxy) && Time.now.to_f > $last_load + 0.5
						begin
							load File.absolute_path("parser.rb")
						rescue => e
							puts "Failed to run parser: #{e.message} (#{e.class})"
							puts e.backtrace
						end
						$last_load = Time.now.to_f
					end

					packets = nil
					if raw == :eof
						closed = true
						return
					else
						packets = Packets.parse(raw, sender: is_client ? :client : :server)
					end

					packets.map! do |packet|
						packet_new = is_client ? server_packet(packet) : client_packet(packet)
						packet = packet_new unless packet_new.nil?

						packet
					end

					packets.select! do |packet|
						![nil, false].include?(packet)
					end

					if is_client
						packets += @client_queue
						@client_queue = []
					else
						packets += @server_queue
						@server_queue = []
					end

					# puts "#{is_client ? "Client" : "Server"} packets: #{packets.inspect}"

					data = packets.map(&:to_binary_s).join("")
					data_new = is_client ? client_send(data) : server_send(data)
					data = data_new if !data_new.nil?

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

	def initialize(client, server)
		@client = client
		@server = server

		@client_queue = []
		@server_queue = []

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
	def initialize(client, server = nil)
		server ||= Socketry::TCP::Socket.connect($options[:master_server], $options[:master_port])
		super(client, server)

		puts "New master server connection"
	end

	def inspect_packet(dir, packet)
		puts "#{dir} sent: #{packet.inspect}"
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
	def initialize(client, server = nil)
		@game = client

		server ||= Socketry::TCP::Socket.connect($options[:master_server], @game.local_port)
		@game_server = server

		@entities = Hash.new

		super(client, server)

		puts "New game server connection on #{@game.local_port}"

		Thread.new do
			loop do
				think
			end
		end
	end

	def inspect_packet(dir, packet)
		return if (packet.type == :noop && dir == "SERVER") || (packet.class == Packets::Position && packet.ent == 0) || packet.type == :noop || packet.type == :entity_position
		puts "#{dir} sent: #{packet.inspect}"
		# puts packet.inspect_bytes
	end

	def think
		# packet = Packet.new(type: :update_health)
		# packet.data[:ent] = 0
		# packet.data[:health] = 95
		# puts packet.generate.inspect
		# @game.writepartial(packet.generate)
		# puts "sent"
		# puts @entities.inspect
		sleep 5
	end

	def server_packet(packet)
		inspect_packet("GAME_CLIENT", packet)

		if packet.type == :send_message
			message = packet.message
			if message.start_with? "."
				if message == ".tp"
					packet = Packets::Position.new
					packet.x = 0
					packet.y = 0
					packet.z = 0
					client.writepartial(packet.to_binary_s)
				elsif message == ".mana"
					packet = Packets::UpdateMana.new
					packet.mana = 999999999999999
					@server_queue << packet
				elsif message == ".hp"
					packet = Packets::UpdateHealth.new
					packet.health = 999999999999999
					@server_queue << packet
				end
				packet = false
			end
		elsif packet.type == :sneak
			@aimbot_on = packet.unsneak == 0

			if @aimbot_on
				#{:weapon_name_length=>16, :weapon_name=>"GreatBallsOfFire", :pitch=>0.4791368246078491, :yaw=>-86.497314453125}
				local_ent = @entities[0]
				local_pos = Vector[local_ent[:x], local_ent[:y], local_ent[:z]+45]

				targets = @entities.select{|index, ent| ent[:name] == "GiantRat" && (ent[:health].nil? || (ent[:health] != 0 && ent[:health] != 65516))}.sort_by do |index, ent|
					target_pos = Vector[ent[:x], ent[:y], ent[:z]]
					(target_pos-local_pos).magnitude
				end

				if target_ent = targets.first
					index, target = target_ent
					aim = local_pos.vector_angles(Vector[target[:x], target[:y], target[:z]])

					puts target.inspect

					packet = Packets::Fire.new
					packet.weapon_name_length = 16
					packet.weapon_name = "GreatBallsOfFire"
					# packet.weapon_name_length = 6
					# packet.weapon_name = "Pistol"
					packet.pitch = -aim.x
					packet.yaw = aim.y

					@client_queue << packet
				end

				# --https://github.com/ValveSoftware/source-sdk-2013/blob/master/sp/src/mathlib/mathlib_base.cpp#L535-L563
				# local origin_x, origin_y, origin_z
				# local target_x, target_y, target_z
				# if x2 == nil then
				# 	target_x, target_y, target_z = x1, y1, z1
				# 	origin_x, origin_y, origin_z = client_eye_position()
				# 	if origin_x == nil then
				# 		return
				# 	end
				# else
				# 	origin_x, origin_y, origin_z = x1, y1, z1
				# 	target_x, target_y, target_z = x2, y2, z2
				# end

				# local delta_x, delta_y, delta_z = target_x-origin_x, target_y-origin_y, target_z-origin_z

				# if delta_x == 0 and delta_y == 0 then
				# 	return (delta_z > 0 and 270 or 90), 0
				# else
				# 	local yaw = math_deg(math_atan2(delta_y, delta_x))
				# 	local hyp = math_sqrt(delta_x*delta_x + delta_y*delta_y)
				# 	local pitch = math_deg(math_atan2(-delta_z, hyp))

				# 	return pitch, yaw
				# end

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
		# inspect_packet("GAME_SERVER", packet) unless packet.type == :position

		if packet.type == :update_mana
			packet.mana = 999999999999999
		elsif packet.type == :entity
			# ENTITY (size: 49, {:ent=>1, :unk1=>0, :unk2=>0, :unk3=>0, :unk4=>0, :entity_name_length=>16, :entity_name=>"GreatBallsOfFire", :x=>-43655.0, :y=>-55820.0, :z=>322.0, :unk5=>2147483648, :unk6=>6553600})
			@entities[packet.ent] = {
				name: packet.entity_name,
				x: packet.x,
				y: packet.y,
				z: packet.z
			}
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
