--- Color picker widget.

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
local min = math.min
local unpack = unpack

-- Modules --
local hsv = require("solar2d_ui.utils.hsv")

-- Solar2D globals --
local display = display

-- Exports --
local M = {}

--
--
--

local ColorPicker = {}

--
--
--

--- Get the currently resolved color.
-- @treturn number r
-- @treturn number g
-- @treturn number b
function ColorPicker:GetColor ()
	return self.m_r, self.m_g, self.m_b
end

--
--
--

local White, FadeTo = { 1 }, {}

local function SetColorsFromBar (bar, r, g, b)
	FadeTo[1], FadeTo[2], FadeTo[3] = r, g, b

	local colors = bar.m_picker.m_colors

	colors:setFillColor{ type = "gradient", color1 = White, color2 = FadeTo, direction = "right" }

	-- Register the hue color for quick lookup.
	colors.m_rhue, colors.m_ghue, colors.m_bhue = r, g, b
end

local RGB = {}

local function PutBarNode (node, t, use_rgb)
	assert(node, "Picker has been finalized")

	local bar, pos_comp = assert(node.parent, "Bar has been finalized"), node.m_pos_comp
	local dim = bar[node.m_dim_comp]
	local new = min(dim * max(t, 0), dim - 1)

	if use_rgb or new ~= node[pos_comp] then
		local r, g, b

		-- The bar color can usually be computed from the provided t. However, if a color is
		-- being assigned by SetColor(), this result might diverge slightly, in which case it
		-- is more correct (only "more", as it can still add slight visual inconsistency) to
		-- retain the original color.
		if use_rgb then
			r, g, b = unpack(RGB)
		else
			r, g, b = hsv.RGB_Hue(new / dim)
		end

		SetColorsFromBar(bar, r, g, b)

		node[pos_comp] = new
	end
end

local ColorChangeEvent = { name = "color_change" }

local function UpdatePick (colors)
	local picker = colors.parent
	local node = picker.m_color_node

	picker.m_r, picker.m_g, picker.m_b = hsv.RGB_ColorSV(colors.m_rhue, colors.m_ghue, colors.m_bhue, node.m_u, 1 - node.m_v)

	ColorChangeEvent.target, ColorChangeEvent.r, ColorChangeEvent.g, ColorChangeEvent.b = picker, picker.m_r, picker.m_g, picker.m_b

	picker:dispatchEvent(ColorChangeEvent)

	ColorChangeEvent.target = nil
end

local function PutColorNode (node, u, v)
	node.m_u, node.m_v = max(0, min(u, 1)), max(0, min(v, 1))

	local colors = node.parent.m_colors

	node.x, node.y = colors.x + node.m_u * colors.width, colors.y + node.m_v * colors.height

	UpdatePick(colors)
end

--- Assign a color and update the elements to match.
-- @number r
-- @number g
-- @number b
function ColorPicker:SetColor (r, g, b)
	local hue, sat, value = hsv.ConvertRGB(r, g, b, RGB)

	PutBarNode(self.m_bar_node, hue, true)
	PutColorNode(self.m_color_node, sat, 1 - value)
end

--
--
--

local FakeTouchEvent = { name = "touch", id = 0 }

local function FakeTouch (node, event)
	FakeTouchEvent.phase, FakeTouchEvent.target = event.phase, node
	FakeTouchEvent.x, FakeTouchEvent.y = event.x, event.y

	node:dispatchEvent(FakeTouchEvent)

	FakeTouchEvent.target = nil

	return true
end

local function PrepareTouch (event, guard_key, get_ref)
	local phase, target, ref = event.phase, event.target

	if get_ref then
		ref = assert(get_ref(target), "Ref has been finalized")
	end

	if phase == "began" then
		if event ~= FakeTouchEvent then
			display.getCurrentStage():setFocus(target, event.id)
		end
	elseif guard_key == nil or target[guard_key] then -- guard against swipes
		if phase ~= "moved" and event ~= FakeTouchEvent then
			display.getCurrentStage():setFocus(target, nil)
		end
	else
		return "swipe"
	end

	return phase, target, ref
end

