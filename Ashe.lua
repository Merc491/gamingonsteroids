--[v1.0]]
local Scriptname,Version,Author,LVersion = "TRUSt in my Ashe","v1.0","TRUS","7.6"
if myHero.charName ~= "Ashe" then return end
class "Ashe"



function Ashe:__init()
	
	PrintChat("TRUSt in my Ashe "..Version.." - Loaded....")
	self:LoadSpells()
	self:LoadMenu()
	Callback.Add("Tick", function() self:Tick() end)
	
	
	
	if _G.SDK then
		_G.SDK.Orbwalker:OnPreMovement(function(arg) 
			if blockmovement then
				arg.Process = false
			end
		end)
		
		_G.SDK.Orbwalker:OnPostAttack(function() 
			self:CastQ()
		end)
		
		_G.SDK.Orbwalker:OnPreAttack(function(arg) 		
			if blockattack then
				arg.Process = false
			end
		end)
	else
		PrintChat("This script support IC Orbwalker only")
		
	end
end
onetimereset = true
blockattack = false
blockmovement = false

local lastpick = 0
--[[Spells]]
function Ashe:LoadSpells()
	W = {Range = 1200, width = nil, Delay = 0.25, Radius = 30, Speed = 900}
end



function GetConeAOECastPosition(unit, delay, angle, range, speed, from)
	range = range and range - 4 or 20000
	radius = 1
	from = from and Vector(from) or Vector(myHero.pos)
	angle = angle * math.pi / 180
	
	local CastPosition = unit:GetPrediction(speed,delay)
	local points = {}
	local mainCastPosition = CastPosition
	
	table.insert(points, Vector(CastPosition) - Vector(from))
	
	local function CountVectorsBetween(V1, V2, points)
		local result = 0	
		local hitpoints = {} 
		for i, test in ipairs(points) do
			local NVector = Vector(V1):CrossP(test)
			local NVector2 = Vector(test):CrossP(V2)
			if NVector.y >= 0 and NVector2.y >= 0 then
				result = result + 1
				table.insert(hitpoints, test)
			elseif i == 1 then
				return -1 --doesnt hit the main target
			end
		end
		return result, hitpoints
	end
	
	local function CheckHit(position, angle, points)
		local direction = Vector(position):Normalized()
		local v1 = position:Rotated(0, -angle / 2, 0)
		local v2 = position:Rotated(0, angle / 2, 0)
		return CountVectorsBetween(v1, v2, points)
	end
	
	for i, target in ipairs(_G.SDK.ObjectManager:GetEnemyHeroes(range)) do
		if target.networkID ~= unit.networkID then
			CastPosition = target:GetPrediction(speed,delay)
			if from:DistanceTo(CastPosition) < range then
				table.insert(points, Vector(CastPosition) - Vector(from))
			end
		end
	end
	
	local MaxHitPos
	local MaxHit = 1
	local MaxHitPoints = {}
	
	if #points > 1 then
		
		for i, point in ipairs(points) do
			local pos1 = Vector(point):Rotated(0, angle / 2, 0)
			local pos2 = Vector(point):Rotated(0, - angle / 2, 0)
			
			local hits, points1 = CountVectorsBetween(pos1, pos2, points)
			--
			if hits >= MaxHit then
				
				MaxHitPos = C1
				MaxHit = hits
				MaxHitPoints = points1
			end
			
		end
	end
	
	if MaxHit > 1 then
		--Center the cone
		local maxangle = -1
		local p1
		local p2
		for i, hitp in ipairs(MaxHitPoints) do
			for o, hitp2 in ipairs(MaxHitPoints) do
				local cangle = Vector():AngleBetween(hitp2, hitp) 
				if cangle > maxangle then
					maxangle = cangle
					p1 = hitp
					p2 = hitp2
				end
			end
		end
		
		
		return Vector(from) + range * (((p1 + p2) / 2)):Normalized(), MaxHit
	else
		return mainCastPosition, 1
	end
end



function Ashe:LoadMenu()
	self.Menu = MenuElement({type = MENU, id = "TRUStinymyAshe", name = Scriptname})
	self.Menu:MenuElement({id = "UseWCombo", name = "UseW in combo", value = true})
	self.Menu:MenuElement({id = "UseQCombo", name = "UseQ in combo", value = true})
	self.Menu:MenuElement({id = "UseWHarass", name = "UseW in Harass", value = true})
	self.Menu:MenuElement({id = "CustomSpellCast", name = "Use custom spellcast", tooltip = "Can fix some casting problems with wrong directions and so (thx Noddy for this one)", value = true})
	self.Menu:MenuElement({id = "delay", name = "Custom spellcast delay", value = 50, min = 0, max = 200, step = 5, identifier = ""})
	
	self.Menu:MenuElement({id = "blank", type = SPACE , name = ""})
	self.Menu:MenuElement({id = "blank", type = SPACE , name = "Script Ver: "..Version.. " - LoL Ver: "..LVersion.. ""})
	self.Menu:MenuElement({id = "blank", type = SPACE , name = "by "..Author.. ""})
end

function Ashe:Tick()
	if myHero.dead or not _G.SDK then return end
	local combomodeactive = _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO]
	local harassmodeactive = _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS]
	if combomodeactive and self.Menu.UseWCombo:Value() and _G.SDK.Orbwalker:CanMove() then
		self:CastW()
	end
	if harassmodeactive and self.Menu.UseWHarass:Value() and _G.SDK.Orbwalker:CanMove() then
		self:CastW()
	end
end


local castSpell = {state = 0, tick = GetTickCount(), casting = GetTickCount() - 1000, mouse = mousePos}



function EnableMovement()
	--unblock movement
	blockattack = false
	blockmovement = false
	onetimereset = true
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

function Ashe:CastSpell(spell,pos)
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
				blockattack = true
				blockmovement = true
				Control.SetCursorPos(pos)
				Control.KeyDown(spell)
				Control.KeyUp(spell)
				DelayAction(LeftClick,delay/1000,{castSpell.mouse})
				castSpell.casting = ticker + 500
			end
		end
	end
end


function Ashe:CastQ()
	if self:CanCast(_Q) and _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] and self.Menu.UseQCombo:Value() then
		Control.CastSpell(HK_Q)
	end
end


function Ashe:CastW(target)
	if not _G.SDK then return end
	local target = _G.SDK.Orbwalker:GetTarget() or _G.SDK.TargetSelector:GetTarget(W.Range, _G.SDK.DAMAGE_TYPE_PHYSICAL);
	if target and self:CanCast(_W) and target:GetCollision(W.Radius,W.Speed,W.Delay) == 0 then
		local getposition = self:GetWPos(target)
		if getposition then
			self:CastSpell(HK_W,getposition)
		end
	end
end


function Ashe:GetWPos(unit)
	if unit then
		local temppos = GetConeAOECastPosition(unit, W.Delay, 45, W.Range, W.Speed)
		if temppos then 
			return temppos
		end
	end
	
	return false
end

function Ashe:IsReady(spellSlot)
	return myHero:GetSpellData(spellSlot).currentCd == 0 and myHero:GetSpellData(spellSlot).level > 0
end

function Ashe:CheckMana(spellSlot)
	return myHero:GetSpellData(spellSlot).mana < myHero.mana
end

function Ashe:CanCast(spellSlot)
	return self:IsReady(spellSlot) and self:CheckMana(spellSlot)
end

function OnLoad()
	Ashe()
end