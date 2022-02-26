TOOL.Category = "Constraints"
TOOL.Name = "Multi-Parent"

if CLIENT then
	language.Add("tool.multi_parent.name","Multi-Parent (Remastered)")
	language.Add("tool.multi_parent.desc","Parent multiple entities to one entity")
	language.Add("tool.multi_parent.left","Primary: Add an entity to the selection")
	language.Add("tool.multi_parent.right","Secondary: Parent all selected entities to the entity")
	language.Add("tool.multi_parent.reload","Reload: Clear selected entities")

	language.Add("tool.multi_parent.left_use","Primary + Use: Select entities in an area")
	language.Add("tool.multi_parent.left1","Primary + Sprint: Select all entities connected to the entity (the whole contraption)")

	language.Add("tool.multi_parent.undo","Undone Multi-Parent")
end

TOOL.Information = {
	{
		name = "left"
	},
	{
		name = "left_use"
	},
	{
		name = "left1",
		icon2 = "gui/noicon.png"
	},
	{
		name = "right"
	},
	{
		name = "reload"
	}
}


TOOL.ClientConVar["removeconstraints"] = "0"
TOOL.ClientConVar["nocollide"] = "0"
TOOL.ClientConVar["disablecollisions"] = "0"
TOOL.ClientConVar["weld"] = "0"
TOOL.ClientConVar["weight"] = "0"
TOOL.ClientConVar["radius"] = "512"
TOOL.ClientConVar["disableshadow"] = "0"

TOOL.SelectedEntities = {}
TOOL.SelectedCount = 0
TOOL.OldEntityColors = {}


local t_MetaEntity = FindMetaTable("Entity")

local f_GetOwner = function(eEnt)
	if t_MetaEntity.CPPIGetOwner then -- CPPI - ( FPP / SPP / MMM / sv_props / gProctect (lul) / And many more that I'm not going to list. IT'S THE STANDARD FFS. )
		return eEnt:CPPIGetOwner()
	end

	return eEnt:GetOwner() -- Used by some other things such as wiremod, HL2 related stuff, etc.. Not very reliable but w/e
end


local tBlacklist = { -- Blacklist of classes that cannot be parented (You can parent to these but they cannot be a child)
	["player"] = true,
	["prop_vehicle_jeep"] = true,
	["prop_vehicle_airboat"] = true,
	["prop_vehicle_jeep_old"] = true
}

local tBlacklistNever = { -- Blacklist of classes that cannot be parented or receive children
	["prop_vehicle_jeep"] = true,
	["prop_vehicle_airboat"] = true,
	["prop_vehicle_jeep_old"] = true
}

local tBlacklistCrashFix = { -- Blacklist of classes that cannot be parented together
	["prop_vehicle_jeep"] = true,
	["prop_vehicle_airboat"] = true,
	["prop_vehicle_jeep_old"] = true
}

local tBlacklistSelection = { -- Classes to filter with the auto selection
	["player"] = true,
	["prop_vehicle_jeep"] = true,
	["prop_vehicle_airboat"] = true,
	["prop_vehicle_jeep_old"] = true,
	["predicted_viewmodel"] = true, -- Some of these may not be needed, whatever.
	["gmod_tool"] = true,
	["none"] = true
}


function TOOL:SelectEntity(eEnt)
	if self.SelectedEntities[eEnt] then return end

	self.SelectedEntities[eEnt] = true


	self.SelectedCount = self.SelectedCount + 1


	local cOldColor = eEnt:GetColor()

	self.OldEntityColors[eEnt] = cOldColor

	eEnt:SetColor(Color(0,255,0,100))
	eEnt:SetRenderMode(RENDERMODE_TRANSALPHA)
end

function TOOL:DeselectEntity(eEnt)
	if not self.SelectedEntities[eEnt] then return end


	eEnt:SetColor(self.OldEntityColors[eEnt])


	self.SelectedCount = self.SelectedCount - 1


	self.OldEntityColors[eEnt] = nil
	self.SelectedEntities[eEnt] = nil
end


