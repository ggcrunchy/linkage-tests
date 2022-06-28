--- Primary editor scene, where objects are made and the playground launched.

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
local atan2 = math.atan2
local deg = math.deg
local ipairs = ipairs

-- Modules --
local controls = require("tests.editor.controls")
local drag = require("solar2d_ui.utils.drag")
local form = require("tests.editor.form")
local gray = require("tests.editor.gray")
local properties_pane = require("tests.editor.properties_pane")

-- Solar2D globals --
local display = display

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

local KeepRefParams = { keep_refs = ObjectRef }

--
--
--

local RectType = {
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

local function PopulatePaneForRect (rect, xs, ys, properties) -- TODO: inconsistent, uses both `rect` and `properties:GetObject()`
	properties:SetObject(rect, RectType)

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

	properties:Line("X:", "@x", KeepRefParams, "Y:", "@y", KeepRefParams)
	properties:Line("Width:", "@width", KeepRefParams, "Height:", "@height", KeepRefParams)
	properties:LiteralAndValue("Rotation", "rotation", KeepRefParams)
	properties:Line("X1:", "@x1", KeepRefParams, "Y1:", "@y1", KeepRefParams)
	properties:Line("X2:", "@x2", KeepRefParams, "Y2:", "@y2", KeepRefParams)
	properties:Line("X3:", "@x3", KeepRefParams, "Y3:", "@y3", KeepRefParams)
	properties:Line("X4:", "@x4", KeepRefParams, "Y4:", "@y4", KeepRefParams)

	local group = rect.parent

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

		x1 = controls.EditToDrag(group[group.numChildren - 3], "x"),
		y1 = controls.EditToDrag(group[group.numChildren - 3], "y"),

		x2 = controls.EditToDrag(group[group.numChildren - 2], "x"),
		y2 = controls.EditToDrag(group[group.numChildren - 2], "y"),

		x3 = controls.EditToDrag(group[group.numChildren - 1], "x"),
		y3 = controls.EditToDrag(group[group.numChildren - 1], "y"),

		x4 = controls.EditToDrag(group[group.numChildren - 0], "x"),
		y4 = controls.EditToDrag(group[group.numChildren - 0], "y")
	} do
		ObjectRef[k]:SetUserInputListener(v)
	end

	SetText("x", group.x)
	SetText("y", group.y)
	SetText("width", group.width)
	SetText("height", group.height)
end

--
--
--

local Drag = drag.Make{
	dragee = "parent",

	post_move = function(dragee)
		SetText("x", dragee.x)
		SetText("y", dragee.y)
	end
}

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

