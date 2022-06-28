--- Utility to gray out part of the editor pane.

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

-- Exports --
local M = {}

--
--
--

local function ApplyEffect (group, effect)
	for i = 1, group.numChildren do
		local item = group[i]

		if item._type ~= "GroupObject" then
			local fill, stroke = item.fill, item.stroke

			if fill then
				fill.effect = effect
			end

			if stroke then
				stroke.effect = effect
			end
		else
			ApplyEffect(item, effect)
		end
	end
end
--
--
--

local function BlockInput () return true end

local function UpdateBlocker (group, is_on)
	display.remove(group.blocker) -- we create a new blocker rather than recycle the old one, since that might call
									-- for resizing: some parts can bleed slightly outside the "main" object, and if
									-- these are movable the shape could change; furthermore, unless the old blocker
									-- is temporarily hoisted out of the group it will throw off the calculation

	if is_on and group.numChildren > 0 then
		local bounds = group.contentBounds
		local x, y = group:contentToLocal(bounds.xMin, bounds.yMin)
		local blocker = display.newRect(group, x, y, bounds.xMax - bounds.xMin, bounds.yMax - bounds.yMin)

		blocker:addEventListener("touch", BlockInput)

		group.blocker, blocker.anchorX, blocker.anchorY, blocker.isHitTestable, blocker.isVisible = blocker, 0, 0, true, false
	else
		group.blocker = nil
	end
end

--- DOCME
function M.Apply (group, is_on)
	ApplyEffect(group, is_on and "filter.grayscale" or nil)
	UpdateBlocker(group, is_on)
end

--
--
--

return M