function TOOL:LeftClick(tTrace)
	if CLIENT then return true end

	if not IsValid(tTrace.Entity) or tTrace.Entity:IsPlayer() or not util.IsValidPhysicsObject(tTrace.Entity,tTrace.PhysicsBone) then return false end


	local ePly = self:GetOwner()

	if not ePly:KeyDown(IN_USE) and tTrace.Entity:IsWorld() then return false end


	if ePly:KeyDown(IN_USE) then
		local iRadius = math.Clamp(self:GetClientNumber("radius"),64,1024)
		local iSelected = 0


		local tFilter = {}

		for _,v in ipairs(ents.GetAll()) do -- Filter carried weapons and blacklisted classes
			if v:IsWeapon() and IsValid(v.Owner) or tBlacklistSelection[v:GetClass()] then
				tFilter[v] = true
			end
		end


		for _,v in ipairs(ents.FindInSphere(tTrace.HitPos,iRadius)) do
			if IsValid(v) and tFilter[v] then goto cont end


			if IsValid(v) and not self.SelectedEntities[v] and f_GetOwner(tTrace.Entity) == ePly then
				self:SelectEntity(v)

				iSelected = iSelected + 1
			end


			::cont::
		end


		if iSelected ~= 1 then
			ePly:PrintMessage(HUD_PRINTTALK,"Multi-Parent: " .. iSelected .. " entities were selected.")
		else
			ePly:PrintMessage(HUD_PRINTTALK,"Multi-Parent: One entity was selected.")
		end

	elseif ePly:KeyDown(IN_SPEED) then

		local iSelected = 0

		for _,v in pairs(constraint.GetAllConstrainedEntities(tTrace.Entity)) do
			self:SelectEntity(v)

			iSelected = iSelected + 1
		end


		if iSelected ~= 1 then
			ePly:PrintMessage(HUD_PRINTTALK,"Multi-Parent: " .. iSelected .. " entities were selected.")
		else
			ePly:PrintMessage(HUD_PRINTTALK,"Multi-Parent: One entity was selected.")
		end

	elseif self.SelectedEntities[tTrace.Entity] then

		self:DeselectEntity(tTrace.Entity)

	else

		self:SelectEntity(tTrace.Entity)
	end


	return true
end


function TOOL:RightClick(tTrace)
	if CLIENT then return true end

	self:DeselectEntity(tTrace.Entity) -- If the target entity was selected, deselect it before we do anything with it

	if self.SelectedCount <= 0 or not IsValid(tTrace.Entity) or tTrace.Entity:IsPlayer() or not util.IsValidPhysicsObject(tTrace.Entity,tTrace.PhysicsBone) or tTrace.Entity:IsWorld() then return false end


	for Key in pairs(self.SelectedEntities) do -- Add Children to the selected entity table
		if not IsValid(Key) then goto cont end


		for _,v in ipairs(Key:GetChildren()) do
			self.SelectedEntities[v] = true
		end


		::cont::
	end


	local tBlacklistCount = {}
	local eOwner = self:GetOwner()
	local sTraceClass = tTrace.Entity:GetClass()

	for Key in pairs(self.SelectedEntities) do -- These objects cannot be parented together! (Crash exploit fix)
		if not IsValid(Key) then goto cont end


		local sClass = Key:GetClass()


		if tBlacklistCrashFix[sClass] then
			tBlacklistCount[sClass] = (tBlacklistCount[sClass] and tBlacklistCount[sClass] + 1) or 1
		end


		if (tBlacklistCount[sClass] and tBlacklistCount[sClass] >= 1) and (tBlacklistCrashFix[sClass] and sTraceClass == sClass) then

			eOwner:PrintMessage(HUD_PRINTTALK,"Multi-Parent: You cannot parent these entities together! (To avoid crashes)")
			eOwner:EmitSound("buttons/button8.wav",65)

			return false
		end


		::cont::
	end


	for k,v in pairs(tBlacklistCount) do
		if v >= 2 then

			eOwner:PrintMessage(HUD_PRINTTALK,"Multi-Parent: To avoid crashes, you may not parent multiple of: \"" .. k .. "\" together!")
			eOwner:EmitSound("buttons/button8.wav",65)

			return false
		end
	end


	local bNoCollide = tobool(self:GetClientNumber("nocollide"))
	local bDisableCollisions = tobool(self:GetClientNumber("disablecollisions"))
	local bWeld = tobool(self:GetClientNumber("weld"))
	local bRemoveConstraints = tobool(self:GetClientNumber("removeconstraints"))
	local bWeight = tobool(self:GetClientNumber("weight"))
	local bDisableShadows = tobool(self:GetClientNumber("disableshadow"))

	local tUndo = {}


	undo.Create("Multi-Parent")


	for Key in pairs(self.SelectedEntities) do
		if IsValid(Key) and not tBlacklist[Key:GetClass()] and not Key:IsWorld() then
			local obj_Phys = Key:GetPhysicsObject()

			if IsValid(obj_Phys) then
				local tData = {}

				if bRemoveConstraints then
					constraint.RemoveAll(Key)
				end

				if bNoCollide then
					undo.AddEntity(constraint.NoCollide(Key,tTrace.Entity,0,0))
				end

				if bDisableCollisions then
					tData.CollisionGroup = Key:GetCollisionGroup()

					Key:SetCollisionGroup(COLLISION_GROUP_WORLD)
				end

				if bWeld then
					undo.AddEntity(constraint.Weld(Key,tTrace.Entity,0,0))
				end

				if bWeight then
					tData.Mass = obj_Phys:GetMass()

					obj_Phys:SetMass(0.1)

					duplicator.StoreEntityModifier(Key,"mass",{
						Mass = 0.1
					})
				end

				if bDisableShadows then
					tData.DisableShadow = true

					Key:DrawShadow(false)
				end

				obj_Phys:EnableMotion(true)
				obj_Phys:Sleep()

				Key:SetColor(v)
				Key:SetParent(tTrace.Entity)

				self.SelectedEntities[Key] = nil

				tUndo[Key] = tData
			end
		else
			if IsValid(Key) then
				Key:SetColor(self.OldEntityColors[Key])
			end

			self.SelectedEntities[Key] = nil
			self.OldEntityColors[Key] = nil
		end
	end

	undo.AddFunction(function(_,tUndo)
		for k,v in pairs(tUndo) do
			if IsValid(k) then
				local obj_Phys = k:GetPhysicsObject()

				if IsValid(obj_Phys) then
					obj_Phys:EnableMotion(false)

					k:SetParent(nil)
					k:SetColor(k:GetColor())
					k:SetMaterial(k:GetMaterial())
					k:SetAngles(k:GetAngles())
					k:SetPos(k:GetPos())

					if v.Mass then
						obj_Phys:SetMass(v.Mass)
					end

					if v.CollisionGroup then
						k:SetCollisionGroup(v.CollisionGroup)
					end

					if v.DisableShadow then
						k:DrawShadow(true)
					end
				end
			end
		end
	end,tUndo)

	undo.SetPlayer(self:GetOwner())
	undo.Finish()

	self.SelectedEntities = {}
	self.OldEntityColors = {}

	return true

