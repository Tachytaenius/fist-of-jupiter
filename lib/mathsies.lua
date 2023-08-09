-- Mathsies provides deterministic (if your machine is compliant with IEEE-754) versions of generic mathematical functions for LuaJIT, as well as quaternions, 2 and 3-dimensional vectors and 4x4 matrices.
-- By Tachytaenius.
-- Version 10

local ffi = require("ffi")

local detmath, vec2, vec3, quat, mat4

do -- detmath
	-- Getting the same results from functions cross-platform
	
	local tau = 6.28318530717958647692 -- Pi is also provided, of course :-)
	local e = 2.71828182845904523536
	local abs, floor, sqrt, modf, frexp, ldexp, huge = math.abs, math.floor, math.sqrt, math.modf, math.frexp, math.ldexp, math.huge
	
	local getRoundingMode
	do
		local modes = {
			nearest_toEven = {2, 2, -2, -2},
			nearest_truncate = {2, 3, -2, -3},
			truncate = {1, 2, -1, -2},
			ceiling = {2, 3, -1, -2},
			floor = {1, 2, -2, -3}
		}
		
		local input = {1.5, 2.5, -1.5, -2.5}
		
		local denormalSmallExponents = {
			half = -24,
			single = -149,
			double = -1074,
			quadruple = -16494,
			octuple = -262378
		}
		
		local normalSmallExponents = {
			half = -14,
			single = -126,
			double = -1022,
			quadruple = -16382,
			octuple = -262142
		}
		
		function getRoundingMode(type, noDenormals)
			local small = ldexp(1, (noDenormals and normalSmallExponents or denormalSmallExponents)[type or "double"])
			
			for name, results in pairs(modes) do
				local this = true
				for i = 1, 4 do
					if small * input[i] ~= small * results[i] then
						this = false
						break
					end
				end
				if this then return name end
			end
		end
	end
	
	-- x raised to an integer is not deterministic
	local function intPow(x, n) -- Exponentiation by squaring
		if n == 0 then
			return 1
		elseif n < 0 then
			x = 1 / x
			n = -n
		end
		local y = 1
		while n > 1 do
			if n % 2 == 0 then -- even
				n = n / 2
			else -- odd
				y = x * y
				n = (n - 1) / 2
			end
			x = x * x
		end
		return x * y
	end
	
	local function exp(x)
		local xint, xfract = modf(x)
		local exint = intPow(e, xint)
		local exfract = 1 + xfract + (xfract*xfract / 2) + (xfract*xfract*xfract / 6) + (xfract*xfract*xfract*xfract / 24) -- for n = 0, 4 sum xfract^n/n!
		return exint * exfract -- e ^ (xint + xfract)
	end
	
	local log
	do
		local powerTable = { -- 1+2^-i
			1.5, 1.25, 1.125, 1.0625, 1.03125, 1.015625, 1.0078125, 1.00390625, 1.001953125, 1.0009765625, 1.00048828125, 1.000244140625, 1.0001220703125, 1.00006103515625, 1.000030517578125
		}
		local logTable = { -- log(1+2^-i)
			0.40546510810816438486, 0.22314355131420976486, 0.11778303565638345574, 0.06062462181643483994, 0.03077165866675368733, 0.01550418653596525448, 0.00778214044205494896, 0.00389864041565732289, 0.00195122013126174934, 0.00097608597305545892, 0.00048816207950135119, 0.00024411082752736271, 0.00012206286252567737, 0.00006103329368063853, 0.00003051711247318638
		}
		local ln2 = 0.69314718055994530942 -- log(2)
		function log(x)
			local xmant, xexp = frexp(x)
			if xmant == 0.5 then
				return ln2 * (xexp-1)
			end
			local arg = xmant * 2
			local prod = 1
			local sum = 0
			for i = 1, 15 do
				local prod2 = prod * powerTable[i]
				if prod2 < arg then
					prod = prod2
					sum = sum + logTable[i]
				end
			end
			return sum + ln2 * (xexp - 1)
		end
	end
	
	local function pow(x, y)
		local yint, yfract = modf(y)
		local xyint = intPow(x, yint)
		local xyfract = exp(log(x)*yfract)
		return xyint * xyfract -- x ^ (yint + yfract)
	end
	
	local function sin(x)
		local over = floor(x / (tau / 2)) % 2 == 0 -- Get sign of sin(x)
		x = tau/4 - x % (tau/2) -- Shift x into domain of approximation
		local absolute = 1 - (20 * x*x) / (4 * x*x + tau*tau) -- https://www.desmos.com/calculator/o6gy67kqpg (should help to visualise what's going on)
		return over and absolute or -absolute
	end
	
	local function cos(x)
		local over = floor((tau/4 - x) / (tau / 2)) % 2 == 0
		x = tau/4 - (tau/4 - x) % (tau/2)
		local absolute = 1 - (20 * x*x) / (4 * x*x + tau*tau)
		return over and absolute or -absolute
	end
	
	local function tan(x)
		return sin(x)/cos(x)
	end
	
	local function asin(x)
		local positiveX, x = x > 0, abs(x)
		local resultForAbsoluteX = tau/4 - sqrt(tau*tau * (1 - x)) / (2 * sqrt(x + 4))
		return positiveX and resultForAbsoluteX or -resultForAbsoluteX
	end
	
	local function acos(x)
		local positiveX, x = x > 0, abs(x)
		local resultForAbsoluteX = sqrt(tau*tau * (1 - x)) / (2 * sqrt(x + 4)) -- Only approximates acos(x) when x > 0
		return positiveX and resultForAbsoluteX or -resultForAbsoluteX + tau/2
	end
	
	local function atan(x)
		x = x / sqrt(1 + x*x)
		local positiveX, x = x > 0, abs(x)
		local resultForAbsoluteX = tau/4 - sqrt(tau*tau * (1 - x)) / (2 * sqrt(x + 4))
		return positiveX and resultForAbsoluteX or -resultForAbsoluteX
	end
	
	-- The transition from atan to atan2 makes sense, but the actual definition of the arctangent doesn't automatically make sense with two arguments
	local function atan2(y, x)
		if x == 0 and y == 0 then
			return 0
		end
		local theta = atan(y/x)
		theta = x == 0 and tau/4 * y / abs(y) or x < 0 and theta + tau/2 or theta
		theta = theta > tau / 2 and theta - tau or theta -- NOTE: This line was added after the above line to change the output range so simplification may be possible
		return theta
	end
	
	local function sinh(x)
		local ex = exp(x)
		return (ex - 1/ex) / 2
	end
	
	local function cosh(x)
		local ex = exp(x)
		return (ex + 1/ex) / 2
	end
	
	local function tanh(x)
		local ex = exp(x)
		return (ex - 1/ex) / (ex + 1/ex)
	end
	
	detmath = {
		getRoundingMode = getRoundingMode,
		
		tau = tau,
		pi = tau / 2, -- Choose whichever you find personally gratifying. I use tau in this library but it's up to you
		e = e,
		
		exp = exp,
		pow = pow,
		intPow = intPow,
		log = log,
		sin = sin,
		cos = cos,
		tan = tan,
		asin = asin,
		acos = acos,
		atan = atan,
		arg = arg,
		atan2 = atan2,
		sinh = sinh,
		cosh = cosh,
		tanh = tanh
	}
