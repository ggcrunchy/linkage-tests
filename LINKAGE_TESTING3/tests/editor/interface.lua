--- Building blocks of shader graph interface.

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
local abs = math.abs
local assert = assert
local pairs = pairs
local type = type

-- Modules --
local drag = require("solar2d_ui.utils.drag")
local node_connection = require("tests.editor.node_connection")
local node_layout = require("tests.editor.node_layout")
local node_runner = require("solar2d_ui.patterns.node_runner")
local runner_theme = require("tests.editor.runner_theme")

-- Solar2D globals --
local display = display
local native = native

-- Exports --
local M = {}

--
--
--

local Layout = node_layout.New()

--
--
--

Layout:SetEdgeWidth(5)
Layout:SetMiddleWidth(14)
Layout:SetSeparation(5)

local function StandardColor (what)
	if what == "delete" then
		return 1, 0, 0, 1
	end

	local r, b = .125, 1

	if what == "lhs" then
		r, b = b, r
	end

	return r, .125, b, .75
end

local Bounds = {}

for k, v in pairs(drag.ContentRegion().contentBounds) do
	Bounds[k] = v
end

local ClampRegion = { contentBounds = Bounds }

local function GetClampRegion ()
	return ClampRegion
end

local Drag = drag.Make{
	dragee = "parent", clamp_region = GetClampRegion,

	post_move = function(group, _)
        for i = 1, group.numChildren do
            node_runner.SetDirty(group[i]) -- no-op if not a node
        end
    end
}

local function Placement_Direct (item, what, value) -- place objects exactly where we say
	item[what] = value
end

local SpoofTouchEvent = { name = "touch", id = 0 }

local function Spoof (back, phase, x, y)
	SpoofTouchEvent.phase, SpoofTouchEvent.target, SpoofTouchEvent.x, SpoofTouchEvent.y = phase, back, x, y

	back:dispatchEvent(SpoofTouchEvent)

	SpoofTouchEvent.target = nil
end

--- DOCME
function M.CommitRect (group, x, y)
	local w, h = Layout:GetDimensions(group)
    local back = display.newRoundedRect(group, x, y, w, h, 12)

    back:addEventListener("touch", Drag)
    back:setFillColor(.7)
    back:toBack()

	Layout:HideItemDuringVisits(back)
	Layout:SetPlacementFunc(Placement_Direct)

	group.back = back -- keep a reference to back, rather than rely on it being child #1

	Layout:VisitGroup(group, "PlaceItems", back)

	Spoof(back, "began", x, y)
	Spoof(back, "ended")
end

--
--
--

--- DOCME
function M.GetDataStream (group)
	group.data_stream = group.data_stream or {}

	return group.data_stream
end

--
--
--

local OwnerID = 1

--- DOCME
function M.GetOwnerID ()
	return OwnerID
end

--
--
--

--- DOCME
function M.IntroduceObject (object, params)
	assert(type(params) == "table", "Non-table params")

	local group, side, extra = object.parent, assert(params.side, "Must supply explicit side"), params.extra or 0

	assert(group[group.numChildren - extra] == object, "Objects expected to be final (newest) elements in group")

	Layout:SetSideExplicitly(object, side)
	Layout:SetExtraTrailingItemsCount(object, extra)

	if params.y_padding then
		Layout:SetYPadding(object, params.y_padding)
	end

	local anchor = side == "lhs" and 0 or 1

	for i = 0, extra do
		group[group.numChildren - i].anchorX = anchor
	end
end

--
--
--

local function Circle (group, width, radius, ...)
	local circle = display.newCircle(group, 0, 0, radius)

	circle:setFillColor(...)

	circle.strokeWidth = width

	return circle
end

local function AuxDelete (group)
	for i = 1, group.numChildren do
		Layout:BreakConnections(group[i]) -- no-op if not a node
	end

	group:removeSelf()
		-- TODO: tethered groups
end

local function Delete (event)
	if event.phase == "ended" then
		AuxDelete(event.target.parent)
	end

	return true
end

--- DOCME
function M.NewDeleteControl (group)
	local object = Circle(group, 3, 7, StandardColor("delete"))

	object:addEventListener("touch", Delete)
	object:setFillColor(1, 0, 0)
	object:setStrokeColor(.7, 0, 0)

	Layout:AffectsCenter(object)
	Layout:SetSideExplicitly(object, "lhs")

	object.anchorX = 0

	return object
end

--
--
--

--- DOCME
function M.NewNode (runner, group, what, name, payload_type, rule)
	local object = Circle(group, 3, 7, StandardColor(what))
	local anchor = (what == "lhs" or what == "delete") and 0 or 1

	runner:AddNode(object, OwnerID, what)
	Layout:SetExtraTrailingItemsCount(object, payload_type and 2 or 1)

	node_connection.SetName(object, name)
	node_connection.SetRule(object, rule) -- if absent, no-op

	local text = display.newText(group, name, 0, 0, native.systemFont, 20) -- TODO: might want more friendly text

	text.anchorX = anchor

	if payload_type then
		local ttext = display.newText(group, payload_type, 0, 0, native.systemFont, 20)

		ttext:setFillColor(0, 1, 1)

		ttext.anchorX = anchor
	end

	object.anchorX = anchor

	return object
end

--
--
--

--- DOCME
function M.NewRunner (back_group)
	local params = runner_theme.MakeRunnerParams{ back_group = back_group, get_color = StandardColor }
	local connect1, can_connect, connect2 = params.connect, node_connection.MakeRunnerFuncs{ layout = Layout }

	params.can_connect = can_connect

	function params.connect (how, a, b, curve)
		connect1(how, a, b, curve) -- theme-related bits
		connect2(how, a, b, curve) -- connection-related ones
	end

	return node_runner.New(params)
end

--
--
--

--- DOCME
function M.Rect (title)
    local group = display.newGroup()

	display.newText(group, title, 0, 0, native.systemFontBold, 18)

    return group
end

--
--
--

--- DOCME
function M.SetDragY (y)
	Bounds.yMin = y
end

--
--
--

--- DOCME
function M.SetOwnerID (owner_id)
	OwnerID = owner_id
end

--
--
--

--- DOCME
function M.Sync (node)
	Layout:SetSyncPoint(node)
end

--
--
--

return M