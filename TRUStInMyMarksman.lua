if myHero.charName == "Ashe" or myHero.charName == "Ezreal" or myHero.charName == "Lucian" or myHero.charName == "Caitlyn" or myHero.charName == "Twitch" or myHero.charName == "KogMaw" or myHero.charName == "Kalista" then
	require "2DGeometry"
	
	
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
end

if myHero.charName == "Ashe" then
	
	local Scriptname,Version,Author,LVersion = "TRUSt in my Ashe","v1.4","TRUS","7.10"
	class "Ashe"
	
	function Ashe:GetBuffs(unit)
		self.T = {}
		for i = 0, unit.buffCount do
			local Buff = unit:GetBuff(i)
			if Buff.count > 0 then
				table.insert(self.T, Buff)
			end
		end
		return self.T
	end
	
	function Ashe:QBuff(buffname)
		for K, Buff in pairs(self:GetBuffs(myHero)) do
			if Buff.name:lower() == "asheqcastready" then
				return true
			end
		end
		return false
	end
	
	function Ashe:__init()
		self:LoadSpells()
		self:LoadMenu()
		Callback.Add("Tick", function() self:Tick() end)
		
		local orbwalkername = ""
		if _G.SDK then
			orbwalkername = "IC'S orbwalker"	
			_G.SDK.Orbwalker:OnPostAttack(function() 
				local combomodeactive = (_G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO])
				local currenttarget = _G.SDK.Orbwalker:GetTarget()
				if (combomodeactive) and self.Menu.UseQCombo:Value() and self:QBuff() then
					self:CastQ()
				end
			end)
		elseif _G.GOS then
			orbwalkername = "Noddy orbwalker"
			
			_G.GOS:OnAttackComplete(function() 
				local combomodeactive = _G.GOS:GetMode() == "Combo"
				local currenttarget = _G.GOS:GetTarget()
				if (combomodeactive) and currenttarget and self.Menu.UseQCombo:Value() and self:QBuff() and currenttarget then
					self:CastQ()
				end
			end)
			
		else
			orbwalkername = "Orbwalker not found"
			
		end
		PrintChat(Scriptname.." "..Version.." - Loaded...."..orbwalkername)
	end
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
		local enemyheroestable = (_G.SDK and _G.SDK.ObjectManager:GetEnemyHeroes(range)) or (_G.GOS and _G.GOS:GetEnemyHeroes())
		for i, target in ipairs(enemyheroestable) do
			if target.networkID ~= unit.networkID and myHero.pos:DistanceTo(target.pos) < range then
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
		self.Menu:MenuElement({id = "UseQAfterAA", name = "UseQ only afterattack", value = true})
		self.Menu:MenuElement({id = "UseWHarass", name = "UseW in Harass", value = true})
		self.Menu:MenuElement({id = "UseBOTRK", name = "Use botrk", value = true})
		self.Menu:MenuElement({id = "CustomSpellCast", name = "Use custom spellcast", tooltip = "Can fix some casting problems with wrong directions and so (thx Noddy for this one)", value = true})
		self.Menu:MenuElement({id = "delay", name = "Custom spellcast delay", value = 50, min = 0, max = 200, step = 5, identifier = ""})
		
		self.Menu:MenuElement({id = "blank", type = SPACE , name = ""})
		self.Menu:MenuElement({id = "blank", type = SPACE , name = "Script Ver: "..Version.. " - LoL Ver: "..LVersion.. ""})
		self.Menu:MenuElement({id = "blank", type = SPACE , name = "by "..Author.. ""})
	end
	
	function Ashe:Tick()
		if myHero.dead or (not _G.SDK and not _G.GOS) then return end
		
		if myHero.activeSpell and myHero.activeSpell.valid and myHero.activeSpell.name == "Volley" then 
			EnableMovement()
		end
		
		local combomodeactive = (_G.SDK and _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO]) or (not _G.SDK and _G.GOS and _G.GOS:GetMode() == "Combo") 
		local harassactive = (_G.SDK and _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS]) or (not _G.SDK and _G.GOS and _G.GOS:GetMode() == "Harass") 
		local canmove = (_G.SDK and _G.SDK.Orbwalker:CanMove()) or (not _G.SDK and _G.GOS and _G.GOS:CanMove())
		local canattack = (_G.SDK and _G.SDK.Orbwalker:CanAttack()) or (not _G.SDK and _G.GOS and _G.GOS:CanAttack())
		local currenttarget = (_G.SDK and _G.SDK.Orbwalker:GetTarget()) or (not _G.SDK and _G.GOS and _G.GOS:GetTarget())
		if combomodeactive and self.Menu.UseBOTRK:Value() then
			UseBotrk()
		end
		
		if combomodeactive and self.Menu.UseWCombo:Value() and canmove and not canattack then
			self:CastW()
		end
		if combomodeactive and self:QBuff() and self.Menu.UseQCombo:Value() and (not self.Menu.UseQAfterAA:Value()) and currenttarget and canmove and not canattack then
			self:CastQ()
		end
		if harassactive and self.Menu.UseWHarass:Value() and ((canmove and not canattack) or not currenttarget) then
			self:CastW()
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
	
	
	function Ashe:CastQ()
		if self:CanCast(_Q) then
			Control.CastSpell(HK_Q)
		end
	end
	
	
	function Ashe:CastW(target)
		local target = (_G.SDK and _G.SDK.TargetSelector:GetTarget(W.Range, _G.SDK.DAMAGE_TYPE_PHYSICAL)) or (_G.GOS and _G.GOS:GetTarget(W.Range,"AD"))
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
				local newpos = myHero.pos:Extended(temppos,math.random(100,300))
				return newpos
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
end

