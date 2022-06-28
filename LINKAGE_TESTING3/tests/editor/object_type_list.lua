--- Objects available to editor.

--
-- Permission is hereby granted, free of charge, to any person obtaining
-- a copy of this software and associated documentation files (the
-- "Software"), to deal in the Software without restriction, including
-- without limitation the rights to use, copy, modify, merge, publish,
-- distribute, sublicense, and/or sell copies of the Software, and to
-- permit persons to whom the Software is furnished to do so, subject to
-- the following conditions:
--
-- The above copyright notice and this permission notice shall be
-- included in all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
-- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
-- IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
-- CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
-- TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
-- SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--
-- [ MIT license: http://www.opensource.org/licenses/mit-license.php ]
--

-- Standard library imports --
local pairs = pairs
local tonumber = tonumber
local type = type
local unpack = unpack

-- Modules --
local interface = require("tests.editor.interface")
local objects = require("tests.editor.objects")
local string_box = require("tests.editor.string_box")

-- Exports --
local M = {}

--
--
--

local function Bind (func, t, name)
	t[name] = func
end

local function DefEvent () end

local function DefInt ()
	return 0
end

local function IsInt (str)
	local n = tonumber(str)

	return n and n % 1 == 0
end

local function IsUint (str)
	local n = tonumber(str)

	return n and n >= 0 and n % 1 == 0
end

M.loaders = {
	get_int = function(info, pubsub)
		if info.result then
			--
		end
	end,

	get_uint = function(info, pubsub)
		if info.result then
			--
		end
	end,

	set_int = function(info, pubsub)
		pubsub:Subscribe(info.value, function(vfunc)
			--
		end)
	end,

	set_uint = function(info, pubsub)
		pubsub:Subscribe(info.value, function(vfunc)
			--
		end)
	end,

	act = function(info, pubsub)
	end,

	react = function(info, pubsub)
	end,

	--
	--
	--

	add = function(info, pubsub)
		if info.result then
			local get_x, get_y = DefInt, DefInt

			pubsub:Subscribe(info.x, function(xfunc)
				get_x = xfunc
			end)
			pubsub:Subscribe(info.y, function(yfunc)
				get_y = yfunc
			end)
			pubsub:Publish(function()
				return get_x() + get_y()
			end, info.uid, "result")
		end
	end,

	mul = function(info, pubsub)
		if info.result then
			local get = { x = DefUint, y = DefUint }

			for k in pairs(get) do -- more typical might be to have `local Type = { x = { def = DefUint, type = "uint" }, etc. }`, then looping here on `Type`
				pubsub:Subscribe(info[k], Bind, get, k)
			end

			pubsub:Publish(function()
				return get.x() * get.y()
			end, info.uid, "result")
		end
	end,

	sub = function(info, pubsub)
		if info.result then
			local get_x, get_y = DefInt, DefInt

			local function AllInOne (func, name)
				if name == nil then
					return get_x() - get_y()
				elseif name == "x" then
					get_x = func
				elseif name == "y" then
					get_y = func
				end
			end

			pubsub:Subscribe(info.x, AllInOne, "x")
			pubsub:Subscribe(info.y, AllInOne, "y")
			pubsub:Publish(AllInOne, info.uid, "result")
		end
	end,

	equal = function(info, pubsub)
		if info.result then
			local get_x, get_y

			pubsub:Subscribe(info.x, function(xfunc)
				get_x = xfunc
			end)
			pubsub:Subscribe(info.y, function(yfunc)
				get_y = yfunc
			end)
			pubsub:Publish(function()
				if get_x and get_y then
					return get_x() == get_y()
				else
					return false
				end
			end, info.uid, "result")
		end
	end,

	lt = function(info, pubsub)
		if info.result then
			local get_x, get_y

			pubsub:Subscribe(info.x, function(xfunc)
				get_x = xfunc
			end)
			pubsub:Subscribe(info.y, function(yfunc)
				get_y = yfunc
			end)
			pubsub:Publish(function()
				if get_x and get_y then
					return get_x() < get_y()
				else
					return false
				end
			end, info.uid, "result")
		end
	end,

	--
	--
	--

	branch = function(info, pubsub)
		if info["do"] then
			local on_if, on_else, get_condition = DefEvent, DefEvent

			pubsub:Subscribe(info.condition, function(cfunc)
				get_condition = cfunc
			end)
			pubsub:Subscribe(info["if"], function(ifunc)
				on_if = ifunc
			end)
			pubsub:Subscribe(info["else"], function(efunc)
				on_else = efunc
			end)
			pubsub:Publish(function()
				if get_condition then
					if get_condition() then
						return on_if()
					else
						return on_else()
					end
				end
			end, info.uid, "do")
		end
	end,

	loop = function(info, pubsub)
		if info["do"] then
			local get_break, get_count, next, action = DefEvent, DefInt, DefEvent

			pubsub:Subscribe(info["break"], function(bfunc)
				get_break = bfunc
			end)
			pubsub:Subscribe(info.count, function(cfunc)
				get_count = cfunc
			end)
			pubsub:Subscribe(info.count, function(afunc)
				action = afunc
			end)
			pubsub:Subscribe(info.next, function(nfunc)
				next = nfunc
			end)
			pubsub:Publish(function()
				if action then
					for i = 1, get_count() do -- TODO: limit
						action()
					end
				end

				return next()
			end, info.uid, "do")
		end
	end,

	once = function(info, pubsub)
		if info["do"] then
			local next, action = DefEvent

			pubsub:Subscribe(info.action, function(afunc)
				action = afunc
			end)
			pubsub:Subscribe(info.next, function(nfunc)
				next = nfunc
			end)
			pubsub:Publish(function()
				if action then
					local asaved = action

					action = nil

					return asaved()
				end

				return next()
			end, info.uid, "do")
		end
	end,

	timer_once = function(info, pubsub)
		if info["do"] then
			local next, delay, get_delay, action = DefEvent, tonumber(info.delay_value) or 0

			pubsub:Subscribe(info.delay, function(dfunc)
				get_delay = dfunc
			end)
			pubsub:Subscribe(info.action, function(afunc)
				action = afunc
			end)
			pubsub:Subscribe(info.next, function(nfunc)
				next = nfunc
			end)
			pubsub:Publish(function()
				if action then
					if get_delay then
						delay = get_delay()
					end 

					timer.performWithDelay(delay, function()
						action()
					end)
				end

				return next()
			end, info.uid, "do")
		end
	end,

	timer_repeat = function(info, pubsub)
		if info["do"] then
			local next, delay, limit, get_delay, get_limit, action = DefEvent, tonumber(info.delay_value) or 0, tonumber(info.limit_value) or 0

			pubsub:Subscribe(info.delay, function(dfunc)
				get_delay = dfunc
			end)
			pubsub:Subscribe(info.limit, function(dfunc)
				get_limit = lfunc
			end)
			pubsub:Subscribe(info.action, function(afunc)
				action = afunc
			end)
			pubsub:Subscribe(info.next, function(nfunc)
				next = nfunc
			end)
			pubsub:Publish(function()
				if action then
					if get_delay then
						delay = get_delay()
					end

					if get_limit then
						limit = get_limit()
					end

					timer.performWithDelay(delay, function()
						action()
					end, limit)
				end

				return next()
			end, info.uid, "do")
		end
	end,

	--
	--
	--

	dispatch = function(info, pubsub, params)
		local dispatcher = params.dispatcher

		pubsub:Subscribe(info.next, function(func)
			dispatcher:addEventListener(info.name, function(_)
				return func()
			end)
		end)
	end,

	print = function(info, pubsub)
		local desc = info.description

		pubsub:Publish(function()
			print("PRINTED:", desc)
		end, info.uid, "do")
	end,

	--
	--
	--

	rect = function(info, pubsub, params)
		local rect = display.newRect(params.group, info.x, info.y, info.width, info.height)

		rect.rotation = info.rotation or 0

		if info.fill_color then
			rect:setFillColor(unpack(info.fill_color))
		end

		if info.path then
			local path = rect.path

			for k, v in pairs(info.path) do
				path[k] = v
			end
		end

		if info.self then
			pubsub:Publish(rect, info.uid, "self")
		end
	end,

	--
	--
	--

	["rect:get_x"] = function(info, pubsub)
		if info.result then
			local object

			pubsub:Subscribe(info.self, function(payload)
				object = payload
			end)
			pubsub:Publish(function()
				return object and object.x or 0
			end, info.uid, "result")
		end
	end,

	["rect:get_y"] = function(info, pubsub)
		if info.result then
			local object

			pubsub:Subscribe(info.self, function(payload)
				object = payload
			end)
			pubsub:Publish(function()
				return object and object.y or 0
			end, info.uid, "result")
		end
	end,

	["rect:get_pos"] = function(info, pubsub)
		--
	end,

	["rect:set_x"] = function(info, pubsub)
		if info["do"] then
			local next, object, get_x = DefEvent

			pubsub:Subscribe(info.self, function(payload)
				object = payload
			end)
			pubsub:Subscribe(info.x, function(vfunc)
				get_x = vfunc
			end)
			pubsub:Subscribe(info.next, function(nfunc)
				next = nfunc
			end)
			pubsub:Publish(function()
				if object and get_x then
					object.x = get_x()

					return next()
				end
			end, info.uid, "do")
		end
	end,

	["rect:set_y"] = function(info, pubsub)
		if info["do"] then
			local next, object, get_y = DefEvent

			pubsub:Subscribe(info.self, function(payload)
				object = payload
			end)
			pubsub:Subscribe(info.y, function(vfunc)
				get_y = vfunc
			end)
			pubsub:Subscribe(info.next, function(nfunc)
				next = nfunc
			end)
			pubsub:Publish(function()
				if object and get_y then
					object.y = get_y()

					return next()
				end
			end, info.uid, "do")
		end
	end,

	["rect:set_pos"] = function(info, pubsub)
		--
	end
}

--
--
--

local function AuxIterList (list)
	local index = list.index + 1
	local name = list[index]

	if name then
		list.index = index

		local ntype = type(name)

		if ntype == "string" then
			local which, rule = list.pattern:GetNodeType(name) -- TODO: assert() or skip if nil?

			return name, rule, which
		elseif ntype == "function" then
			return name, "own_objects"
		-- TODO: other type?
		end
	end
end

local function IterList (list, np)
	list.pattern, list.index = np, 0

	return AuxIterList, list
end

local function GetTextfieldData (textfield)
	return textfield.text
end

--
--
--

local function IterXYR (np)
	return IterList({
		"x", "y",
		"result"
	}, np)
end

M.general_menu_items = {
	Common = {
		Int = objects.MakeFactory{ title = "Int", type = "get_int", exports = "int" },
		Uint = objects.MakeFactory{ title = "Uint", type = "get_uint", exports = "uint" },
		SetInt = objects.MakeFactory{ title = "Set(int)", type = "set_int", imports = "int" },
		SetUint = objects.MakeFactory{ title = "Set(uint)", type = "set_uint", imports = "uint" },
		Fire = objects.MakeFactory{ title = "Fire!", type = "act", exports = "event" },
		OnComplete = objects.MakeFactory{ title = "On(complete)", type = "react", imports = "event" }
	},

	Operators = {
		["x + y"] = objects.MakeFactory{
			title = "+ (ints)", type = "add", imports = { x = "int", y = "int" }, exports = "int",
			iter = IterXYR
		},

		["x * y"] = objects.MakeFactory{
			title = "* (uints)", type = "mul", imports = { x = "uint", y = "uint" }, exports = "uint",
			iter = IterXYR
		},

		["x - y"] = objects.MakeFactory{
			title = "- (ints)", type = "sub", imports = { x = "int", y = "int" }, exports = "int",
			iter = IterXYR
		},

		["x == y"] = objects.MakeFactory{
			title = "== (numbers)", type = "equal", imports = { x = "number", y = "number" }, exports = "boolean",
			iter = IterXYR
		},

		["x < y"] = objects.MakeFactory{
			title = "< (numbers)", type = "lt", imports = { x = "number", y = "number" }, exports = "boolean",
			iter = IterXYR
		}
	},

	Control = {
		["If-Else"] = objects.MakeFactory{
			title = "If-Else", type = "branch", imports = { condition = "boolean", ["if"] = "event", ["else"] = "event" }, exports = "event",

			iter = function(np)
				return IterList({
					"condition",
					"if", "else",
					"do"
				}, np)
			end
		},

		Loop = objects.MakeFactory{
			title = "Do n times", type = "loop", imports = { action = "event", count = "uint", ["break"] = "boolean", next = "event" }, exports = "event",

			iter = function(np)
				return IterList({
					"action", "next",
					"count", "break",
					"do"
				}, np)
			end
		},

		["Once Only"] = objects.MakeFactory{
			title = "Do once only", type = "once", imports = { action = "event", next = "event" }, exports = "event",

			iter = function(np)
				return IterList({
					"action", "next",
					"do"
				}, np)
			end
		},

		["Timer (once)"] = objects.MakeFactory{
			title = "One-shot timer", type = "timer_once", imports = { delay = "uint", action = "event", next = "event" }, exports = "event",

			iter = function(np)
				return IterList({
					"action", "next",
					"delay",
					function(group)
						local input = string_box.New("0", 120, 25)

						group:insert(input)
						input:SetGoodValuePredicate(IsUint)

						interface.IntroduceObject(input, { side = "lhs" })
						objects.MakeNonNodeDatumAvailable(input, "delay_value", GetTextfieldData)
					end,
					"do"
				}, np)
			end
		},

		["Timer (repeat)"] = objects.MakeFactory{
			title = "Repeating timer", type = "timer_repeat", imports = { delay = "uint", action = "event", limit = "uint", next = "event" }, exports = "event",

			iter = function(np)
				return IterList({
					"action", "next",
					"delay",
					function(group)
						local input = string_box.New("0", 120, 25)

						group:insert(input)
						input:SetGoodValuePredicate(IsUint)

						interface.IntroduceObject(input, { side = "lhs" })
						objects.MakeNonNodeDatumAvailable(input, "delay_value", GetTextfieldData)
					end,
					"limit",
					function(group)
						local input = string_box.New("0", 120, 25)

						group:insert(input)
						input:SetGoodValuePredicate(IsUint)

						interface.IntroduceObject(input, { side = "lhs" })
						objects.MakeNonNodeDatumAvailable(input, "limit_value", GetTextfieldData)
					end,
					"do"
				}, np)
			end
		}
	},

	Other = {
		Dispatch = objects.MakeFactory{
			title = "On(dispatch)", type = "dispatch", imports = "event",

			iter = function(np)
				return IterList({
					function(group)
						local str = display.newText(group, "Name:", 0, 0, native.systemFont, 20)
						local input = string_box.New("", 120, 25)

						group:insert(input)

						interface.IntroduceObject(str, { side = "lhs", extra = 1, y_padding = 10 })
						objects.MakeNonNodeDatumAvailable(input, "name", GetTextfieldData)
					end,
					"next"
				}, np)
			end
		},

		Print = objects.MakeFactory{
			title = "Print(message)", type = "print", exports = "event",

			iter = function(np)
				return IterList({
					"do",
					function(group)
						local str = display.newText(group, "Message:", 0, 0, native.systemFont, 20)
						local input = string_box.New("", 120, 25)

						group:insert(input)

						interface.IntroduceObject(str, { side = "lhs", extra = 1, y_padding = 10 })
						objects.MakeNonNodeDatumAvailable(input, "description", GetTextfieldData)
					end
				}, np)
			end
		}
	}
}

--
--
--

M.type_specific_menu_items = {
	rect = function()
		return {
			["Get x"] = objects.MakeFactory{
				title = "Get object.x", type = "rect:get_x", imports = { self = "object" }, exports = "number"
			},

			["Get y"] = objects.MakeFactory{
				title = "Get object.y", type = "rect:get_y", imports = { self = "object" }, exports = "number"
			},
--[[
			get_pos = objects.MakeFactory{
			},
]]
			["Set x"] = objects.MakeFactory{
				title = "Set object.x", type = "rect:set_x", imports = { self = "object", x = "number", next = "event" }, exports = "event"
			},

			["Set y"] = objects.MakeFactory{
				title = "Set object.y", type = "rect:set_y", imports = { self = "object", y = "number", next = "event" }, exports = "event"
			},
--[[
			set_pos = objects.MakeFactory{
			}
]]
		}
	end
}

--
--
--

return M