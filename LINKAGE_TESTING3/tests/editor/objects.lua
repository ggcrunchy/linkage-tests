--- Common behavior for objects maintained by editor.

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
local pairs = pairs
local random = math.random
local setmetatable = setmetatable
local type = type

-- Modules --
local adaptive = require("tektite_core.table.adaptive")
local interface = require("tests.editor.interface")
local node_connection = require("tests.editor.node_connection")
local node_environment = require("s3_editor.NodeEnvironment")
local node_pattern = require("s3_editor.NodePattern")
local node_runner = require("solar2d_ui.patterns.node_runner")
local pubsub = require("solar2d_utils.pubsub")
local utils = require("solar2d_utils.linkage.utils")

-- Unique keys --
local _getter = {}
local _name = {}
local _metatable = {}

-- Cached module references --
local _ImportsExports_

-- Exports --
local M = {}

--
--
--

local WantReplacement = true

local ResolveLimit = WantReplacement and "multi_imports"

local Env = node_environment.New{
	has_no_links = function(event)
		return not node_runner.HasAnyConnections(event.node)
	end,

	interpretation_lists = {
		exports = {
			int = { "int", "number" },
			uint = { "uint", "int", "number" }
		},
		imports = {
			number = { "number", "int", "uint" },
			int = { "int", "uint" }
		}
	},

	resolve_limit = ResolveLimit
}

--
--
--

--- DOCME
function M.Inherit (what)
	local added = not Env:HasInterpretations(what, "exports")

	if added then -- n.b. both added, so checking one enough
		local interfaces = { "object", what }

		Env:GetRule("object", "exports") -- ensure rule exists
		Env:AddInterpretations(what, "exports", interfaces)
		Env:GetRule("object", "imports") -- ditto
		Env:AddInterpretations(what, "imports", interfaces)
	end

	return added
end

--
--
--

local function DefName (method, arg)
	if arg == "event" then
		return method == "AddImportNode" and "next" or "do"
	else
		return method == "AddImportNode" and "value" or "result"
	end
end

local function DefGetName (arg) return arg end

local Field

local function GetNameFromMember (t)
	assert(type(t) == "table", "Expecting to extract node type member from a table")

	return t[Field]
end

local function AddNodes (np, method, arg, get_name)
	if type(arg) == "string" then
		np[method](np, DefName(method, arg), arg)
	elseif arg then
		if type(get_name) == "string" then -- e.g. with `arg` an array of exports, name = "what": `{ --[[ snip ]], { what = "event", func = DoSomething }, { what = "boolean", func = Succeeded }, --[[ snip ]] }`
			get_name, Field = GetNameFromMember, get_name
		else 
			get_name = get_name or DefGetName
		end

		for name, what in pairs(arg) do
			np[method](np, name, get_name(what))
		end
	end
end

local function MakeEntryLinker (np, opts)
-- TODO: exceptions for certain names, etc.
	local out_key = opts and opts.out_key

	return function(entry1, name1, entry2, name2)
		local ntype = np:GetNodeType(name1)

		if ntype == "imports" then
			entry1[name1], entry2.uid_in_use = adaptive.Append(entry1[name1], pubsub.MakeEndpoint(entry2.uid, name2)), true
			-- TODO: perform actual cleanup...
		else
			assert(ntype == "exports", "Invalid node")

			if out_key then
				entry1[out_key] = adaptive.AddToSet(entry1[out_key], name1)
			else
				entry1[name1] = true
			end
		end

-- TODO: if IsGenerated(name1)
	-- labels, etc.
	end
end

-- Say we have two linked rects:
--
-- /------------------\           /------------------\
-- |                  |           |                  |
-- | Event node RHS O-|-----------|-O Event node LHS |
-- |                  |           |                  |
-- | Value node RHS O-|-----------|-O Value node LHS |
-- |                  |           |                  |
-- \------------------/           \------------------/
--
-- Right-hand-side nodes seem to convey an outgoing value or flow of control; those on the
-- left represent an incoming one. This matches what we do for values: LHS = imports, RHS =
-- exports, i.e. "pull"-style behavior. Control flow is slightly surprising: "finished, now
-- do the next one" means we need to have the subsequent event available; swapping the roles
-- of the two sides here preserves the visual intuition.
local Side = {
	[true] = {	-- what = "event"?
		imports = "rhs", exports = "lhs"
	},

	[false] = {
		imports = "lhs", exports = "rhs"
	}
}

local function DefIterNodes (np)
	return np:IterNodes()
end

