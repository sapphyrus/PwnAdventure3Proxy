# $VERBOSE = nil

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
		0x7374 => :entity_state,
		0x7472 => :attack_state,
		0x7878 => :entity_remove,
		0x733D => :slot,
		0x7665 => :event
	}
	TYPES_TO_CLASS = {}

	def self.sender
		@@sender
	end

	def self.parse(str, sender: nil, channel: nil)
		packets = []
		io = StringIO.new(str)

		@@sender = sender
		@@channel = channel

		i = 0
		while !io.eof?
			# puts i
			i += 1
			packet = nil
			identifier = nil
			start_pos = io.pos
			begin
				if io.length-io.pos > 1
					identifier = BinData::Uint16be.read(io).to_i
					io.seek(start_pos)

					if TYPES_TO_CLASS.key?(TYPES[identifier])
						packet = TYPES_TO_CLASS[TYPES[identifier]].read(io)
					end
				# else
					# puts "Ignoring #{io.read.inspect}"
					# start_pos = io.pos
				end
			rescue StandardError => e
				puts "Failed to create packet #{identifier.is_a?(Numeric) ? identifier.to_hex : identifier.inspect}: "
				puts e.full_message
			end

			if packet.nil?
				#puts "UnimplementedPacket creating"
				io.seek(start_pos)
				packet = UnimplementedPacket.read(io, disable_find: channel != :game)
				#puts "UnimplementedPacket created"
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
			return "#{name} (size: #{num_bytes}#{field_names.empty? ? "" : (", " + Hash[field_names.select{|key| key != :identifier}.map{|key| [key, self[key].is_a?(Numeric) ? self[key].to_hex : self[key]]}].inspect)})" if self.is_a? EntityState
			name
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

		def self.read(str_or_io, disable_find: false)
			instance = new

			io = str_or_io.respond_to?(:read) ? str_or_io : StringIO.new(str_or_io.to_s)
			len = 2
			pos_prev = io.pos

			if !disable_find
				while io.length-io.pos > 0 do
					# puts "ASD"
					io.seek(pos_prev+len)
					rr = io.read(2)
					break if rr.nil?
					rd = rr.unpack("s>").first
					if TYPES.key?(rd) && rd != 0x0000
						# puts "found unknown packet end #{TYPES[rd]}!"
						break
					end
					len += 1
				end
			end
			io.seek(pos_prev)
			# puts "reading #{len}!"
			instance.raw = io.read(len)
			#puts "done reading !"

			instance
		end

		def identifier
			@raw.unpack("s>").first
		end

		def type
			TYPES[identifier]
		end

		def name
			if TYPES.key?(identifier)
				"UNIMPLEMENTED_#{TYPES[identifier].to_s}"
			else
				"UNKNOWN_#{identifier.nil? ? "NIL" : sprintf("%02X", identifier)}#{source.nil? ? "" : "-#{source}"}"
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

	class Auth < BasePacket
		uint16 :unk1
		uint16 :unk2

		uint16 :auth1_length
		string :auth1, read_length: :auth1_length
	end

	class Entity < BasePacket
		uint16 :ent
		uint16 :unk1
		uint16 :unk2
		uint16 :unk3
		uint8 :unk4
		uint16 :entity_name_length
		string :entity_name, read_length: :entity_name_length

		float :x
		float :y
		float :z

		uint32 :unk5
		uint32 :unk6
		uint16 :unk7
	end

	class EntityPosition < BasePacket
		uint16 :ent

		uint16 :unk1

		float :x
		float :y
		float :z

		uint32 :unk2
		uint32 :unk3
		uint32 :unk4
	end

	class EntityRemove < BasePacket
		uint16 :ent
	end

	class EntityState < BasePacket
		uint16 :ent

		uint16 :unk1

		uint16le :state_length
		string :state, read_length: proc {self[:state_length]}
		uint8 :unk2

		def inspect
			puts inspect_fields_hex
			super
		end
	end

	class Position < BasePacket
		float :x
		float :y
		float :z

		int16 :pitch
		int16 :yaw

		uint16 :ent

		int8 :forward
		int8 :side

		uint8 :unk1, onlyif: -> {Packets.sender == :client && self[:ent] != 0}

		def inspect
			"pos: %.2f / %.2f / %.2f, view: %.2f / %.2f, forward: %1d, side: %1d" % [self[:x], self[:y], self[:z], self[:pitch], self[:yaw], self[:forward], self[:side]]
			"POSITION #{Packets.sender == :client && self[:ent] != 0}"
		end
	end

	class Fire < BasePacket
		uint16le :weapon_name_length
		string :weapon_name, read_length: :weapon_name_length

		float :pitch
		float :yaw

		uint32 :unk1
	end

	class SendMessage < BasePacket
		uint16le :message_length
		string :message, read_length: :message_length

		def inspect
			puts self.inspect_fields_hex
			super
		end
	end

	class PickupItem < BasePacket
		uint16le :ent
		uint16 :unk1
	end

	class UpdateMana < BasePacket
		int32 :mana
	end

	class UpdateHealth < BasePacket
		int16 :ent
		uint16 :unk1
		uint16 :health
	end

	class AttackState < BasePacket
		int16 :ent
	end

	self.constants.map{|name| self.const_get(name)}.select{|c| c.is_a?(Class)}.each do |c|
		if type = TYPES.values.select{|_type| _type.to_s.classify == c.name.demodulize}.first
			TYPES_TO_CLASS[type] = c
		end
	end
end
