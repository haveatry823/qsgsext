dofile "lua/config.lua"
dofile "lua/sgs_ex.lua"

module("extensions.endlesspk", package.seeall)
extension = sgs.Package("endlesspk")
elanjiang=sgs.General(extension, "elanjiang", "qun", 5, true,true,true)

endlessskill = sgs.CreateTriggerSkill{
	name = "#endlessskill",
	events = {sgs.GameStart,sgs.AskForPeaches,sgs.MaxHpChanged},
	priority = 5,
	can_trigger = function()
		return true
	end,

	on_trigger = function(self, event, player, data)
		local room = player:getRoom()
		local isowner= room:getOwner():objectName()==player:objectName()
		local owner=room:getOwner()
		local ai=owner:getNext()

		if room:getMode()~="02p" then return false end

		if event ==sgs.GameStart and room:getTag("initGameEndlessPK"):toBool()==false then
			room:setTag("initGameEndlessPK",sgs.QVariant(true))
			
			local choice=room:askForChoice(owner,"@choosePKmode","cancelpk+throwall+throwequip+thrownone")
			room:setTag("useEndlessPK",sgs.QVariant(choice))

			if choice~="cancelpk" then
				room:setPlayerMark(owner, "@nirvana",3)
				room:setPlayerMark(ai, "@nirvana",99)
				room:detachSkillFromPlayer(owner, "niepan")
				room:detachSkillFromPlayer(ai, "niepan")
				room:acquireSkill(owner,"pkrecordvs")
			end
		end

		if event ==sgs.MaxHpChanged and room:getTag("useEndlessPK"):toString()~="cancelpk" then
			if player:getMaxHp()<1 then
				room:setPlayerMark(player,"maxhpdown",1)
				room:setPlayerProperty(player, "maxhp", sgs.QVariant(1))
				room:setPlayerProperty(player, "hp", sgs.QVariant(0))
				room:loseHp(player)
			end
		end

		if event ==sgs.AskForPeaches and room:getTag("useEndlessPK"):toString()~="cancelpk" then
			local dying=data:toDying()
			local who=dying.who
			if who:getMark("@nirvana")<1 then 
				return false
			end
			if who:getMark("maxhpdown")==1 then
				useSkillNiepan(room,who)
				return false
			end
			local n = 0
			for _, card in sgs.qlist(who:getHandcards()) do
				if card:isKindOf("Peach") or card:isKindOf("Analeptic") then
					n = n + 1
				end
				if who:hasSkill("wushen") and card:isKindOf("Peach") and card:getSuit()==sgs.Card_Heart then
					n = n - 1
				end
				if who:hasSkill("jinjiu") and card:isKindOf("Analeptic") then
					n = n - 1
				end
			end
			if who:getHp()+n < 1 then
				if who:objectName()==ai:objectName() or ( who:objectName()==owner:objectName() and who:askForSkillInvoke("useniepan")) then
					useSkillNiepan(room,who)
				end
			end
			return false
		end
		return false
	end,
}

