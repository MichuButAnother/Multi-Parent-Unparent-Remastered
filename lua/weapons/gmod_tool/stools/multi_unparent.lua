TOOL.Category = "Constraints"
TOOL.Name = "Multi-Unparent"

if CLIENT then
	language.Add("tool.multi_unparent.name","Multi-Unparent (Remastered)")
	language.Add("tool.multi_unparent.desc","Unparent multiple entities")
	language.Add("tool.multi_unparent.left","Primary: Add an entity to the selection")
	language.Add("tool.multi_unparent.right","Secondary: Unparent all selected entities")
	language.Add("tool.multi_unparent.reload","Reload: Clear selected entities")
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

TOOL.SelectedEntities = {}
TOOL.SelectedCount = 0
TOOL.OldEntityColors = {}

local entMeta = FindMetaTable("Entity")

-- Unused, just ported it if I need to use it later
local getOwner = function(ent)
	if entMeta.CPPIGetOwner then return ent:CPPIGetOwner() end

	return ent:GetOwner()
end

-- Also unused, maybe will be used
local selection_blacklist = {
	["player"] = true,
	["predicted_viewmodel"] = true, -- Some of these may not be needed, whatever. (idk what does this mean but whatever, i'll just let it sit here)
	["gmod_tool"] = true,
	["none"] = true
}

function TOOL:SelectEntity(ent)
	if self.SelectedEntities[ent] then return end

	self.SelectedEntities[ent] = true

	self.SelectedCount = self.SelectedCount + 1

	local cOldColor = ent:GetColor()

	self.OldEntityColors[ent] = cOldColor

	ent:SetColor(Color(255,0,0,100))
	ent:SetRenderMode(RENDERMODE_TRANSALPHA)
end

function TOOL:DeselectEntity(ent)
	if not self.SelectedEntities[ent] then return end

	ent:SetColor(self.OldEntityColors[ent])

	self.SelectedCount = self.SelectedCount - 1

	self.OldEntityColors[ent] = nil
	self.SelectedEntities[ent] = nil
end

function TOOL:LeftClick(trace)
	if CLIENT then return true end
	local ent = trace.Entity

	if not IsValid(ent) or ent:IsPlayer() or ent:IsWorld() or not util.IsValidPhysicsObject(ent, trace.PhysicsBone) then return false end

	if self.SelectedEntities[ent] then
		self:DeselectEntity(ent)
	else
		self:SelectEntity(ent)
	end

	return true
end

function TOOL:RightClick(trace)
	if CLIENT then return true end
	local owner = self:GetOwner()

	if self.SelectedCount <= 0 then return false end

	local count = 0

	for ent2 in pairs(self.SelectedEntities) do -- Unparent!
		if not IsValid(ent2) then continue end

		ent2:SetParent()
		self:DeselectEntity(ent2)

		count = count + 1
	end

	if count ~= 1 then
		owner:PrintMessage(HUD_PRINTTALK,"Multi-Parent: " .. count .. " entities were unparented.")
	else
		owner:PrintMessage(HUD_PRINTTALK,"Multi-Parent: One entity was unparented.")
	end

	self.SelectedEntities = {}
	self.OldEntityColors = {}

	return true
end

function TOOL:Reload()
	if CLIENT then return true end
	if self.SelectedCount <= 0 then return end

	for ent in pairs(self.SelectedEntities) do
		if not IsValid(ent) then continue end

		ent:SetColor(self.OldEntityColors[Key])
	end

	self.SelectedCount = 0
	self.SelectedEntities = {}
	self.OldEntityColors = {}

	return true
end

function TOOL:Think()
	for ent in pairs(self.SelectedEntities) do
		if not IsValid(ent) then self.SelectedEntities[ent] = nil end
	end

	for ent in pairs(self.OldEntityColors) do
		if not IsValid(ent) then self.OldEntityColors[ent] = nil end
	end
end