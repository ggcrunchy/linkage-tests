--- TODO!
-- @module NodePattern

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
local next = next
local pairs = pairs
local setmetatable = setmetatable

-- Modules --
local node_environment = require("s3_editor.NodeEnvironment")

-- Exports --
local M = {}

--
--
--

local NodePattern = {}

NodePattern.__index = NodePattern

--
--
--

local function AddNode (NP, name, key, what)
	local elist, ilist = NP.m_export_nodes, NP.m_import_nodes

	assert(not (elist and elist[name]), "Name already used in exports list")
	assert(not (ilist and ilist[name]), "Name already used in imports list")

	local list = NP[key] or {}

	NP[key], list[name] = list, NP.m_env:GetRule(what, key == "m_export_nodes" and "exports" or "imports")
end

--- Add an export node to the pattern.
-- @param name Node name, expected to be unique among both exports and imports.
--
-- String-type names that end in **"*"** are interpreted as templates and may be cloned via
-- @{NodePattern:Generate}, useful for effecting certain dynamic patterns.
-- @param what What sort of node this will be.
--
-- If this is a string, it may also end with some combination of options: **"-"** or **"+"**
-- (but not both), **"="**, and **"?"** or **"!"** (but not both). Once read, these will be
-- peeled off and the shortened string used as _what_.
--
-- Three kinds of node are currently available: functions, values, and wildcards.
--
-- Functions are denoted by _what_ being **"event"** and will only match fellow events.
--
-- Values are subtyped by _what_ and will typically give themselves the interface derived
-- from _what_ and the node's list, e.g. something like `interface = NameFrom(what, "exports")`,
-- although this can be changed on a case-by-case basis in the interface lists, cf.
-- @{NodeEnvironment:New}. The node in question will match the interface `opposite = NameFrom(what, "imports")`.
-- A _what_ of **"bool"**, for instance, might have interface **"exports:bool"** and match
-- against **"imports:bool"**.
--
-- By default, values also receive a "this is a value" interface, making them visible
-- to @{ImplementsValue}, and also try to match wildcards. The strict modifier (**"="** from
-- above) will let them opt out of this policy.
--
-- When a **"?"** or **"!"** modifier is present, _what_ is the name of a wildcard predicate,
-- cf. @{NodeEnvironment:New}, that will be used to try to match values. In the mixture case
-- (**"!"**), the value need only satisfy the predicate; otherwise, once one link has been
-- established, any further matches must also implement its "primary interface".
--
-- The remaining modifiers determine whether the node should be limited to one link (**"-"**)
-- or unlimited (**"+"**). The former is the default for value import nodes and the latter
-- for everything else.
-- @see NodePattern:AddImportNode
function NodePattern:AddExportNode (name, what)
	AddNode(self, name, "m_export_nodes", what)
end

--
--
--

--- Add an import node to the pattern.
-- @param name As per @{NodePattern:AddExportNode}, but for the imports list.
-- @param what Ditto.
function NodePattern:AddImportNode (name, what)
	AddNode(self, name, "m_import_nodes", what)
end

--
--
--

local function CheckListsForRule (NP, name)
	local elist, ilist = NP.m_export_nodes, NP.m_import_nodes

	return elist and elist[name], ilist and ilist[name]
end

local function FindRule (NP, name)
	local erule, irule = CheckListsForRule(NP, name)

	return erule or irule
end

--- DOCME
-- @param name
-- @treturn[1] string N
-- @treturn[1] function F
-- @return[2] **nil**
-- @see NodePattern:AddExportNode, NodePattern:AddImportNode, NodePattern:GetTemplate
function NodePattern:Generate (name)
	local env = self.m_env

	if env:IsTemplate(name) then
		local rule = FindRule(self, name)

		if rule then
			return env:Instantiate(name), rule
		end
	end

	return nil
end

--
--
--

--- DOCME
-- @treturn NodeEnvironment X
-- @see New
function NodePattern:GetEnvironment ()
	return self.m_env
end

--
--
--

