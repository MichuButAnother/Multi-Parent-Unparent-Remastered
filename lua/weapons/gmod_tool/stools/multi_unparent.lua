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
	local eOwner = self:GetOwner()

	tUniqueToPlayer[eOwner] = {
		SelectedEntities = {},
		SelectedCount = 0,
		OldEntityColors = {}
	}


	if SERVER then
		eOwner:SendLua("MMM__TOOL__PARENT__UNPARENT__INIT()") -- Yes. Really.
	end
end

function TOOL:Holster()
	self:Reload() -- Reset!

	return true
end


function TOOL:LeftClick(tTrace)
	if not IsValid(tTrace.Entity) or tTrace.Entity:IsPlayer() or tTrace.Entity:IsWorld() then return false end


	if CLIENT then
		local eOwner = self:GetOwner()


		net.Start(sTag)
			net.WriteEntity(eOwner:GetEyeTrace().Entity)
		net.SendToServer()


		if not tUniqueToPlayer[eOwner].SelectedEntities[tTrace.Entity] then
			tUniqueToPlayer[self:GetOwner()].SelectedEntities[tTrace.Entity] = true
		else
			tUniqueToPlayer[self:GetOwner()].SelectedEntities[tTrace.Entity] = nil
		end


		return true
	end


	return true
end


function TOOL:RightClick(tTrace)
	if CLIENT then return true end


	local eOwner = self:GetOwner()

	if tUniqueToPlayer[eOwner].SelectedCount <= 0 then return false end


	--[[ -- We don't do this for now as this could potentially break a lot of stuff and be used as an exploit!
	for Key in pairs(tUniqueToPlayer[eOwner].SelectedEntities) do -- Add Children to the selected entity table
		if not IsValid(Key) then goto cont end


		for _,v in ipairs(Key:GetChildren()) do
			tUniqueToPlayer[eOwner].SelectedEntities[v] = true
		end


		::cont::
	end
	]]


	local iCount = 0

	for Key in pairs(tUniqueToPlayer[eOwner].SelectedEntities) do -- Unparent!
		if not IsValid(Key) then goto cont end


		Key:SetParent()

		iCount = iCount + 1


		::cont::
	end


	self:Reload() -- Lazy reset


	if iCount ~= 1 then
		eOwner:PrintMessage(HUD_PRINTTALK,"Multi-Parent: " .. iCount .. " entities were unparented.")
	else
		eOwner:PrintMessage(HUD_PRINTTALK,"Multi-Parent: One entity was unparented.")
	end


	return true
end


function TOOL:Reload()
	if CLIENT then return true end


	local eOwner = self:GetOwner()

	if tUniqueToPlayer[eOwner].SelectedCount <= 0 then return end

	for Key in pairs(tUniqueToPlayer[eOwner].SelectedEntities) do
		if not IsValid(Key) then goto cont end


		Key:SetColor(tUniqueToPlayer[eOwner].OldEntityColors[Key])


		::cont::
	end


	tUniqueToPlayer[eOwner].SelectedCount = 0
	tUniqueToPlayer[eOwner].SelectedEntities = {}
	tUniqueToPlayer[eOwner].OldEntityColors = {}

	return true
end


-- ----- ----- ----- ----- ----- ----- ----- ----- ----- --

if CLIENT then return end


local t_MetaEntity = FindMetaTable("Entity")

local f_GetOwner = function(eEnt)
	if t_MetaEntity.CPPIGetOwner then -- CPPI - ( FPP / SPP / MMM / sv_props / gProctect (lul) / And many more that I'm not going to list. IT'S THE STANDARD FFS. )
		return eEnt:CPPIGetOwner()
	end

	return eEnt:GetOwner() -- Used by some other things such as wiremod, HL2 related stuff, etc.. Not very reliable but w/e
end


util.AddNetworkString(sTag)

net.Receive(sTag,function(_,ePly)
	local eEnt = net.ReadEntity()

	if not IsValid(eEnt) or eEnt:IsPlayer() or eEnt:IsWorld() or not f_GetOwner(eEnt) then return end -- Never trust the client, yo! ( AND This bypasses protection checks! )

	if tUniqueToPlayer[ePly].SelectedEntities[eEnt] then -- Deselect
		if not tUniqueToPlayer[ePly].SelectedEntities[eEnt] then return end


		eEnt:SetColor(tUniqueToPlayer[ePly].OldEntityColors[eEnt])


		tUniqueToPlayer[ePly].SelectedCount = tUniqueToPlayer[ePly].SelectedCount - 1


		tUniqueToPlayer[ePly].OldEntityColors[eEnt] = nil
		tUniqueToPlayer[ePly].SelectedEntities[eEnt] = nil

		return
	end


	tUniqueToPlayer[ePly].SelectedEntities[eEnt] = true

	tUniqueToPlayer[ePly].SelectedCount = tUniqueToPlayer[ePly].SelectedCount + 1


	local cOldColor = eEnt:GetColor()

	tUniqueToPlayer[ePly].OldEntityColors[eEnt] = cOldColor

	eEnt:SetColor(Color(255,0,0,100))
	eEnt:SetRenderMode(RENDERMODE_TRANSALPHA)
end)


-- ----- ----- ----- ----- ----- ----- ----- ----- ----- --