--- Drag listener factory unit tests.

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

-- Modules --
local drag = require("solar2d_ui.utils.drag")

--
--
--

local Test = "Zoomed"

--
--
--

local CX, CY = display.contentCenterX, display.contentCenterY
local CW, CH = display.contentWidth, display.contentHeight

local function Outline (x, y, w, h)
	local outline = display.newRect(x, y, w, h)

	outline:setFillColor(0, 0)
	outline:setStrokeColor(0, 1, 0)

	outline.strokeWidth = 2

	return outline
end

--
-- This is just a vanilla drag.
--

if Test == "Basics_OpenEnded" then

	local DragTouch = drag.Make{}

	local rect = display.newRoundedRect(CX, CY, 100, 100, 12)

	rect:addEventListener("touch", DragTouch)
	rect:setFillColor(.7)


--
-- This is just a drag but clamps the object against the content area.
--

elseif Test == "Basics_ContentClamped" then

	local DragTouch = drag.Make{ clamp_region = drag.ContentRegion }

	local rect = display.newRoundedRect(CX, CY, 100, 100, 12)

	rect:addEventListener("touch", DragTouch)
	rect:setFillColor(.7)

--
-- This is also a plain drag but clamped against a custom box.
--

elseif Test == "Basics_BoxClamped" then

	local box = Outline(CX - 100, CY - 100, 320, 320)

	local DragTouch = drag.Make{
		clamp_region = function()
			return box
		end
	}

	local rect = display.newRoundedRect(CX, CY, 100, 100, 12)

	rect:addEventListener("touch", DragTouch)
	rect:setFillColor(.7)

--
-- This is another custom box-clamped drag, but here the box is looked up through a member.
--

elseif Test == "Basics_BoxClampedKey" then

	local DragTouch = drag.Make{
		clamp_region = "m_outline"
	}

	local rect = display.newRoundedRect(CX, CY, 100, 100, 12)

	rect:addEventListener("touch", DragTouch)
	rect:setFillColor(.7)

	rect.m_outline = Outline(CX - 100, CY - 100, 360, 360)

--
-- The box starts out penetrating the clamp region but will depenetrate when the first drag begins.
--

elseif Test == "Depenetrate" then

	local box = Outline(CX - 100, CY - 100, 280, 320)

	local DragTouch = drag.Make{
		clamp_region = function()
			return box
		end
	}

	local rect = display.newRoundedRect(CX, CY, 100, 100, 12)

	rect:addEventListener("touch", DragTouch)
	rect:setFillColor(.7)

--
-- The box is again penetrating the clamp region, along the vertical axis, but the region is too small to successfully free it.
--

elseif Test == "Stuck" then

	local box = Outline(CX - 100, CY, 280, 80)

	local DragTouch = drag.Make{
		clamp_region = function()
			return box
		end
	}

	local rect = display.newRoundedRect(CX, CY + 10, 100, 100, 12)

	rect:addEventListener("touch", DragTouch)
	rect:setFillColor(.7)

--
-- The object's parent is what gets dragged.
--

elseif Test == "Parent" then

	local DragTouch = drag.Make{ dragee = "parent" }

	local group = display.newGroup()

	local rect = display.newRect(group, CX, CY, 200, 200)

	rect:addEventListener("touch", DragTouch)
	rect:setFillColor(.6)

	local child2 = display.newCircle(group, CX + 75, CY, 7)

	child2:setFillColor(1, 0, 0)

--
-- Again, the parent is dragged, this time also being clamped against the content area.
--

elseif Test == "Parent_ContentClamped" then

	local DragTouch = drag.Make{ dragee = "parent", clamp_region = drag.ContentRegion }

	local group = display.newGroup()

	local rect = display.newRect(group, CX, CY, 250, 250)

	rect:addEventListener("touch", DragTouch)
	rect:setFillColor(.6)

	local child2 = display.newCircle(group, CX - 15, CY, 9)

	child2:setFillColor(1, 0, 0)

--
-- We want to drag the parent but clamp against the box, even though some other children overstep its bounds.
--