if myHero.charName == "Lucian" then
	local Scriptname,Version,Author,LVersion = "TRUSt in my Lucian","v1.3","TRUS","7.10"
	
	class "Lucian"
	
	local passive = true
	local lastbuff = 0
	function Lucian:__init()
		
		self:LoadSpells()
		self:LoadMenu()
		Callback.Add("Tick", function() self:Tick() end)
		
		local orbwalkername = ""
		if _G.SDK then
			orbwalkername = "IC'S orbwalker"		
			_G.SDK.Orbwalker:OnPostAttack(function() 
				passive = false 
				--PrintChat("passive removed")
				local combomodeactive = _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO]
				if combomodeactive and _G.SDK.Orbwalker:CanMove() and Game.Timer() > lastbuff - 3.5 then 
					if self:CanCast(_E) and self.Menu.UseE:Value() and _G.SDK.Orbwalker:GetTarget() then
						self:CastSpell(HK_E,mousePos)
						return
					end
				end
			end)
		elseif _G.GOS then
			orbwalkername = "Noddy orbwalker"
			_G.GOS:OnAttackComplete(function() 
				passive = false 
				local combomodeactive = _G.GOS:GetMode() == "Combo"
				local canmove = _G.GOS:CanMove()
				if combomodeactive and canmove and Game.Timer() > lastbuff - 3.5 then 
					if self:CanCast(_E) and self.Menu.UseE:Value() and _G.GOS:GetTarget() then
						self:CastSpell(HK_E,mousePos)
						return
					end
				end
			end)
			
			
		else
			orbwalkername = "Orbwalker not found"
			
		end
		PrintChat(Scriptname.." "..Version.." - Loaded...."..orbwalkername)
	end
	onetimereset = true
	blockattack = false
	blockmovement = false
	
	local lastpick = 0
	
	--[[Spells]]
	function Lucian:LoadSpells()
		Q = {Range = 1190, width = nil, Delay = 0.25, Radius = 60, Speed = 2000, Collision = false, aoe = false, type = "linear"}
	end
	
	
	
	function Lucian:LoadMenu()
		self.Menu = MenuElement({type = MENU, id = "TRUStinymyLucian", name = Scriptname})
		self.Menu:MenuElement({id = "UseQ", name = "UseQ", value = true})
		self.Menu:MenuElement({id = "UseW", name = "UseW", value = true})
		self.Menu:MenuElement({id = "UseE", name = "UseE", value = true})
		self.Menu:MenuElement({id = "UseBOTRK", name = "Use botrk", value = true})
		self.Menu:MenuElement({id = "UseQHarass", name = "Harass with Q", value = true})
		self.Menu:MenuElement({id = "CustomSpellCast", name = "Use custom spellcast", tooltip = "Can fix some casting problems with wrong directions and so (thx Noddy for this one)", value = true})
		self.Menu:MenuElement({id = "delay", name = "Custom spellcast delay", value = 50, min = 0, max = 200, step = 5, identifier = ""})
		
		self.Menu:MenuElement({id = "blank", type = SPACE , name = ""})
		self.Menu:MenuElement({id = "blank", type = SPACE , name = "Script Ver: "..Version.. " - LoL Ver: "..LVersion.. ""})
		self.Menu:MenuElement({id = "blank", type = SPACE , name = "by "..Author.. ""})
	end
	
	function Lucian:GetBuffs(unit)
		self.T = {}
		for i = 0, unit.buffCount do
			local Buff = unit:GetBuff(i)
			if Buff.count > 0 then
				table.insert(self.T, Buff)
			end
		end
		return self.T
	end
	
	function Lucian:HasBuff(unit, buffname)
		for K, Buff in pairs(self:GetBuffs(unit)) do
			if Buff.name:lower() == buffname:lower() then
				return Buff.expireTime
			end
		end
		return false
	end
	
	function Lucian:Tick()
		if myHero.dead or (not _G.SDK and not _G.GOS) then return end
		
		local buffcheck = self:HasBuff(myHero,"lucianpassivebuff")
		if buffcheck and buffcheck ~= lastbuff then
			lastbuff = buffcheck
			--PrintChat("Passive added : "..Game.Timer().." : "..lastbuff)
			passive = true
		end
		local combomodeactive = (_G.SDK and _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO]) or (not _G.SDK and _G.GOS and _G.GOS:GetMode() == "Combo") 
		local harassactive = (_G.SDK and _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS]) or (not _G.SDK and _G.GOS and _G.GOS:GetMode() == "Harass") 
		local canmove = (_G.SDK and _G.SDK.Orbwalker:CanMove()) or (not _G.SDK and _G.GOS and _G.GOS:CanMove())
		local canattack = (_G.SDK and _G.SDK.Orbwalker:CanAttack()) or (not _G.SDK and _G.GOS and _G.GOS:CanAttack())
		local currenttarget = (_G.SDK and _G.SDK.Orbwalker:GetTarget()) or (not _G.SDK and _G.GOS and _G.GOS:GetTarget())
		if combomodeactive and self.Menu.UseBOTRK:Value() then
			UseBotrk()
		end
		if harassactive and self.Menu.UseQHarass:Value() and self:CanCast(_Q) then self:Harass() end 
		if combomodeactive and canmove and not canattack and Game.Timer() > lastbuff - 3 then 
			if self:CanCast(_E) and self.Menu.UseE:Value() and currenttarget then
				self:CastSpell(HK_E,mousePos)
				return
			end
			if self:CanCast(_Q) and self.Menu.UseQ:Value() and currenttarget then
				self:CastQ(currenttarget)
				return
			end
			if self:CanCast(_W) and self.Menu.UseW:Value() and currenttarget then
				self:CastW(currenttarget)
				return
			end
			
			
		end
		
		if myHero.activeSpell and myHero.activeSpell.valid and 
		(myHero.activeSpell.name == "LucianQ" or myHero.activeSpell.name == "LucianW") then
			passive = true
			--PrintChat("found passive1")
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
	
	function Lucian:CastSpell(spell,pos)
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
	function Lucian:CastQ(target)
		if target and self:CanCast(_Q) and passive == false then
			self:CastSpell(HK_Q, target.pos)
		end
	end
	
	--[[CastQ]]
	function Lucian:CastW(target)
		if target and self:CanCast(_W) and passive == false then
			self:CastSpell(HK_W, target.pos)
		end
	end
	
	
	function Lucian:IsReady(spellSlot)
		return myHero:GetSpellData(spellSlot).currentCd == 0 and myHero:GetSpellData(spellSlot).level > 0
	end
	
	function Lucian:CheckMana(spellSlot)
		return myHero:GetSpellData(spellSlot).mana < myHero.mana
	end
	
	function Lucian:CanCast(spellSlot)
		return self:IsReady(spellSlot) and self:CheckMana(spellSlot)
	end
	
	
	
	function Lucian:Harass()
		local temptarget = self:FarQTarget()
		if temptarget then
			self:CastSpell(HK_Q,temptarget.pos)
		end
	end
	
	
	
	
	function Lucian:FarQTarget()
		local qtarget = (_G.SDK and _G.SDK.TargetSelector:GetTarget(900, _G.SDK.DAMAGE_TYPE_PHYSICAL)) or (_G.GOS and _G.GOS:GetTarget(900,"AD"))
		if qtarget then
			
			if myHero.pos:DistanceTo(qtarget.pos)<500 then
				return qtarget
			end
			
			
			local qdelay = 0.4 - myHero.levelData.lvl*0.01
			local pos = qtarget:GetPrediction(math.huge,qdelay)
			if not pos then return false end 
			local minionlist = {}
			if _G.SDK then
				minionlist = _G.SDK.ObjectManager:GetEnemyMinions(500)
			elseif _G.GOS then
				for i = 1, Game.MinionCount() do
					local minion = Game.Minion(i)
					if minion.valid and minion.isEnemy and minion.pos:DistanceTo(myHero.pos) < 500 then
						table.insert(minionlist, minion)
					end
				end
			end
			V = Vector(pos) - Vector(myHero.pos)
			
			Vn = V:Normalized()
			Distance = myHero.pos:DistanceTo(pos)
			tx, ty, tz = Vn:Unpack()
			TopX = pos.x - (tx * Distance)
			TopY = pos.y - (ty * Distance)
			TopZ = pos.z - (tz * Distance)
			
			Vr = V:Perpendicular():Normalized()
			Radius = qtarget.boundingRadius or 65
			tx, ty, tz = Vr:Unpack()
			
			LeftX = pos.x + (tx * Radius)
			LeftY = pos.y + (ty * Radius)
			LeftZ = pos.z + (tz * Radius)
			RightX = pos.x - (tx * Radius)
			RightY = pos.y - (ty * Radius)
			RightZ = pos.z - (tz * Radius)
			
			Left = Point(LeftX, LeftY, LeftZ)
			Right = Point(RightX, RightY, RightZ)
			Top = Point(TopX, TopY, TopZ)
			Poly = Polygon(Left, Right, Top)
			
			for i, minion in pairs(minionlist) do
				toPoint = Point(minion.pos.x, minion.pos.y,minion.pos.z)
				if Poly:__contains(toPoint) then
					return minion
				end
			end
		end
		return false 
	end
	
	
	function OnLoad()
		Lucian()
	end
	
end


