--- A runner comprises various display objects, the so-called "nodes", that may be connected
-- to one another, with some further operations to manage these relationships. 
--
-- @todo Skins?

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
local assert = assert
local error = error
local ipairs = ipairs
local pairs = pairs
local pcall = pcall
local rawequal = rawequal
local remove = table.remove
local setmetatable = setmetatable
local type = type

-- Modules --
local curve_between_nodes = require("solar2d_ui.utils.curve_between_nodes")
local curve_plotter = require("solar2d_ui.utils.curve_plotter")
local position = require("solar2d_ui.utils.position")

-- Solar2D globals --
local display = display

-- Cached module members --
local _ConnectObjects_
local _DisconnectObjects_

-- Exports --
local M = {}

--
--
--

local NodeRunner = {}

NodeRunner.__index = NodeRunner

--
--
--

local ContainedBy = {}

local function ChooseFrontmost (n)
	local over = position.Frontmost(ContainedBy, n)

	for i = 1, n do
		ContainedBy[i] = false
	end

	return over
end

local NodeInfo = {}

local function GetPairingInfo (node)
	local node_info = NodeInfo[node]

	return node_info.owner_id, not node_info.is_lhs
end

local BroadcastState = {}

local function BroadcastPairing (emphasize, items, node, touch_id, how)
	local id, is_rhs = GetPairingInfo(node)

	BroadcastState.node, BroadcastState.touch_id = node, touch_id

	for _, item in ipairs(items) do
		local node_info = NodeInfo[item]

		BroadcastState.owners_differ = not rawequal(id, node_info.owner_id)
		BroadcastState.sides_differ = node_info.is_lhs == is_rhs

		emphasize(how, item, BroadcastState)
	end

	BroadcastState.node = nil
end

local DefCushion = 5

local DefRadius = 25

local function InNode (node, x, y)
	local npath, lx, ly = node.path, node:localToContent(0, 0)
	local radius, w = npath.radius, npath.width

	if w or not radius then
		local h = npath.height

		radius = (w and h) and (w + h) / 4 or DefRadius -- divide by 4 for average of half-width and -height
	end

	radius = radius + DefCushion -- accept slightly outside inputs

	return (x - lx)^2 + (y - ly)^2 < radius^2
end

local function MayPair (item, id, is_rhs)
	local node_info = NodeInfo[item]

	return node_info.is_lhs == is_rhs and not rawequal(id, node_info.owner_id)
end

local function FindNodeContainingPoint (runner, node, x, y)
	local n, owner_id, is_rhs = 0, GetPairingInfo(node)

	for _, item in ipairs(runner.m_items) do
		if MayPair(item, owner_id, is_rhs) and InNode(item, x, y) then
			n, ContainedBy[n + 1] = n + 1, item
		end
	end

	return n >= 1 and ChooseFrontmost(n) or nil
end

local function Highlight (node, emphasize, is_over)
	if node and emphasize then
		emphasize("highlight", node, is_over)
	end
end

local function UpdateOver (runner, emphasize, node, event)
	local id, over_set, over = event.id, runner.m_over_set, FindNodeContainingPoint(runner, node, event.x, event.y)

	if emphasize and over_set[id] ~= over then
		Highlight(over_set[id], emphasize, false)
		Highlight(over, emphasize, true)
	end

	over_set[id] = over
end

local PlotterOpts = {}

local function GetPlotterOpts (curve)
	local knot_func, knots = curve:GetKnotFunc(), curve:GetKnots()

	if knot_func and knots then -- enough to use knots?
		PlotterOpts.knot_func = knot_func
		PlotterOpts.knots = knots
		PlotterOpts.shift = curve:GetShift()

		return PlotterOpts
	else -- wipe any collectible members
		PlotterOpts.knot_func, PlotterOpts.knots = nil
	end
end

