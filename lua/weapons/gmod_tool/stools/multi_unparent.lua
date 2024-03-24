TOOL.Category = "Constraints"
TOOL.Name = "Multi-Unparent"

local sTag = "mmm_tool_unparent"
local tUniqueToPlayer = {}

if CLIENT then
	language.Add("tool.multi_unparent.name","Multi-Unparent (Remastered)")
	language.Add("tool.multi_unparent.desc","Unparent multiple entities")
	language.Add("tool.multi_unparent.left","Primary: Add an entity to the selection")
	language.Add("tool.multi_unparent.right","Secondary: Unparent all selected entities")
	language.Add("tool.multi_unparent.reload","Reload: Clear selected entities")

	MMM__TOOL__PARENT__UNPARENT__INIT = function() -- We have to do something really stupid here because of how tools function..
		tUniqueToPlayer[LocalPlayer()] = {
			SelectedEntities = {},
			SelectedCount = 0,
			OldEntityColors = {}
		}
	end
end

TOOL.Information = {
	{
		name = "left"
	},
	{
		name = "right"
	},
	{
		name = "reload"
	}
}

function TOOL:Deploy() -- Sometimes is called on client, sometimes is not. To fix this unreliable mess we simply do some hacky stuff!
	local owner = self:GetOwner()

	tUniqueToPlayer[owner] = {
		SelectedEntities = {},
		SelectedCount = 0,
		OldEntityColors = {}
	}

	if SERVER then
		owner:SendLua("MMM__TOOL__PARENT__UNPARENT__INIT()") -- Yes. Really.
	end
end

function TOOL:Holster()
	self:Reload()

	return true
end

function TOOL:LeftClick(trace)
	local ent = trace.Entity
	if not IsValid(ent) or ent:IsPlayer() or ent:IsWorld() then return false end

	if CLIENT then
		local owner = self:GetOwner()

		net.Start(sTag)
			net.WriteEntity(owner:GetEyeTrace().Entity)
		net.SendToServer()

		if not tUniqueToPlayer[owner].SelectedEntities[ent] then
			tUniqueToPlayer[self:GetOwner()].SelectedEntities[ent] = true
		else
			tUniqueToPlayer[self:GetOwner()].SelectedEntities[ent] = nil
		end

		return true
	end

	return true
end

function TOOL:RightClick(tTrace)
	if CLIENT then return true end

	local owner = self:GetOwner()

	if tUniqueToPlayer[owner].SelectedCount <= 0 then return false end

	local count = 0

	for ent in pairs(tUniqueToPlayer[owner].SelectedEntities) do -- Unparent!
		if not IsValid(ent) then continue end

		ent:SetParent()

		count = count + 1
	end

	self:Reload()

	if count ~= 1 then
		owner:PrintMessage(HUD_PRINTTALK,"Multi-Parent: " .. count .. " entities were unparented.")
	else
		owner:PrintMessage(HUD_PRINTTALK,"Multi-Parent: One entity was unparented.")
	end

	return true
end

function TOOL:Reload()
	if CLIENT then return true end

	local owner = self:GetOwner()

	if tUniqueToPlayer[owner].SelectedCount <= 0 then return end

	for Key in pairs(tUniqueToPlayer[owner].SelectedEntities) do
		if not IsValid(Key) then continue end

		Key:SetColor(tUniqueToPlayer[owner].OldEntityColors[Key])
	end

	tUniqueToPlayer[owner].SelectedCount = 0
	tUniqueToPlayer[owner].SelectedEntities = {}
	tUniqueToPlayer[owner].OldEntityColors = {}

	return true
end

if SERVER then
	util.AddNetworkString(sTag)

	local t_MetaEntity = FindMetaTable("Entity")

	local f_GetOwner = function(ent)
		if t_MetaEntity.CPPIGetOwner then -- CPPI - ( FPP / SPP / MMM / sv_props / gProctect (lul) / And many more that I'm not going to list. IT'S THE STANDARD FFS. )
			return ent:CPPIGetOwner()
		end

		return ent:GetOwner() -- Used by some other things such as wiremod, HL2 related stuff, etc.. Not very reliable but w/e
	end

	net.Receive(sTag, function(_,ePly)
		local ent = net.ReadEntity()

		if not IsValid(ent) or ent:IsPlayer() or ent:IsWorld() or not f_GetOwner(ent) then return end -- Never trust the client, yo! ( AND This bypasses protection checks! )

		if tUniqueToPlayer[ePly].SelectedEntities[ent] then -- Deselect
			if not tUniqueToPlayer[ePly].SelectedEntities[ent] then return end

			ent:SetColor(tUniqueToPlayer[ePly].OldEntityColors[ent])

			tUniqueToPlayer[ePly].SelectedCount = tUniqueToPlayer[ePly].SelectedCount - 1

			tUniqueToPlayer[ePly].OldEntityColors[ent] = nil
			tUniqueToPlayer[ePly].SelectedEntities[ent] = nil

			return
		end

		tUniqueToPlayer[ePly].SelectedEntities[ent] = true

		tUniqueToPlayer[ePly].SelectedCount = tUniqueToPlayer[ePly].SelectedCount + 1

		local cOldColor = ent:GetColor()

		tUniqueToPlayer[ePly].OldEntityColors[ent] = cOldColor

		ent:SetColor(Color(255,0,0,100))
		ent:SetRenderMode(RENDERMODE_TRANSALPHA)
	end)
end