if myHero.charName == "Caitlyn" then
	if myHero.charName ~= "Caitlyn" then return end
	class "Caitlyn"
	local Scriptname,Version,Author,LVersion = "TRUSt in my Caitlyn","v1.4","TRUS","7.10"
	require "DamageLib"
	local qtarget
	local LastW
	function Caitlyn:__init()
		self:LoadSpells()
		self:LoadMenu()
		Callback.Add("Tick", function() self:Tick() end)
		Callback.Add("Draw", function() self:Draw() end)
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
	onetimereset = true
	blockattack = false
	blockmovement = false
	
	local lastpick = 0
	--[[Spells]]
	function Caitlyn:LoadSpells()
		Q = {Range = 1190, width = nil, Delay = 0.25, Radius = 60, Speed = 2000}
		E = {Range = 800, width = nil, Delay = 0.25, Radius = 80, Speed = 1600}
	end
	
	function Caitlyn:LoadMenu()
		self.Menu = MenuElement({type = MENU, id = "TRUStinymyCaitlyn", name = Scriptname})
		self.Menu:MenuElement({id = "UseUlti", name = "Use R", tooltip = "On killable target which is on screen", key = string.byte("R")})
		self.Menu:MenuElement({id = "UseEQ", name = "UseEQ", key = string.byte("X")})
		self.Menu:MenuElement({id = "autoW", name = "Use W on cc", value = true})
		self.Menu:MenuElement({id = "UseBOTRK", name = "Use botrk", value = true})
		self.Menu:MenuElement({id = "CustomSpellCast", name = "Use custom spellcast", value = true})
		self.Menu:MenuElement({id = "DrawR", name = "Draw Killable with R", value = true})
		self.Menu:MenuElement({id = "DrawColor", name = "Color for Killable circle", color = Draw.Color(0xBF3F3FFF)})
		self.Menu:MenuElement({id = "delay", name = "Custom spellcast delay", value = 50, min = 0, max = 200, step = 5, identifier = ""})
		
		self.Menu:MenuElement({id = "blank", type = SPACE , name = ""})
		self.Menu:MenuElement({id = "blank", type = SPACE , name = "Script Ver: "..Version.. " - LoL Ver: "..LVersion.. ""})
		self.Menu:MenuElement({id = "blank", type = SPACE , name = "by "..Author.. ""})
	end
	
	function Caitlyn:Tick()
		if myHero.dead or (not _G.SDK and not _G.GOS) then return end
		local combomodeactive = (_G.SDK and _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO]) or (not _G.SDK and _G.GOS and _G.GOS:GetMode() == "Combo") 
		local harassactive = (_G.SDK and _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS]) or (not _G.SDK and _G.GOS and _G.GOS:GetMode() == "Harass") 
		local canmove = (_G.SDK and _G.SDK.Orbwalker:CanMove()) or (not _G.SDK and _G.GOS and _G.GOS:CanMove())
		local canattack = (_G.SDK and _G.SDK.Orbwalker:CanAttack()) or (not _G.SDK and _G.GOS and _G.GOS:CanAttack())
		local currenttarget = (_G.SDK and _G.SDK.Orbwalker:GetTarget()) or (not _G.SDK and _G.GOS and _G.GOS:GetTarget())
		
		if combomodeactive and self.Menu.UseBOTRK:Value() then
			UseBotrk()
		end
		
		local useEQ = self.Menu.UseEQ:Value()
		
		if self.Menu.UseUlti:Value() and self:CanCast(_R) then
			self:UseR()
		end
		
		if self:CanCast(_Q) and self:CanCast(_E) and useEQ then
			self:CastE(currenttarget)
		end
		
		if myHero.activeSpell and myHero.activeSpell.valid and myHero.activeSpell.name == "CaitlynEntrapment" and self:CanCast(_Q) and useEQ then
			Control.CastSpell(HK_Q,qtarget)
		end
		if self:CanCast(_W) then
			self:AutoW()
		end
	end
	
	
	local castSpell = {state = 0, tick = GetTickCount(), casting = GetTickCount() - 1000, mouse = mousePos}
	
	
	function ReturnCursor(pos)
		if _G.SDK then 
			_G.SDK.Orbwalker:SetMovement(true)
			_G.SDK.Orbwalker:SetAttack(true)
		else
			_G.GOS.BlockAttack = false
			_G.GOS.BlockMovement = false
		end
		Control.SetCursorPos(pos)
		castSpell.state = 0
		
	end
	
	function LeftClick(pos)
		DelayAction(ReturnCursor,0.01,{pos})
	end
	
	function Caitlyn:GetRTarget()
		self.KillableHeroes = {}
		local RRange = ({2000, 2500, 3000})[myHero:GetSpellData(_R).level]
		local heroeslist = (_G.SDK and _G.SDK.ObjectManager:GetEnemyHeroes(RRange)) or (_G.GOS and _G.GOS:GetEnemyHeroes())
		for i, hero in pairs(heroeslist) do
			local RDamage = getdmg("R",hero,myHero,1)
			if hero.health and RDamage and RDamage > hero.health and hero.pos2D.onScreen and myHero.pos:DistanceTo(hero.pos) < RRange then
				table.insert(self.KillableHeroes, hero)
			end
		end
		return self.KillableHeroes
	end
	
	function Caitlyn:UseR()
		local RTarget = self:GetRTarget()
		if #RTarget > 0 then
			Control.SetCursorPos(RTarget[1].pos)
			Control.KeyDown(HK_R)
			Control.KeyUp(HK_R)
		end
	end
	
	function Caitlyn:Draw()
		if self.Menu.DrawR:Value() then
			local RTarget = self:GetRTarget()
			for i, hero in pairs(RTarget) do
				Draw.Circle(hero.pos, 60, 3, self.Menu.DrawColor:Value())
			end
		end
	end
	
	function Caitlyn:Stunned(enemy)
		for i = 0, enemy.buffCount do
			local buff = enemy:GetBuff(i);
			if (buff.type == 5 or buff.type == 11 or buff.type == 24) and buff.duration > 0.5 and buff.name ~= "caitlynyordletrapdebuff" then
				return true
			end
		end
		return false
	end
	
	function Caitlyn:AutoW()
		if not self.Menu.autoW:Value() then return end
		local ImmobileEnemy = self:GetImmobileTarget()
		if ImmobileEnemy and myHero.pos:DistanceTo(ImmobileEnemy.pos)<800 and (not LastW or LastW:DistanceTo(ImmobileEnemy.pos)>60) then
			LastW = ImmobileEnemy.pos
			self:CastSpell(HK_W,ImmobileEnemy.pos)
		end
	end
	
	function Caitlyn:CastSpell(spell,pos)
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
					Control.SetCursorPos(pos)
					Control.KeyDown(spell)
					Control.KeyUp(spell)
					DelayAction(LeftClick,delay/1000,{castSpell.mouse})
					castSpell.casting = ticker
				end
			end
		end
	end
	
	
	function Caitlyn:GetImmobileTarget()
		local GetEnemyHeroes = (_G.SDK and _G.SDK.ObjectManager:GetEnemyHeroes(800)) or (_G.GOS and _G.GOS:GetEnemyHeroes())
		for i = 1, #GetEnemyHeroes do
			local Enemy = GetEnemyHeroes[i]
			if Enemy and self:Stunned(Enemy) and myHero.pos:DistanceTo(Enemy.pos) < 800 then
				return Enemy
			end
		end
		return false
	end
	
	
	function Caitlyn:CastCombo(pos)
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
				Control.KeyDown(HK_E)
				Control.KeyUp(HK_E)
				Control.KeyDown(HK_Q)
				Control.KeyUp(HK_Q)
				DelayAction(LeftClick,delay/1000,{castSpell.mouse})
				castSpell.casting = ticker
			end
		end
	end
	
	
	--[[CastEQ]]
	function Caitlyn:CastE(target)
		if not _G.SDK and not _G.GOS then return end
		if target and target:GetCollision(E.Radius,E.Speed,E.Delay) == 0 then
			local castPos = target:GetPrediction(E.Speed, E.Delay)
			local newpos = myHero.pos:Extended(castPos,math.random(100,300))
			self:CastCombo(newpos)
			qtarget = newpos
		end
	end
	
	
	function Caitlyn:IsReady(spellSlot)
		return myHero:GetSpellData(spellSlot).currentCd == 0 and myHero:GetSpellData(spellSlot).level > 0
	end
	
	function Caitlyn:CheckMana(spellSlot)
		return myHero:GetSpellData(spellSlot).mana < myHero.mana
	end
	
	function Caitlyn:CanCast(spellSlot)
		return self:IsReady(spellSlot) and self:CheckMana(spellSlot)
	end
	
	function OnLoad()
		Caitlyn()
	end
end

if myHero.charName == "Ezreal" then
	local Scriptname,Version,Author,LVersion = "TRUSt in my Ezreal","v1.5","TRUS","7.10"
	
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
end