--- DOCME
function M.MakeFactory (params)
	assert(type(params) == "table", "Non-table params")

	local np = node_pattern.New(Env)

	AddNodes(np, "AddImportNode", params.imports, params.get_import_name)
	AddNodes(np, "AddExportNode", params.exports, params.get_export_name)

	local mt = { type = params.type }

	mt.__index, mt.link_entries = mt, MakeEntryLinker(np, params)

	local has_delete, iter, owner_id = not params.no_delete, params.iter or DefIterNodes, params.owner_id
	local name_to_text, title = params.name_to_text, params.title or ""

	return function(into, runner)
		local group = interface.Rect(title)

		if has_delete then
			local delete = interface.NewDeleteControl(group)

			interface.Sync(delete)
		end

		local old_id = interface.GetOwnerID()

		if owner_id then
			assert(owner_id < old_id, "Invalid owner ID")

			interface.SetOwnerID(owner_id)
		end

		for name, rule, which, what in iter(np) do
			if rule ~= "own_objects" then
				if not (which and what) then -- these are useful to discover rule, so custom iterator might already have them
					which, what = Env:GetRuleInfo(rule)
				end

				if name_to_text then
					name = name_to_text[name] or name
				end

				local is_event = what == "event"
				local node = interface.NewNode(runner, group, Side[is_event][which], name, what, rule)

				node[_metatable] = mt

				if WantReplacement and not is_event and which == "imports" then
					node_connection.AllowLinkReplacement(node)
				end
			else -- name: custom object populater
				local n = group.numChildren

				name(group)

				for i = group.numChildren, n + 1, -1 do
					local item = group[i]
					local name = item[_name]

					if name ~= nil then
						local stream = interface.GetDataStream(group)

						stream[#stream + 1] = item
						stream[#stream + 1] = name
						stream[#stream + 1] = item[_getter]
						-- TODO: is this robust for undo / redo?

						item[_name], item[_getter] = nil
					end
				end
			end
		end

		interface.CommitRect(group, display.contentCenterX + random(-30, 30), 75 + random(-20, 20))

		if owner_id then
			interface.SetOwnerID(old_id) -- restore sequence...
		else
			interface.SetOwnerID(old_id + 1) -- ...or advance
		end

		into:insert(group)
	end
end

--
--
--

--- DOCME
function M.MakeNonNodeDatumAvailable (object, name, getter)
	assert(name ~= nil, "No name provided")

	object[_name], object[_getter] = name, assert(getter, "No getter provided")
end

--
--
--

--- DOCME
function M.PopulateFromDataStream (out, node)
	local data_stream = node.parent.data_stream

	for i = 1, #(data_stream or ""), 3 do
		local item, name, getter = data_stream[i], data_stream[i + 1], data_stream[i + 2]

		out[name] = getter(item)
	end
end

--
--
--

--- DOCME
function M.PrepareOwnerForLink (owner, node)
	local mt = node[_metatable]

	assert(owner.type == nil or mt.type == nil or owner.type == mt.type, "Mismatched owner type")

	owner.type = owner.type or mt.type -- object might already set it; bring it in otherwise, since saving ignores metatable

	return setmetatable(owner, mt)
end

--
--
--

local function EstablishOwner (saved, node, id_to_index, new)
	local owner_id = node_runner.GetOwner(node)

	if id_to_index[owner_id] then -- is the owner already sequenced?
		saved[#saved + 1] = utils.ResumeEntryPairTag()
		saved[#saved + 1] = id_to_index[owner_id]
	else
		saved[#saved + 1] = utils.EntryPairTag()
		saved[#saved + 1] = owner_id

		new(node, owner_id)

		local n = id_to_index.n + 1

		id_to_index[owner_id], id_to_index.n = n, n
	end
end

local function AuxConnectedNodes (nodes, index)
	local connected = nodes.connected

	repeat
		index = index + 1

		local node = nodes[index]
		local results, n = node_runner.GetConnectedObjects(node, connected) -- if node absent, n = 0

		if n > 0 then
			return index, node, results, n
		end
	until not node
end

local function ConnectedNodes (runner)
	local nodes = runner:GetNodes()

	nodes.connected = {}

	return AuxConnectedNodes, nodes, 0
end

local AttachmentPairTag = utils.AttachmentPairTag()

--- DOCME
function M.Save (runner, new)
	local id_to_index, saved = { n = 0 }, {}

	for _, node, results, n in ConnectedNodes(runner) do
		EstablishOwner(saved, node, id_to_index, new)

		local node_name = node_connection.GetName(node)

		for i = 1, n do
			local other = results[i]
			local other_index = id_to_index[node_runner.GetOwner(other)]

			if other_index then -- other owner known yet?
				saved[#saved + 1] = AttachmentPairTag
				saved[#saved + 1] = node_name
				saved[#saved + 1] = other_index
				saved[#saved + 1] = node_connection.GetName(other)
			end
		end
	end

	return saved
end

--
--
--

_ImportsExports_ = M.ImportsExports

return M