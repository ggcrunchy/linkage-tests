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

-- Modules --
local boxes = require("tests.shader_graph.boxes")
local code_gen = require("tests.shader_graph.code_gen")
local drag = require("solar2d_ui.utils.drag")
local node_layout = require("tests.shader_graph.node_layout")
local node_runner = require("solar2d_ui.patterns.node_runner")
local node_state = require("tests.shader_graph.node_state")
local runner_basics = require("tests.shader_graph.runner_basics")
local touch = require("solar2d_ui.utils.touch")

-- Solar2D globals --
local display = display
local native = native
local timer = timer
local transition = transition

-- Exports --
local M = {}

--
--
--

node_layout.SetEdgeWidth(5)
node_layout.SetMiddleWidth(20)
node_layout.SetSeparation(7)

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
            local item = group[i]

            if item.bound_bit then -- nodes will have this member
                node_runner.SetDirty(item)
            end
        end
    end
}

local function Place_Direct (item, what, value) -- place objects exactly where we say
	item[what] = value
end

local OwnerID = 1

--- DOCME
function M.CommitRect (group, x, y)
	group.fully_bound, group.next_bit = group.next_bit - 1
    group.bound = 0 -- when = fully_bound, all nodes are connected

	local w, h = node_layout.GetDimensions(group)
    local back = display.newRoundedRect(group, x, y, w, h, 12)

    back:addEventListener("touch", Drag)
    back:setFillColor(.7)
    back:toBack()

	node_layout.HideItemDuringVisits(back)
	node_layout.SetPlaceFunc(Place_Direct)

	group.back = back -- back should be in element 1, but keep a ref just in case

	node_layout.VisitGroup(group, node_layout.PlaceItems, back)
	touch.Spoof(back)

    OwnerID = OwnerID + 1
end

--
--
--

local BackGroup = display.newGroup()

--- DOCME
function M.GetBackGroup ()
	return BackGroup
end

--
--
--

local ToUpdate

local ResizeParams = {
	onComplete = function(object)
		local to_update = object.to_update

		if to_update then
			object.to_update[object] = object.to_update[object] - 1
		end
	end, time = 150
}

local function Place_MightTransition (item, what, value) -- set objects' final destinations, preferring a transition
														-- but opting for direct placement when not worth the hassle
	local cur = item[what]
	local diff = cur - value

	if abs(diff) >= 3 then -- enough to be worth transitioning?
		ToUpdate = ToUpdate or {}
		ToUpdate[item] = (ToUpdate[item] or 0) + 1 -- how many properties need waiting on?
		item.to_update, ResizeParams[what] = ToUpdate, value

		transition.to(item, ResizeParams)

		ResizeParams[what] = nil
	elseif diff ~= 0 then -- at least needs an update?
		Place_Direct(item, what, value)
	end
end

local function AuxDecayItem (item)
	item:setFillColor(1, 0, 1)

	item.text = "?"
end

local can_connect, connect, do_decays = boxes.MakeRunnerFuncs{
	decay_item = function(item)
		if item.needs_resolving then -- TODO: might be string, be more fancy with text, colors, etc.
			AuxDecayItem(item)
		end
	end,

	resolve_item = function(item, rtype)
		if item.needs_resolving then -- TODO: might be string, be more fancy with text, colors, etc.
			item:setFillColor(1, 1, 0)

			item.text = rtype
		end
	end,

	resize = function(parent)
		local back, w, h = parent.back, node_layout.GetDimensions(parent)

		node_layout.SetPlaceFunc(Place_MightTransition)

		local bw, bh = back.width, back.height	-- the back object will be used as a guide to launch the others'
											 -- transitions, so temporarily swap out its dimensions with the
											 -- final results and do those calculations, then restore them

		back.width, back.height = w, h

		node_layout.VisitGroup(parent, node_layout.PlaceItems, back)

		back.width, back.height = bw, bh

		Place_MightTransition(back.path, "width", w) -- we want to transition the scale of the back object, but only
		Place_MightTransition(back.path, "height", h) -- when necessary, so (directly) reuse the "might" logic

		if ToUpdate then
			local to_update = ToUpdate

			timer.performWithDelay(35, function(event)
				local done = true

				for object, count in pairs(to_update) do
					if count == 0 then -- all properties done?
						to_update[object], object.to_update = nil
					else
						done = false
					end

					node_runner.SetDirty(object)
				end

				if done then
					timer.cancel(event.source)
				end
			end, 0)
		end

		ToUpdate = nil
	end
}

local function Circle (group, width, radius, ...)
	local circle = display.newCircle(group, 0, 0, radius)

	circle:setFillColor(...)

	circle.strokeWidth = width

	return circle
end

local function Delete (event)
	if event.phase == "ended" then
		local group = event.target.parent

		boxes.DeferDecays()

		for i = 1, group.numChildren do
            local item = group[i]

            if item.bound_bit then -- nodes will have this member
                node_layout.BreakConnections(item)
            end
        end

		boxes.RemoveFromDecayList(group)
		boxes.ResumeDecays()

		do_decays("rebuild")

		group:removeSelf()
	end

	return true
end

local Runner = runner_basics.NewRunner{ back_group = BackGroup, can_connect = can_connect, connect = connect, get_color = StandardColor }

--- DOCME
function M.NewNode (group, what, name, payload_type, how)
	if how == "sync" then
		node_layout.SetSyncPoint(group)
	end

	local object = Circle(group, 3, 7, StandardColor(what))
	local anchor = (what == "lhs" or what == "delete") and 0 or 1

	if what == "delete" then
		object:addEventListener("touch", Delete)
		object:setFillColor(1, 0, 0)
		object:setStrokeColor(.7, 0, 0)

		node_layout.SetSideExplicitly(object, "lhs")
	else
		Runner:AddNode(object, OwnerID, what)

		local non_resolving, tstr

		if payload_type:sub(-1) == "~" then -- TODO: better choice???
			non_resolving = payload_type:sub(1, -2)

			node_state.SetNonResolvingHardType(object, non_resolving)
		elseif payload_type ~= "?" then
			tstr = assert(payload_type, "Expected type")

			node_state.SetHardType(object, tstr)
		end

		node_layout.SetExtraTrailingItemsCount(object, 2)
		code_gen.SetValueName(object, name)

		object.bound_bit = group.next_bit
		group.next_bit = 2 * group.next_bit

		local text = display.newText(group, name, 0, 0, native.systemFont, 24)

		text.anchorX = anchor

		local ttext = display.newText(group, tstr or "", 0, 0, native.systemFont, 24)

		if tstr then
			ttext:setFillColor(0, 1, 1)
		else
			ttext.needs_resolving = non_resolving or true

			AuxDecayItem(ttext)
		end

		ttext.anchorX = anchor
	end

	object.anchorX = anchor
end

--
--
--

node_state.AddHardToWildcardEntries{ "float", "vec2", "vec3", "vec4", wildcard_type = "vector" }

--- DOCME
function M.Rect (title, wildcard_type, code_form, scheme)
    local group = display.newGroup()

    group.next_bit = 1

	code_gen.SetCodeForm(group, code_form, scheme)
	node_state.SetWildcardType(group, wildcard_type)

	display.newText(group, title, 0, 0, native.systemFontBold)

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

return M