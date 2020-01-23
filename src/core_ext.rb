class Numeric
	def to_hex
		"%x" % self
	end
end

class Array
	def to_hex
		map{|v| v.to_hex}.join
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
	def x; self[0] end
	def y; self[1] end
	def z; self[2] end

	def vector_angles(other)
		delta = other-self

		# exactly above/below
		return Vector[delta.z > 0 ? -90 : 90, 0] if delta.x == 0 && delta.y == 0

		yaw = Math.degrees(Math.atan2(delta.y, delta.x))
		hyp = Math.sqrt(delta.x*delta.x + delta.y*delta.y)
		pitch = Math.degrees(Math.atan2(-delta.z, hyp))

		Vector[pitch, yaw]
	end
end