local function ColorNodeTouch (event)
	local phase, node = PrepareTouch(event, "m_grabx")

	if phase == "began" then
		node.m_grabx, node.m_graby = node:contentToLocal(event.x, event.y)
	elseif phase == "moved" then
		local picker = node.parent
		local colors = picker.m_colors
		local cx, cy = colors:contentToLocal(event.x, event.y)

		PutColorNode(node, (cx - node.m_grabx) / colors.width + .5, (cy - node.m_graby) / colors.height + .5)
	elseif phase ~= "swipe" then
		node.m_grabx, node.m_graby = nil
	end

	return true
end

local function ColorsTouch (event)
	local phase, colors = PrepareTouch(event)
	local node = colors.parent.m_color_node

	if phase == "began" then
		local x, y = colors:contentToLocal(event.x, event.y)

		PutColorNode(node, x / colors.width + .5, y / colors.height + .5)
	end

	return FakeTouch(node, event)
end

local LocalPos = {}

local function GetPickerFromNode (node)
	local bar = node.parent

	return bar and bar.m_picker
end

local function BarNodeTouch (event)
	local phase, node, picker = PrepareTouch(event, "m_grab_pos", GetPickerFromNode)

	if phase == "began" then
		LocalPos.x, LocalPos.y = node:contentToLocal(event.x, event.y)

		node.m_grab_pos = LocalPos[node.m_pos_comp]
	elseif phase == "moved" then
		local bar = node.parent

		LocalPos.x, LocalPos.y = bar:contentToLocal(event.x, event.y)

		PutBarNode(node, (LocalPos[node.m_pos_comp] - node.m_grab_pos) / bar[node.m_dim_comp])
		UpdatePick(picker.m_colors)
	elseif phase ~= "swipe" then
		node.m_grab_pos = nil
	end

	return true
end

local function GetPickerFromBar (bar)
	return bar.m_picker
end

local function BarTouch (event)
	local phase, bar, picker = PrepareTouch(event, nil, GetPickerFromBar)
	local node = picker.m_bar_node

	if phase == "began" then
		LocalPos.x, LocalPos.y = bar:contentToLocal(event.x, event.y)

		PutBarNode(node, LocalPos[node.m_pos_comp] / bar[node.m_dim_comp])
		UpdatePick(picker.m_colors)
	end

	return FakeTouch(node, event)
end

local Pos, Dim = {}, {}

local function FillBar (group, w, h, dir)
	Dim[1], Dim[2] = w, h

	local length_index = dir == "right" and 1 or 2
	local thickness_index = 3 - length_index

	Pos[thickness_index] = Dim[thickness_index] / 2

	local length = Dim[length_index]

	Dim[length_index] = length / 6
	Pos[length_index] = .5 * length - 2.5 * Dim[length_index]

	for i = 1, 6 do
		local rect = display.newRect(group, Pos[1], Pos[2], Dim[1], Dim[2])

		rect:setFillColor(hsv.HueGradient(i, dir))

		Pos[length_index] = Pos[length_index] + Dim[length_index]
	end
end

--
--
--

local DefaultTheme = {
	separation = 10, thickness = 35, width = 200, height = 150,

	make_bar_node = function(comp, dim)
		local w, h

		if comp == "width" then
			w, h = dim, 3
		else
			w, h = 3, dim
		end

		local bar_node = display.newRect(0, 0, w, h)

		bar_node:setFillColor(.75, .75)
		bar_node:setStrokeColor(0, .75, .75)

		bar_node.strokeWidth = 2

		return bar_node
	end,

	make_color_node = function()
		local node = display.newCircle(0, 0, 6)

		node:setFillColor(.75, .5)
		node:setStrokeColor(.75, 0, .5)

		node.strokeWidth = 2

		return node
	end
}

local function GetProperty (params, name)
	return params[name] or DefaultTheme[name]
end

local function AddBaseColorsRect (picker, params)
	local colors = display.newRect(picker, 0, 0, GetProperty(params, "width"), GetProperty(params, "height"))

	colors:addEventListener("touch", ColorsTouch)

	colors.anchorX, colors.anchorY = 0, 0

	picker.m_colors = colors

	return colors
end

local function AddFadeToBlockOverlay (picker, colors)
	FadeTo[1], FadeTo[2], FadeTo[3] = 0, 0, 0

	local overlay = display.newRect(picker, 0, 0, colors.width, colors.height)

	overlay:setFillColor{ type = "gradient", color1 = White, color2 = FadeTo, direction = "down" }

	overlay.anchorX, overlay.anchorY = 0, 0
	overlay.blendMode = "multiply"
end

local function FinalizeBar (event)
	event.target.m_picker = nil
