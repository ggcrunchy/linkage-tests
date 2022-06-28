--- Scroll view-backed editor pane, populated from object property values.

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
local setmetatable = setmetatable
local type = type

-- Exports --
local M = {}

--
--
--

local PropertiesPane = {}

PropertiesPane.__index = PropertiesPane

--
--
--

--- DOCME
function PropertiesPane:Begin (scroll_view)
	local yoffset = self.m_yoffset or 0

	self.m_penx, self.m_peny, self.m_lowest = self.m_xoffset or 0, yoffset, yoffset
	self.m_scroll_view = scroll_view
end

--
--
--

--- DOCME
function PropertiesPane:BeginSeries ()
	self.m_in_series = true
end

--
--
--

--- DOCME
function PropertiesPane:GetLowestY ()
	return self.m_lowest
end

--
--
--

--- DOCME
function PropertiesPane:GetObject ()
	return self.m_object
end

--
--
--

--- DOCME
function PropertiesPane:GetScrollView ()
	return self.m_scroll_view
end

--
--
--

--- DOCME
function PropertiesPane:GetXOffset ()
	return self.m_xoffset or 0
end

--
--
--

--- DOCME
function PropertiesPane:GetYOffset ()
	return self.m_yoffset or 0
end

--
--
--

--- DOCME
function PropertiesPane:HasItemsInLine ()
	return #self.m_line_items > 0
end


--
--
--

--- DOCME
function PropertiesPane:Indent (sep)
	assert(sep and sep >= 0, "Expected non-negative horizontal separation")

	self.m_penx = self.m_penx + sep
end

--
--
--

--- DOCME
function PropertiesPane:IsLineUnlocked ()
	return self.m_lock_count == 0
end

--
--
--

local function AuxLine (pane, a, b, ...)
	assert(a == nil or type(a) == "string", "Non-string line entry")

	if a then
		local params

		if a:find("@") == 1 then
			local value = a:sub(2)

			if type(b) == "table" then
				params = b
			end

			pane:Value(value, params)
		else
			pane:Literal(a)
		end

		if params then
			return AuxLine(pane, ...)
		else
			return AuxLine(pane, b, ...)
		end
	end
end

--- DOCME
function PropertiesPane:Line (...)
	self:LockLine()

	AuxLine(self, ...)

	self:UnlockLine()
end

--
--
--

local function Add (pane, object, name)
	local into = pane.m_group or pane.m_scroll_view

	into:insert(object)

	local penx, peny, dx, dy = pane.m_penx, pane.m_peny, object.width, object.height
	local x, y, items = penx, peny, pane.m_line_items

	if object._type ~= "GroupObject" or object.anchorChildren then
		x, y = x + dx / 2, y + dy / 2
	end

	object.x, object.y = x, y

	pane.m_penx, pane.m_lowest = penx + dx + (pane.m_sepx or 0), max(pane.m_lowest, peny + dy)

	items[#items + 1] = object

	if pane:IsLineUnlocked() then
		pane:NewLine()
	end
end

--
--
--

--- DOCME
function PropertiesPane:Literal (str)
	local handler = self.m_form.literal

	assert(handler, "Missing handler for literal")

	Add(self, handler(str))
end

--
--
--

--- DOCME
function PropertiesPane:LiteralAndValue (str, name, params)
	self:LockLine()
	self:Literal(str)
	self:Value(name, params)
	self:UnlockLine()
end

--
--
--

--- DOCME
function PropertiesPane:LockLine ()
	self.m_lock_count = self.m_lock_count + 1
end

--
--
--

local function CenterTextObjects (items, midy)
	for i = #items, 1, -1 do
		local item = items[i]

		if item._type == "TextObject" then
			item.y = midy
		end

		items[i] = nil
	end
end

--- DOCME
function PropertiesPane:NewLine (sep)
	assert(sep == nil or sep >= 0, "Expected non-negative vertical separation")

	CenterTextObjects(self.m_line_items, (self.m_peny + self.m_lowest) / 2)

	local peny = self.m_lowest + (sep or self.m_sepy or 0)

	self.m_lock_count, self.m_penx, self.m_peny, self.m_lowest = 0, self.m_xoffset or 0, peny, peny
end

--
--
--

--- DOCME
function PropertiesPane:SetForm (form)
	self.m_form = form
end

--
--
--

--- DOCME
function PropertiesPane:SetObject (object, object_type)
	self.m_object, self.m_type = object, object_type
end

--
--
--

--- DOCME
function PropertiesPane:SetOffsets (xoffset, yoffset)
	self.m_xoffset, self.m_yoffset = xoffset, yoffset
end

--
--
--

--- DOCME
function PropertiesPane:SetSeparationDistances (sepx, sepy)
	self.m_sepx, self.m_sepy = sepx, sepy
end

--
--
--

--- DOCME
function PropertiesPane:StartGroup (group, on_done, arg)
	if self.m_on_group_done then
		self.m_on_group_done(self.m_group, self.m_group_done_arg)
	end

	if group then
		assert(group.numChildren == 0, "Cannot start non-empty group")
	else
		group = display.newGroup()
	end

	self.m_scroll_view:insert(group)

	self.m_group, self.m_on_group_done, self.m_group_done_arg = group, on_done, arg

	return group
end

--
--
--

--- DOCME
function PropertiesPane:UnlockLine ()
	local lock_count = self.m_lock_count - 1

	if lock_count >= 0 then
		self.m_lock_count = lock_count

		if lock_count == 0 and self:HasItemsInLine() then
			self:NewLine()
		end
	end
end

--
--
--

--- DOCME
function PropertiesPane:Value (name, params)
	local details = assert(self.m_type[name], "Unknown value")
	local handler = assert(self.m_form[details.type], "Missing handler")
	local v = self.m_object[name]

	if v == nil then
		v = details.default
	end

	Add(self, handler(v, name, params, self))
end

--
--
--

--- DOCME
function PropertiesPane:ValueAndLiteral (name, str, params)
	self:LockLine()
	self:Value(name, params)
	self:Literal(str)
	self:UnlockLine()
end

--
--
--

--- DOCME
function M.New ()
	return setmetatable({ m_line_items = {}, m_lock_count = 0 }, PropertiesPane)
end

--
--
--

return M