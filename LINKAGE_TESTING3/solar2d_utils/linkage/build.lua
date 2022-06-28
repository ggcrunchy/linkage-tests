--- TODO

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
local table_funcs = require("tektite_core.table.funcs")
local utils = require("solar2d_utils.linkage.utils")

-- Exports --
local M = {}

--
--
--

--- DOCME
function M.BuildEntry (level, mod, entry, acc, links)
	acc = acc or {}

	local built, instances = table_funcs.Copy(entry), entry.instances

	if instances then
		built.instances = nil

		mod.EditorEvent(entry.type, "build_instances", built, {
			instances = instances, labels = level.labels, links = links
		})
	--[[
		entry:SendMessage("build_generated_names", built, {
			generated_names = entry.generated_names, labels = level.labels, links = env.links
		})
	]]
	end

	built.positions = nil

	if entry.uid then
		level.links[entry.uid], built.uid = built

		local prep_link, cleanup = mod.EditorEvent(entry.type, "prep_link", level, built)
--[[
	entry:SendMessage("prep_link", level, built)
]]
		level.links[built] = prep_link

		if cleanup then
			level.cleanup = level.cleanup or {}
			level.cleanup[built] = cleanup
		end
	end

	built.name = nil

	mod.EditorEvent(entry.type, "build", level, entry, built)
--[[
	entry:SendMessage("fix_built_data", level, entry, built)
]]
	acc[#acc + 1] = built

	return acc
end

--
--
--

local function LinkEntries (event, entry1, aname1, entry2, aname2, cleanup)
	if entry1.link_entries then
		entry1:link_entries(aname1, entry2, aname2, event)

		if event.remove_resources then -- introduced temporary resources that should go away once linking is complete
			cleanup = cleanup or {}

			cleanup[#cleanup + 1] = event.remove_resources
			cleanup[#cleanup + 1] = entry1
			cleanup[#cleanup + 1] = aname1

			event.remove_resources = nil
		end
	end

	return cleanup
end

--- DOCME
function M.ResolveLinks (stream, ids_to_entries, labels)
	local link_event, cleanup = { labels = labels }
	local visited, count = utils.VisitLinks(stream, {
		ids_to_entries = ids_to_entries,

		resolve_pair = function(entry1, aname1, entry2, aname2)
			cleanup = LinkEntries(link_event, entry1, aname1, entry2, aname2, cleanup)
			cleanup = LinkEntries(link_event, entry2, aname2, entry1, aname1, cleanup)
		end,

		visit_entry = function(entry, index)
			entry.uid = index
		end
	})

	for i = 1, #(cleanup or ""), 3 do
		cleanup[i](cleanup[i + 1], cleanup[i + 2])
	end

	return visited, count
end

--
--
--

return M