if myHero.charName == "Twitch" then
	local Scriptname,Version,Author,LVersion = "TRUSt in my Twitch","v1.1","TRUS","7.10"
	class "Twitch"
	require "DamageLib"
	local qtarget
	stacks = {}
	function Twitch:__init()
		self:LoadMenu()
		Callback.Add("Tick", function() self:Tick() end)
		Callback.Add("Draw", function() self:Draw() end)
		local orbwalkername = ""
		if _G.SDK then
			orbwalkername = "IC'S orbwalker"		
			_G.SDK.Orbwalker:OnPostAttack(function(arg) 		
				DelayAction(recheckparticle,0.2)
			end)
		elseif _G.GOS then
			orbwalkername = "Noddy orbwalker"
			_G.GOS:OnAttackComplete(function() 
				DelayAction(recheckparticle,0.2)
			end)
		else
			orbwalkername = "Orbwalker not found"
			
		end
		PrintChat(Scriptname.." "..Version.." - Loaded...."..orbwalkername)
	end
	
	function Twitch:LoadMenu()
		self.Menu = MenuElement({type = MENU, id = "TRUStinymyTwitch", name = Scriptname})
		self.Menu:MenuElement({id = "UseEKS", name = "Use E on killable", value = true})
		self.Menu:MenuElement({id = "UseERange", name = "Use E on running enemy", value = true})
		self.Menu:MenuElement({id = "MinStacks", name = "Minimal E stacks", value = 2, min = 0, max = 6, step = 5, identifier = ""})
		self.Menu:MenuElement({id = "UseBOTRK", name = "Use botrk", value = true})
		self.Menu:MenuElement({id = "CustomSpellCast", name = "Use custom spellcast", value = true})
		self.Menu:MenuElement({id = "DrawE", name = "Draw Killable with E", value = true})
		self.Menu:MenuElement({id = "DrawColor", name = "Color for Killable circle", color = Draw.Color(0xBF3F3FFF)})
		self.Menu:MenuElement({id = "delay", name = "Custom spellcast delay", value = 50, min = 0, max = 200, step = 5, identifier = ""})
		
		self.Menu:MenuElement({id = "blank", type = SPACE , name = ""})
		self.Menu:MenuElement({id = "blank", type = SPACE , name = "Script Ver: "..Version.. " - LoL Ver: "..LVersion.. ""})
		self.Menu:MenuElement({id = "blank", type = SPACE , name = "by "..Author.. ""})
	end
	function Twitch:Tick()
		if myHero.dead or (not _G.SDK and not _G.GOS) then return end
		local combomodeactive = (_G.SDK and _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO]) or (not _G.SDK and _G.GOS and _G.GOS:GetMode() == "Combo") 
		local harassactive = (_G.SDK and _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS]) or (not _G.SDK and _G.GOS and _G.GOS:GetMode() == "Harass") 
		
		
		if combomodeactive then 
			if self.Menu.UseBOTRK:Value() then
				UseBotrk()
			end	
		end
		
		if self:CanCast(_E) and self.Menu.UseEKS:Value() then
			self:UseEKS()
		end
		
		if (harassactive or combomodeactive) and self.Menu.UseERange:Value() and self:CanCast(_E) then
			self:UseERange()
		end
	end
	
	function Twitch:UseERange()
		local heroeslist = (_G.SDK and _G.SDK.ObjectManager:GetEnemyHeroes(1100)) or (_G.GOS and _G.GOS:GetEnemyHeroes())
		local target = (_G.SDK and _G.SDK.TargetSelector.SelectedTarget) or (_G.GOS and _G.GOS:GetTarget())
		if target then return end 
		for i, hero in pairs(heroeslist) do
			if stacks[hero.charName] and self:GetStacks(stacks[hero.charName].name) >= self.Menu.MinStacks:Value() then
				
				if myHero.pos:DistanceTo(hero.pos)<1000 and myHero.pos:DistanceTo(hero:GetPrediction(math.huge,0.25)) < 600 then
					return
				end
				
				if myHero.pos:DistanceTo(hero.pos)<1000 and myHero.pos:DistanceTo(hero:GetPrediction(math.huge,0.25)) > 1000 then
					Control.CastSpell(HK_E)
				end
			end
		end
	end
	
	function Twitch:GetStacks(str)
		if str:lower():find("twitch_poison_counter_01.troy") then return 1
		elseif str:lower():find("twitch_poison_counter_02.troy") then return 2
		elseif str:lower():find("twitch_poison_counter_03.troy") then return 3
		elseif str:lower():find("twitch_poison_counter_04.troy") then return 4
		elseif str:lower():find("twitch_poison_counter_05.troy") then return 5
		elseif str:lower():find("twitch_poison_counter_06.troy") then return 6
		end
		return 0
	end
	
	function recheckparticle()
		local heroeslist = (_G.SDK and _G.SDK.ObjectManager:GetEnemyHeroes(1100)) or (_G.GOS and _G.GOS:GetEnemyHeroes())
		for i = 1, Game.ObjectCount() do
			local object = Game.Object(i)		
			if object then
				for i, hero in pairs(heroeslist) do
					if object.pos:DistanceTo(hero.pos)<200 and object ~= hero then 
						local stacksamount = Twitch:GetStacks(object.name)
						if stacksamount > 0 then
							stacks[hero.charName] = object
						end
					end
				end
			end
		end
		return false
	end
	
	function Twitch:GetETarget()
		self.KillableHeroes = {}
		local heroeslist = (_G.SDK and _G.SDK.ObjectManager:GetEnemyHeroes(1200)) or (_G.GOS and _G.GOS:GetEnemyHeroes())
		local level = myHero:GetSpellData(_E).level
		for i, hero in pairs(heroeslist) do
			if stacks[hero.charName] and self:GetStacks(stacks[hero.charName].name) > 0 then 
				local EDamage = (self:GetStacks(stacks[hero.charName].name) * (({15, 20, 25, 30, 35})[level] + 0.2 * myHero.ap + 0.25 * myHero.bonusDamage)) + ({20, 35, 50, 65, 80})[level]
				local tmpdmg = CalcPhysicalDamage(myHero, hero, EDamage)
				if hero.health and tmpdmg and tmpdmg > hero.health and myHero.pos:DistanceTo(hero.pos)<1200 then
					table.insert(self.KillableHeroes, hero)
				end
			end
		end
		return self.KillableHeroes
	end
	
	function Twitch:UseEKS()
		local ETarget = self:GetETarget()
		if #ETarget > 0 then
			Control.KeyDown(HK_E)
			Control.KeyUp(HK_E)
		end
	end
	
	function Twitch:Draw()
		if self.Menu.DrawE:Value() then
			local ETarget = self:GetETarget()
			for i, hero in pairs(ETarget) do
				Draw.Circle(hero.pos, 60, 3, self.Menu.DrawColor:Value())
			end
		end
	end
	
	
	function Twitch:IsReady(spellSlot)
		return myHero:GetSpellData(spellSlot).currentCd == 0 and myHero:GetSpellData(spellSlot).level > 0
	end
	
	function Twitch:CheckMana(spellSlot)
		return myHero:GetSpellData(spellSlot).mana < myHero.mana
	end
	
	function Twitch:CanCast(spellSlot)
		return self:IsReady(spellSlot) and self:CheckMana(spellSlot)
	end
	
	function OnLoad()
		Twitch()
	end
end

