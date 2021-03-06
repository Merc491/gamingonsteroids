local Scriptname,Version,Author,LVersion = "TRUSt in my Ezreal","v1.5","TRUS","7.10"
if myHero.charName ~= "Ezreal" then return end
keybindings = { [ITEM_1] = HK_ITEM_1, [ITEM_2] = HK_ITEM_2, [ITEM_3] = HK_ITEM_3, [ITEM_4] = HK_ITEM_4, [ITEM_5] = HK_ITEM_5, [ITEM_6] = HK_ITEM_6}


function GetInventorySlotItem(itemID)
	assert(type(itemID) == "number", "GetInventorySlotItem: wrong argument types (<number> expected)")
	for _, j in pairs({ ITEM_1, ITEM_2, ITEM_3, ITEM_4, ITEM_5, ITEM_6}) do
		if myHero:GetItemData(j).itemID == itemID and myHero:GetSpellData(j).currentCd == 0 then return j end
	end
	return nil
end

function UseBotrk()
	local target = (_G.SDK and _G.SDK.TargetSelector:GetTarget(300, _G.SDK.DAMAGE_TYPE_PHYSICAL)) or (_G.GOS and _G.GOS:GetTarget(300,"AD"))
	if target then 
		local botrkitem = GetInventorySlotItem(3153) or GetInventorySlotItem(3144)
		if botrkitem then
			Control.CastSpell(keybindings[botrkitem],target.pos)
		end
	end
end

class "Ezreal"
require "DamageLib"
function Ezreal:__init()
	self:LoadSpells()
	self:LoadMenu()
	Callback.Add("Tick", function() self:Tick() end)
	
	local orbwalkername = ""
	if _G.SDK then
		orbwalkername = "IC'S orbwalker"	
	elseif _G.GOS then
		orbwalkername = "Noddy orbwalker"
	else
		orbwalkername = "Orbwalker not found"
	end
	PrintChat(Scriptname.." "..Version.." - Loaded...."..orbwalkername)
end

local lastpick = 0
--[[Spells]]
function Ezreal:LoadSpells()
	Q = {Range = 1190, width = nil, Delay = 0.25, Radius = 60, Speed = 2000, Collision = false, aoe = false, type = "linear"}
end

function Ezreal:LoadMenu()
	self.Menu = MenuElement({type = MENU, id = "TRUStinymyEzreal", name = Scriptname})
	self.Menu:MenuElement({id = "UseQ", name = "UseQ on champions", value = true})
	self.Menu:MenuElement({id = "UseQLH", name = "[WIP] UseQ to lasthit", value = true})
	self.Menu:MenuElement({id = "UseBOTRK", name = "Use botrk", value = true})
	self.Menu:MenuElement({id = "CustomSpellCast", name = "Use custom spellcast", tooltip = "Can fix some casting problems with wrong directions and so (thx Noddy for this one)", value = true})
	self.Menu:MenuElement({id = "delay", name = "Custom spellcast delay", value = 50, min = 0, max = 200, step = 5, identifier = ""})
	
	self.Menu:MenuElement({id = "blank", type = SPACE , name = ""})
	self.Menu:MenuElement({id = "blank", type = SPACE , name = "Script Ver: "..Version.. " - LoL Ver: "..LVersion.. ""})
	self.Menu:MenuElement({id = "blank", type = SPACE , name = "by "..Author.. ""})
end

function Ezreal:Tick()
	if myHero.dead or (not _G.SDK and not _G.GOS) then return end
	local combomodeactive = (_G.SDK and _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO]) or (not _G.SDK and _G.GOS and _G.GOS:GetMode() == "Combo") 
	local harassactive = (_G.SDK and _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS]) or (not _G.SDK and _G.GOS and _G.GOS:GetMode() == "Harass") 
	local farmactive = (_G.SDK and _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LASTHIT]) or (not _G.SDK and _G.GOS and _G.GOS:GetMode() == "Lasthit") 
	local laneclear = (_G.SDK and _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR]) or (not _G.SDK and _G.GOS and _G.GOS:GetMode() == "Clear") 
	local canmove = (_G.SDK and _G.SDK.Orbwalker:CanMove()) or (not _G.SDK and _G.GOS and _G.GOS:CanMove())
	local canattack = (_G.SDK and _G.SDK.Orbwalker:CanAttack()) or (not _G.SDK and _G.GOS and _G.GOS:CanAttack())
	local currenttarget = (_G.SDK and _G.SDK.Orbwalker:GetTarget()) or (not _G.SDK and _G.GOS and _G.GOS:GetTarget())
	if combomodeactive and self.Menu.UseBOTRK:Value() then
		UseBotrk()
	end
	if (combomodeactive or harassactive) and self:CanCast(_Q) and self.Menu.UseQ:Value() and canmove and (not canattack or not currenttarget) then
		self:CastQ()
	end
	
	if (farmactive or laneclear) and self.Menu.UseQLH:Value() then 
		self:QLastHit()
	end
	
	
