-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIABLES
-----------------------------------------------------------------------------------------------------------------------------------------
local Attached = false

local modelosPermitidos = {
    ["dlbrickadels"] = true,
    ["dlbrickade"] = true,
    ["flatbed"] = true
}
-----------------------------------------------------------------------------------------------------------------------------------------
-- INVENTORY:TOW
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("inventory:Tow")
AddEventHandler("inventory:Tow",function(Selected)
	local Ped = PlayerPedId()
	local Selected = Selected[3]
	local Vehicle = GetLastDrivenVehicle()
	if DoesEntityExist(Selected) and DoesEntityExist(Vehicle) and not Entity(Selected)["state"]["Tower"] and modelosPermitidos[GetEntityArchetypeName(Vehicle)] and not IsPedInAnyVehicle(Ped) then
		local Coords = GetEntityCoords(Selected)
		local OtherCoords = GetEntityCoords(Vehicle)

		if #(Coords - OtherCoords) <= 15 then
			if Entity(Selected)["state"]["Tow"] then
				TriggerServerEvent("inventory:Tow",VehToNet(Vehicle),VehToNet(Selected),false)
			else
				LocalPlayer["state"]["Cancel"] = true
				LocalPlayer["state"]["Commands"] = true

				TaskTurnPedToFaceEntity(Ped,Tower,5000)
				TriggerEvent("sounds:Private","tow",0.5)
				vRP.playAnim(false,{"mini@repair","fixing_a_player"},true)

				SetTimeout(5000,function()
					vRP.Destroy()

					LocalPlayer["state"]["Cancel"] = false
					LocalPlayer["state"]["Commands"] = false
					Entity(Vehicle)["state"]:set("Tow",true,true)
					Entity(Selected)["state"]:set("Tow",true,true)

					TriggerServerEvent("inventory:Tow",VehToNet(Vehicle),VehToNet(Selected),true)
				end)
			end
		else
			TriggerEvent("Notify","Aviso","O reboque precisa estar próximo do veículo.","amarelo",5000)
		end
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- INVENTORY:CLIENTTOW
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("inventory:ClientTow")
AddEventHandler("inventory:ClientTow",function(Vehicle,Selected,Mode)
	if NetworkDoesNetworkIdExist(Vehicle) and NetworkDoesNetworkIdExist(Selected) then
		local Vehicle = NetToEnt(Vehicle)
		local Selected = NetToEnt(Selected)
		local modeloFlatbed = GetEntityModel(Vehicle) == GetHashKey("flatbed")
		if DoesEntityExist(Vehicle) and DoesEntityExist(Selected) then
			if Mode then
				local Model = GetEntityModel(Selected)
				local Dimensions = GetModelDimensions(Model)
				
                if modeloFlatbed then
					AttachEntityToEntity(Selected,Vehicle,GetEntityBoneIndexByName(Vehicle,"bodyshell"),0,-2.0,0.3 - Dimensions["z"],0,0,0,true,true,true,true,2,true)
				else
				    AttachEntityToEntity(Selected,Vehicle,GetEntityBoneIndexByName(Vehicle,"misc_a"),0,0.0,0.1 - Dimensions["z"],0,0,0,true,true,true,true,2,true)	
				end
			else
				DetachEntity(Selected,false,false)

				-- Posição atrás da rampa (atrás do bone 'misc_a')
				local boneIndex1 = GetEntityBoneIndexByName(Vehicle, "bodyshell" )
				local boneIndex2 = GetEntityBoneIndexByName(Vehicle, "misc_a" )
				local bonePos1 = GetWorldPositionOfEntityBone(Vehicle, boneIndex1)
				local bonePos2 = GetWorldPositionOfEntityBone(Vehicle, boneIndex2)
				local heading = GetEntityHeading(Vehicle)
				-- Ajuste a distância para trás conforme necessário (ex: -4.0)
				local offset1 = -10.0
				local offset2 = -7.0
				local rad = math.rad(heading)
				local x1 = bonePos1.x - math.sin(rad) * offset1
				local y1 = bonePos1.y + math.cos(rad) * offset1
				local z1 = bonePos1.z
				local x2 = bonePos2.x - math.sin(rad) * offset2
				local y2 = bonePos2.y + math.cos(rad) * offset2
				local z2 = bonePos2.z

				if modeloFlatbed then
					SetEntityCoords(Selected, x1, y1, z1, false, false, false, false)
					SetEntityHeading(Selected, heading)
					SetVehicleOnGroundProperly(Selected)
				else
					SetEntityCoords(Selected, x2, y2, z2, false, false, false, false)
					SetEntityHeading(Selected, heading)
					SetVehicleOnGroundProperly(Selected)
                end

				if Entity(Vehicle)["state"]["Tow"] then
					Entity(Vehicle)["state"]:set("Tow",nil,true)
				end

				if Entity(Selected)["state"]["Tow"] then
					Entity(Selected)["state"]:set("Tow",nil,true)
				end
			end
		end
	end
end)
