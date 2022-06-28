--- Utility for editor controls.

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
local tonumber = tonumber

-- Exports --
local M = {}

--
--
--

local FakeTouch = { name = "touch" }

--
--
--

--- DOCME
function M.EditToDrag (control, comp, along_axis)
	return function(event)
		if event.phase == "editing" then
			local new_value = tonumber(event.text)
			
			if new_value then
				event.target.editing, FakeTouch.target = true, control
				FakeTouch.phase, FakeTouch.x, FakeTouch.y = "began", control:localToContent(0, 0)

				control:dispatchEvent(FakeTouch)

				FakeTouch.phase = "moved"

				local ax, ay, delta = 0, 0, new_value - tonumber(event.oldText)

				if along_axis then
					delta = delta / 2

					if comp == "x" then
						ax = delta
					else
						ay = delta
					end

					FakeTouch.x, FakeTouch.y = control:localToContent(ax, ay)
				else
					FakeTouch[comp] = FakeTouch[comp] + delta
				end

				control:dispatchEvent(FakeTouch)

				FakeTouch.phase = "ended"

				control:dispatchEvent(FakeTouch)

				event.target.editing, FakeTouch.target = false
			else
				event.target.text = event.oldText
			end
		end
	end
end

--
--
--

--- DOCME
function M.OnMoveControl (func, properties)
	return function(event)
		local phase, control = event.phase, event.target

		if phase == "began" then
			control.dx, control.dy = control:contentToLocal(event.x, event.y)

			if event ~= FakeTouch then
				display.getCurrentStage():setFocus(control, event.id)
			end
		elseif control.dx then
			if phase == "moved" then
				local target = properties:GetObject()
				local x, y = target:contentToLocal(event.x, event.y)

				func(x - control.dx, y - control.dy, target, control)
			else
				if event ~= FakeTouch then
					display.getCurrentStage():setFocus(control, nil)
				end

				control.dx, control.dy = nil
			end
		end

		return true
	end
end

--
--
--

return M