--- DOCME
-- @param name
-- @treturn[1] string
-- @treturn[1] callable
-- @return **nil**, if _name_ belongs to no node.
function NodePattern:GetNodeType (name)
	local erule, irule = CheckListsForRule(self, name)

	if erule then
		return "exports", erule
	elseif irule then
		return "imports", irule
	else
		return nil
	end
end

--
--
--

--- DOCME
-- @param name
-- @treturn ?|string|nil
-- @see NodePattern:Generate
function NodePattern:GetTemplate (name)
	local template = self.m_env:GetTemplate(name)

	return FindRule(self, template) and template
end

--
--
--

local function GetNodeList (NP, how)
	return NP[how == "exports" and "m_export_nodes" or "m_import_nodes"]
end

---
-- @param name
-- @string[opt] how
-- @treturn boolean X
function NodePattern:HasNode (name, how)
	if how == "exports" or how == "imports" then
		local list = GetNodeList(self, how)

		return (list and list[name]) ~= nil
	else
		return FindRule(self, name) ~= nil
	end
end

--
--
--

local function AuxIterBoth (NP, name)
	local elist = NP.m_export_nodes

	if elist and (name == nil or elist[name]) then
		local node

		name, node = next(elist, name)

		if node then
			return name, node
		else
			name = nil -- switch from export to import list?
		end
	end

	local ilist = NP.m_import_nodes

	if ilist then
		return next(ilist, name) -- name will be nil if elist empty
	end
end

local function DefIter () end

local function PairsOrNoOp (list)
	if list then
		return pairs(list)
	else
		return DefIter
	end
end


local function IterBoth (NP)
	local elist, ilist = NP.m_export_nodes, NP.m_import_nodes

	if elist and ilist then
		return AuxIterBoth, NP, nil
	else
		return PairsOrNoOp(elist or ilist)
	end
end

--- Iterate over a set of the nodes thus far added to the pattern.
-- @string[opt] how If this is **"exports"** or **"imports"**, iteration will be restricted
-- to the corresponding subset of nodes. Otherwise, all nodes are iterated.
-- @return Iterator that supplies name, rule pairs for requested nodes.
-- @see NodePattern:AddExportNode, NodePattern:AddImportNode, NodePattern:IterNonTemplateNodes, NodePattern:IterTemplateNodes
function NodePattern:IterNodes (how)
	if how == "exports" or how == "imports" then
		return PairsOrNoOp(GetNodeList(self, how))
	else
		return IterBoth(self)
	end
end

--
--
--

--- Variant of @{NodePattern:IterNodes} that only considers non-template nodes.
-- @string[opt] how As per @{NodePattern:IterNodes}.
-- @treturn Iterator that supplies name, rule pairs for requested nodes.
-- @see NodePattern:AddExportNode, NodePattern:AddImportNode, NodePattern:IterNodes, NodePattern:IterTemplateNodes
function NodePattern:IterNonTemplateNodes (how)
	local env, list = self.m_env

	for k, v in self:IterNodes(how) do
		if not env:IsTemplate(k) then
			list = list or {}
			list[k] = v
		end
	end

	return PairsOrNoOp(list)
end

--
--
--

--- Variant of @{NodePattern:IterNodes} that only considers template nodes.
-- @string[opt] how As per @{NodePattern:IterNodes}.
-- @treturn Iterator that supplies name, rule pairs for requested nodes.
-- @see NodePattern:AddExportNode, NodePattern:AddImportNode, NodePattern:IterNodes, NodePattern:IterNonTemplateNodes
function NodePattern:IterTemplateNodes (how)
	local env, list = self.m_env

	for k, v in self:IterNodes(how) do
		if env:IsTemplate(k) then
			list = list or {}
			list[k] = v
		end
	end

	return PairsOrNoOp(list)
end

--
--
--

local DefEnvironment

--- DOCME
-- @tparam[opt] NodeEnvironment env If present, an environment returned by @{NodeEnvironment.New}.
-- Otherwise, the default environment is chosen.
-- @treturn NodePattern Node pattern.
-- @see NodePattern:GetEnvironment
function M.New (env)
	if not env then
		DefEnvironment = DefEnvironment or node_environment.New{}
		env = DefEnvironment
	end

	return setmetatable({ m_env = env }, NodePattern)
end

--
--
--

return M