--- Trying out editor UI.

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
local controls = require("tests.editor.controls")
local drag = require("solar2d_ui.utils.drag")
local form = require("tests.editor.form")
local gray = require("tests.editor.gray")
local properties_pane = require("tests.editor.properties_pane")

-- Solar2D globals --
local display = display

-- Solar2D modules --
local widget = require( "widget" )

--
--
--

local properties = properties_pane.New()

local function UpdateChildren (group, comp, ucomp, delta)
	for i = 1, group.numChildren do
		local child = group[i]
		local update = child[ucomp]

		if update == "+" then
			child[comp] = child[comp] + delta
		elseif update == "-" then
			child[comp] = child[comp] - delta
		end
	end
end

--
--
--

local ObjectRef = {}

local function SetText (name, value)
	local ref = ObjectRef[name]

	if ref and not ref.editing then
		ref.text = ("%.2f"):format(value)
	end
end

local function UpdateProperty (object, name, value)
	object[name] = value

	SetText(name, value)
end

--
--
--

local g = display.newGroup()

g.anchorChildren = true
g.anchorX, g.x = .5, display.contentCenterX
g.anchorY, g.y = .5, display.contentCenterY

--
--
--

local r = display.newRect(g, 0, 0, 200, 200)

r:setStrokeColor(1, 0, 0)

r.strokeWidth = 2

local Drag = drag.Make{
	dragee = "parent",

	post_move = function(dragee)
		SetText("x", dragee.x)
		SetText("y", dragee.y)
	end
}

r:addEventListener("touch", Drag)

--
--
--

local MinDim = 7

--
--
--

local xs = display.newRect(g, r.width / 2, 0, 10, 10)

xs:addEventListener("touch", controls.OnMoveControl(function(x, _, rect, control)
	if x > MinDim then
		UpdateChildren(g, "x", "xupdate", x - control.x)
		UpdateProperty(rect, "width", 2 * x) -- x = distance from center, thus half the width
	end
end, properties))
xs:setFillColor(.7)

xs.xupdate = "+"

--
--
--

local ys = display.newRect(g, 0, r.height / 2, 10, 10)

ys:addEventListener("touch", controls.OnMoveControl(function(_, y, rect, control)
	if y > MinDim then
		UpdateChildren(g, "y", "yupdate", y - control.y)
		UpdateProperty(rect, "height", 2 * y) -- as with x
	end
end, properties))
ys:setFillColor(.7)

ys.yupdate = "+"

--
--
--

local rot = display.newCircle(g, xs.x + 30, 0, 7)

rot:addEventListener("touch", controls.OnMoveControl(function(x, y, rect)
	if math.abs(x) + math.abs(y) > 2 then
		local group, angle = rect.parent, math.atan2(y, x)

		UpdateProperty(group, "rotation", (group.rotation + math.deg(angle)) % 360)
	end
end, properties))
rot:setFillColor(0, 0, 1)

rot.xupdate = "+"

--
--
--

local CornerListener = controls.OnMoveControl(function(x, y, rect, control)
	local path = rect.path

	UpdateProperty(path, control.xprop, path[control.xprop] + x - control.x)
	UpdateProperty(path, control.yprop, path[control.yprop] + y - control.y)

	control.x, control.y = x, y
end, properties)

for i = 1, 4 do
	local w, h = r.width / 2, r.height / 2
	local xupdate, yupdate = i >= 3 and "+" or "-", (i == 2 or i == 3) and "+" or "-"
	local corner = display.newCircle(g, xupdate == "+" and w or -w, yupdate == "+" and h or -h, 7)

	corner:addEventListener("touch", CornerListener)
	corner:setFillColor(0, 1, 0, .7)

	corner.xprop, corner.xupdate = "x" .. i, xupdate
	corner.yprop, corner.yupdate = "y" .. i, yupdate
end

--
--
--

local rtype = {
	description = { type = "string", default = "" },
	gray_out = { type = "enable", default = true },
	is_good = { type = "boolean", default = true },
	is_okay = { type = "boolean", default = false },
	is_bad = { type = "boolean", default = true },
	fill_color = { type = "color", default = { 1, 1, 1 } },
	n = { type = "number", default = 0 },
	pretty_color = { type = "color", default = { 0, 0, 0 } },
	x = { type = "number", default = 0 },
	y = { type = "number", default = 0 },
	width = { type = "number", default = 100 },
	height = { type = "number", default = 100 },
	rotation = { type = "number", default = 0 },
	x1 = { type = "number", default = 0 },
	y1 = { type = "number", default = 0 },
	x2 = { type = "number", default = 0 },
	y2 = { type = "number", default = 0 },
	x3 = { type = "number", default = 0 },
	y3 = { type = "number", default = 0 },
	x4 = { type = "number", default = 0 },
	y4 = { type = "number", default = 0 }
}

