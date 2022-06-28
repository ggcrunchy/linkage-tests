--- Various operations related to maintaining inter-node connections.

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

-- Unique keys --
local _can_replace = {}
local _name = {}
local _rule = {}

-- Exports --
local M = {}

--
--
--

--- DOCME
function M.AllowLinkReplacement (node)
	node[_can_replace] = true
end

--
--
--

--- DOCME
function M.GetName (node)
	return node[_name]
end

--
--
--

--- DOCME
function M.MakeRunnerFuncs (ops)
	local event, layout = {}, ops.layout

	local function can_connect (a, b)
		local arule, brule = a[_rule], b[_rule]

		event.target, event.node, event.other = brule, a, b

		local aok = arule(event)

		event.target, event.node, event.other = arule, b, a

		local bok = brule(event)

		event.target, event.node, event.other = nil

		return aok and bok
	end

	local function connect (how, a, b)
		if how == "connect" then -- n.b. display object does NOT exist yet...
			if a[_can_replace] then
				layout:BreakConnections(a)
			end

			if b[_can_replace] then
				layout:BreakConnections(b)
			end
		elseif how == "disconnect" then -- ...but here it usually does, cf. note in FadeAndDie()
			--
		end
	end

	return can_connect, connect
end

--
--
--

--- DOCME
function M.SetName (node, name)
	node[_name] = name
end

--
--
--

--- DOCME
function M.SetRule (node, rule)
	node[_rule] = rule
end

--
--
--

return M