end

do -- vec2
	ffi.cdef([=[
		typedef struct {
			double x, y;
		} vec2;
	]=])
	
	local ffi_istype = ffi.istype
	
	local rawnew = ffi.typeof("vec2")
	local function new(x, y)
		x = x or 0
		y = y or x
		return rawnew(x, y)
	end
	
	local sqrt, sin, cos, atan2 = math.sqrt, math.sin, math.cos, math.atan2
	local detSin, detCos, detAtan2 = detmath.sin, detmath.cos, detmath.atan2
	
	local function length(v)
		local x, y = v.x, v.y
		return sqrt(x * x + y * y)
	end
	
	local function length2(v)
		local x, y = v.x, v.y
		return x * x + y * y
	end
	
	local function distance(a, b)
		local x, y = b.x - a.x, b.y - a.y
		return sqrt(x * x + y * y)
	end
	
	local function distance2(a, b)
		local x, y = b.x - a.x, b.y - a.y
		return x * x + y * y
	end
	
	local function dot(a, b)
		return a.x * b.x + a.y * b.y
	end
	
	local function normalise(v)
		return v/length(v)
	end
	
	local function reflect(incident, normal)
		return incident - 2 * dot(normal, incident) * normal
	end
	
	local function refract(incident, normal, eta)
		local ndi = dot(normal, incident)
		local k = 1 - eta * eta * (1 - ndi * ndi)
		if k < 0 then
			return rawnew(0, 0)
		else
			return eta * incident - (eta * ndi + sqrt(k)) * normal
		end
	end
	
	local function rotate(v, a)
		local x, y = v.x, v.y
		return rawnew(
			x * cos(a) - y * sin(a),
			y * cos(a) + x * sin(a)
		)
	end
	
	local function detRotate(v, a)
		local x, y = v.x, v.y
		return rawnew(
			x * detCos(a) - y * detSin(a),
			y * detCos(a) + x * detSin(a)
		)
	end
	
	local function fromAngle(a)
		return rawnew(cos(a), sin(a))
	end
	
	local function detFromAngle(a)
		return rawnew(detCos(a), detSin(a))
	end
	
	local function toAngle(v)
		return atan2(v.y, v.x)
	end
	
	local function detToAngle(v)
		return detAtan2(v.y, v.x)
	end
	
	local function components(v)
		return v.x, v.y
	end
	
	local function clone(v)
		return rawnew(v.x, v.y)
	end
	
	ffi.metatype("vec2", {
		__add = function(a, b)
			if type(a) == "number" then
				return rawnew(a + b.x, a + b.y)
			elseif type(b) == "number" then
				return rawnew(a.x + b, a.y + b)
			else
				return rawnew(a.x + b.x, a.y + b.y)
			end
		end,
		__sub = function(a, b)
			if type(a) == "number" then
				return rawnew(a - b.x, a - b.y)
			elseif type(b) == "number" then
				return rawnew(a.x - b, a.y - b)
			else
				return rawnew(a.x - b.x, a.y - b.y)
			end
		end,
		__unm = function(v)
			return rawnew(-v.x, -v.y)
		end,
		__mul = function(a, b)
			if type(a) == "number" then
				return rawnew(a * b.x, a * b.y)
			elseif type(b) == "number" then
				return rawnew(a.x * b, a.y * b)
			else
				return rawnew(a.x * b.x, a.y * b.y)
			end
		end,
		__div = function(a, b)
			if type(a) == "number" then
				return rawnew(a / b.x, a / b.y)
			elseif type(b) == "number" then
				return rawnew(a.x / b, a.y / b)
			else
				return rawnew(a.x / b.x, a.y / b.y)
			end
		end,
		__mod = function(a, b)
			if type(a) == "number" then
				return rawnew(a % b.x, a % b.y)
			elseif type(b) == "number" then
				return rawnew(a.x % b, a.y % b)
			else
				return rawnew(a.x % b.x, a.y % b.y)
			end
		end,
		__eq = function(a, b)
			local isVec2 = type(b) == "cdata" and ffi_istype("vec2", b)
			return isVec2 and a.x == b.x and a.y == b.y
		end,
		__len = length,
		__tostring = function(v)
			return string.format("vec2(%f, %f)", v.x, v.y)
		end
	})
	
	vec2 = setmetatable({
		new = new,
		length = length,
		length2 = length2,
		distance = distance,
		distance2 = distance2,
		dot = dot,
		normalise = normalise,
		normalize = normalise,
		reflect = reflect,
		refract = refract,
		rotate = rotate,
		detRotate = detRotate,
		fromAngle = fromAngle,
		detFromAngle = detFromAngle,
		toAngle = toAngle,
		detToAngle = detToAngle,
		components = components,
		clone = clone
	}, {
		__call = function(_, x, y)
			return new(x, y)
		end
	})