--
--
--

properties:SetForm(form)
properties:SetOffsets(10, 10)
properties:SetSeparationDistances(5, 5)

--
--
--

local scroll_view = widget.newScrollView{
	backgroundColor = { .7, .7, .7 },
	top = 200, left = display.contentWidth - 302,
	width = 300, height = display.contentHeight - 202
}

local sv_bounds = scroll_view.contentBounds
local border = display.newRect((sv_bounds.xMin + sv_bounds.xMax) / 2 - 1, (sv_bounds.yMin + sv_bounds.yMax) / 2 - 1, sv_bounds.xMax - sv_bounds.xMin + 2, sv_bounds.yMax - sv_bounds.yMin + 2)

border:setFillColor(0, 0)
border:setStrokeColor(.3)

border.strokeWidth = 4

properties:Begin(scroll_view)
properties:SetObject(r, rtype)

properties:Literal("Fill Color:")
properties:Indent(20)
properties:Value("fill_color", {
	listener = function(event)
		properties:GetObject():setFillColor(event.r, event.g, event.b)
	end
})

properties:ValueAndLiteral("is_good", "Is it good?")

local gray_group = display.newGroup()

properties:LiteralAndValue("Enable pretty color?", "gray_out", {
	on_enable = function(event)
		gray.Apply(gray_group, event.target.isOn)
	end
})

properties:StartGroup(gray_group)--, Gray, not gray_out)

properties:Literal("Pretty color:")
properties:Value("pretty_color")

properties:StartGroup()

properties:LiteralAndValue("Count", "n")
properties:LiteralAndValue("Description", "description")

properties:Line("@is_okay", "Is it okay?", "Is it bad?", "@is_bad")

local KeepRefParams = { keep_refs = ObjectRef }

properties:Line("X:", "@x", KeepRefParams, "Y:", "@y", KeepRefParams)
properties:Line("Width:", "@width", KeepRefParams, "Height:", "@height", KeepRefParams)
properties:LiteralAndValue("Rotation", "rotation", KeepRefParams)
properties:Line("X1:", "@x1", KeepRefParams, "Y1:", "@y1", KeepRefParams)
properties:Line("X2:", "@x2", KeepRefParams, "Y2:", "@y2", KeepRefParams)
properties:Line("X3:", "@x3", KeepRefParams, "Y3:", "@y3", KeepRefParams)
properties:Line("X4:", "@x4", KeepRefParams, "Y4:", "@y4", KeepRefParams)

for k, v in pairs{
	x = function(event)
		if event.phase == "editing" then
			properties:GetObject().parent.x = tonumber(event.text)
		end
	end,

	y = function(event)
		if event.phase == "editing" then
			properties:GetObject().parent.y = tonumber(event.text)
		end
	end,

	width = controls.EditToDrag(xs, "x", true), -- TODO: add >= MinDim constraint...
	height = controls.EditToDrag(ys, "y", true),

	rotation = function(event)
		if event.phase == "editing" then
			properties:GetObject().parent.rotation = tonumber(event.text)
		end
	end,

	x1 = controls.EditToDrag(g[g.numChildren - 3], "x"),
	y1 = controls.EditToDrag(g[g.numChildren - 3], "y"),

	x2 = controls.EditToDrag(g[g.numChildren - 2], "x"),
	y2 = controls.EditToDrag(g[g.numChildren - 2], "y"),

	x3 = controls.EditToDrag(g[g.numChildren - 1], "x"),
	y3 = controls.EditToDrag(g[g.numChildren - 1], "y"),

	x4 = controls.EditToDrag(g[g.numChildren - 0], "x"),
	y4 = controls.EditToDrag(g[g.numChildren - 0], "y")
} do
	ObjectRef[k]:SetUserInputListener(v)
end

SetText("x", properties:GetObject().parent.x)
SetText("y", properties:GetObject().parent.y)
SetText("width", properties:GetObject().width)
SetText("height", properties:GetObject().height)