end


local castSpell = {state = 0, tick = GetTickCount(), casting = GetTickCount() - 1000, mouse = mousePos}



function EnableMovement()
	--unblock movement
	if _G.SDK then 
		_G.SDK.Orbwalker:SetMovement(true)
		_G.SDK.Orbwalker:SetAttack(true)
	else
		_G.GOS.BlockAttack = false
		_G.GOS.BlockMovement = false
	end
	castSpell.state = 0
end

function ReturnCursor(pos)
	Control.SetCursorPos(pos)
	DelayAction(EnableMovement,0.1)
end

function LeftClick(pos)
	Control.mouse_event(MOUSEEVENTF_LEFTDOWN)
	Control.mouse_event(MOUSEEVENTF_LEFTUP)
	DelayAction(ReturnCursor,0.05,{pos})
end

function Ezreal:CastSpell(spell,pos)
	local customcast = self.Menu.CustomSpellCast:Value()
	if not customcast then
		Control.CastSpell(spell, pos)
		return
	else
		local delay = self.Menu.delay:Value()
		local ticker = GetTickCount()
		if castSpell.state == 0 and ticker > castSpell.casting then
			castSpell.state = 1
			castSpell.mouse = mousePos
			castSpell.tick = ticker
			if ticker - castSpell.tick < Game.Latency() then
				--block movement
				if _G.SDK then 
					_G.SDK.Orbwalker:SetMovement(false)
					_G.SDK.Orbwalker:SetAttack(false)
				else
					_G.GOS.BlockAttack = true
					_G.GOS.BlockMovement = true
				end
				Control.SetCursorPos(pos)
				Control.KeyDown(spell)
				Control.KeyUp(spell)
				DelayAction(LeftClick,delay/1000,{castSpell.mouse})
				castSpell.casting = ticker + 500
			end
		end
	end
end


--[[CastQ]]
function Ezreal:CastQ(target)
	if (not _G.SDK and not _G.GOS) then return end
	local target = target or (_G.SDK and _G.SDK.TargetSelector:GetTarget(Q.Range, _G.SDK.DAMAGE_TYPE_PHYSICAL)) or (_G.GOS and _G.GOS:GetTarget(Q.Range,"AD"))
	if target and target.type == "AIHeroClient" and self:CanCast(_Q) and self.Menu.UseQ:Value() and target:GetCollision(Q.Radius,Q.Speed,Q.Delay) == 0 then
		local castPos = target:GetPrediction(Q.Speed,Q.Delay)
		local newpos = myHero.pos:Extended(castPos,math.random(100,300))
		self:CastSpell(HK_Q, newpos)
	end
end
function Ezreal:QLastHit()
	local minionlist = {}
	local canattack = (_G.SDK and _G.SDK.Orbwalker:CanAttack()) or (not _G.SDK and _G.GOS and _G.GOS:CanAttack())
	local canmove = (_G.SDK and _G.SDK.Orbwalker:CanMove()) or (not _G.SDK and _G.GOS and _G.GOS:CanMove())
	if _G.SDK then
		minionlist = _G.SDK.ObjectManager:GetEnemyMinions(Q.Range)
	elseif _G.GOS then
		for i = 1, Game.MinionCount() do
			local minion = Game.Minion(i)
			if minion.valid and minion.isEnemy and minion.pos:DistanceTo(myHero.pos) < Q.Range then
				table.insert(minionlist, minion)
			end
		end
	end
	
	for i, minion in pairs(minionlist) do
		local distancetominion = myHero.pos:DistanceTo(minion.pos)
		if (distancetominion > myHero.range or (not canattack and canmove)) and not _G.SDK.Orbwalker:ShouldWait() then
			local QDamage = getdmg("Q",minion,myHero)
			local timetohit = distancetominion/Q.Speed
			if _G.SDK.HealthPrediction:GetPrediction(minion, timetohit + 0.3)<0 and _G.SDK.HealthPrediction:GetPrediction(minion, timetohit)< QDamage and _G.SDK.HealthPrediction:GetPrediction(minion, timetohit)>0 then
				if minion and self:CanCast(_Q) and minion:GetCollision(Q.Radius,Q.Speed,Q.Delay) == 1 then
					local castPos = minion:GetPrediction(Q.Speed,Q.Delay)
					local newpos = myHero.pos:Extended(castPos,math.random(100,300))
					self:CastSpell(HK_Q, newpos)
				end
			end
		end
	end
end

function Ezreal:IsReady(spellSlot)
	return myHero:GetSpellData(spellSlot).currentCd == 0 and myHero:GetSpellData(spellSlot).level > 0
end

function Ezreal:CheckMana(spellSlot)
	return myHero:GetSpellData(spellSlot).mana < myHero.mana
end

function Ezreal:CanCast(spellSlot)
	return self:IsReady(spellSlot) and self:CheckMana(spellSlot)
end


function OnLoad()
	Ezreal()
end