--- Scene where editor elements are put into play.

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
local ipairs = ipairs

-- Modules --
local pubsub = require("solar2d_utils.pubsub")
local object_type_list = require("tests.editor.object_type_list")

-- Solar2D globals --
local system = system
local timer = timer
local transition = transition

-- Solar2D modules --
local composer = require("composer")
local widget = require("widget")

--
--
--

local Scene = composer.newScene()

--
--
--

function Scene:create ()
	local quit = widget.newButton{
		left = 5, top = display.contentHeight - 55, width = 150, height = 50,
        label = "Quit to Main", shape = "roundedRect",
        fillColor = { default = { 1, 0, 0, 1 }, over = { 1, .1, .7, .4 } },
		font = native.systemFontBold, fontSize = 20,

        onEvent = function(event)
			if event.phase == "ended" then
				composer.gotoScene("tests.editor.scenes.common")
			end
		end
    }

	self.view:insert(quit)
end

Scene:addEventListener("create")

--
--
--

function Scene:show (event)
	if event.phase == "did" then
		self.objects = display.newGroup()

		self.view:insert(self.objects)

		local ps_list, params = pubsub.New(), { dispatcher = system.newEventDispatcher(), group = self.objects }

		for _, info in ipairs(event.params) do
			object_type_list.loaders[info.type](info, ps_list, params)														
		end

		ps_list:Dispatch()

		params.dispatcher:dispatchEvent{ name = "launched" }
	end
end

Scene:addEventListener("show")

--
--
--

function Scene:hide (event)
	if event.phase == "did" then
		timer.cancelAll()
		transition.cancelAll()

		self.objects:removeSelf()

		self.objects = nil
	end
end

Scene:addEventListener("hide")

--
--
--

return Scene