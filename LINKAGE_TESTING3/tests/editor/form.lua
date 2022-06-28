--- Form followed when presenting values with certain types to the property pane.

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
local unpack = unpack

-- Modules --
local color_picker = require("solar2d_ui.widgets.color_picker")
local string_box = require("tests.editor.string_box")

-- Solar2D globals --
local native = native

-- Solar2D modules --
local widget = require("widget")

--
--
--

local function RemoveProperties (object)
	object.properties = nil
end

--
--
--

local function Boolean (event)
	local switch = event.target

	switch.properties:GetObject()[switch.id] = switch.isOn
end

local function Color (event)
	local picker = event.target
	local color = picker[picker.value_name] or {}

	color.r, color.g, color.b = event.r, event.g, event.b

	picker[picker.value_name] = color
end

--
--
--

return {
	boolean = function(v, name, _, properties)
		local params = { id = name, onPress = Boolean, style = "checkbox" }

		if v ~= nil then
			params.initialSwitchState = v
		end

		local switch = widget.newSwitch(params)

		switch:addEventListener("finalize", RemoveProperties)

		switch.properties = properties

		return switch
	end,

	color = function(v, name, params)
		local picker = color_picker.New(params)
		local listener = params and params.listener

		if not listener then
			picker.value_name, listener = name, Color
		end

		picker:addEventListener("color_change", listener)

		if v then
			picker:SetColor(unpack(v))
		end

		return picker
	end,

	enable = function(v, name, params)
		local sparams = { id = name, style = "onOff" }

		if params then
			sparams.onPress = params.on_enable
		end

		if v ~= nil then
			sparams.initialSwitchState = v
		end

		return widget.newSwitch(sparams)
	end,

	-- ranged_float = text + slider...

	literal = function(v)
		return display.newText(v, 0, 0, native.systemFont, 20)
	end,

	number = function(v, name, params, properties)	
		local width, height, listener

		if params then
			width, height, listener = params.width, params.height, params.listener
		end

		local numeric = string_box.New("0.00", width or 100, height or 25) -- n.b. numeric type enforced manually to allow floats and negatives

		numeric:SetGoodValuePredicate(tonumber)

		local native_list = properties:GetScrollView().native_list

		native_list[#native_list + 1] = numeric

		if params then
			if params.keep_refs then
				params.keep_refs[name] = numeric
			end

			local step, step_listener = params.step, params.step_listener

			if step or step_listener then


--[[
local currentNumber = 0
 
-- Handle stepper events
local function onStepperPress( event )
 
    if ( "increment" == event.phase ) then
        currentNumber = currentNumber + 1
    elseif ( "decrement" == event.phase ) then
        currentNumber = currentNumber - 1
    end
end
         
-- Create the widget
local newStepper = widget.newStepper(
    {
        left = 150,
        top = 200,
        minimumValue = 0,
        maximumValue = 50,
        onPress = onStepperPress
    }
)
]]
			end
		end
		-- TODO: overlay for this

		-- TODO: listener

		return numeric
	end,

	string = function(v, name, _, properties)
		local str, list = string_box.New("", 180, 30), properties:GetScrollView().native_list

		-- TODO: listener

		list[#list + 1] = str

		return str	
	end
}

--[[
-- Handle press events for the buttons
local function onSwitchPress( event )
    local switch = event.target
    print( "Switch with ID '"..switch.id.."' is on: "..tostring(switch.isOn) )
end
 
-- Create a group for the radio button set
local radioGroup = display.newGroup()
 
-- Create two associated radio buttons (inserted into the same display group)
local radioButton1 = widget.newSwitch(
    {
        left = 150,
        top = 200,
        style = "radio",
        id = "RadioButton1",
        initialSwitchState = true,
        onPress = onSwitchPress
    }
)
radioGroup:insert( radioButton1 )
 
local radioButton2 = widget.newSwitch(
    {
        left = 250,
        top = 200,
        style = "radio",
        id = "RadioButton2",
        onPress = onSwitchPress
    }
)
radioGroup:insert( radioButton2 )
]]

--[[    
-- Slider listener
local function sliderListener( event )
    print( "Slider at " .. event.value .. "%" )
end
 
-- Create the widget
local slider = widget.newSlider(
    {
        x = display.contentCenterX,
        y = display.contentCenterY,
        width = 400,
        value = 10,  -- Start slider at 10% (optional)
        listener = sliderListener
    }
)
]]