if myHero.charName == "KogMaw" then
	local Scriptname,Version,Author,LVersion = "TRUSt in my KogMaw","v1.0","TRUS","7.10"
	class "KogMaw"
	
	function KogMaw:__init()
		self:LoadSpells()
		self:LoadMenu()
		Callback.Add("Tick", function() self:Tick() end)
		
		local orbwalkername = ""
		if _G.SDK then
			orbwalkername = "IC'S orbwalker"
			_G.SDK.Orbwalker:OnPostAttack(function() 
				local combomodeactive = _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO]
				local harassactive = _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS]
				if (combomodeactive or harassactive) then
					self:CastQ(_G.SDK.Orbwalker:GetTarget())
				end
			end)
		elseif _G.GOS then
			orbwalkername = "Noddy orbwalker"
			_G.GOS:OnAttackComplete(function() 
				local combomodeactive = _G.GOS:GetMode() == "Combo"
				local harassactive = _G.GOS:GetMode() == "Harass"
				if (combomodeactive or harassactive) then
					self:CastQ(_G.GOS:GetTarget())
				end
			end)
		else
			orbwalkername = "Orbwalker not found"
			
		end
		PrintChat(Scriptname.." "..Version.." - Loaded...."..orbwalkername)
	end
	blockattack = false
	blockmovement = false
	
	local lastpick = 0
	--[[Spells]]
	function KogMaw:LoadSpells()
		Q = {Range = 1175, width = 70, Delay = 0.25, Speed = 1650}
		E = {Range = 1280, width = 120, Delay = 0.5, Speed = 1350}
		R = {Range = 1200, Delay = 1.2, Radius = 120, Speed = math.huge}
	end
	
	function KogMaw:LoadMenu()
		self.Menu = MenuElement({type = MENU, id = "TRUStinymyKogMaw", name = Scriptname})
		
		--[[Combo]]
		self.Menu:MenuElement({id = "UseBOTRK", name = "Use botrk", value = true})
		self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo Settings"})
		self.Menu.Combo:MenuElement({id = "comboUseQ", name = "Use Q", value = true})
		self.Menu.Combo:MenuElement({id = "comboUseE", name = "Use E", value = true})
		self.Menu.Combo:MenuElement({id = "comboUseR", name = "Use R", value = true})
		self.Menu.Combo:MenuElement({id = "MaxStacks", name = "Max R stacks: ", value = 3, min = 0, max = 10})
		self.Menu.Combo:MenuElement({id = "ManaW", name = "Save mana for W", value = true})
		
		--[[Harass]]
		self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass Settings"})
		self.Menu.Harass:MenuElement({id = "harassUseQ", name = "Use Q", value = true})
		self.Menu.Harass:MenuElement({id = "harassUseE", name = "Use E", value = true})
		self.Menu.Harass:MenuElement({id = "harassMana", name = "Minimal mana percent:", value = 30, min = 0, max = 101, identifier = "%"})
		self.Menu.Harass:MenuElement({id = "harassUseR", name = "Use R", value = true})
		self.Menu.Harass:MenuElement({id = "HarassMaxStacks", name = "Max R stacks: ", value = 3, min = 0, max = 10})
		
		
		
		self.Menu:MenuElement({id = "CustomSpellCast", name = "Use custom spellcast", tooltip = "Can fix some casting problems with wrong directions and so (thx Noddy for this one)", value = true})
		self.Menu:MenuElement({id = "delay", name = "Custom spellcast delay", value = 50, min = 0, max = 200, step = 5, identifier = ""})
		
		self.Menu:MenuElement({id = "blank", type = SPACE , name = ""})
		self.Menu:MenuElement({id = "blank", type = SPACE , name = "Script Ver: "..Version.. " - LoL Ver: "..LVersion.. ""})
		self.Menu:MenuElement({id = "blank", type = SPACE , name = "by "..Author.. ""})
	end
	
	function KogMaw:Tick()
		if myHero.dead or (not _G.SDK and not _G.GOS) then return end
		local combomodeactive = (_G.SDK and _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO]) or (not _G.SDK and _G.GOS and _G.GOS:GetMode() == "Combo") 
		local harassactive = (_G.SDK and _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS]) or (not _G.SDK and _G.GOS and _G.GOS:GetMode() == "Harass") 
		local canmove = (_G.SDK and _G.SDK.Orbwalker:CanMove()) or (not _G.SDK and _G.GOS and _G.GOS:CanMove())
		local canattack = (_G.SDK and _G.SDK.Orbwalker:CanAttack()) or (not _G.SDK and _G.GOS and _G.GOS:CanAttack())
		local currenttarget = (_G.SDK and _G.SDK.Orbwalker:GetTarget()) or (not _G.SDK and _G.GOS and _G.GOS:GetTarget())
		local HarassMinMana = self.Menu.Harass.harassMana:Value()
		
		
		if combomodeactive and self.Menu.UseBOTRK:Value() then
			UseBotrk()
		end
		
		if ((combomodeactive) or (harassactive and myHero.maxMana * HarassMinMana * 0.01 < myHero.mana)) and (canmove or not currenttarget) then
			self:CastQ(currenttarget,combomodeactive or false)
			self:CastE(currenttarget,combomodeactive or false)
			self:CastR(currenttarget,combomodeactive or false)
		end
		
		
		if myHero.activeSpell and myHero.activeSpell.valid and (myHero.activeSpell.name == "KogMawQ" or myHero.activeSpell.name == "KogMawVoidOozeMissile" or myHero.activeSpell.name == "KogMawLivingArtillery") then
			EnableMovement()
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
	
	function KogMaw:CastSpell(spell,pos)
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
	
	function KogMaw:GetRRange()
		return (myHero:GetSpellData(_R).level > 0 and ({1200,1500,1800})[myHero:GetSpellData(_R).level]) or 0
	end
	
	function KogMaw:GetBuffs()
		self.T = {}
		for i = 0, myHero.buffCount do
			local Buff = myHero:GetBuff(i)
			if Buff.count > 0 then
				table.insert(self.T, Buff)
			end
		end
		return self.T
	end
	
	function KogMaw:UltStacks()
		for K, Buff in pairs(self:GetBuffs()) do
			if Buff.name:lower() == "kogmawlivingartillerycost" then
				return Buff.count
			end
		end
		return 0
	end
	
	
	--[[CastQ]]
	function KogMaw:CastQ(target, combo)
		if (not _G.SDK and not _G.GOS) then return end
		local target = target or (_G.SDK and _G.SDK.TargetSelector:GetTarget(Q.Range, _G.SDK.DAMAGE_TYPE_PHYSICAL)) or (_G.GOS and _G.GOS:GetTarget(Q.Range,"AP"))
		if target and target.type == "AIHeroClient" and self:CanCast(_Q) and ((combo and self.Menu.Combo.comboUseQ:Value()) or (combo == false and self.Menu.Harass.harassUseQ:Value())) and target:GetCollision(Q.Width,Q.Speed,Q.Delay) == 0 then
			local castPos = target:GetPrediction(Q.Speed,Q.Delay)
			local newpos = myHero.pos:Extended(castPos,math.random(100,300))
			self:CastSpell(HK_Q, newpos)
		end
	end
	
	
	--[[CastE]]
	function KogMaw:CastE(target,combo)
		if (not _G.SDK and not _G.GOS) then return end
		local target = target or (_G.SDK and _G.SDK.TargetSelector:GetTarget(E.Range, _G.SDK.DAMAGE_TYPE_PHYSICAL)) or (_G.GOS and _G.GOS:GetTarget(E.Range,"AP"))
		if target and target.type == "AIHeroClient" and self:CanCast(_E) and ((combo and self.Menu.Combo.comboUseE:Value()) or (combo == false and self.Menu.Harass.harassUseE:Value())) then
			local castPos = target:GetPrediction(E.Speed,E.Delay)
			local newpos = myHero.pos:Extended(castPos,math.random(100,300))
			self:CastSpell(HK_E, newpos)
		end
	end
	
	--[[CastR]]
	function KogMaw:CastR(target,combo)
		if (not _G.SDK and not _G.GOS) then return end
		local RRange = self:GetRRange()
		local target = target or (_G.SDK and _G.SDK.TargetSelector:GetTarget(RRange, _G.SDK.DAMAGE_TYPE_PHYSICAL)) or (_G.GOS and _G.GOS:GetTarget(RRange,"AP"))
		local currentultstacks = self:UltStacks()
		if target and target.type == "AIHeroClient" and self:CanCast(_R) 
		and ((combo and self.Menu.Combo.comboUseR:Value()) or (combo == false and self.Menu.Harass.harassUseR:Value())) 
		and ((combo == false and currentultstacks < self.Menu.Harass.HarassMaxStacks:Value()) or (currentultstacks < self.Menu.Combo.MaxStacks:Value()))
		then
			local castPos = target:GetPrediction(R.Speed,R.Delay)
			self:CastSpell(HK_R, castPos)
		end
	end
	
	function KogMaw:IsReady(spellSlot)
		return myHero:GetSpellData(spellSlot).currentCd == 0 and myHero:GetSpellData(spellSlot).level > 0
	end
	
	function KogMaw:CheckMana(spellSlot)
		local savemana = self.Menu.Combo.ManaW:Value()
		return myHero:GetSpellData(spellSlot).mana < (myHero.mana - ((savemana and 40) or 0))
	end
	
	function KogMaw:CanCast(spellSlot)
		return self:IsReady(spellSlot) and self:CheckMana(spellSlot)
	end
	
	
	function OnLoad()
		KogMaw()
	end
