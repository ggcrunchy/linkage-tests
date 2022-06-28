--- This module provides touch listeners with drag mechanics.

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
local ipairs = ipairs
local type = type

-- Solar2D globals --
local display = display

-- Cached module references --
local _ChooseDragee_
local _ChooseObject_
local _UnboundedRegion_

-- Unique member keys --
local _dragx = {}
local _dragy = {}
local _object_bounds = {}
local _region_bounds = {}
local _x0 = {}
local _y0 = {}

-- Exports --
local M = {}

--
--
--

--- Convenience option for **clamp\_object** or **clamp\_region**.
-- @return _dragee_.
-- @see Make
function M.ChooseDragee (_, dragee)
	return dragee
end

--
--
--

--- Convenience option for **dragee**, **clamp\_object**, or **clamp\_region**.
-- @return _object_.
-- @see Make
function M.ChooseObject (object)
	return object
end

--
--
--

local Content = {
	contentBounds = { xMin = 0, yMin = 0, xMax = display.contentWidth, yMax = display.contentHeight }
}

--- Convenience option for **clamp\_region**.
-- @return Content-bounded object, i.e. clamping will be performed against the content area.
-- @see Make
function M.ContentRegion ()
	return Content
end

--
--
--

local Unbounded = {
	contentBounds = {}
}

--- Convenience option for **clamp\_region**.
-- @return Unbounded object, i.e. no clamping will be performed.
-- @see Make
function M.UnboundedRegion ()
	return Unbounded
end

--
--
--

local function FollowKey (object, key, is_string)
	local n = 1

	if is_string and key:match("^_p+$") then -- is of form _pp...ppp, i.e. iterated 'parent'?
		key, n = "parent", #key - 1 -- p count
	end

	for _ = 1, n do
		object = assert(object[key], "Invalid key")
	end

	return object
end

local function StringLookup (key)
	return function(object)
		return FollowKey(object, key, true)
	end
end

local function KeyChainLookup (keys)
	return function(object)
		for _, k in ipairs(keys) do
			object = FollowKey(object, k, type(k) == "string")
		end

		return object
	end
end