function useSkillNiepan(room,who)
	-- 因为 标记原因，禁止下面几个将
	local banstr=",zuoci,shenzhugeliang,shenlvbu,shensimayi,bgm_lvmeng,bgm_pangtong,"

	local isowner= room:getOwner():objectName()==who:objectName()
	local owner=room:getOwner()
	local ai=owner:getNext()
	local mode=room:getTag("useEndlessPK"):toString()
	local newname=who:getGeneralName()
	local names

	if not isowner then
		local victim=sgs.Sanguosha:translate(who:getGeneralName())
		local num=99 - who:getMark("@nirvana") + 1
		owner:speak(string.format("#%d. <font color=red>%s</font>跪了.",num,victim))

		if mode=="throwequip" then 
			owner:throwAllEquips() 
		elseif mode=="throwall" then
			owner:throwAllCards()
			owner:drawCards(3)
		end
		repeat
			names=sgs.Sanguosha:getRandomGenerals(1)
			if string.match(banstr,","..names[1]..",")==nil then break end
		until false
		newname=names[1]
	else
		if who:getGeneral2() then
			repeat
				names=sgs.Sanguosha:getRandomGenerals(1)
				if string.match(banstr,","..names[1]..",")==nil then break end
			until false
			newname=names[1]
		else
			names=table.concat(sgs.Sanguosha:getRandomGenerals(10),"+")
			local choice=room:askForChoice(who,"@chooseGeneral","cancel+"..names)
			if choice~='cancel' then newname=choice end
		end
	end

	for _,skill in sgs.qlist(who:getVisibleSkillList()) do
		if skill:getLocation()==sgs.Skill_Right then
			room:detachSkillFromPlayer(who, skill:objectName())
		end
	end
	
	if who:getGeneral2() then 
		room:changeHero(who, who:getGeneral2Name(), true, true, true, false) 
	end
	room:changeHero(who, newname, true, true, false, true)
	room:setPlayerProperty(who, "kingdom", sgs.QVariant(who:getGeneral():getKingdom()))
	who:setGender(who:getGeneral():getGender())

	room:acquireSkill(owner,"pkrecordvs")
	room:setTag("SwapPile",sgs.QVariant(0))

	room:detachSkillFromPlayer(who, "niepan")
	room:broadcastInvoke("animate", "lightbox:$niepan")
	room:broadcastSkillInvoke("niepan")
	
	local num= who:getMark("@nirvana")-1
	who:bury()
	if num>0 then room:setPlayerMark(who, "@nirvana",num) end
	who:drawCards(3)

	if who:isChained()  then who:setChained(false) end
	if not who:faceUp() then who:turnOver() end
end