elseif Test == "ClampObject" then

	local DragTouch = drag.Make{ dragee = "parent", clamp_object = drag.ChooseObject, clamp_region = drag.ContentRegion }

	local group = display.newGroup()

	local rect = display.newRect(group, CX, CY, 250, 250)

	rect:addEventListener("touch", DragTouch)
	rect:setFillColor(.6)

	local child2 = display.newCircle(group, CX - 15, CY, 9)

	child2:setFillColor(1, 0, 0)

	local outlier1 = display.newCircle(group, rect.x + rect.width / 2 + 15, CY, 20)

	outlier1:setFillColor(0, 1, 0)

	local outlier2 = display.newCircle(group, CX, rect.y - rect.height / 2 - 20, 15)

	outlier2:setFillColor(0, 0, 1)

--
-- A child object may be dragged within its parent.
--

elseif Test == "DragWithinParent" then

	local DragTouch = drag.Make{
		clamp_region = { "_p", "RECT" }
	}

	local group = display.newGroup()
	local rect = display.newRect(group, CX, CY, 350, 350)

	rect:setFillColor(.6)

	group.RECT = rect

	local child2 = display.newCircle(group, CX - 15, CY, 9)

	child2:addEventListener("touch", DragTouch)
	child2:setFillColor(1, 0, 0)

--
-- Again we can drag a child inside its parent, but the system has been scaled.
--

elseif Test == "DragWithinParent_Scaled" then

	local DragTouch = drag.Make{
		clamp_region = { "_p", "RECT" }
	}

	local group = display.newGroup()
	local rect = display.newRect(group, CX, CY, 320, 310)

	rect:setFillColor(.6)

	group.RECT = rect

	local child2 = display.newCircle(group, CX + 15, CY, 11)

	child2:addEventListener("touch", DragTouch)
	child2:setFillColor(1, 1, 0)

	group:scale(.7, .7)

--
-- Dragging one object will move another (non-parent) one.
--

elseif Test == "ExternalObject" then

	local DragTouch = drag.Make{ dragee = "EXTERNAL" }

	local rect = display.newRect(CX, CY, 120, 140)

	rect:addEventListener("touch", DragTouch)
	rect:setFillColor(.6)

	local rect2 = display.newRect(CX + 150, CY - 100, 80, 90)

	rect2:setFillColor(0, 0, 1)

	rect.EXTERNAL = rect2

--
-- This also moves a separate object, while also clamping against the content area.
--

elseif Test == "ExternalObject_ContentClamped" then

	local DragTouch = drag.Make{ dragee = "EXTERNAL", clamp_region = drag.ContentRegion }

	local rect = display.newRect(CX, CY, 100, 120)

	rect:addEventListener("touch", DragTouch)
	rect:setFillColor(.6)

	local rect2 = display.newRect(CX + 150, CY + 130, 180, 190)

	rect2:setFillColor(0, 0, 1)

	rect.EXTERNAL = rect2

--
-- An object is hidden behind some others but when the first drag begins is brought to the front.
--

elseif Test == "Began" then

	local DragTouch = drag.Make{
		began = function(dragee)
			dragee:toFront()
		end
	}

	local newCircle = display.newCircle
	local random = math.random

	local rect = display.newRect(CX, CY, 75, 75)

	rect:addEventListener("touch", DragTouch)
	rect:setFillColor(.7)

	for _ = 1, 100 do
		local circle = newCircle(random(CX - 100, CX + 100), random(CY - 100, CY + 100), random(5, 15))

		circle:setFillColor(random(), random(), random())
	end

--
-- The dragged object is changed slightly when dragging begins and restored as it ends.
--

elseif Test == "BeganAndEnded" then

	local FadeParams = {}

	local DragTouch = drag.Make{
		began = function(dragee)
			FadeParams.alpha = .625

			transition.to(dragee, FadeParams)
		end,

		ended = function(dragee)
			FadeParams.alpha = 1

			transition.to(dragee, FadeParams)
		end
	}

	local rect = display.newRect(CX, CY, 85, 65)

	rect:addEventListener("touch", DragTouch)
	rect:setFillColor(.7)

--
-- The last state of the dragged object is shown as it moves.
--

elseif Test == "PreMove" then

	local box

	local DragTouch = drag.Make{
		pre_move = function(dragee)
			display.remove(box)

			box = Outline(dragee.x, dragee.y, dragee.width, dragee.height)
		end
	}

	local rect = display.newRect(CX, CY, 120, 150)

	rect:addEventListener("touch", DragTouch)
	rect:setFillColor(.7)

