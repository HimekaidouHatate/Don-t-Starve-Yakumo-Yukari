local assets = {   
	Asset("ANIM", "anim/spell_none.zip"),    
	Asset("ATLAS", "images/inventoryimages/scheme.xml"),    
}

prefabs = {}

local function GetIngameName(prefab)
	return STRINGS.NAMES[string.upper(prefab)]
end

local function GetTable(owner)
	--local difficulty = _G.YUKARI_DIFFICULTY
	local HatLevel = owner.components.upgrader.HatLevel
	local GAMEMODE = SaveGameIndex:IsModePorkland() and "PL" or SaveGameIndex:IsModeShipwrecked() and "SW" or SaveGameIndex:ROGEnabledOnSlot() and "ROG" or "Vanilla"

	return HatLevel < 5 and require("recipes_yukari").SCHEME[GAMEMODE][HatLevel] or {}
end

local function CountInventoryItem(owner, item)
	local inventory = owner.components.inventory
	local count = 0

	local function countitem(item, count)
		if item.components.stackable ~= nil then
			count = count + item.components.stackable.stacksize
		else 
			count = count + 1
		end
		return count
	end
	
	for k,v in pairs(inventory.itemslots) do
		if v.prefab == item then
			count = countitem(v, count)
		end
	end
	
	for k,v in pairs(inventory.equipslots) do
		if type(v) == "table" and v.components.container then
			for k, v2 in pairs(v.components.container.slots) do
				if v2.prefab == item then
					count = countitem(v2, count)
				end
			end
		end
	end
	
	return count
end

local function GetStr(owner)
	local list = GetTable(owner)
	local text = ""

	if owner.components.upgrader.HatLevel < 5 then
		for i = 1, #list, 1 do
			text = text.."\n"..GetIngameName(list[i][1]).." - "..CountInventoryItem(owner, list[i][1]).." / "..list[i][2]
		end
	else
		text = "\n"..STRINGS.YUKARI_UPGRADE_FINISHED
	end
	
	return text
end

local function GetCanpell(owner)
	local list = GetTable(owner)
	local condition = true

	if owner.components.upgrader.HatLevel < 5 then 
		for i = 1, #list, 1 do 
			condition = condition and ( CountInventoryItem(owner, list[i][1]) >= list[i][2] )
		end
	else
		condition = false
	end
	
	return condition
end

local function SetCanspell(inst, data)
	local owner = data.owner or data
	local var = GetCanpell(owner)
	inst.components.spellcard:SetCondition(var)
	inst.canspell = var
end

local function GetDesc(inst, viewer)
	if viewer:HasTag("yakumoyukari") then
		local var = GetCanpell(viewer)
		SetCanspell(inst, viewer)
		return string.format( STRINGS.YUKARI_CURRENT_LEVEL.." - "..viewer.components.upgrader.HatLevel..GetStr(viewer)..(var and "\nI can spell." or "") )
	end

	return ""
end

local function DoUpgrade(inst, owner)
	local inventory = owner.components.inventory
	local list = GetTable(owner)

	if not GetCanpell(owner) then
		inst.components.spellcard:SetCondition(false)
		inst.canspell:set(false)
		owner.components.talker:Say(GetString(owner.prefab, "DESCRIBE_INGREDIENTS"))
		return false
	end
	
	local function remove(item, left_count)
		if left_count > 0 then
			if item.components.stackable then
				if item.components.stackable.stacksize >= left_count then
					item.components.stackable:Get(left_count):Remove()
					return 0
				else 
					left_count = left_count - item.components.stackable.stacksize
					item:Remove()
				end
			else 
				left_count = left_count - 1
				item:Remove()
			end
		end
		return left_count
	end

	for i = 1, #list, 1 do -- I won't use RemoveItem function in inventory components because it doesn't get items in custom backpack slot. 
		local left_count = list[i][2]

		while left_count > 0 do
			for k,v in pairs(inventory.itemslots) do
				if v.prefab == list[i][1] then
					left_count = remove(v, left_count)
				end
			end
			
			for k,v in pairs(inventory.equipslots) do
				if type(v) == "table" and v.components.container then
					for k, v2 in pairs(v.components.container.slots) do
						if v2.prefab == list[i][1] then
							left_count = remove(v2, left_count)
						end
					end
				end
			end
		end
	end

	owner.components.upgrader.HatLevel = owner.components.upgrader.HatLevel + 1
	owner.components.talker:Say(GetString(owner.prefab, "DESCRIBE_HATUPGRADE"))
end

local function OnFinish(inst, owner)
	inst.canspell = false
	inst.components.spellcard:SetCondition(false)
	owner.components.upgrader:ApplyHatAbility(owner:GetYukariHat())
	owner.components.upgrader:ApplyStatus()
end

local function fn()  
	local inst = CreateEntity() 
	
	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddMiniMapEntity()

    inst.MiniMapEntity:SetIcon("scheme.tex")

	MakeInventoryPhysics(inst)
	if _G.DLC_ENABLED_FLAG % 4 >= 2 then    
		MakeInventoryFloatable(inst, "idle", "idle")
	end	

	inst.AnimState:SetBank("spell_none")    
	inst.AnimState:SetBuild("spell_none")    
	inst.AnimState:PlayAnimation("idle")    

	inst:AddTag("scheme")
	inst.canspell = false

	inst:AddComponent("inspectable")    
	inst.components.inspectable.description = GetDesc
	
	inst:AddComponent("inventoryitem")   
	inst.components.inventoryitem.atlasname = "images/inventoryimages/scheme.xml" 
	
	inst:AddComponent("spellcard")
	inst.components.spellcard.name = "scheme"
	inst.components.spellcard:SetSpellFn( DoUpgrade )
	inst.components.spellcard:SetOnFinish( OnFinish )
	inst.components.spellcard:SetCondition( false )
	
	return inst
end

return Prefab("common/inventory/scheme", fn, assets)