end


function TOOL:Reload()
	if CLIENT then return true end
	if self.SelectedCount <= 0 then return end

	for Key in pairs(self.SelectedEntities) do
		if not IsValid(Key) then goto cont end


		Key:SetColor(self.OldEntityColors[Key])

		::cont::
	end


	self.SelectedCount = 0
	self.SelectedEntities = {}
	self.OldEntityColors = {}

	return true
end


function TOOL:Think() -- Cleanup tables
	for Key in pairs(self.SelectedEntities) do
		if not IsValid(Key) then
			self.SelectedEntities[Key] = nil
		end
	end

	for Key in pairs(self.OldEntityColors) do
		if not IsValid(Key) then
			self.OldEntityColors[Key] = nil
		end
	end
end


if CLIENT then
	function TOOL.BuildCPanel(obj_Panel)
		obj_Panel:AddControl("Slider",{
			Label = "Auto Select Radius:",
			Type = "integer",
			Min = "64",
			Max = "1024",
			Command = "multi_parent_radius"
		})

		obj_Panel:AddControl("Checkbox",{
			Label = "Remove all constraints before parenting",
			Command = "multi_parentbRemoveConstraints"
		})

		obj_Panel:AddControl("Checkbox",{
			Label = "No Collide",
			Command = "multi_parentbNoCollide"
		})

		obj_Panel:AddControl("Checkbox",{
			Label = "Weld",
			Command = "multi_parentbWeld"
		})

		obj_Panel:AddControl("Checkbox",{
			Label = "Disable Collisions",
			Command = "multi_parentbDisableCollisions"
		})

		obj_Panel:AddControl("Checkbox",{
			Label = "Set weight",
			Command = "multi_parentbWeight"
		})

		obj_Panel:AddControl("Checkbox",{
			Label = "Disable Shadows",
			Command = "multi_parentbDisableShadows"
		})
	end
end

if SERVER then
	local t_MetaEntity = FindMetaTable("Entity")

	t_MetaEntity.Old_MMM_SetParent = t_MetaEntity.Old_MMM_SetParent or t_MetaEntity.SetParent


	function t_MetaEntity:SetParent(eTarget)
		eTarget = eTarget or NULL


		local sOurClass = self:GetClass()
		local sTheirClass = IsValid(eTarget) and eTarget:GetClass() or ""

		if (tBlacklistCrashFix[sOurClass] and tBlacklistCrashFix[sTheirClass]) and sOurClass == sTheirClass then -- These two classes cannot be parented together!
			return
		end

		if (tBlacklistNever[sOurClass] or tBlacklistNever[sTheirClass]) then -- These classes may not be parented at all!
			return
		end


		self:Old_MMM_SetParent(eTarget)
	end
end