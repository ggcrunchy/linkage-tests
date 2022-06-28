--- Shader graph box logic.

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
local concat = table.concat
local error = error
local pairs = pairs
local remove = table.remove

-- Modules --
local code_gen = require("tests.shader_graph.code_gen")
local dfs = require("tests.shader_graph.dfs")
local node_runner = require("solar2d_ui.patterns.node_runner")
local node_state = require("tests.shader_graph.node_state")

-- Solar2D globals --
local timer = timer

-- Solar2D modules --
local widget = require("widget")

-- Exports --
local M = {}

--
--
--

--
-- Connectedness search
--

local function AuxAdjacentBoxesIter (adjacency_stack, n)
	if n > 0 then
		return n - 1, remove(adjacency_stack)
	end
end

local function MakeAdjacencyIterator (gather, layout)
	local adjacency_stack = {}

	return function(_, box) -- TODO: node works as index EXCEPT with undo / redo
		local n = #adjacency_stack

		layout:VisitNodesConnectedToChildren(box, gather, adjacency_stack)

		return AuxAdjacentBoxesIter, adjacency_stack, #adjacency_stack - n
	end
end

local OnFoundHard

local function GatherResolvableBoxes (neighbor, parent_node, adjacency_stack)
	local what = node_state.Classify(neighbor, parent_node)

	if what == "hard" then
		OnFoundHard()
	elseif what == "neither_hard" then
		adjacency_stack[#adjacency_stack + 1] = neighbor.parent
	end
end

--
-- Connect / Resolve
--

local ConnectAlg = dfs.NewAlgorithm()

local ConnectionGen = 0

local ToResolve = {}

local function DoConnect (graph, box, adj_iter)
	ToResolve[box] = ConnectionGen

	ConnectAlg:VisitAdjacentVertices_Once(DoConnect, graph, box, adj_iter)
end

local function MakeResolve (func)
	return function(parent, rtype)
		node_state.SetResolvedType(parent, rtype)

		for i = 1, parent.numChildren do
			func(parent[i], rtype)
		end
	end
end

--
-- Disconnect / Decay
--

local DisconnectAlg = dfs.NewAlgorithm()

local DecayCandidates = { n = 0 }

local NoHardNodes

local function DoDisconnect (graph, box, adj_iter)
	if NoHardNodes then
		local n = DecayCandidates.n + 1

		DecayCandidates[n], DecayCandidates.n = box, n

		DisconnectAlg:VisitAdjacentVertices_Once(DoDisconnect, graph, box, adj_iter)
	end
end

local function CanReachHardNode ()
	NoHardNodes = false
end

local ToDecay = {}

local function ExploreDisconnectedNode (node, opts)
	DecayCandidates.n, NoHardNodes = 0, true

	DisconnectAlg:VisitRoot(DoDisconnect, node.parent, opts)

	for i = 1, NoHardNodes and DecayCandidates.n or 0 do
		ToDecay[DecayCandidates[i]] = ConnectionGen
	end

	for i = 1, DecayCandidates.n do
		DecayCandidates[i] = false
	end
end

local function MakeDecay (func)
	return function(parent)
		for i = 1, parent.numChildren do
			func(parent[i])
		end

		node_state.SetResolvedType(parent, nil)
	end
end

--
-- Cycle check
--

local CycleCheckOpts = {}

local FromBox, FromSide, CycleFormed

local function GatherCycle (neighbor, _, adjacency_stack)
	if neighbor.parent == FromBox then
		CycleFormed = true
	elseif node_runner.GetSide(neighbor) == FromSide then
		adjacency_stack[#adjacency_stack + 1] = neighbor.parent
	end
end

local CycleCheckAlg = dfs.NewAlgorithm()

local function DoCycleCheck (graph, box, adj_iter)
	if not CycleFormed then
		CycleCheckAlg:VisitAdjacentVertices_Once(DoCycleCheck, graph, box, adj_iter)
	end
end

local function FormsCycle (from, to)
	FromBox, FromSide, CycleFormed = from.parent, node_runner.GetSide(from)

	CycleCheckAlg:VisitRoot(DoCycleCheck, to.parent, CycleCheckOpts)

	FromBox = nil

	return CycleFormed
end

--
-- Program building
--

local PendingValues = {}

local function GatherRHS (neighbor, parent_node, adjacency_stack)
	if node_runner.GetSide(neighbor) == "rhs" then -- or equivalently, parent node on lhs
		local box = neighbor.parent

		PendingValues[#PendingValues + 1] = box
		PendingValues[#PendingValues + 1] = parent_node

		adjacency_stack[#adjacency_stack + 1] = box
	end
end

local BuildOpts = {}

local SortedBoxes = {}

local BuildAlg = dfs.NewAlgorithm{
	after_visit = function(box)
		SortedBoxes[#SortedBoxes + 1] = box
	end
}

local function DoBuild (graph, box, adj_iter)
	code_gen.ResetValues(box)

	BuildAlg:VisitAdjacentVertices_Once(DoBuild, graph, box, adj_iter)
end

local BuildGen

local IsBuildDirty

local LastInLine

local Code = {}

local AddCode

local function AuxRebuild ()
	BuildGen, IsBuildDirty = (BuildGen or 0) + 1 -- by default, not even last-in-line has generation;
												-- it implicitly has generation "nil", like any other
												-- box, thus the first connection will dirty it

	BuildAlg:VisitRoot(DoBuild, LastInLine, BuildOpts)

	local pi, ni, cn = #PendingValues - 1, 1, 0

	for i = 1, #SortedBoxes do
		local box, decl = SortedBoxes[i]

		box.build_gen = BuildGen

		if PendingValues[pi] == box then
			local name = code_gen.GetExportedName(box)

			if not name then
				decl = "IntermediateResult_" .. ni
				name = decl
			end

			repeat
				local parent_node = PendingValues[pi + 1]

				code_gen.SetValue(parent_node.parent, code_gen.GetValueName(parent_node), name)

				pi, PendingValues[pi], PendingValues[pi + 1] = pi - 2
			until PendingValues[pi] ~= box

			ni = ni + 1
		end

		local code = code_gen.Generate(box, node_state.ResolvedTypeOfParent(box), decl)

		if code then
			Code[cn + 1], cn = code, cn + 1
		end

		SortedBoxes[i] = nil
	end

	for i = #Code, cn + 1, -1 do
		Code[i] = nil
	end

	local result = concat(Code, ";\n")

	AddCode(result)
end

local function Rebuild (how)
	if IsBuildDirty then
		if how == "no_defer" then
			AuxRebuild()
		else
			timer.performWithDelay(0, AuxRebuild) -- in connect or disconnect, so graph still taking shape
		end
	end
end

--
-- Runner logic
--

local function ApplyChanges (resize, list, func, arg)
	for box, gen in pairs(list) do
		if gen == ConnectionGen then
			func(box, arg)
            resize(box)
		end

        list[box] = nil
	end
end

local function CanConnect (a, b)
    local compatible = node_state.WilcardOrHardType(a) == node_state.WilcardOrHardType(b) -- e.g. restrict to vectors, matrices, etc.
    local how1, what1 = node_state.QueryRule(a, b, compatible)
    local how2, what2 = node_state.QueryRule(b, a, compatible)

    if how1 and how2 and not FormsCycle(a, b) then
        if how1 == "resolve" then
            a.resolve = what1
        elseif how2 == "resolve" then
            b.resolve = what2
        end

        return true
    end
end

local function EnumerateDecayCandidates (a, b)
    local ctype, x, y = node_state.Classify(a, b)

    if ctype == "neither_hard" and node_state.ResolvedType(a) then -- if a is resolved, so is b
        return 2, a, b
    else
        return ctype == "hard" and 1 or 0, x, y
    end
end

local function FindNodeToResolve (a, b)
    local ctype, x, y = node_state.Classify(a, b)

    if ctype == "hard" and not node_state.ResolvedType(y) then
        return y, node_state.HardType(x)
    elseif ctype == "neither_hard" then
        local atype, btype = node_state.ResolvedType(a), node_state.ResolvedType(b)

        if atype and not btype then
            return b, atype
        elseif btype and not atype then
            return a, btype
        end
    end
end

local IsDeferred

--- DOCME
function M.DeferDecays ()
	IsDeferred = true
end

--
--
--

--- DOCME
function M.MakeRunnerFuncs (ops)
	local resize, decay, resolve = ops.resize, MakeDecay(ops.decay_item), MakeResolve(ops.resolve_item)

	local function DoDecays (how)
		ApplyChanges(resize, ToDecay, decay)

		ConnectionGen = ConnectionGen + 1

		if how == "rebuild" then
			Rebuild("no_defer")
		end
	end

	local layout = ops.layout
	local visit_opts = { adjacency_iter = MakeAdjacencyIterator(GatherResolvableBoxes, layout) }

	-- TODO? not reusable...
	CycleCheckOpts.adjacency_iter = MakeAdjacencyIterator(GatherCycle, layout)
	BuildOpts.adjacency_iter = MakeAdjacencyIterator(GatherRHS, layout)
	-- /TODO?

	return CanConnect, function(how, a, b)
		local aparent, bparent = a.parent, b.parent

		if aparent.build_gen == BuildGen or bparent.build_gen == BuildGen then -- potentially affects code?
			IsBuildDirty = true
		end

		if how == "connect" then -- n.b. display object does NOT exist yet...
			IsDeferred = true -- defer any decays introduced by the next two calls

			layout:BreakConnections(a)
			layout:BreakConnections(b)

			aparent.bound, bparent.bound = aparent.bound + a.bound_bit, bparent.bound + b.bound_bit

			local rnode, rtype = FindNodeToResolve(a, b)

			if rnode then
				OnFoundHard = error -- any hard nodes along the way violate the node's unresolved state

				ConnectAlg:VisitRoot(DoConnect, rnode.parent, visit_opts)
			end

			local adgen, bdgen = ToDecay[aparent], ToDecay[bparent]

			if adgen == ConnectionGen and adgen == ToResolve[bparent] then
				ToResolve[bparent] = nil
			elseif bdgen == ConnectionGen and bdgen == ToResolve[aparent] then
				ToResolve[aparent] = nil
			end
			--[=[
			for index, gen in pairs(ToDecay) do -- breaking old connections can put boxes in the to-decay list, but
												-- the new connection might put them in the to-resolve list; these
												-- boxes are already resolved, so remove them from both lists
				if gen == ConnectionGen and ToResolve[index] == gen then
--print("MIRBLE")
					ToDecay[index], ToResolve[index] = nil
				end
			end
			]=]
-- seems to be missing that it's decaying, but the other thing WILL be resolved?
			ApplyChanges(resize, ToDecay, decay)

			if rtype then
				ApplyChanges(resize, ToResolve, resolve, rtype)
			end

			Rebuild()
--DUMP_INFO("connect")
			ConnectionGen, IsDeferred = ConnectionGen + 1
		elseif how == "disconnect" then -- ...but here it usually does, cf. note in FadeAndDie()
			aparent.bound, bparent.bound = aparent.bound - a.bound_bit, bparent.bound - b.bound_bit

			local ncandidates, x, y = EnumerateDecayCandidates(a, b)

			OnFoundHard = CanReachHardNode -- we throw away decay candidates if any node has a hard connection

			if ncandidates == 2 then -- not a hard connection, so either node is a candidate...
				ExploreDisconnectedNode(x, visit_opts)
			end

			if ncandidates >= 1 then -- ...whereas in a hard connection, only the non-hard one is
				ExploreDisconnectedNode(y, visit_opts)
			end
--DUMP_INFO("disconnect")
			if ncandidates > 0 and not IsDeferred then -- defer disconnections happening as a side effect of a connection or deletion
				DoDecays()
				Rebuild()
			end
		end
	end, DoDecays
end

--
--
--

--- DOCME
function M.PutLastInLine (box)
	LastInLine = box
end

--
--
--

--- DOCME
function M.RemoveFromDecayList (box)
	ToDecay[box] = nil
end

--
--
--

--- DOCME
function M.ResumeDecays ()
	IsDeferred = false
end

--
--
--

--[=[
function DUMP_INFO (why)
	local stage = display.getCurrentStage()
	local Connected={}
	local node_runner = require("corona_ui.patterns.node_runner")
	print("DUMP", why)
	for i = 1, stage.numChildren do
		local p = stage[i]
		if p.numChildren and p.numChildren >= 2 and p[2].text then
			print("ELEMENT:", p, p[2].text)

			local info = {}
			for k, v in pairs(p) do
if k ~= "_class" and k ~= "_proxy" and k ~= "back" then -- skip some unenlightening stuff
				info[#info + 1] = ("%s = %s"):format(tostring(k), tostring(v))
end
			end
			print("{ " .. table.concat(info, ", ") .. " }")

			for j = 3, p.numChildren do
				local _, n = node_runner.GetConnectedObjects(p[j], Connected)

				if n > 0 then
					print("NODE: ", p[j + 1].text, NODE_INFO(p[j]))

					for k = 1, n do
						print("CONNECTED TO: ", NODE_INFO(Connected[k]))
					end

					print("")
				end
			end

			print("")
		end
	end
end
--]=]

local SVH = 200

local scroll_view = widget.newScrollView{
	top = display.contentHeight - (SVH + 10), left = 10,
	width = 500, height = 200
}

local svb = scroll_view.contentBounds
local svr = display.newRect((svb.xMin + svb.xMax) / 2, (svb.yMin + svb.yMax) / 2, svb.xMax - svb.xMin, svb.yMax - svb.yMin)

svr:setFillColor(0, 0)
svr:setStrokeColor(1, 0, 0)

svr.strokeWidth = 3

local Text

function AddCode (code)
	display.remove(Text)

	Text = display.newText(code, 0, 0, svr.width - 10, svr.height - 10, native.systemFontBold, 16)

	Text:setFillColor(0, 0.5, 1)
	scroll_view:insert(Text)
	Text:translate(Text.width / 2 + 5, Text.height / 2 + 5)
end

return M