end

do -- vec3
	ffi.cdef([=[
		typedef struct {
			double x, y, z;
		} vec3;
	]=])
	
	local ffi_istype = ffi.istype
	
	local rawnew = ffi.typeof("vec3")
	local function new(x, y, z)
		x = x or 0
		y = y or x
		z = z or y
		return rawnew(x, y, z)
	end
	
	local sqrt, sin, cos = math.sqrt, math.sin, math.cos
	local detSin, detCos = detmath.sin, detmath.cos
	
	local function length(v)
		local x, y, z = v.x, v.y, v.z
		return sqrt(x * x + y * y + z * z)
	end
	
	local function length2(v)
		local x, y, z = v.x, v.y, v.z
		return x * x + y * y + z * z
	end
	
	local function distance(a, b)
		local x, y, z = b.x - a.x, b.y - a.y, b.z - a.z
		return sqrt(x * x + y * y + z * z)
	end
	
	local function distance2(a, b)
		local x, y, z = b.x - a.x, b.y - a.y, b.z - a.z
		return x * x + y * y + z * z
	end
	
	local function dot(a, b)
		return a.x * b.x + a.y * b.y + a.z * b.z
	end
	
	local function cross(a, b)
		return rawnew(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
	end
	
	local function normalise(v)
		return v/length(v)
	end
	
	local function reflect(incident, normal)
		return incident - 2 * dot(normal, incident) * normal
	end
	
	local function refract(incident, normal, eta)
		local ndi = dot(normal, incident)
		local k = 1 - eta * eta * (1 - ndi * ndi)
		if k < 0 then
			return rawnew(0, 0)
		else
			return eta * incident - (eta * ndi + sqrt(k)) * normal
		end
	end
	
	local function rotate(v, q)
		local qxyz = new(q.x, q.y, q.z)
		local uv = cross(qxyz, v)
		local uuv = cross(qxyz, uv)
		return v + ((uv * q.w) + uuv) * 2
	end
	
	local function fromAngles(theta, phi)
		local st, sp, ct, cp = sin(theta), sin(phi), cos(theta), cos(phi)
		return rawnew(st*sp,ct,st*cp)
	end
	
	local function detFromAngles(theta, phi)
		local st, sp, ct, cp = detSin(theta), detSin(phi), detCos(theta), detCos(phi)
		return rawnew(st*sp,ct,st*cp)
	end
	
	local function components(v)
		return v.x, v.y, v.z
	end
	
	local function clone(v)
		return rawnew(v.x, v.y, v.z)
	end
	
	ffi.metatype("vec3", {
		__add = function(a, b)
			if type(a) == "number" then
				return rawnew(a + b.x, a + b.y, a + b.z)
			elseif type(b) == "number" then
				return rawnew(a.x + b, a.y + b, a.z + b)
			else
				return rawnew(a.x + b.x, a.y + b.y, a.z + b.z)
			end
		end,
		__sub = function(a, b)
			if type(a) == "number" then
				return rawnew(a - b.x, a - b.y, a - b.z)
			elseif type(b) == "number" then
				return rawnew(a.x - b, a.y - b, a.z - b)
			else
				return rawnew(a.x - b.x, a.y - b.y, a.z - b.z)
			end
		end,
		__unm = function(v)
			return rawnew(-v.x, -v.y, -v.z)
		end,
		__mul = function(a, b)
			if type(a) == "number" then
				return rawnew(a * b.x, a * b.y, a * b.z)
			elseif type(b) == "number" then
				return rawnew(a.x * b, a.y * b, a.z * b)
			else
				return rawnew(a.x * b.x, a.y * b.y, a.z * b.z)
			end
		end,
		__div = function(a, b)
			if type(a) == "number" then
				return rawnew(a / b.x, a / b.y, a / b.z)
			elseif type(b) == "number" then
				return rawnew(a.x / b, a.y / b, a.z / b)
			else
				return rawnew(a.x / b.x, a.y / b.y, a.z / b.z)
			end
		end,
		__mod = function(a, b)
			if type(a) == "number" then
				return rawnew(a % b.x, a % b.y, a % b.z)
			elseif type(b) == "number" then
				return rawnew(a.x % b, a.y % b, a.z % b)
			else
				return rawnew(a.x % b.x, a.y % b.y, a.z % b.z)
			end
		end,
		__eq = function(a, b)
			local isVec3 = type(b) == "cdata" and ffi_istype("vec3", b)
			return isVec3 and a.x == b.x and a.y == b.y and a.z == b.z
		end,
		__len = length,
		__tostring = function(v)
			return string.format("vec3(%f, %f, %f)", v.x, v.y, v.z)
		end
	})
	
	vec3 = setmetatable({
		new = new,
		length = length,
		length2 = length2,
		distance = distance,
		distance2 = distance2,
		dot = dot,
		cross = cross,
		normalise = normalise,
		normalize = normalise,
		reflect = reflect,
		refract = refract,
		rotate = rotate,
		fromAngles = fromAngles,
		detFromAngles = detFromAngles,
		components = components,
		clone = clone
	}, {
		__call = function(_, x, y, z)
			return new(x, y, z)
		end
	})
end

do -- quat
	ffi.cdef([=[
		typedef struct {
			double x, y, z, w;
		} quat;
	]=])
	
	local ffi_istype = ffi.istype
	
	local rawnew = ffi.typeof("quat")
	local function new(x, y, z, w)
		if x and y and z then
			if w then
				return rawnew(x, y, z, w)
			else
				return rawnew(x, y, z, 0)
			end
		else
			return rawnew(0, 0, 0, 1)
		end
	end
	
	local sqrt, sin, cos, acos = math.sqrt, math.sin, math.cos, math.acos
	local detSin, detCos, detAcos = detmath.sin, detmath.cos, detmath.acos
	
	local function length(q)
		local x, y, z, w = q.x, q.y, q.z, q.w
		return sqrt(x * x + y * y + z * z + w * w)
	end
	
	local function normalise(q)
		local len = #q
		return rawnew(q.x / len, q.y / len, q.z / len, q.w / len)
	end
	
	local function inverse(q)
		return rawnew(-q.x, -q.y, -q.z, q.w)
	end
	
	local function dot(a, b)
		return a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w
	end
	
	local function slerp(a, b, i)
		if a == b then return a end
		
		local cosHalfTheta = dot(a, b)
		local halfTheta = acos(cosHalfTheta)
		local sinHalfTheta = sqrt(1 - cosHalfTheta^2)
		
		return a * (sin((1 - i) * halfTheta) / sinHalfTheta) + b * (sin(i * halfTheta) / sinHalfTheta)
	end
	
	local function detSlerp(a, b, i)
		if a == b then return a end
		
		local cosHalfTheta = dot(a, b)
		local halfTheta = detAcos(cosHalfTheta)
		local sinHalfTheta = sqrt(1 - cosHalfTheta*cosHalfTheta)
		
		return a * (detSin((1 - i) * halfTheta) / sinHalfTheta) + b * (detSin(i * halfTheta) / sinHalfTheta)
	end
	
	local function fromAxisAngle(v)
		local angle = #v
		if angle == 0 then return rawnew(0, 0, 0, 1) end
		local axis = v / angle
		local s, c = sin(angle / 2), cos(angle / 2)
		return normalise(new(axis.x * s, axis.y * s, axis.z * s, c))
	end
	
	local function detFromAxisAngle(v)
		local angle = #v
		if angle == 0 then return rawnew(0, 0, 0, 1) end
		local axis = v / angle
		local s, c = detSin(angle / 2), detCos(angle / 2)
		return normalise(new(axis.x * s, axis.y * s, axis.z * s, c))
	end
	
	local function components(q)
		return q.x, q.y, q.z, q.w
	end
	
	local function clone(q)
		return rawnew(q.x, q.y, q.z, q.w)
	end
	
	ffi.metatype("quat", {
		__unm = function(q)
			return rawnew(-q.x, -q.y, -q.z, -q.w)
		end,
		__mul = function(a, b)
			local isQuat = type(b) == "cdata" and ffi_istype("quat", b)
			if isQuat then
				return rawnew(
					a.x * b.w + a.w * b.x + a.y * b.z - a.z * b.y,
					a.y * b.w + a.w * b.y + a.z * b.x - a.x * b.z,
					a.z * b.w + a.w * b.z + a.x * b.y - a.y * b.x,
					a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z
				)
			else
				return rawnew(a.x * b, a.y * b, a.z * b, a.w * b)
			end
		end,
		__add = function(a, b)
			return rawnew(a.x + b.x, a.y + b.y, a.z + b.z, a.w + b.w)
		end,
		__eq = function(a, b)
			local isQuat = type(b) == "cdata" and ffi_istype("quat", b)
			return isQuat and a.x == b.x and a.y == b.y and a.z == b.z and a.w == b.w
		end,
		__len = length,
		__tostring = function(q)
			return string.format("quat(%f, %f, %f, %f)", q.x, q.y, q.z, q.w)
		end
	})
	
	quat = setmetatable({
		new = new,
		length = length,
		normalise = normalise,
		normalize = normalise,
		inverse = inverse,
		dot = dot,
		slerp = slerp,
		detSlerp = detSlerp,
		fromAxisAngle = fromAxisAngle,
		detFromAxisAngle = detFromAxisAngle,
		components = components,
		clone = clone
	}, {
		__call = function(_, x, y, z, w)
			return new(x, y, z, w)
		end
	})
end

do -- mat4
	ffi.cdef([=[
		typedef struct {
			double _00, _01, _02, _03, _10, _11, _12, _13, _20, _21, _22, _23, _30, _31, _32, _33;
		} mat4;
	]=])
	
	local ffi_istype = ffi.istype
	
	local rawnew = ffi.typeof("mat4")
	local function new(a,b,c,d, e,f,g,h, i,j,k,l, m,n,o,p)
		a = a or 1
		if not b then
			return rawnew(a,0,0,0, 0,a,0,0, 0,0,a,0, 0,0,0,a)
		else
			return rawnew(a,b,c,d, e,f,g,h, i,j,k,l, m,n,o,p)
		end
	end
	
	local tan = math.tan
	local detTan = detmath.tan
	
	local function perspectiveLeftHanded(aspect, vfov, far, near)
		return rawnew(
			1/(aspect*tan(vfov/2)), 0, 0, 0,
			0, 1/tan(vfov/2), 0, 0,
			0, 0, (far+near)/(far-near), 2*(near+far)/(near-far),
			0, 0, 1, 0
		)
	end
	
	-- The deterministic maths is really for cross-platform identical gamestate reproduction from inputs, but... might as well use it here (where it's used for output).
	local function detPerspectiveLeftHanded(aspect, vfov, far, near)
		return rawnew(
			1/(aspect*detTan(vfov/2)), 0, 0, 0,
			0, 1/detTan(vfov/2), 0, 0,
			0, 0, (far+near)/(far-near), 2*(near+far)/(near-far),
			0, 0, 1, 0
		)
	end
	
	local function perspectiveRightHanded(aspect, vfov, far, near)
		return rawnew(
			1/(aspect*tan(vfov/2)), 0, 0, 0,
			0, 1/tan(vfov/2), 0, 0,
			0, 0, (near+far)/(near-far), 2*(near+far)/(near-far),
			0, 0, -1, 0
		)
	end
	
	local function detPerspectiveRightHanded(aspect, vfov, far, near)
		return rawnew(
			1/(aspect*detTan(vfov/2)), 0, 0, 0,
			0, 1/detTan(vfov/2), 0, 0,
			0, 0, (near+far)/(near-far), 2*(near+far)/(near-far),
			0, 0, -1, 0
		)
	end
	
	local function translate(v)
		return rawnew(
			1, 0, 0, v.x,
			0, 1, 0, v.y,
			0, 0, 1, v.z,
			0, 0, 0, 1
		)
	end
	
	local function rotate(q)
		local x, y, z, w = q.x, q.y, q.z, q.w
		return rawnew(
			1-2*y*y-2*z*z,   2*x*y-2*z*w,   2*x*z+2*y*w, 0,
			  2*x*y+2*z*w, 1-2*x*x-2*z*z,   2*y*z-2*x*w, 0,
			  2*x*z-2*y*w,   2*y*z+2*x*w, 1-2*x*x-2*y*y, 0,
			0, 0, 0, 1
		  )
	end
	
	local function scale(v)
		return rawnew(
			v.x, 0, 0, 0,
			0, v.y, 0, 0,
			0, 0, v.z, 0,
			0, 0, 0, 1
		)
	end
	
	local function transform(t, r, s)
		if type(s) == "number" then
			s = vec3(s)
		else
			s = s or vec3(1)
		end
		return translate(t) * rotate(r) * scale(s)
	end
	
	local function camera(t, r, s)
		if type(s) == "number" then
			s = vec3(s)
		else
			s = s or vec3(1)
		end
		return scale(1/s) * rotate(quat.inverse(r)) * translate(-t)
	end
	
	local function components(m)
		return m._00,m._01,m._02,m._03, m._10,m._11,m._12,m._13, m._20,m._21,m._22,m._23, m._30,m._31,m._32,m._33
	end
	
	local function clone(m)
		return rawnew(m._00,m._01,m._02,m._03, m._10,m._11,m._12,m._13, m._20,m._21,m._22,m._23, m._30,m._31,m._32,m._33)
	end
	
	local function inverse(m)
		return rawnew(
			 m._11 * m._22 * m._33 - m._11 * m._23 * m._32 - m._21 * m._12 * m._33 + m._21 * m._13 * m._32 + m._31 * m._12 * m._23 - m._31 * m._13 * m._22,
			-m._01 * m._22 * m._33 + m._01 * m._23 * m._32 + m._21 * m._02 * m._33 - m._21 * m._03 * m._32 - m._31 * m._02 * m._23 + m._31 * m._03 * m._22,
			 m._01 * m._12 * m._33 - m._01 * m._13 * m._32 - m._11 * m._02 * m._33 + m._11 * m._03 * m._32 + m._31 * m._02 * m._13 - m._31 * m._03 * m._12,
			-m._01 * m._12 * m._23 + m._01 * m._13 * m._22 + m._11 * m._02 * m._23 - m._11 * m._03 * m._22 - m._21 * m._02 * m._13 + m._21 * m._03 * m._12,
			-m._10 * m._22 * m._33 + m._10 * m._23 * m._32 + m._20 * m._12 * m._33 - m._20 * m._13 * m._32 - m._30 * m._12 * m._23 + m._30 * m._13 * m._22,
			 m._00 * m._22 * m._33 - m._00 * m._23 * m._32 - m._20 * m._02 * m._33 + m._20 * m._03 * m._32 + m._30 * m._02 * m._23 - m._30 * m._03 * m._22,
			-m._00 * m._12 * m._33 + m._00 * m._13 * m._32 + m._10 * m._02 * m._33 - m._10 * m._03 * m._32 - m._30 * m._02 * m._13 + m._30 * m._03 * m._12,
			 m._00 * m._12 * m._23 - m._00 * m._13 * m._22 - m._10 * m._02 * m._23 + m._10 * m._03 * m._22 + m._20 * m._02 * m._13 - m._20 * m._03 * m._12,
			 m._10 * m._21 * m._33 - m._10 * m._23 * m._31 - m._20 * m._11 * m._33 + m._20 * m._13 * m._31 + m._30 * m._11 * m._23 - m._30 * m._13 * m._21,
			-m._00 * m._21 * m._33 + m._00 * m._23 * m._31 + m._20 * m._01 * m._33 - m._20 * m._03 * m._31 - m._30 * m._01 * m._23 + m._30 * m._03 * m._21,
			 m._00 * m._11 * m._33 - m._00 * m._13 * m._31 - m._10 * m._01 * m._33 + m._10 * m._03 * m._31 + m._30 * m._01 * m._13 - m._30 * m._03 * m._11,
			-m._00 * m._11 * m._23 + m._00 * m._13 * m._21 + m._10 * m._01 * m._23 - m._10 * m._03 * m._21 - m._20 * m._01 * m._13 + m._20 * m._03 * m._11,
			-m._10 * m._21 * m._32 + m._10 * m._22 * m._31 + m._20 * m._11 * m._32 - m._20 * m._12 * m._31 - m._30 * m._11 * m._22 + m._30 * m._12 * m._21,
			 m._00 * m._21 * m._32 - m._00 * m._22 * m._31 - m._20 * m._01 * m._32 + m._20 * m._02 * m._31 + m._30 * m._01 * m._22 - m._30 * m._02 * m._21,
			-m._00 * m._11 * m._32 + m._00 * m._12 * m._31 + m._10 * m._01 * m._32 - m._10 * m._02 * m._31 - m._30 * m._01 * m._12 + m._30 * m._02 * m._11,
			 m._00 * m._11 * m._22 - m._00 * m._12 * m._21 - m._10 * m._01 * m._22 + m._10 * m._02 * m._21 + m._20 * m._01 * m._12 - m._20 * m._02 * m._11
		)
	end
	
	local function transpose(m)
		return rawnew(m._00,m._10,m._20,m._30, m._01,m._11,m._21,m._31, m._02,m._12,m._22,m._32, m._03,m._13,m._23,m._33)
	end
	
	ffi.metatype("mat4", {
		__mul = function(a, b)
			if type(b) == "number" then
				a, b = b, a
			end
			if type(a) == "number" then
				return rawnew(a*b._00,a*b._01,a*b._02,a*b._03, a*b._10,a*b._11,a*b._12,a*b._13, a*b._20,a*b._21,a*b._22,a*b._23, a*b._30,a*b._31,a*b._32,a*b._33)
			end
			if ffi_istype("vec3", b) then
				return vec3(
					(a._00 * b.x + a._01 * b.y + a._02 * b.z + a._03 * 1) / (a._30 * b.x + a._31 * b.y + a._32 * b.z + a._33 * 1),
					(a._10 * b.x + a._11 * b.y + a._12 * b.z + a._13 * 1) / (a._30 * b.x + a._31 * b.y + a._32 * b.z + a._33 * 1),
					(a._20 * b.x + a._21 * b.y + a._22 * b.z + a._23 * 1) / (a._30 * b.x + a._31 * b.y + a._32 * b.z + a._33 * 1)
				)
			end
			return rawnew(
				a._00 * b._00 + a._01 * b._10 + a._02 * b._20 + a._03 * b._30,
				a._00 * b._01 + a._01 * b._11 + a._02 * b._21 + a._03 * b._31,
				a._00 * b._02 + a._01 * b._12 + a._02 * b._22 + a._03 * b._32,
				a._00 * b._03 + a._01 * b._13 + a._02 * b._23 + a._03 * b._33,
				a._10 * b._00 + a._11 * b._10 + a._12 * b._20 + a._13 * b._30,
				a._10 * b._01 + a._11 * b._11 + a._12 * b._21 + a._13 * b._31,
				a._10 * b._02 + a._11 * b._12 + a._12 * b._22 + a._13 * b._32,
				a._10 * b._03 + a._11 * b._13 + a._12 * b._23 + a._13 * b._33,
				a._20 * b._00 + a._21 * b._10 + a._22 * b._20 + a._23 * b._30,
				a._20 * b._01 + a._21 * b._11 + a._22 * b._21 + a._23 * b._31,
				a._20 * b._02 + a._21 * b._12 + a._22 * b._22 + a._23 * b._32,
				a._20 * b._03 + a._21 * b._13 + a._22 * b._23 + a._23 * b._33,
				a._30 * b._00 + a._31 * b._10 + a._32 * b._20 + a._33 * b._30,
				a._30 * b._01 + a._31 * b._11 + a._32 * b._21 + a._33 * b._31,
				a._30 * b._02 + a._31 * b._12 + a._32 * b._22 + a._33 * b._32,
				a._30 * b._03 + a._31 * b._13 + a._32 * b._23 + a._33 * b._33
			)
		end,
		__eq = function(a, b)
			local isMat4 = ffi_istype("mat4", b)
			if isMat4 then
				for i = 1, 16 do
					if a[i] ~= b[i] then
						return false
					end
				end
				return true
			end
			return false
		end,
		__tostring = function(m)
			return string.format("mat4(%f,%f,%f,%f, %f,%f,%f,%f, %f,%f,%f,%f, %f,%f,%f,%f)", mat4.components(m))
		end
	})
	
	mat4 = setmetatable({
		new = new,
		perspectiveLeftHanded = perspectiveLeftHanded,
		detPerspectiveLeftHanded = detPerspectiveLeftHanded,
		perspectiveRightHanded = perspectiveRightHanded,
		detPerspectiveRightHanded = detPerspectiveRightHanded,
		translate = translate,
		rotate = rotate,
		scale = scale,
		transform = transform,
		camera = camera,
		components = components,
		clone = clone,
		inverse = inverse,
		transpose = transpose
	}, {
		__call = function(_, a,b,c,d, e,f,g,h, i,j,k,l, m,n,o,p)
			return new(a,b,c,d, e,f,g,h, i,j,k,l, m,n,o,p)
		end
	})
end

return {
	detmath = detmath,
	vec2 = vec2,
	vec3 = vec3,
	quat = quat,
	mat4 = mat4
}
