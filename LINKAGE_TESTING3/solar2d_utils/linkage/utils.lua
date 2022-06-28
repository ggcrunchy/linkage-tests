--- DOCME

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
local type = type

-- Exports --
local M = {}

--
--
--

-- Default values for the type being saved or loaded --
-- TODO: How much work would it be to install some prefab logic?
local Defs

--- DOCME
function M.AssignDefs (item)
	for k, v in pairs(Defs) do
		if item[k] == nil then
			item[k] = v
		end
	end
end

--
--
--

-- Current module and value type being saved or loaded --
local Mod, ValueType

--- DOCME
function M.EditorEvent (mod, what, level, entry, values)
	mod.EditorEvent(ValueType, what, level, entry, values)
end

--
--
--

--- DOCME
function M.EnumDefs (mod, value)
	if Mod ~= mod or ValueType ~= value.type then
		Mod, ValueType = mod, value.type

		Defs = { name = "", type = ValueType }

		mod.EditorEvent(ValueType, "enum_defs", Defs)
	end
end

--
--
--

local AttachmentPairTag, EntryPairTag, ResumeEntryPairTag = "pair>attachment", "pair>entry", "pair>resume_entry"

--- DOCME
function M.AttachmentPairTag ()
	return AttachmentPairTag
end

--
--
--

--- DOCME
function M.EntryPairTag ()
	return EntryPairTag
end

--
--
--

--- DOCME
function M.ResumeEntryPairTag ()
	return ResumeEntryPairTag
end

--
--
--

local function DefCallback () end

--- DOCMEMORE
-- @array stream
-- @ptable params
-- * **ids_to_entries**: If absent, _params_.
-- * **visited**: If absent, _stream_.
-- * **visit_entry**: Called as `visit_entry(entry, index)`.
-- * **resolve_pair**: Called as `resolve_pair(entry1, name1, entry2, name2)`.
-- @treturn array Visited entries...
-- @treturn uint ...count of such entries; in general this is not `#visited`.
function M.VisitLinks (stream, params)
	assert(type(params) == "table", "Invalid params")

	local ids_to_entries, visited = params.ids_to_entries or params, params.visited or stream
	local resolve_pair, visit_entry = params.resolve_pair or DefCallback, params.visit_entry or DefCallback
	local count, index, entry, aname = 0, 0

	for i = 1, #(stream or ""), 2 do
		local a, b = stream[i], stream[i + 1]

		-- Entry tags introduce and visit "objects". For resolution purposes, the first entry
		-- has index 1, the second 2, etc.
		if a == EntryPairTag then -- b: entry ID
			entry, count = ids_to_entries[b], count + 1
			index = count

			visit_entry(entry, index)

			visited[index] = entry -- n.b. since we read two elements at a time but write
									-- at most one, we may safely use stream as visited

		-- Resume entry tags make an already visited entry current.
		elseif a == ResumeEntryPairTag then -- b: index of entry
			entry, index = visited[b], b

		-- Attachment tags associate an attachment with the current "object", i.e. the last
		-- introduced or resumed one, whichever was more recent.
		elseif a == AttachmentPairTag then -- b: attachment point name
			aname = b

		-- Resolution will pair the current entry + attachment to another one, also with an
		-- attachment. This is a no-op if the second entry has not yet been visited.
		--
		-- A stream might be structured thus: an entry, then all its attachments with their
		-- resolutions, followed by another entry and so on. In this case, the filtering of
		-- nonexistent entries also removes duplicate resolves as a side effect.
-- TODO: the above has been generalized, plus some of this language is a little tighter:

-- depending on when both owners are known, we might encounter the pair
-- twice, as (A, B) and (B, A), thus this guard against duplication; since
-- an index describes "when" an owner becomes known, larger values will be
-- assigned to those still pending, motivating our greater-than comparison
		elseif index > a then -- a: index of other entry; b: attachment point name for other entry
							  -- n.b. for simplicity, (index #1, name #1) and (index #2, name #2) are each
							  -- represented; the pair is resolved after both entries have been visited
			resolve_pair(entry, aname, visited[a], b)
		end
	end

	return visited, count
end

--
--
--

return M