--[[
格式：
..1.........2.............3.....4....5.....6......7.......8........9.......10....11.....12......13........14..........15.........16....::: 
state|generalname|general2name|maxhp|hp|kingdom|chained|faceup|slashcount|flags|marks|skills|handcards|equipcards|judgecards|piplecards:::
]]
pkrecordcard=sgs.CreateSkillCard{
	name="pkrecordcard",
	target_fixed=true,
	will_throw=false,
	on_use = function(self, room, source, targets)	
		local owner=room:getOwner()
		local ai=owner:getNext()
		local players={owner,ai}
		local fname="./etc/endless.png"
		local content=""
		
		--神杀没有提供 marks的枚举接口，只能来蛮的
		local marklist="@beam,@bear,@burnheart,@chaos,@chou,@chuanqi,@collapse,@conspiracy,@duanchang,@earth,@fenyong,@fire,@flame,@fog,"
		marklist=marklist.."@frantic,@gale,@hate,@jueji,@kuiwei,@laoji,@nightmare,@nirvana,@round,@shouye,@sleep,@struggle,@thunder,"
		marklist=marklist.."@tied,@waked,@water,@wen,@wind,@wrath,@wu,@xiongyi,@zhenggong,"
		marklist=marklist.."anxian,chengxiang,danji,fenyong,frantic_over,hunzi,haoshi,JilveEvent,lianpo,forbid_shien,jiehuo,baiyin,"
		marklist=marklist.."shuangxiong,qinyin,qixingOwner,qiaobianPhase,xiangle,ruoyu,rende,juao,longluo,shouyeonce,"
		marklist=marklist.."qinggang,shichouInvoke,kegou,lexue,SlashCount,secondMode,xuanfeng,zuixiangHasTrigger,zaoxian,zili,zhiji"
		
		local marks=marklist:split(",")
		
		local pilelist="dream,brocade,junwei-equip,#xuehen,stars,field,buqu,hautain,rice,power,wine"
		local piles=pilelist:split(",")
		
		for i=0, sgs.Sanguosha:getCardCount()-1, 1 do		
			if sgs.Sanguosha:getCard(i) then
				local pile1=owner:getPileName(i)
				local pile2=ai:getPileName(i)
				if pile1 and pile1~="" and not table.contains(piles,pile1) then table.insert(piles,pile1) end
				if pile2 and pile2~="" and not table.contains(piles,pile2) then table.insert(piles,pile2) end
			end
		end

		local fp=io.open(fname,"rb")
		if fp then
			content=fp:read("*a")
			local arr={}
			for num in string.gmatch(content, "@nirvana:([0-9]+)") do	table.insert(arr,num) end
			if #arr==2 then
				owner:speak(string.format("原存档中的复活标记 <font color=red>%d:%d</font>",arr[1],arr[2]))
			else
				content=""
			end
			fp:close()
		end

		local choice=room:askForChoice(owner,"@chooseGeneral","cancel+loadrecord+saverecord")
		if choice=='saverecord' then
			local fp = io.open(fname,"wb")
			for _,p in ipairs(players) do
				local line={}
				table.insert(line,p:getState())
				table.insert(line,p:getGeneralName())
				table.insert(line,p:getGeneral2Name())
				table.insert(line,p:getMaxHp())
				table.insert(line,p:getHp())
				table.insert(line,p:getKingdom())
				table.insert(line,p:isChained() and '1' or '0')
				table.insert(line,p:faceUp() and '1' or '0')
				table.insert(line,p:getSlashCount())
				table.insert(line,p:getFlags())
				
				local markarr={}
				for _,mark in ipairs(marks) do
					if p:getMark(mark)>0 or mark=='@nirvana' then table.insert(markarr,string.format("%s:%d",mark,p:getMark(mark))) end
				end
				table.insert(line,table.concat(markarr,","))
				
				local skillarr={}
				for _,skill in sgs.qlist(p:getVisibleSkillList()) do
					if skill:getLocation()==sgs.Skill_Right then
						table.insert(skillarr,skill:objectName())
					end
				end
				table.insert(line,table.concat(skillarr,","))

				table.insert(line,table.concat(sgs.QList2Table(p:handCards()),","))
				
				local equiparr={}
				for i=0,3,1 do
					table.insert(equiparr,p:getEquip(i) and p:getEquip(i):getEffectiveId() or "-1")
				end
				table.insert(line,table.concat(equiparr,","))
				
				local judgearr={}
				for _,card in sgs.qlist(p:getJudgingArea()) do
					table.insert(judgearr,card:getEffectiveId())
				end
				table.insert(line,table.concat(judgearr,","))
				
				local pilearr={}
				for _,pile in ipairs(piles) do
					local cards=sgs.QList2Table(p:getPile(pile))
					if #cards>0 then
						table.insert(pilearr,string.format("%s:%s",pile,table.concat(cards,",")))
					end
				end
				table.insert(line,table.concat(pilearr,"+"))

				fp:write(table.concat(line,"|")..":::")
			end			
			fp:close()
			owner:speak("已保存游戏记录")
		elseif choice=='loadrecord' then
			if content=="" then
				owner:speak("暂无存档记录")
				return false
			end

			local arr=content:split(":::")

			for _,skill in sgs.qlist(ai:getVisibleSkillList()) do
				ai:loseSkill(skill:objectName())
			end
			for _,skill in sgs.qlist(owner:getVisibleSkillList()) do
				owner:loseSkill(skill:objectName())
			end

			for _,line in ipairs(arr) do
				local item=line:split("|")
				if #item==16 and (item[1]=='online' or item[1]=='robot') then
					local p= item[1]=='robot' and ai or owner
					p:bury()
					if sgs.Sanguosha:getGeneral(item[2]) then room:changeHero(p, item[2], true, true, false, true) end
					if sgs.Sanguosha:getGeneral(item[3]) then room:changeHero(p, item[3], true, true, true, false) end

					item[4]=tonumber(item[4])
					item[5]=tonumber(item[5])
					if item[4]>=1 and item[4]<=999 then room:setPlayerProperty(p, "maxhp", sgs.QVariant(item[4])) end
					if item[5]>=-20 and item[5]<=999 then room:setPlayerProperty(p, "hp", sgs.QVariant(item[5])) end

					p:setGender(p:getGeneral():getGender())
					if item[6]=='wei' or item[6]=='shu' or item[6]=='wu' or item[6]=='qun' then 
						room:setPlayerProperty(p, "kingdom", sgs.QVariant(item[6])) 
					end

					p:setChained(item[7]=="1")
					p:setFaceUp(item[8]=="1")
					
					--slash history
					item[9]=tonumber(item[9])
					if item[9]>0 then p:addHistory("Slash",item[9]) end

					--flags
					if item[10]~="" then
						for _,flag in ipairs(item[10]:split("+")) do
							p:setFlags(flag)
						end
					end

					--marks
					if item[11]~="" then
						for _,mark in ipairs(item[11]:split(",")) do
							if string.match(mark,"^@?[_a-zA-Z]+:[0-9]+$") then
								local markpart=mark:split(":")
								if string.match(marklist,markpart[1]) and tonumber(markpart[2])>0 then 
									room:setPlayerMark(p,markpart[1],tonumber(markpart[2])) 
								end
							end
						end
					end

					--skills
					for _,skill in sgs.qlist(p:getVisibleSkillList()) do
						p:loseSkill(skill:objectName())
					end					
					if item[12]~="" then
						for _,skill in ipairs(item[12]:split(",")) do
							if sgs.Sanguosha:getSkill(skill) and not p:hasSkill(skill) then
								room:acquireSkill(p,skill)
							end
						end
					end
					
					--handcard
					if item[13]~="" then
						for _,cid in ipairs(item[13]:split(",")) do
							cid=tonumber(cid)
							if sgs.Sanguosha:getCard(cid) then room:obtainCard(p,cid) end
						end
					end
					
					--equip
					if item[14]~="" then
						for _,cid in ipairs(item[14]:split(",")) do
							cid=tonumber(cid)
							if cid>=0 and sgs.Sanguosha:getCard(cid) and sgs.Sanguosha:getCard(cid):isKindOf("EquipCard") then
								room:moveCardTo(sgs.Sanguosha:getCard(cid), p, sgs.Player_PlaceEquip, true)
							end
						end
					end

					--judge cards
					if item[15]~="" then
						for _,cid in ipairs(item[15]:split(",")) do
							cid=tonumber(cid)
							if cid>=0 and sgs.Sanguosha:getCard(cid) then 
								room:moveCardTo(sgs.Sanguosha:getCard(cid), p, sgs.Player_PlaceDelayedTrick, true)
							end
						end
					end
					
					--piles
					if item[16]~="" then
						for _,pile in ipairs(item[16]:split("+")) do
							if string.match(pile,"^#?[-a-zA-Z0-9_]+:[,0-9]+$") then
								local pilearr=pile:split(":")
								if table.contains(piles,pilearr[1]) then
									for _,cid in ipairs(pilearr[2]:split(",")) do
										cid=tonumber(cid)
										if cid>=0 and sgs.Sanguosha:getCard(cid) then 
											p:addToPile(pilearr[1],cid)
										end
									end	
								end
							end
						end
					end

				end 
			end 
		end 
	end,
}