end

local function FinalizePicker (event)
	event.target.m_bar_node = nil
end

--- Create a HSV-based color picker: a box shows RGB colors currently on offer and allows
-- their selection; a corresponding bar likewise lets us vary the hue and thus the colors.
-- @ptable[opt] params Various optional parameters, which include:
--
-- * **make\_color\_node**: Called as `node = make_color_node(w, h)`, where _w_ and _h_ are
-- the dimensions of the colors rect and _node_ is a display object whose placement over said
-- rect will track or control the saturation and value. If absent, a default maker is used.
-- * **make\_bar\_node**: Called as `node = make_bar_node(which, dim)`, where _which_ is
-- either **"width"** or **"height"**, corresponding to the bar's length, with _dim_ being
-- its value, and _node_ is a display object whose placement over the bar will track or
-- control the hue. If absent, a default maker is used.
-- * **orientation**: If this is **"horizontal"**, the bar will share the color rect's width,
-- and its height will be given by the thickness. Otherwise, the thickness supplies the width
-- and the bar inherits the rect's height.
-- * **separation**: If the bar is not separate, it will be to the right of / below the rect,
-- according to the orientation, by this amount. When absent, a default is used.
-- * **thickness**: Bar thickness, cf. **orientation**. When absent, a default is used.
-- * **width**: Width of the colors rect... (When absent, a default is used.)
-- * **height**: ...and height. (Ditto.)
-- * **top**: The y-coordinate of the top of the color rect... (If absent, 0.)
-- * **left**: ...and the x-coordinate. (Ditto.)
-- * **separate_bar**: If true, the picker and bar are separate objects and both returned.
-- * **bar_top**: If the bar is separate, the top's y-coordinate. (If absent, 0.)
-- * **bar_left**: ...and the x-coordinate. (Ditto.)
-- @treturn[1] ColorPicker Picker.
-- @treturn[2] ColorPicker Picker...
-- @treturn[2] DisplayGroup ...and bar.
function M.New (params)
	params = params or FadeTo -- latter can spoof as "no params"

	--
	--
	--

	local picker = display.newGroup()
	local colors = AddBaseColorsRect(picker, params)

	AddFadeToBlockOverlay(picker, colors)

	--
	--
	--

	local bar, pos_comp, pos_other, dim_comp, dim_other = display.newGroup(), "y", "x", "height", "width"

	bar:addEventListener("touch", BarTouch)

	if params.orientation == "horizontal" then
		pos_comp, pos_other, dim_comp, dim_other = pos_other, pos_comp, dim_other, dim_comp

		FillBar(bar, colors.width, GetProperty(params, "thickness"), "right")
	else
		FillBar(bar, GetProperty(params, "thickness"), colors.height, "down")
	end

	if not params.separate_bar then
		bar[pos_comp], bar[pos_other] = colors[pos_comp], colors[pos_other] + colors[dim_other] + GetProperty(params, "separation")

		picker:insert(bar)
	end

	bar.m_picker = picker

	--
	--
	--

	local bar_dim = bar[dim_other]
	local bar_node = GetProperty(params, "make_bar_node")(dim_other, bar_dim)

	bar:insert(bar_node)
	bar_node:addEventListener("touch", BarNodeTouch)

	bar_node[pos_comp], bar_node[pos_other] = -1, bar_dim / 2 -- n.b. -1 will differ from new position, cf. PutBarNode()

	bar_node.m_pos_comp, bar_node.m_dim_comp = pos_comp, dim_comp

	picker.m_bar_node = bar_node

	PutBarNode(bar_node, 0)

	--
	--
	--

	local color_node = GetProperty(params, "make_color_node")(colors.width, colors.height)

	picker:insert(color_node)
	color_node:addEventListener("touch", ColorNodeTouch)

	picker.m_color_node = color_node

	PutColorNode(color_node, 0, 0)

	--
	--
	--

	picker.GetColor, picker.SetColor = ColorPicker.GetColor, ColorPicker.SetColor

	--
	--
	--

	picker.x, picker.y = params.left or 0, params.top or 0

	if params.separate_bar then
		bar.x, bar.y = params.bar_left or 0, params.bar_top or 0

		bar:addEventListener("finalize", FinalizeBar)
		picker:addEventListener("finalize", FinalizePicker)

		return picker, bar
	else
		return picker
	end
end

--
--
--

return M