local function GetObjectToActOnLookup (params, what, def)
	local lookup = params[what] or def
	local ltype = type(lookup)

	if ltype == "function" then
		return lookup
	elseif ltype == "string" then
		return StringLookup(lookup)
	elseif ltype == "table" then
		assert(#lookup > 0, "Empty lookup chain")

		return KeyChainLookup(lookup)
	else
		assert(lookup == nil, "Unhandled object lookup type")

		return _ChooseObject_
	end
end

local function DefOp () end

local function GetOps (params)
	return params.init or DefOp, params.began or DefOp, params.pre_move or DefOp, params.post_move or DefOp, params.ended or DefOp
end

local function GetReversals (params)
	if params.reverse then
		return true, true
	else
		return not not params.x_reverse, not not params.y_reverse
	end
end

local function ClampToEdge (object, region, comp, offset, over_op)
	local region_edge, delta = region[comp], 0

	if region_edge then -- no value = no clamping (edge at infinity)
		local object_edge = object[comp] + offset

		if over_op(object_edge, region_edge) then
			delta = region_edge - object_edge
		end
	end

	return offset + delta
end

local function MaxOver (object_edge, region_edge)
	return object_edge > region_edge
end

local function ClampToMax (object, region, comp, offset)
	return ClampToEdge(object, region, comp, offset, MaxOver)
end

local function MinOver (object_edge, region_edge)
	return object_edge < region_edge
end

local function ClampToMin (object, region, comp, offset)
	return ClampToEdge(object, region, comp, offset, MinOver)
end

local function GetAxisClampOffsets (object, region, min_comp, max_comp, offset1)
	local offset2 = ClampToMax(object, region, max_comp, offset1)
	local offset3 = ClampToMin(object, region, min_comp, offset2)

	return offset2, offset3
end

local function ClampOnAxis (object, region, min_comp, max_comp)
	local offset2, offset3 = GetAxisClampOffsets(object, region, min_comp, max_comp, 0)

	if offset2 < 0 and offset3 > offset2 then -- depenetrated at both ends?
		local object_mid, region_mid = object[min_comp] + object[max_comp], region[min_comp] + region[max_comp] -- both midpoints have coefficient .5, so defer to next step

		return false, (region_mid - object_mid) / 2 -- object stuck on axis, so as a compromise align the center components of the object and region
	else
		return true, offset3
	end
end

local function ClampOnBegin (object, region)
	local xfree, dx = ClampOnAxis(object, region, "xMin", "xMax")
	local yfree, dy = ClampOnAxis(object, region, "yMin", "yMax")

	return xfree, yfree, dx, dy
end

local function ComponentNames (axis_comp)
	if axis_comp == "x" then
		return _dragx, _x0, "xMin", "xMax"
	else
		return _dragy, _y0, "yMin", "yMax"
	end
end

local ContentPos = {}

local function PrepareAxisDrag (object, event, comp, free)
	local drag_comp, base_comp = ComponentNames(comp)

	if free then
		object[drag_comp], object[base_comp] = -event[comp], ContentPos[comp]
	else
		object[drag_comp], object[base_comp] = nil
	end
end

local function GetMoveOffset (object, event, comp, rev)
	local drag_comp = ComponentNames(comp)
	local drag_value = object[drag_comp]

	if drag_value then
		local delta = drag_value + event[comp]
		-- TODO: Everything is nicely set up for a fixed position. However, when dragging it
		-- is also useful to scroll the view as we approach the edges. The touch event works
		-- against us here, since it is only considering the content position; presumably we
		-- should at least add the scroll offset relative to where we started dragging. Will
		-- this play well with clamping?

		return rev and -delta or delta
	end
end

local function Move (object, comp, offset)
	if offset then
		local _, base_comp, min_comp, max_comp = ComponentNames(comp)
		local _, new_offset = GetAxisClampOffsets(object[_object_bounds], object[_region_bounds], min_comp, max_comp, offset)

		ContentPos[comp] = object[base_comp] + new_offset
	end
end

local function LocalizePosition (dragee, xoff, yoff)
	local x, y = dragee.parent:contentToLocal(ContentPos.x, ContentPos.y)

	if xoff then
		dragee.x = x
	end

	if yoff then
		dragee.y = y
	end
end

local NoParams = {}

--- Make a touch listener that handles dragging.
--
-- If a bounding region is provided, the dragged object, hereafter the "dragee", is clamped
-- to it. This includes depenetration when the drag begins; if the object is outright stuck
-- along an axis, it gets centered in the region as a best effort and that axis disabled.
--
-- Drags are performed in content space but relocalized afterward.
-- @ptable[opt] params Optional drag configuration parameters:
-- * **dragee**: Lookup technique, if the dragged object differs from _object_, i.e. the
-- touch event target.
--
-- This may be a function, called as `dragee = get_dragee(object)`.
--
-- It may be a string, in which case it is taken as a key and evaluated as `dragee =
-- object[key]`. An important special case is the form **"_pp...p"**: the count of **p**s
-- says how many times to follow the **parent**, so for instance **"_ppp"** would evaluate to
-- `dragee = object.parent.parent.parent`.
--
-- An array of keys may be provided, to be indexed successively: for instance, `{ "neighbor",
-- 5, "_p" }` would evaluate to `dragee = object.neighbor[5].parent`.
--
-- It is an error if no dragee is obtained at the end.
--
-- If absent, @{ChooseObject}.
-- * **clamp\_object**: This is like the **dragee** policy, except a function will be called
-- as `clamp_object = get_clamp_object(object, dragee)`. The result will be queried for its
-- **contentBounds**, so will typically be a display object. If absent, @{ChooseDragee}.
-- * **clamp\_region**: This follows the **clamp\_object** policy, except **contentBounds**
-- fields may be omitted to disable the corresponding clamping. If absent, @{UnboundedRegion}.
-- * **init**: If present, this is called as `init(dragee, object)` before the drag actually
-- begins, in particular before any stuck object resolution.
-- * **began**: If present, called as `began(dragee, object)` once the drag has begun...
-- * **ended**: ...and ended, as `ended(dragee, object)`.
-- * **pre_move**: During a move phase, this is called as `pre_move(dragee, object)` before
-- the dragee has been updated...
-- * **post_move**: ...and afterward, as `post_move(dragee, object)`.
-- * **x_reverse**: If true, a drag to the right will move the dragee left, and vice versa.
-- * **y_reverse**: Simiarly, a drag down will cause an upward move, and vice versa.
-- * **reverse**: As a convenience, both reverse policies will be in effect if true.
-- @treturn function Drag listener.
function M.Make (params)
	assert(params == nil or type(params) == "table", "Non-table params")

	params = params or NoParams

	-- Get any object customizations. The dragee and clamp object may be the same, defaulting
	-- to the touch event target.
	local get_dragee = GetObjectToActOnLookup(params, "dragee")
	local get_clamp_object = GetObjectToActOnLookup(params, "clamp_object", _ChooseDragee_)
	local get_clamp_region = GetObjectToActOnLookup(params, "clamp_region", _UnboundedRegion_)

	-- Get customization point logic.
	local init, began, pre_move, post_move, ended = GetOps(params)

	-- Get any requests to apply the drag in the reverse direction.
	local xrev, yrev = GetReversals(params)

	--
	--
	--

	return function(event)
		local object, phase = event.target, event.phase
		local dragee = assert(get_dragee(object), "Unable to find dragee object")

		if phase == "began" then
			display.getCurrentStage():setFocus(object, event.id)

			init(dragee, object)

			local clamp_object = assert(get_clamp_object(object, dragee), "Unable to find clamp object")
			local clamp_region = assert(get_clamp_region(object, dragee), "Unable to find clamp region")

			object[_object_bounds] = clamp_object.contentBounds
			object[_region_bounds] = clamp_region.contentBounds

			local xfree, yfree, dx, dy = ClampOnBegin(object[_object_bounds], object[_region_bounds])

			ContentPos.x, ContentPos.y = dragee:localToContent(0, 0) -- bounds and touch event positions are in content coordinates, so transform

			PrepareAxisDrag(object, event, "x", xfree) -- if free, drag and base components will be populated, else nil
			PrepareAxisDrag(object, event, "y", yfree)

			ContentPos.x, ContentPos.y = ContentPos.x + dx, ContentPos.y + dy

			LocalizePosition(dragee, true, true)

			began(dragee, object)

		elseif object[_object_bounds] then -- guard against swipe
			if phase == "moved" then
				local xoff = GetMoveOffset(object, event, "x", xrev)
				local yoff = GetMoveOffset(object, event, "y", yrev)

				pre_move(dragee, object)

				Move(object, "x", xoff)
				Move(object, "y", yoff)
				LocalizePosition(dragee, xoff, yoff)

				post_move(dragee, object)
			else
				ended(dragee, object)

				object[_object_bounds], object[_region_bounds] = nil

				display.getCurrentStage():setFocus(object, nil)
			end
		end

		return true
	end
end

--
--
--

_ChooseDragee_ = M.ChooseDragee
_ChooseObject_ = M.ChooseObject
_UnboundedRegion_ = M.UnboundedRegion

return M