pkrecordvs=sgs.CreateViewAsSkill{
	name="pkrecordvs",
	n=0,
	view_as = function(self, cards)
		local card=pkrecordcard:clone()
		card:setSkillName(self:objectName())
		return card
	end,
	enabled_at_play=function(self, player)
		return true
	end,
}



function initEndlessMode()
	local generalnames=sgs.Sanguosha:getLimitedGeneralNames()
	local hidden={"sp_diaochan","sp_sunshangxiang","sp_pangde","sp_caiwenji","sp_machao","sp_jiaxu","anjiang","shenlvbu1","shenlvbu2"}
	table.insertTable(generalnames,hidden)
	for _, generalname in ipairs(generalnames) do
		local general = sgs.Sanguosha:getGeneral(generalname)
		if general then 
			general:addSkill("#endlessskill")			
		end
	end
end

elanjiang:addSkill(endlessskill)
elanjiang:addSkill(pkrecordvs)
initEndlessMode()

sgs.LoadTranslationTable {
	["endlesspk"] ="无尽模式包",

	["@choosePKmode"] ="选择游戏模式",
	["@chooseGeneral"] ="选择武将",
	["pkrecordcard"] = "存档",
	["pkrecordvs"] = "存档",
	["saverecord"] = "保存进度",
	["loadrecord"] = "读取进度",
	["cannel"] = "取消",

	["useniepan"] = "涅槃",

	["cancelpk"]   ="取消,不开启无尽模式",
	["throwall"]   ="无尽模式一: AI倒下时,你弃掉所有牌并摸三牌",
	["throwequip"] ="无尽模式二: AI倒下时,你只弃掉装备牌",
	["thrownone"]  ="无尽模式三: AI倒下时,你不弃任何牌",
}