function Scene:create ()
	self.properties = properties_pane.New()

	self.properties:SetForm(form)
	self.properties:SetOffsets(10, 10)
	self.properties:SetSeparationDistances(5, 5)

	--
	--
	--

	local group = display.newGroup()

	group.anchorChildren = true
	group.anchorX, group.x = .5, display.contentCenterX
	group.anchorY, group.y = .5, display.contentCenterY

	self.view:insert(group)

	--
	--
	--

	local rect = display.newRect(group, 0, 0, 200, 200)

	rect:addEventListener("touch", Drag)
	rect:setStrokeColor(1, 0, 0)

	rect.strokeWidth = 2

	--
	--
	--

	local MinDim = 7

	--
	--
	--

	local xs = display.newRect(group, rect.width / 2, 0, 10, 10)

	xs:addEventListener("touch", controls.OnMoveControl(function(x, _, rect, control)
		if x > MinDim then
			UpdateChildren(rect.parent, "x", "xupdate", x - control.x)
			UpdateProperty(rect, "width", 2 * x) -- x = distance from center, thus half the width
		end
	end, self.properties))
	xs:setFillColor(.7)

	xs.xupdate = "+"

	--
	--
	--

	local ys = display.newRect(group, 0, rect.height / 2, 10, 10)

	ys:addEventListener("touch", controls.OnMoveControl(function(_, y, rect, control)
		if y > MinDim then
			UpdateChildren(rect.parent, "y", "yupdate", y - control.y)
			UpdateProperty(rect, "height", 2 * y) -- as with x
		end
	end, self.properties))
	ys:setFillColor(.7)

	ys.yupdate = "+"

	--
	--
	--

	local rot = display.newCircle(group, xs.x + 30, 0, 7)

	rot:addEventListener("touch", controls.OnMoveControl(function(x, y, rect)
		if abs(x) + abs(y) > 2 then
			local group, angle = rect.parent, atan2(y, x)

			UpdateProperty(group, "rotation", (group.rotation + deg(angle)) % 360)
		end
	end, self.properties))
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
	end, self.properties)

	for i = 1, 4 do
		local w, h = rect.width / 2, rect.height / 2
		local xupdate, yupdate = i >= 3 and "+" or "-", (i == 2 or i == 3) and "+" or "-"
		local corner = display.newCircle(group, xupdate == "+" and w or -w, yupdate == "+" and h or -h, 7)

		corner:addEventListener("touch", CornerListener)
		corner:setFillColor(0, 1, 0, .7)

		corner.xprop, corner.xupdate = "x" .. i, xupdate
		corner.yprop, corner.yupdate = "y" .. i, yupdate
	end

	--
	--
	--

	local scroll_view = widget.newScrollView{
		backgroundColor = { .7, .7, .7 },
		top = 200, left = display.contentWidth - 302,
		width = 300, height = display.contentHeight - 202
	}

	self.view:insert(scroll_view)

	local svb = scroll_view.contentBounds
	local border = display.newRect(self.view, (svb.xMin + svb.xMax) / 2 - 1, (svb.yMin + svb.yMax) / 2 - 1, svb.xMax - svb.xMin + 2, svb.yMax - svb.yMin + 2)

	border:setFillColor(0, 0)
	border:setStrokeColor(.3)

	border.strokeWidth = 4

	--
	--
	--

	scroll_view.native_list = {}

	self.properties:Begin(scroll_view)

	PopulatePaneForRect(rect, xs, ys, self.properties)

	self.native_list, scroll_view.native_list = scroll_view.native_list

	--
	--
	--

	local button = widget.newButton{
		left = 5, top = display.contentHeight - 55, width = 150, height = 50,
        label = "> Links", shape = "roundedRect",
        fillColor = { default = { 1, 0, 0, 1 }, over = { 1, .1, .7, .4 } },
		font = native.systemFontBold, fontSize = 20,

        onEvent = function(event)
			if event.phase == "ended" then
				composer.gotoScene("tests.editor.scenes.linkage")
			end
		end
    }

	self.view:insert(button)

	--
	--
	--

	local phases = {}

	local launch = widget.newButton{
		left = 160, top = display.contentHeight - 55, width = 150, height = 50,
        label = "Launch", shape = "roundedRect",
        fillColor = { default = { 1, 0, 0, 1 }, over = { 1, .1, .7, .4 } },
		font = native.systemFontBold, fontSize = 20,

        onEvent = function(event)
			if event.phase == "ended" then
				local launch_data = { objects = {}, owners = {} }

				phases.objects(launch_data)

				if phases.links then -- TODO: loadScene() of linkage, since we might need this if loading from file
					phases.links(launch_data)
				end

				phases.package(launch_data)
				vdump(launch_data)
				composer.gotoScene("tests.editor.scenes.playground", launch_data)
			end
		end
    }

	self.view:insert(launch)

	--
	--
	--

	local function IterObjects ()
		return ipairs{ rect } -- TODO! (table view or something)
	end

	local PathProps = { "x1", "y1", "x2", "y2", "x3", "y3", "x4", "y4" }

	function phases.objects (launch_data)
		local objects, owners, rescue = launch_data.objects, launch_data.owners

		for _, object in IterObjects() do
			local refs, data = object.refs, { type = "rect" } -- TODO: per-object...
			local group = object.parent
	
			-- TODO: object-specific saver...

			data.x, data.y = object:localToContent(0, 0)
			data.width, data.height = object.width, object.height

			local rotation = group.rotation

			if abs(rotation) > 1e-3 then
				data.rotation = rotation
			end

			local fill = object.fill
			local r, g, b, a = fill.r, fill.g, fill.b, fill.a

			if abs(1 - r) > 1e-3 or abs(1 - g) > 1e-3 or abs(1 - b) > 1e-3 or abs(1 - a) > 1e-3 then
				data.fill_color = { r, g, b, a }
			end

			local path, pout = object.path

			for _, name in ipairs(PathProps) do
				local v = path[name]

				if abs(v) > 1e-3 then
					pout = pout or {}
					pout[name] = v
				end
			end

			data.path = pout

			-- /TODO

			if refs and #refs > 0 then -- has references?
				owners[refs.id] = data -- cf. show() in linkage
				rescue = rescue or {} -- backup in case we never use the reference
				rescue[#rescue + 1] = refs.id 
			else
				objects[#objects + 1] = data
			end
		end
	end

	--
	--
	--

	function phases.package (launch_data)
		local objects, owners, rescue, saved, n = launch_data.objects, launch_data.owners, launch_data.rescue, launch_data.saved, launch_data.nsaved or 0

		launch_data.objects, launch_data.owners, launch_data.rescue, launch_data.saved, launch_data.nsaved = nil
	
		for i = 1, n do
			objects[#objects + 1] = saved[i]
		end

		for i = 1, #(rescue or "") do
			local object = owners[rescue[i]]

			if not object.self then -- reference not linked?
				objects[#objects + 1] = object
			end
		end

		launch_data.params = objects
	end

	--
	--
	--

	composer.setVariable("launch_phases", phases)
end

Scene:addEventListener("create")

--
--
--

function Scene:show (event)
	if event.phase == "did" then
		for _, v in ipairs(self.native_list) do
			v.isVisible = true -- TODO: use text container + overlay to native
		end
	end
end

Scene:addEventListener("show")

--
--
--

function Scene:hide (event)
	if event.phase == "did" then
		for _, v in ipairs(self.native_list) do
			v.isVisible = false -- TODO: cf. show()
		end

		local object = self.properties:GetObject()
		local refs = object.refs or {}

		object.refs = refs

		composer.setVariable("current_editor_object_name", "RECT (#1)") -- TODO: make this dynamic
		composer.setVariable("current_editor_object_refs", refs)
		composer.setVariable("current_editor_object_type", "rect") -- TODO: ditto
	end
end

Scene:addEventListener("hide")

--
--
--

return Scene