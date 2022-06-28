--- Various operations related to layout of nodes and their boxes.

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
local max = math.max
local remove = table.remove
local setmetatable = setmetatable
local type = type

-- Modules --
local node_runner = require("solar2d_ui.patterns.node_runner")

-- Unique keys --
local _extra = {}
local _hidden_during_visits = {}
local _side = {}
local _sync = {}

-- Exports --
local M = {}

--
--
--

local NodeLayout = {}

NodeLayout.__index = NodeLayout

--
--
--

local function AuxConnectedObjects (connected, n)
	if n > 0 then
		local node = connected[n]

		connected[n] = nil

		return n - 1, node
	end
end

local function EnumConnections (node, out)
	return node_runner.GetConnectedObjects(node, out) -- if out absent, i.e. stack is empty, GetConnectedObjects() makes new table
end

--- DOCME
function NodeLayout:BreakConnections (node)
	local stack = self.m_connected_stack
	local connected, n = EnumConnections(node, remove(stack))

	for _, object in AuxConnectedObjects, connected, n do
		node_runner.DisconnectObjects(node, object)
	end

	stack[#stack + 1] = connected
end

--
--
--

local Dimensions = {} -- n.b. immediately consumed, so fine as global

local function GetSide (node)
	return node[_side] or node_runner.GetSide(node)
end

local function AuxGetDimensions (item, dims, group, index)
	local separation, extra, side, sync = dims.separation, item[_extra] or 0, GetSide(item)

	if side then
		local w, h, y = extra * separation, 0

		for i = 0, extra do
			local elem = group[index + i]
	
			w, h, sync = w + elem.contentWidth, max(h, elem.contentHeight), sync or elem[_sync]
		end

		if side == "lhs" then
			dims.left, y = max(dims.left, w), dims.left_y
			dims.left_y = y + h + separation
		else
			dims.right, y = max(dims.right, w), dims.right_y
			dims.right_y = y + h + separation
		end

		local mid = y + h / 2

		for i = 0, extra do
			group[index + i].y_offset = mid
		end
	else
		-- TODO?: use extra?
		dims.center, sync = max(dims.center, item.contentWidth), item[_sync]

        local cy, ch = dims.center_y, item.contentHeight

		item.y_offset, dims.center_y = cy + ch / 2, cy + ch + separation
	end

	if sync then
		local y = max(dims.center_y, dims.left_y, dims.right_y)

		dims.center_y, dims.left_y, dims.right_y = y, y, y
	end

	return extra
end

--- DOCME
function NodeLayout:GetDimensions (group)
	local edge, separation = self.m_edge, self.m_separation

	Dimensions.center, Dimensions.left, Dimensions.right = 0, 0, 0
	Dimensions.left_y, Dimensions.right_y, Dimensions.center_y = edge, edge, edge
	Dimensions.separation = separation

	self:VisitGroup(group, AuxGetDimensions, Dimensions)

	local w = Dimensions.center

	if Dimensions.left > 0 and Dimensions.right > 0 then -- on each side?
		w = max(2 * max(Dimensions.left, Dimensions.right) + self.m_middle, w)
	elseif Dimensions.left + Dimensions.right > 0 then -- one side only
		w = max(w, Dimensions.left, Dimensions.right)
	end

	w = w + 2 * edge

	local h = max(Dimensions.center_y, Dimensions.left_y, Dimensions.right_y) - separation -- account for last item added

    return w, h + edge -- height already includes one "edge" from starting offsets
end

--
--
--

--- DOCME
function NodeLayout:HideItemDuringVisits (item)
    item[_hidden_during_visits] = true
end

--
--
--

--- DOCME
function NodeLayout:PlaceItems (item, back, group, index)
	local placement, side, x, y = self.m_placement, GetSide(item), back.x, back.y - back.height / 2

	if side then
		local extra, offset, half = item[_extra], self.m_edge, back.width / 2

		for i = 0, extra or 0 do
			item = group[index + i]

			if side == "lhs" then
				placement(item, "x", x - half + offset)
			else
				placement(item, "x", x + half - offset)
			end

			placement(item, "y", y + item.y_offset)

			offset = offset + item.contentWidth + self.m_separation
		end

		return extra
	else
		placement(item, "x", x)
		placement(item, "y", y + item.y_offset)
	end
end

--
--
--

--- DOCME
function NodeLayout:SetEdgeWidth (edge)
    self.m_edge = edge
end

--
--
--

--- DOCME
function NodeLayout:SetExtraTrailingItemsCount (item, extra)
	item[_extra] = extra
end

--
--
--

--- DOCME
function NodeLayout:SetMiddleWidth (mid)
    self.m_middle = mid
end

--
--
--

--- DOCME
function NodeLayout:SetPlacementFunc (func)
    self.m_placement = func
end

--
--
--

--- DOCME
function NodeLayout:SetSeparation (sep)
    self.m_separation = sep
end

--
--
--

--- DOCME
function NodeLayout:SetSideExplicitly (node, side)
	node[_side] = side
end

--
--
--

--- DOCME
function NodeLayout:SetSyncPoint (group)
	local n = group.numChildren

	if n > 0 then
		group[n][_sync] = true
	end
end

--
--
--

--- DOCME
function NodeLayout:VisitGroup (group, func, arg)
	local index, n, want_self = 1, group.numChildren, type(func) == "string"

	if want_self then
		func = assert(self[func], "Invalid method name")
	end

	repeat
		local item, extra = group[index]

		if not item[_hidden_during_visits] then
			if want_self then
				extra = func(self, item, arg, group, index)
			else
				extra = func(item, arg, group, index)
			end
		end

		index = index + 1 + (extra or 0)
	until index > n
end

--
--
--

--- DOCME
function NodeLayout:VisitNodesConnectedToChildren (parent, func, arg)
	local stack = self.m_connected_stack
	local connected = remove(stack)

	for i = 1, parent.numChildren do
		local parent_node, n = parent[i]

		connected, n = EnumConnections(parent_node, connected)

		for _, cnode in AuxConnectedObjects, connected, n do
			func(cnode, parent_node, arg)
		end
	end

	stack[#stack + 1] = connected
end

--
--
--

--- DOCME
function M.New ()
	return setmetatable({ m_connected_stack = {} }, NodeLayout)
end

--
--
--

return M