local function NodeTouch (event)
	local id, node = event.id, event.target
	local node_info = NodeInfo[node]
	local curve, runner = node_info.temp_curve, assert(node_info and node_info.runner, "Object is not a node")

	if event.phase == "began" then
		if runner.m_can_touch(node, id) then
			display.getCurrentStage():setFocus(node, id)

			local candidates, gather, items = runner.m_candidates, runner.m_gather, runner.m_items

			if gather then
				gather(items, event, node)

				local wi = 1

				for _, item in ipairs(items) do
					if candidates[item] then
						items[wi], wi = item, wi + 1
					end
				end

				for i = #items, wi, -1 do
					items[i] = nil
				end
			end

			local emphasize, temp_curve = runner.m_emphasize, curve_between_nodes.New()

			runner.m_with_temp_curve("began", temp_curve)

			node_info.temp_curve, temp_curve.x_nc, temp_curve.y_nc = temp_curve, event.x, event.y

			if emphasize then
				BroadcastPairing(emphasize, items, node, id, "began")
			end

			UpdateOver(runner, emphasize, node, event)
		else
			return false
		end
	elseif curve then -- guard against swipes
		if event.phase == "moved" then
			local ex, ey = event.x, event.y
			local line = runner.m_plotter:FromObjectToPoint(node, ex, ey, GetPlotterOpts(curve))

			curve:ReplaceDisplayObject(line)

			curve.x_nc, curve.y_nc = ex, ey

			UpdateOver(runner, runner.m_emphasize, node, event)
		else
			display.getCurrentStage():setFocus(node, nil)

			local over, emphasize, connected = runner.m_over_set[id], runner.m_emphasize

			if over then
				Highlight(over, emphasize, false)

				connected = runner.m_can_touch(over, event.id)

				if connected then
					_ConnectObjects_(node, over)
				end
			end

			local temp_curve = node_info.temp_curve

			if temp_curve:HasDisplayObject() then
				runner.m_with_temp_curve(connected and "connected" or "ended", temp_curve)

				temp_curve:RemoveDisplayObject()
			end

			node_info.temp_curve = nil

			if emphasize then
				BroadcastPairing(emphasize, runner.m_items, node, id, "ended")
			end

			runner.m_over_set[id] = nil

			if runner.m_gather then
				local items = runner.m_items

				for i = #items, 1, -1 do
					items[i] = nil
				end
			end
		end
	end

	return true
end

local function ForEachOtherNode (node_info, func, arg1, arg2)
	for k, v in pairs(node_info) do
		if type(k) ~= "string" then
			func(k, v, arg1, arg2)
		end
	end
end

local function DetachOtherNode (other_node, _, node)
	local other_info = NodeInfo[other_node]

	_DisconnectObjects_(node, other_node)

	other_info[node] = nil
end

local function WipeObject (node)
	local node_info = NodeInfo[node]

	ForEachOtherNode(node_info, DetachOtherNode, node)

	local runner = node_info.runner
	local over_set = runner.m_over_set

	for id, over in pairs(over_set) do
		if over == node then
			over_set[id] = nil
		end
	end

	local temp_curve = node_info.temp_curve

	if temp_curve and temp_curve:HasDisplayObject() then
		runner.m_with_temp_curve("cancelled", temp_curve)

		temp_curve:RemoveDisplayObject()
	end

	local candidates, items = runner.m_candidates, runner.m_items

	if candidates then
		candidates[node] = nil
	end

	for i, item in ipairs(items) do
		if item == node then
			remove(items, i)

			break
		end
	end
end

local function AuxRemoveObject (node)
	WipeObject(node)

	NodeInfo[node] = nil
end

local function RemoveObject (event)
	AuxRemoveObject(event.target)
end

local NodeInfoID = 0

local function AddNodeInfo (object)
	local node_info = { id = NodeInfoID }

	NodeInfo[object], NodeInfoID = node_info, NodeInfoID + 1

	object:addEventListener("finalize", RemoveObject)
	object:addEventListener("touch", NodeTouch)

	return node_info
end

local function DetachOtherNodeIfOwnersMatch (other_node, curve, node, owner_id)
	if owner_id == NodeInfo[other_node].owner_id then
		-- TODO: disconnect
		-- anything else?
	end
end