--
-- The object's position is tracked as it moves.
--

elseif Test == "PostMove" then

	local line

	local DragTouch = drag.Make{
		post_move = function(dragee)
			display.remove(line)

			if math.abs(dragee.x - CX) > 2 or math.abs(dragee.y - CY) > 2 then
				line = display.newLine(dragee.x, dragee.y, CX, CY)

				line:setStrokeColor(0, 1, 0)

				line.strokeWidth = 2
			else -- fake it if too close to center
				line = display.newCircle(CX, CY, 1)

				line:setFillColor(0, 1, 0)
			end
		end
	}

	local rect = display.newRect(CX, CY, 130, 180)

	rect:addEventListener("touch", DragTouch)
	rect:setFillColor(.7)

--
-- This is another case of dragging to move a separate object, but along the x-axis it will move in the reverse direction.
--

elseif Test == "Reverse" then

	local DragTouch = drag.Make{ dragee = "EXTERNAL", x_reverse = true }

	local rect = display.newRoundedRect(CX, CY, 130, 120, 12)

	rect:addEventListener("touch", DragTouch)
	rect:setFillColor(.7)

	local rect2 = display.newRect(CX + 110, CY + 120, 180, 120)

	rect2:setFillColor(1, 0, 1)

	rect.EXTERNAL = rect2

--
-- Here we look at a populated group and manipulate it as separate object. Looking further to the right amounts to moving
-- the group to the left, and so on. Clamping restricts the view to what the group contains; since the group could change
-- form as we add or remove objects, the clamp region is resolved when dragging begins.
--

elseif Test == "Scroll" then

	local Bounds = {}

	local DragTouch = drag.Make{
		dragee = "GROUP", reverse = true,

		clamp_region = "CLAMP",

		init = function(dragee)
			local w, h = dragee.contentWidth, dragee.contentHeight

			if w > CW then -- wider than the content?
				Bounds.xMin = -(w - CW) -- let the group slide back until right edge is flush with content's own
			else
				Bounds.xMin = 0 -- too little to scroll: lock the group in place
			end

			Bounds.xMax = w -- lock in right-hand limit

			-- and basically ditto all that:

			if h > CH then
				Bounds.yMin = -(h - CH)
			else
				Bounds.yMin = 0
			end

			Bounds.yMax = h
		end
	}

	local newCircle = display.newCircle
	local random = math.random

	local rect = display.newRect(CX, CY, CW, CH)

	rect:addEventListener("touch", DragTouch)

	rect.isHitTestable, rect.isVisible = true, false

	local group = display.newGroup()
	local dummy = display.newRect(group, 0, 0, 2 * CW, CH) -- this just ensures the group's shape, since the random circles fall a little short of the edges

	dummy.anchorX, dummy.anchorY, dummy.isVisible = 0, 0, false

	for _ = 1, 500 do
		local circle = newCircle(group, random(15, 2 * CW - 15), random(15, CH - 15), random(5, 15))

		circle:setFillColor(random(), random(), random())
	end

	rect.CLAMP = { contentBounds = Bounds }
	rect.GROUP = group

--
-- This is a scaled-down version of the scrolling scenario, without the clamping.
--

elseif Test == "Zoomed" then

	local DragTouch = drag.Make{ dragee = "GROUP", reverse = true }

	local newCircle = display.newCircle
	local random = math.random

	local rect = display.newRect(CX, CY, CW, CH)

	rect:addEventListener("touch", DragTouch)

	rect.isHitTestable, rect.isVisible = true, false

	local group = display.newGroup()

	group:scale(.7, .7)

	for _ = 1, 500 do
		local circle = newCircle(group, random(15, 2 * CW - 15), random(15, CH - 15), random(5, 15))

		circle:setFillColor(random(), random(), random())
	end

	rect.GROUP = group

--
-- TODO: this would be a scroll scenario but where being near the screen edges would cause its own scrolling, e.g. on a timer add `x - RightEdge` (maybe eased through curve)
-- if we do clamping this would need some of its own or the offset would be quite botched when we switch directions
-- maybe we could use pre_move and post_move and cap the offset if change was too low?
--

elseif Test == "ScrollViaDrag" then

	-- TODO

end