end

if myHero.charName == "Kalista" then 
	local Scriptname,Version,Author,LVersion = "TRUSt in my Kalista","v1.7","TRUS","7.10"
	class "Kalista"
	require "DamageLib"
	
	function Kalista:__init()
		self:LoadSpells()
		self:LoadMenu()
		Callback.Add("Tick", function() self:Tick() end)
		Callback.Add("Draw", function() self:Draw() end)
		local orbwalkername = ""
		if _G.SDK then
			orbwalkername = "IC'S orbwalker"	
			_G.SDK.Orbwalker:OnPostAttack(function() 
				local combomodeactive = _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO]
				local harassactive = _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS]
				local QMinMana = self.Menu.Combo.qMinMana:Value()
				if (combomodeactive or harassactive) then	
					if (harassactive or (myHero.maxMana * QMinMana * 0.01 < myHero.mana)) then
						self:CastQ(_G.SDK.Orbwalker:GetTarget(),combomodeactive or false)
					end
				end
			end)
		elseif _G.GOS then
			orbwalkername = "Noddy orbwalker"
			_G.GOS:OnAttackComplete(function() 
				local combomodeactive = _G.GOS:GetMode() == "Combo"
				local harassactive = _G.GOS:GetMode() == "Harass"
				local QMinMana = self.Menu.Combo.qMinMana:Value()
				
				if (combomodeactive or harassactive) then
					if (harassactive or (myHero.maxMana * QMinMana * 0.01 < myHero.mana)) then
						self:CastQ(_G.GOS:GetTarget(),combomodeactive or false)
					end
				end
			end)
		else
			orbwalkername = "Orbwalker not found"
			
		end
		PrintChat(Scriptname.." "..Version.." - Loaded...."..orbwalkername)
	end
	
	--[[Spells]]
	function Kalista:LoadSpells()
		Q = {Range = 1150, width = 40, Delay = 0.25, Speed = 2100}
		E = {Range = 1000}
	end
	
	function Kalista:LoadMenu()
		self.Menu = MenuElement({type = MENU, id = "TRUStinymyKalista", name = Scriptname})
		
		--[[Combo]]
		self.Menu:MenuElement({id = "UseBOTRK", name = "Use botrk", value = true})
		self.Menu:MenuElement({id = "AlwaysKS", name = "Always KS with E", value = true})
		
		self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo Settings"})
		self.Menu.Combo:MenuElement({id = "comboUseQ", name = "Use Q", value = true})
		self.Menu.Combo:MenuElement({id = "qMinMana", name = "Minimal mana for Q:", value = 30, min = 0, max = 101, identifier = "%"})
		self.Menu.Combo:MenuElement({id = "comboUseE", name = "Use E", value = true})
		
		--[[Draw]]
		self.Menu:MenuElement({type = MENU, id = "Draw", name = "Draw Settings"})
		self.Menu.Draw:MenuElement({id = "DrawEDamage", name = "Draw health remaining after E", value = true})
		self.Menu.Draw:MenuElement({id = "DrawInPrecent", name = "Draw numbers in percent", value = true})
		self.Menu.Draw:MenuElement({id = "DrawE", name = "Draw Killable with E", value = true})
		self.Menu.Draw:MenuElement({id = "TextOffset", name = "Z offset for text ", value = 0, min = -100, max = 100})
		self.Menu.Draw:MenuElement({id = "TextSize", name = "Font size ", value = 30, min = 2, max = 64})
		self.Menu.Draw:MenuElement({id = "DrawColor", name = "Color for drawing", color = Draw.Color(0xBF3F3FFF)})
		
		
		--[[Harass]]
		self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass Settings"})
		self.Menu.Harass:MenuElement({id = "harassUseQ", name = "Use Q", value = true})
		self.Menu.Harass:MenuElement({id = "harassUseELasthit", name = "Use E Harass when lasthit", value = true})
		self.Menu.Harass:MenuElement({id = "harassUseERange", name = "Use E when out of range", value = true})
		self.Menu.Harass:MenuElement({id = "HarassMinEStacks", name = "Min E stacks: ", value = 3, min = 0, max = 10})
		self.Menu.Harass:MenuElement({id = "harassMana", name = "Minimal mana percent:", value = 30, min = 0, max = 101, identifier = "%"})
		
		self.Menu:MenuElement({type = MENU, id = "SmiteMarker", name = "AutoE Jungle"})
		self.Menu.SmiteMarker:MenuElement({id = "Enabled", name = "Enabled", key = string.byte("K"), toggle = true})
		self.Menu.SmiteMarker:MenuElement({id = "MarkBaron", name = "Baron", value = true, leftIcon = "http://puu.sh/rPuVv/933a78e350.png"})
		self.Menu.SmiteMarker:MenuElement({id = "MarkHerald", name = "Herald", value = true, leftIcon = "http://puu.sh/rQs4A/47c27fa9ea.png"})
		self.Menu.SmiteMarker:MenuElement({id = "MarkDragon", name = "Dragon", value = true, leftIcon = "http://puu.sh/rPvdF/a00d754b30.png"})
		self.Menu.SmiteMarker:MenuElement({id = "MarkBlue", name = "Blue Buff", value = true, leftIcon = "http://puu.sh/rPvNd/f5c6cfb97c.png"})
		self.Menu.SmiteMarker:MenuElement({id = "MarkRed", name = "Red Buff", value = true, leftIcon = "http://puu.sh/rPvQs/fbfc120d17.png"})
		self.Menu.SmiteMarker:MenuElement({id = "MarkGromp", name = "Gromp", value = true, leftIcon = "http://puu.sh/rPvSY/2cf9ff7a8e.png"})
		self.Menu.SmiteMarker:MenuElement({id = "MarkWolves", name = "Wolves", value = true, leftIcon = "http://puu.sh/rPvWu/d9ae64a105.png"})
		self.Menu.SmiteMarker:MenuElement({id = "MarkRazorbeaks", name = "Razorbeaks", value = true, leftIcon = "http://puu.sh/rPvZ5/acf0e03cc7.png"})
		self.Menu.SmiteMarker:MenuElement({id = "MarkKrugs", name = "Krugs", value = true, leftIcon = "http://puu.sh/rPw6a/3096646ec4.png"})
		self.Menu.SmiteMarker:MenuElement({id = "MarkCrab", name = "Crab", value = true, leftIcon = "http://puu.sh/rPwaw/10f0766f4d.png"})
		
		
		self.Menu:MenuElement({type = MENU, id = "SmiteDamage", name = "Draw damage in Jungle"})
		self.Menu.SmiteDamage:MenuElement({id = "Enabled", name = "Enabled", value = true})
		self.Menu.SmiteDamage:MenuElement({id = "MarkBaron", name = "Baron", value = true, leftIcon = "http://puu.sh/rPuVv/933a78e350.png"})
		self.Menu.SmiteDamage:MenuElement({id = "MarkHerald", name = "Herald", value = true, leftIcon = "http://puu.sh/rQs4A/47c27fa9ea.png"})
		self.Menu.SmiteDamage:MenuElement({id = "MarkDragon", name = "Dragon", value = true, leftIcon = "http://puu.sh/rPvdF/a00d754b30.png"})
		self.Menu.SmiteDamage:MenuElement({id = "MarkBlue", name = "Blue Buff", value = true, leftIcon = "http://puu.sh/rPvNd/f5c6cfb97c.png"})
		self.Menu.SmiteDamage:MenuElement({id = "MarkRed", name = "Red Buff", value = true, leftIcon = "http://puu.sh/rPvQs/fbfc120d17.png"})
		self.Menu.SmiteDamage:MenuElement({id = "MarkGromp", name = "Gromp", value = true, leftIcon = "http://puu.sh/rPvSY/2cf9ff7a8e.png"})
		self.Menu.SmiteDamage:MenuElement({id = "MarkWolves", name = "Wolves", value = true, leftIcon = "http://puu.sh/rPvWu/d9ae64a105.png"})
		self.Menu.SmiteDamage:MenuElement({id = "MarkRazorbeaks", name = "Razorbeaks", value = true, leftIcon = "http://puu.sh/rPvZ5/acf0e03cc7.png"})
		self.Menu.SmiteDamage:MenuElement({id = "MarkKrugs", name = "Krugs", value = true, leftIcon = "http://puu.sh/rPw6a/3096646ec4.png"})
		self.Menu.SmiteDamage:MenuElement({id = "MarkCrab", name = "Crab", value = true, leftIcon = "http://puu.sh/rPwaw/10f0766f4d.png"})
		
		self.Menu:MenuElement({id = "CustomSpellCast", name = "Use custom spellcast", tooltip = "Can fix some casting problems with wrong directions and so (thx Noddy for this one)", value = true})
		self.Menu:MenuElement({id = "delay", name = "Custom spellcast delay", value = 50, min = 0, max = 200, step = 5, identifier = ""})
		
		self.Menu:MenuElement({id = "blank", type = SPACE , name = ""})
		self.Menu:MenuElement({id = "blank", type = SPACE , name = "Script Ver: "..Version.. " - LoL Ver: "..LVersion.. ""})
		self.Menu:MenuElement({id = "blank", type = SPACE , name = "by "..Author.. ""})
	end
	
	function Kalista:Tick()
		if myHero.dead or (not _G.SDK and not _G.GOS) then return end
		local combomodeactive = (_G.SDK and _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO]) or (not _G.SDK and _G.GOS and _G.GOS:GetMode() == "Combo") 
		local harassactive = (_G.SDK and _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS]) or (not _G.SDK and _G.GOS and _G.GOS:GetMode() == "Harass") 
		local canmove = (_G.SDK and _G.SDK.Orbwalker:CanMove()) or (not _G.SDK and _G.GOS and _G.GOS:CanMove())
		local canattack = (_G.SDK and _G.SDK.Orbwalker:CanAttack()) or (not _G.SDK and _G.GOS and _G.GOS:CanAttack())
		local currenttarget = (_G.SDK and _G.SDK.Orbwalker:GetTarget()) or (not _G.SDK and _G.GOS and _G.GOS:GetTarget())
		local HarassMinMana = self.Menu.Harass.harassMana:Value()
		local QMinMana = self.Menu.Combo.qMinMana:Value()
		
		if combomodeactive and self.Menu.UseBOTRK:Value() then
			UseBotrk()
		end
		
		if ((combomodeactive) or (harassactive and myHero.maxMana * HarassMinMana * 0.01 < myHero.mana)) then
			if (harassactive or (myHero.maxMana * QMinMana * 0.01 < myHero.mana)) and not currenttarget then
				self:CastQ(currenttarget,combomodeactive or false)
			end
			if (not canattack or not currenttarget) and self.Menu.Combo.comboUseE:Value() then
				self:CastE(currenttarget,combomodeactive or false)
			end
		end
		
		if self.Menu.AlwaysKS:Value() then
			self:CastE(false,combomodeactive or false)
		end
		
		if self.Menu.Harass.harassUseELasthit:Value() then
			self:UseEOnLasthit()
		end
		if (harassactive or combomodeactive) and self:CanCast(_E) and not canattack then
			if self.Menu.Harass.harassUseERange:Value() then 
				self:UseERange()
			end
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
		onetimereset = true
		castSpell.state = 0
	end
	
	function ReturnCursor(pos)
		Control.SetCursorPos(pos)
		Control.mouse_event(MOUSEEVENTF_RIGHTDOWN)
		Control.mouse_event(MOUSEEVENTF_RIGHTUP)
		DelayAction(EnableMovement,0.1)
	end
	
	function LeftClick(pos)
		Control.mouse_event(MOUSEEVENTF_LEFTDOWN)
		Control.mouse_event(MOUSEEVENTF_LEFTUP)
		DelayAction(ReturnCursor,0.05,{pos})
	end
	
	function Kalista:CastSpell(spell,pos)
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
	
	local SmiteTable = {
		SRU_Baron = "MarkBaron",
		SRU_RiftHerald = "MarkHerald",
		SRU_Dragon_Water = "MarkDragon",
		SRU_Dragon_Fire = "MarkDragon",
		SRU_Dragon_Earth = "MarkDragon",
		SRU_Dragon_Air = "MarkDragon",
		SRU_Dragon_Elder = "MarkDragon",
		SRU_Blue = "MarkBlue",
		SRU_Red = "MarkRed",
		SRU_Gromp = "MarkGromp",
		SRU_Murkwolf = "MarkWolves",
		SRU_Razorbeak = "MarkRazorbeaks",
		SRU_Krug = "MarkKrugs",
		Sru_Crab = "MarkCrab",
	}
	
	
	function Kalista:DrawDamageMinion(type, minion, damage)
		if not type or not self.Menu.SmiteDamage[type] or not self.Menu.SmiteDamage.Enabled:Value() then
			return
		end
		if self.Menu.SmiteDamage[type]:Value() then
			local offset = self.Menu.Draw.TextOffset:Value()
			local fontsize = self.Menu.Draw.TextSize:Value()
			local InPercents = self.Menu.Draw.DrawInPrecent:Value()
			local healthremaining = InPercents and math.floor((minion.health - damage)/minion.maxHealth*100).."%" or math.floor(hero.hero.health - hero.damage,1)
			Draw.Text(healthremaining, fontsize, minion.pos2D.x, minion.pos2D.y+offset,self.Menu.Draw.DrawColor:Value())
		end
		
	end
	
	function Kalista:DrawSmiteableMinion(type,minion)
		if not type or not self.Menu.SmiteMarker[type] then
			return
		end
		if self.Menu.SmiteMarker[type]:Value() then
			if minion.pos2D.onScreen then
				Draw.Circle(minion.pos,minion.boundingRadius,6,Draw.Color(0xFF00FF00));
			end
			if self:CanCast(_E) then
				Control.CastSpell(HK_E)
			end
		end
	end
	function Kalista:HasBuff(unit, buffname)
		for K, Buff in pairs(self:GetBuffs(unit)) do
			if Buff.name:lower() == buffname:lower() then
				return Buff.expireTime
			end
		end
		return false
	end
	
	
	function Kalista:CheckKillableMinion()
		local minionlist = {}
		if _G.SDK then
			minionlist = _G.SDK.ObjectManager:GetMonsters(E.Range)
		elseif _G.GOS then
			for i = 1, Game.MinionCount() do
				local minion = Game.Minion(i)
				if minion.valid and minion.isEnemy and minion.pos:DistanceTo(myHero.pos) < E.Range then
					table.insert(minionlist, minion)
				end
			end
		end
		for i, minion in pairs(minionlist) do
			if self:GetSpears(minion) > 0 then 
				local EDamage = getdmg("E",minion,myHero)
				local minionName = minion.charName
				if EDamage*((minion.charName == "SRU_RiftHerald" and 0.65) or (self:HasBuff(myHero,"barontarget") and 0.5) or 0.79) > minion.health then
					local minionName = minion.charName
					self:DrawSmiteableMinion(SmiteTable[minionName], minion)
				else
					self:DrawDamageMinion(SmiteTable[minionName], minion, EDamage)
				end
			end
		end
	end
	function Kalista:GetBuffs(unit)
		self.T = {}
		for i = 0, unit.buffCount do
			local Buff = unit:GetBuff(i)
			if Buff.count > 0 then
				table.insert(self.T, Buff)
			end
		end
		return self.T
	end
	
	function Kalista:GetSpears(unit, buffname)
		for K, Buff in pairs(self:GetBuffs(unit)) do
			if Buff.name:lower() == "kalistaexpungemarker" then
				return Buff.count
			end
		end
		return 0
	end
	
	function Kalista:UseERange()
		local heroeslist = (_G.SDK and _G.SDK.ObjectManager:GetEnemyHeroes(1100)) or (_G.GOS and _G.GOS:GetEnemyHeroes())
		local target = (_G.SDK and _G.SDK.TargetSelector.SelectedTarget) or (_G.GOS and _G.GOS:GetTarget())
		if target then return end 
		for i, hero in pairs(heroeslist) do
			if self:GetSpears(hero) >= self.Menu.Harass.HarassMinEStacks:Value() then
				if myHero.pos:DistanceTo(hero.pos)<1000 and myHero.pos:DistanceTo(hero:GetPrediction(math.huge,0.25)) < 600 then
					return
				end
				if myHero.pos:DistanceTo(hero.pos)<1000 and myHero.pos:DistanceTo(hero:GetPrediction(math.huge,0.25)) > 700 then
					Control.CastSpell(HK_E)
				end
			end
		end
	end
	
	function Kalista:UseEOnLasthit()
		local heroeslist = (_G.SDK and _G.SDK.ObjectManager:GetEnemyHeroes(1100)) or (_G.GOS and _G.GOS:GetEnemyHeroes())
		local useE = false
		local minionlist = {}
		
		for i, hero in pairs(heroeslist) do
			if self:GetSpears(hero) >= self.Menu.Harass.HarassMinEStacks:Value() then
				if _G.SDK then
					minionlist = _G.SDK.ObjectManager:GetEnemyMinions(E.Range)
				elseif _G.GOS then
					for i = 1, Game.MinionCount() do
						local minion = Game.Minion(i)
						if minion.valid and minion.isEnemy and minion.pos:DistanceTo(myHero.pos) < E.Range then
							table.insert(minionlist, minion)
						end
					end
				end
				
				for i, minion in pairs(minionlist) do
					local spearsamount = self:GetSpears(minion)
					if spearsamount > 0 then 
						local EDamage = getdmg("E",minion,myHero)
						-- local basedmg = ({20, 30, 40, 50, 60})[level] + 0.6* (myHero.totalDamage)
						-- local perspear = ({10, 14, 19, 25, 32})[level] + ({0.2, 0.225, 0.25, 0.275, 0.3})[level]* (myHero.totalDamage)
						-- local tempdamage = basedmg + perspear*spearsamount
						if EDamage*0.8 > minion.health then
							Control.CastSpell(HK_E)
						end
					end
				end
			end
		end
	end
	
	function Kalista:GetETarget()
		self.KillableHeroes = {}
		self.DamageHeroes = {}
		local heroeslist = (_G.SDK and _G.SDK.ObjectManager:GetEnemyHeroes(1200)) or (_G.GOS and _G.GOS:GetEnemyHeroes())
		local level = myHero:GetSpellData(_E).level
		for i, hero in pairs(heroeslist) do
			if self:GetSpears(hero) > 0 and myHero.pos:DistanceTo(hero.pos)<E.Range then 
				local EDamage = getdmg("E",hero,myHero)*0.9
				if hero.health and EDamage and EDamage > hero.health then
					table.insert(self.KillableHeroes, hero)
				else
					table.insert(self.DamageHeroes, {hero = hero, damage = EDamage})
				end
			end
		end
		return self.KillableHeroes, self.DamageHeroes
	end
	
	--[[CastQ]]
	function Kalista:CastQ(target, combo)
		if (not _G.SDK and not _G.GOS) then return end
		local target = target or (_G.SDK and _G.SDK.TargetSelector:GetTarget(Q.Range, _G.SDK.DAMAGE_TYPE_PHYSICAL)) or (_G.GOS and _G.GOS:GetTarget(Q.Range,"AD"))
		if target and target.type == "AIHeroClient" and self:CanCast(_Q) and ((combo and self.Menu.Combo.comboUseQ:Value()) or (combo == false and self.Menu.Harass.harassUseQ:Value())) and target:GetCollision(Q.Width,Q.Speed,Q.Delay) == 0 then
			local castPos = target:GetPrediction(Q.Speed,Q.Delay)
			self:CastSpell(HK_Q, castPos)
		end
	end
	
	
	--[[CastE]]
	function Kalista:CastE(target,combo)
		local killable, damaged = self:GetETarget()
		if self:CanCast(_E) and #killable > 0 then
			Control.CastSpell(HK_E)
		end
	end
	
	
	
	function Kalista:IsReady(spellSlot)
		return myHero:GetSpellData(spellSlot).currentCd == 0 and myHero:GetSpellData(spellSlot).level > 0
	end
	
	function Kalista:CheckMana(spellSlot)
		return myHero:GetSpellData(spellSlot).mana < myHero.mana
	end
	
	function Kalista:CanCast(spellSlot)
		return self:IsReady(spellSlot) and self:CheckMana(spellSlot)
	end
	
	function Kalista:Draw()
		if self.Menu.SmiteMarker.Enabled:Value() then
			self:CheckKillableMinion()
		end
		local killable, damaged = self:GetETarget()
		local offset = self.Menu.Draw.TextOffset:Value()
		local fontsize = self.Menu.Draw.TextSize:Value()
		local InPercents = self.Menu.Draw.DrawInPrecent:Value()
		if self.Menu.Draw.DrawE:Value() then
			for i, hero in pairs(killable) do
				Draw.Circle(hero.pos, 80, 6, self.Menu.Draw.DrawColor:Value())
				Draw.Text("killable", fontsize, hero.pos2D.x, hero.pos2D.y+offset,self.Menu.Draw.DrawColor:Value())
			end	
		end
		if self.Menu.Draw.DrawEDamage:Value() then
			for i, hero in pairs(damaged) do
				
				local healthremaining = InPercents and math.floor((hero.hero.health - hero.damage)/hero.hero.maxHealth*100).."%" or math.floor(hero.hero.health - hero.damage,1)
				Draw.Text(healthremaining, fontsize, hero.hero.pos2D.x, hero.hero.pos2D.y+offset,self.Menu.Draw.DrawColor:Value())
			end
		end
	end
	
	function OnLoad()
		Kalista()
	end