--- DOCME
-- @pobject object
-- @param owner_id
-- @string what Either **"lhs"** or **"rhs"**, indicating that the node is on the left- or
-- right-hand side, respectively.
function NodeRunner:AddNode (object, owner_id, what)
	assert(what == "lhs" or what == "rhs", "Invalid node")

	local is_lhs, node_info = what == "lhs", NodeInfo[object]

	if not node_info then
		node_info = AddNodeInfo(object)
	elseif node_info.runner ~= self or node_info.is_lhs ~= is_lhs then
		WipeObject(object) -- TODO: do all the behaviors make sense?
	else
		ForEachOtherNode(node_info, DetachOtherNodeIfOwnersMatch, object, node_info.owner_id)
	end

	node_info.runner, node_info.is_lhs, node_info.owner_id = self, is_lhs, owner_id

	if self.m_gather then
		self.m_candidates[object] = true
	else
		local items = self.m_items

		items[#items + 1] = object
	end

	Highlight(object, self.m_emphasize, false)
end

--
--
--

--- DOCME
function NodeRunner:Clear ()
	if self.m_gather then
		for item in pairs(self.m_candidates) do
			AuxRemoveObject(item)
		end

		self.m_candidates = {}
	else
		for _, item in ipairs(self.m_items) do
			AuxRemoveObject(item)
		end
	end

	self.m_items = {}
end

--
--
--

--- DOCME
-- @pobject object1
-- @pobject object2
-- @treturn boolean X
function M.AreConnected (object1, object2)
	local node_info = NodeInfo[object1]

	return (node_info and node_info[object2]) ~= nil
end

--
--
--

local function GetRunnerAndNodeInfo (object)
	local node_info = NodeInfo[object]

	return node_info and node_info.runner, node_info
end

--- DOCME
-- @pobject object1
-- @pobject object2
-- @return[1] **true**
-- @return[2] **false**
-- @treturn string Y
function M.ConnectObjects (object1, object2)
	local ninfo1, runner, ninfo2 = NodeInfo[object1], GetRunnerAndNodeInfo(object2)

	if not (ninfo1 and ninfo2) then
		return false, "Object #" .. (ninfo1 and "2" or "1") .. " is not a node"
	elseif runner ~= ninfo1.runner then
		return false, "Objects belong to different runners"
	elseif ninfo1[object2] ~= nil then
		return false, ninfo1[object2] and "Nodes already connected" or "Connection in progress"
	elseif not runner.m_can_connect(object1, object2) then
		return false, "Nodes not connectable"
	end

	ninfo1[object2], ninfo2[object1] = false, false -- guard against duplicate connection attempts

	local curve = curve_between_nodes.New()
	local ok, err = pcall(runner.m_connect, "connect", object1, object2, curve)

	if ok then
		local line = runner.m_plotter:BetweenObjects(object1, object2, GetPlotterOpts(curve))

		curve.first_id_nc = ninfo1.id

		curve:ReplaceDisplayObject(line)

		ninfo1[object2], ninfo2[object1] = curve, curve

		return true
	else
		ninfo1[object2], ninfo2[object1] = nil

		error(err)
	end
end

--
--
--

--- DOCME
-- @pobject object1
-- @pobject object2
-- @return[1] **true**
-- @return[2] **false**
-- @treturn string Y
function M.DisconnectObjects (object1, object2)
	local ninfo1, ninfo2 = NodeInfo[object1], NodeInfo[object2]

	if not (ninfo1 and ninfo2) then
		return false, "Object #" .. (ninfo1 and "2" or "1") .. " is not a node"
	end

	local curve = ninfo1[object2]

	if not curve then
		return false, curve == nil and "Objects are not attached" or "Disconnection in progress"
	end

	ninfo1[object2], ninfo2[object1] = false, false -- guard against duplicate disconnection attempts

	local ok, err = pcall(ninfo1.runner.m_connect, "disconnect", object1, object2, curve)

	if ok then
		curve:RemoveDisplayObject()

		ninfo1[object2], ninfo2[object1] = nil
	else
		ninfo1[object2], ninfo2[object1] = curve, curve

		error(err)
	end

	return true
end

--
--
--

function NODE_INFO (node)
	local ni = NodeInfo[node]

	if ni then
		local info = {}
		for k, v in pairs(ni) do
if k ~= "runner" and k ~= "id" and k ~= "is_lhs" and k ~= "owner_id" then -- skip some unenlightening stuff
			info[#info + 1] = ("%s = %s"):format(tostring(k), tostring(v))
end
		end
		return "{ " .. table.concat(info, ", ") .. " }"
	end
end

--
--
--

--- DOCME
-- @pobject object
function M.GetRunner (object)
	return (GetRunnerAndNodeInfo(object))
end

--
--
--

local ConnectedN

local function AuxGetConnectedObjects (object, curve, out)
	if curve then -- skip connection guard
		ConnectedN, out[ConnectedN + 1] = ConnectedN + 1, object
	end
end

--
--
--

--- DOCME
-- @pobject object
-- @ptable[opt] out
-- @treturn table X
-- @treturn uint C
function M.GetConnectedObjects (object, out)
	ConnectedN, out = 0, out or {}

	local node_info = NodeInfo[object]

	if node_info then
		ForEachOtherNode(node_info, AuxGetConnectedObjects, out)
	end

	return out, ConnectedN
end

--
--
--

--- DOCME
function M.GetOwner (object)
	local node_info = NodeInfo[object]

	return node_info and node_info.owner_id
end

--
--
--

--- DOCME
function M.GetSide (object)
	local node_info = NodeInfo[object]

	return node_info and (node_info.is_lhs and "lhs" or "rhs")
end

--
--
--

local function UpdateCurveFromOtherNode (other_node, curve, node, plotter)
	local other_info = NodeInfo[other_node]

	if curve.first_id_nc == other_info.id then -- keep objects in order, e.g. for knots
		other_node, node = node, other_node
	end

	local line = plotter:BetweenObjects(node, other_node, GetPlotterOpts(curve))

	curve:ReplaceDisplayObject(line)
end

local function LateUpdate (runner)
	local plotter, update_list = runner.m_plotter, runner.m_update_list

	for node in pairs(update_list) do
		local node_info = NodeInfo[node]
		local temp_curve = node_info.temp_curve

		if temp_curve then
			local line = plotter:FromObjectToPoint(node, temp_curve.x_nc, temp_curve.y_nc, GetPlotterOpts(temp_curve))

			temp_curve:ReplaceDisplayObject(line)
		end

		ForEachOtherNode(node_info, UpdateCurveFromOtherNode, node, plotter)

		update_list[node] = nil
	end

	Runtime:removeEventListener("lateUpdate", runner)

	runner.lateUpdate = nil
end

--- DOCME
-- @pobject object
function M.SetDirty (object)
	local runner = GetRunnerAndNodeInfo(object)

	if runner then
		runner.m_update_list[object] = true

		if not runner.lateUpdate then
			runner.lateUpdate = LateUpdate

			Runtime:addEventListener("lateUpdate", runner)
		end
	end
end

--
--
--

local function DefCanDo () return true end

local DefWithTempCurve = DefCanDo

--- DOCME
-- @ptable params
-- @treturn NodeRunner NR
function M.New (params)
	assert(type(params) == "table", "Expected parameters table")

	return setmetatable({
		m_can_connect = params.can_connect or DefCanDo,
		m_can_touch = params.can_touch or DefCanDo,
		m_candidates = params.gather and {},
		m_connect = assert(params.connect, "Connection function required"),
		m_emphasize = params.emphasize,
		m_gather = params.gather,
		m_items = {},
-- TODO: handle lines group being destroyed?
		m_over_set = {},
		m_plotter = curve_plotter.New(params),
		m_update_list = {},
		m_with_temp_curve = params.with_temp_curve or DefWithTempCurve
	}, NodeRunner)
end

--
--
--

_ConnectObjects_ = M.ConnectObjects
_DisconnectObjects_ = M.DisconnectObjects

return M