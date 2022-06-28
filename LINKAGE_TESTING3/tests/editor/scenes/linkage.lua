--- Editor scene where node linkages can be manipulated.

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
local pairs = pairs
local remove = table.remove
local sort = table.sort

-- Modules --
local build = require("solar2d_utils.linkage.build")
local interface = require("tests.editor.interface")
local menu = require("solar2d_ui.widgets.menu")
local objects = require("tests.editor.objects")
local object_type_list = require("tests.editor.object_type_list")
local pubsub = require("solar2d_utils.pubsub")

-- Extension imports --
local indexOf = table.indexOf

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

function Scene:create ()
	local name_to_builder, pre_columns = {}, {}

	for cname, group in pairs(object_type_list.general_menu_items) do
		local column = { name = cname }

		for name, builder in pairs(group) do
			column[#column + 1] = name
			name_to_builder[name] = builder
		end

		sort(column)

		pre_columns[#pre_columns + 1] = column
	end

	sort(pre_columns, function(c1, c2) return c1.name < c2.name end)

	local columns = {}

	for _, column in ipairs(pre_columns) do
		columns[#columns + 1] = column.name
		columns[#columns + 1] = column

		column.name = nil
	end

	local get_name = menu.Menu{ group = self.view, columns = columns, column_width = 135 }
	local back_group = display.newGroup()

	self.box_group = display.newGroup()
	self.runner = interface.NewRunner(back_group)

	get_name:addEventListener("menu_item", function(event)
		local name = columns[event.column * 2][event.index]
		local builder = name_to_builder[name]

		builder(self.box_group, self.runner)
	end)

-- TODO: make box group draggable, add some tint or grid above it

	local h = get_name:GetHeadingHeight()
	local cont = display.newContainer(self.view, display.contentWidth, display.contentHeight - h)

	cont.anchorChildren = false
	cont.anchorX, cont.anchorY = 0, 0

	cont:insert(self.box_group)
	cont:insert(back_group)
	cont:translate(0, h)
	cont:toBack()

	interface.SetDragY(h)

	--
	--
	--

	local button = widget.newButton{
		left = 5, top = display.contentHeight - 55, width = 150, height = 50,
        label = "> Main", shape = "roundedRect",
        fillColor = { default = { 1, 0, 0, 1 }, over = { 1, .1, .7, .4 } },
		font = native.systemFontBold, fontSize = 20,

        onEvent = function(event)
			if event.phase == "ended" then
				composer.gotoScene("tests.editor.scenes.common")
			end
		end
    }

	self.view:insert(button)

	--
	--
	--

	self.about_current = display.newText(self.view, "", 175, display.contentHeight - 30, native.systemFontBold, 20)

	self.about_current.anchorX = 0

	local function FinalizeRefBox (event)
		local box = event.target
		local pos = indexOf(box.refs, box)

		if pos then -- in case already removed manually
			remove(box.refs, pos)
		end
	end

	self.add_ref = widget.newButton{
		left = get_name.contentBounds.xMax + 5, top = 5, width = 165, height = 25,
        label = "Add object reference", shape = "roundedRect",
        fillColor = { default = { 1, 0, 0, 1 }, over = { 1, .1, .7, .4 } },
		font = native.systemFont, fontSize = 15,

        onEvent = function(event)
			if event.phase == "ended" and self.builder then
				self.builder(self.box_group, self.runner)

				local box = self.box_group[self.box_group.numChildren]

				box:addEventListener("finalize", FinalizeRefBox)

				box.refs = self.object_refs
					-- create reference:
						-- if object not seen yet, allocate owner ID
						-- node in reference made using said ID
						-- make sure owner routes there
						-- if such an owner found, merge saved object data into it
			end
		end
    }

	self.view:insert(self.add_ref)

	--
	--
	--
-- TODO!
local component = require("tektite_core.component")

component.RegisterType("object")
component.RegisterType{ name = "rect", interfaces = "object" }

	--
	--
	--

	local phases = composer.getVariable("launch_phases")

	function phases.links (launch_data)
		local owners = launch_data.owners

		local function NewOwner (node, owner_id)
			local owner = owners[owner_id] or {} -- might already have been made by object

			owners[owner_id] = owner

			objects.PopulateFromDataStream(owner, node)
			objects.PrepareOwnerForLink(owner, node)
		end

		local saved = objects.Save(self.runner, NewOwner)

		print("BEFORE")

		vdump(saved)

		print("")
		print("RESOLVING BUILD")

		local visited, n = build.ResolveLinks(saved, owners)

		print("")
		print("AFTER")

		visited[n + 1] = "EVERYTHING STARTING HERE IS NO LONGER RELEVANT"

		vdump(saved)

		if n > 0 then
			launch_data.saved, launch_data.nsaved = visited, n
		end
	end

	--
	--
	--

	-- TODO: load scene from file, hook up refs
end

Scene:addEventListener("create")

--
--
--

function Scene:show (event)
	if event.phase == "did" then
		local object_name = composer.getVariable("current_editor_object_name")
		local object_refs = composer.getVariable("current_editor_object_refs")
		local object_type = composer.getVariable("current_editor_object_type")

		if object_name ~= self.object_name then
			self.about_current.text = "Current object: " .. object_name
		end

		local same_refs, same_type = object_refs == self.object_refs, object_type == self.object_type

		assert(not same_refs or same_type, "Object refs changed, but type did not")

		if not (same_refs and same_type) then
			if not object_refs.id then
				object_refs.id = interface.GetOwnerID() -- TODO: robust with undo / redo?

				interface.SetOwnerID(object_refs.id + 1)
			end

			if not same_type then
				objects.Inherit(object_type)

				local column, name_to_builder = {}, object_type_list.type_specific_menu_items[object_type]()

				for name in pairs(name_to_builder) do
					column[#column + 1] = name
				end

				sort(column)

				display.remove(self.get_name)

				self.get_name = menu.Dropdown{ group = self.view, column = column, left = self.add_ref.contentBounds.xMax + 5, column_width = 135 }

				self.get_name:addEventListener("menu_item", function(event)
					local name = column[event.index]
					local builder = name_to_builder[name]

					builder(self.box_group, self.runner)

					self.object_refs[#self.object_refs + 1] = self.box_group[self.box_group.numChildren] -- TODO: not very load friendly...
				end)
			end

			self.builder = objects.MakeFactory{
				title = "Reference to " .. object_name, -- TODO: should adjust to renaming, possibly resizing the rect as well
				exports = { self = object_type },
				owner_id = object_refs.id
			}
		end

		self.object_name, self.object_refs, self.object_type = object_name, object_refs, object_type
	end
end

Scene:addEventListener("show")

--
--
--

function Scene:hide (event)
	if event.phase == "did" then
		--
	end
end

Scene:addEventListener("hide")

--
--
--

return Scene