end


if myHero.charName == "Sivir" then 
	local Scriptname,Version,Author,LVersion = "TRUSt in my Sivir","v1.0","TRUS","7.10"
	class "Sivir"
	
	function Sivir:__init()
		self:LoadMenu()
		local orbwalkername = ""
		if _G.SDK then
			orbwalkername = "IC'S orbwalker"	
			_G.SDK.Orbwalker:OnPostAttack(function() 
				local combomodeactive = _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO]
				local harassactive = _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS]
				if (combomodeactive or harassactive) and self:CanCast(_W) and self.Menu.UseW:Value()then
					Control.CastSpell(HK_W)
				end
			end)
		elseif _G.GOS then
			orbwalkername = "Noddy orbwalker"
			_G.GOS:OnAttackComplete(function() 
				local combomodeactive = _G.GOS:GetMode() == "Combo"
				local harassactive = _G.GOS:GetMode() == "Harass"
				local QMinMana = self.Menu.Combo.qMinMana:Value()	
				if (combomodeactive or harassactive) and self:CanCast(_W) and self.Menu.UseW:Value() then
					Control.CastSpell(HK_W)
				end
			end)
		else
			orbwalkername = "Orbwalker not found"
			
		end
		PrintChat(Scriptname.." "..Version.." - Loaded...."..orbwalkername)
	end
	
	
	function Sivir:LoadMenu()
		self.Menu = MenuElement({type = MENU, id = "TRUStinymySivir", name = Scriptname})
		
		--[[Combo]]
		self.Menu:MenuElement({id = "UseW", name = "Use W", value = true})
		
		
		self.Menu:MenuElement({id = "blank", type = SPACE , name = ""})
		self.Menu:MenuElement({id = "blank", type = SPACE , name = "Script Ver: "..Version.. " - LoL Ver: "..LVersion.. ""})
		self.Menu:MenuElement({id = "blank", type = SPACE , name = "by "..Author.. ""})
	end
	
	
	local castSpell = {state = 0, tick = GetTickCount(), casting = GetTickCount() - 1000, mouse = mousePos}
	
	function Sivir:IsReady(spellSlot)
		return myHero:GetSpellData(spellSlot).currentCd == 0 and myHero:GetSpellData(spellSlot).level > 0
	end
	
	function Sivir:CheckMana(spellSlot)
		return myHero:GetSpellData(spellSlot).mana < myHero.mana
	end
	
	function Sivir:CanCast(spellSlot)
		return self:IsReady(spellSlot) and self:CheckMana(spellSlot)
	end
	
	function OnLoad()
		Sivir()
	end
	
end