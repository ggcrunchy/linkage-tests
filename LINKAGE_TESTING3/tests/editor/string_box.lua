--- String box used as a stand-in for native textboxes when not editing.

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
local ceil = math.ceil

-- Modules --
local meta = require("tektite_core.table.meta")

-- Solar2D globals --
local display = display
local native = native
local transition = transition

-- Exports --
local M = {}

--
--
--

local StringBox = {}

--
--
--

StringBox.__rprops = {
	text = function(box)
		return box.string.text
	end
}

StringBox.__wprops = {
	text = function(box, v)
		box.string.text = v
	end
}

--
--
--

--- DOCME
function StringBox:SetGoodValuePredicate (is_good)
	self.m_is_good = is_good
end

--
--
--

local function CloseTextfield (textfield)
	native.setKeyboardFocus(nil)
	display.remove(textfield)
end

local FadeParams = {
	onComplete = function(object)
		if object.alpha < .05 and object.removeSelf then
			object:removeSelf()
		end
	end
}

local function FadeOut (object)
	FadeParams.alpha, object.fading = 0, true

	transition.to(object, FadeParams)
end

--- DOCME
function StringBox:SetUserInputListener (listener)
	function self.m_listener (event)
		listener(event)

		if event.phase == "submitted" then
			local textfield = event.target
			local box = textfield.source
			local is_good, text = box.m_is_good, textfield.text

			if not is_good or is_good(text) then
				box.text = text
			end

			FadeOut(textfield.blocker)
			CloseTextfield(textfield)
		end
	end
end

--
--
--

local function DefListener () end


local function CatchTouch (event)
	local blocker, phase = event.target, event.phase

	if (phase == "ended" or phase == "cancelled") and not event.fading then
		FadeOut(blocker)
		CloseTextfield(blocker.textfield)
	end

	return true
end

local function BoxTouch (event)
	local phase, back = event.phase, event.target

	if phase == "began" then
		display.getCurrentStage():setFocus(back, event.id)

		back.touched = true
	elseif back.touched and (phase == "ended" or phase == "cancelled") then
		display.getCurrentStage():setFocus(back, nil)

		local blocker = display.newRect(display.contentCenterX, display.contentCenterY, display.contentWidth, display.contentHeight)

		blocker:addEventListener("touch", CatchTouch)
		blocker:setFillColor(.7)

		blocker.alpha, blocker.isHitTestEnabled = 0, true

		FadeParams.alpha = .3

		transition.to(blocker, FadeParams)

		local box = back.parent
		local bounds = box.contentBounds
		local textfield = native.newTextField((bounds.xMin + bounds.xMax) / 2, (bounds.yMin + bounds.yMax) / 2, bounds.xMax - bounds.xMin, ceil((bounds.yMax - bounds.yMin) * 1.5))

		textfield:addEventListener("userInput", box.m_listener)

		blocker.textfield, textfield.blocker, textfield.source, textfield.text, back.touched = textfield, blocker, box, box.text

		native.setKeyboardFocus(textfield)
	end

	return true
end

--- DOCME
function M.New (text, w, h)
	local box = display.newContainer(w, h)
	local back = display.newRect(0, 0, w, h)
	local str = display.newText(text, -w / 2 + 3, 0, native.systemFont, 18)

	back:setStrokeColor(.35)
	str:setTextColor(0)

	box.string, str.anchorX, back.strokeWidth = str, 0, 2

	box:insert(back)
	box:insert(str)

	meta.Augment(box, StringBox)

	back:addEventListener("touch", BoxTouch)
	box:SetUserInputListener(DefListener)

	return box
end

--
--
--

return M