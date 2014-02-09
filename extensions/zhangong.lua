enableSkillCard = 1		-- 是否开启技能卡， 1:开启, 0:不开启
--enableLuckyCard = 1		-- 是否开启手气卡,  1:开启, 0:不开启
enableHulaoCard = 1		-- 是否开启虎牢关点将卡,  1:开启, 0:不开启

zgver='20131217'

dofile "lua/config.lua"
dofile "lua/sgs_ex.lua"

module("extensions.zhangong", package.seeall)
extension = sgs.Package("zhangong")
zganjiang=sgs.General(extension, "zganjiang", "qun", 5, true,true,true)

zgfunc={}
zgturndata={}
zggamedata={}

zggamedata.turncount=0
zggamedata.roomid=0
zggamedata.enable=0
zggamedata.hegemony=0

zgfunc[sgs.CardEffect]={}
zgfunc[sgs.CardEffected]={}
zgfunc[sgs.CardFinished]={}
zgfunc[sgs.CardUsed]={}
zgfunc[sgs.CardsMoveOneTime]={}
zgfunc[sgs.CardResponded]={}
zgfunc[sgs.ChoiceMade]={}
zgfunc[sgs.AfterDrawNCards]={}
zgfunc[sgs.AfterDrawInitialCards] = {}


zgfunc[sgs.PreDamageDone]={}
zgfunc[sgs.Damage]={}
zgfunc[sgs.DamageCaused]={}
zgfunc[sgs.Damaged]={}
zgfunc[sgs.DamageComplete]={}
zgfunc[sgs.DamageInflicted]={}


zgfunc[sgs.Death]={}
zgfunc[sgs.Dying]={}
zgfunc[sgs.EventPhaseEnd]={}
zgfunc[sgs.EventPhaseStart]={}

zgfunc[sgs.FinishRetrial]={}

zgfunc[sgs.GameStart]={}
zgfunc[sgs.GameOverJudge]={}
zgfunc[sgs.GameOverJudge]["callback"]={}
zgfunc[sgs.HpRecover]={}
zgfunc[sgs.HpChanged]={}

zgfunc[sgs.SlashHit]={}
zgfunc[sgs.SlashEffected]={}
zgfunc[sgs.SlashMissed]={}

zgfunc[sgs.TurnStart]={}
zgfunc[sgs.Pindian]={}
zgfunc[sgs.Predamage]={}

local db

function logmsg(fmt,...)
	local fp = io.open("zgdebug.log","ab")
	local arg = {...}
	if type(fmt)=="boolean" then fmt = fmt and "true" or "false" end
	fp:write(string.format(fmt, unpack(arg)).."\r\n")	
	fp:close()
end

function sqlexec(sql,...)
	local arg = {...}	
	local sqlstr=string.format(sql, unpack(arg))
	db:exec(sqlstr)
end

function isSameGroup(a,b)
	local role1=a:getRole()
	local role2=b:getRole()
	if role1=="lord" then role1="loyalist" end
	if role2=="lord" then role2="loyalist" end
	if a:getRoom():getMode() == "06_3v3" then
		if role1=="renegade" then role1="rebel" end
		if role2=="renegade" then role2="rebel" end
	end
	return role1==role2 and role1~="renegade"
end


-- wenwu ::  :: 每打出或使用一个【杀】,增加一点武功;  每打出或使用一个锦囊,增加一点文功
--
zgfunc[sgs.CardFinished].wenwu=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	local use=data:toCardUse()
	local card=use.card
	if card:isKindOf("TrickCard") then addTurnData("wen",1) end
	if card:isKindOf("Slash") then addTurnData("wu",1) end
end

-- expval ::  :: 每造成一点伤害，增加一点经验，最高限8点
--
zgfunc[sgs.Damage].expval=function(self, room, event, player, data,isowner,name)
	local damage = data:toDamage()
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() then
		addTurnData("expval",math.min(damage.damage,8))
	end
end

-- init ::  :: 更新results, 将所有的 turndata重置为0
--
zgfunc[sgs.TurnStart].init=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	addGameData("turncount",1)
	local alive=room:getOwner():isAlive() and 1 or 0
	local kingdom=room:getOwner():getKingdom()
	if kingdom=="god" and getGameData("hegemony")==1 then kingdom=room:getOwner():getGeneral():getKingdom() end

	sqlexec("update results set general='%s',kingdom='%s',turncount=%d,alive=%d,wen=wen+%d,wu=wu+%d,expval=expval+%d where id=%d",
			room:getOwner():getGeneralName(),kingdom,getGameData("turncount"), alive,getTurnData("wen"),
			getTurnData("wu"),getTurnData("expval"),getGameData("roomid"))
	for key,val in pairs(zgturndata) do
		zgturndata[key]=0
	end
end

-- 游戏结束判断代码
-- 因为游戏结束的时候，当前阵亡的人的 sgs.Death 事件不会被触发，sgs.cardFinished也不会被触发，这里额外处理
-- zgfunc[sgs.GameOverJudge]["callback"] 处理最后一个阵亡的人的 Death事件
zgfunc[sgs.GameOverJudge].tongji=function(self, room, event, player, data,isowner,name)
	local winner=getWinner(room,player)
	if not winner then return false end
	local winlist= winner:split("+")
	local owner=room:getOwner()
	local result = (table.contains(winlist, owner:getRole()) or table.contains(winlist, owner:objectName())) and 'win' or 'lose'
	local alive=owner:isAlive() and 1 or 0
	local damage =data:toDeath().damage

	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() then
		addTurnData("expval", math.min(damage.damage,8))
		if damage.card then
			if damage.card:isKindOf("TrickCard") then addTurnData("wen",1) end
			if damage.card:isKindOf("Slash") then addTurnData("wu",1) end
		end
		gainSkill(room)
	end

	local kingdom=room:getOwner():getKingdom()
	if kingdom=="god" and getGameData("hegemony")==1 then kingdom=room:getOwner():getGeneral():getKingdom() end

	sqlexec("update results set kingdom='%s', general='%s',turncount=%d,alive=%d,result='%s',wen=wen+%d,wu=wu+%d,expval=expval+%d where id=%d",
			kingdom,owner:getGeneralName(),getGameData("turncount"),alive,result,getTurnData("wen"),
			getTurnData("wu"),getTurnData("expval"),getGameData("roomid"))

	local callbacks=zgfunc[sgs.GameOverJudge]["callback"]
	for name, func in pairs(callbacks) do
		if type(func)=="function" then func(room,player,data,name,result) end
	end
	for row in db:rows("select * from results where id= "..getGameData("roomid")) do
		broadcastMsg(room,"#gainWen",row.wen)
		broadcastMsg(room,"#gainWu",row.wu)
		broadcastMsg(room,"#gainExp",row.expval)
	end

	setGameData("status",0)
end


-- bj :: 暴君 :: 身为主公在1局游戏中，在反贼和内奸全部存活的情况下杀死全部忠臣，并最后胜利
--
zgfunc[sgs.Death].bj=function(self, room, event, player, data,isowner,name)
	local damage = data:toDeath().damage
	if not damage then return false end
	if getGameData("hegemony")==1 then return false end
	if room:getOwner():isLord() and damage.from and damage.from:objectName()==room:getOwner():objectName()
		and damage.to:getRole()=="loyalist" then
		local players = room:getPlayers()
		local enemy_dead=0
		for _, p in sgs.qlist(players) do
			if p:getRole()=="rebel" or p:getRole()=="renegade" then
				if p:isDead() then enemy_dead=enemy_dead+1 end
			end
		end
		if enemy_dead==0 then addGameData(name,1) end
	end
end


-- bj :: 暴君 :: 身为主公在1局游戏中，在反贼和内奸全部存活的情况下杀死全部忠臣，并最后胜利
--
zgfunc[sgs.GameOverJudge].callback.bj=function(room,player,data,name,result)
	if result~='win' or not room:getOwner():isLord() then return false end
	if getGameData("hegemony")==1 then return false end
	local loyalist_num=0
	for _,ap in sgs.qlist(room:getPlayers()) do
		if ap:getRole()=="loyalist" then
			if ap:isAlive() then return false
			else
				loyalist_num=loyalist_num+1
			end
		end
	end
	if getGameData(name)==loyalist_num and loyalist_num>0 then
		addZhanGong(room,name)
	end
end


-- bjz :: 败家子 :: 在一局游戏中，弃牌阶段累计弃掉至少10张桃
--
zgfunc[sgs.CardsMoveOneTime].bjz=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	local move = data:toMoveOneTime()
	if not move.from then return false end
	local reason = move.reason
	
	if player:getPhase() ~= sgs.Player_Discard then return false end
	--if reason.m_reason ~= sgs.CardMoveReason_S_REASON_RULEDISCARD then return false end
	if player:objectName() ~= move.from:objectName() then return false end
	if bit32.band(reason.m_reason, sgs.CardMoveReason_S_MASK_BASIC_REASON) ~= sgs.CardMoveReason_S_REASON_DISCARD then return false end

	for i = 0, move.card_ids:length()-1 do
		local cdid=move.card_ids:at(i)
		if sgs.Sanguosha:getCard(cdid):isKindOf("Peach") then
			addGameData(name,1)
			if getGameData(name)==10 then addZhanGong(room,name) end
		end
	end
end


-- bqbr :: 不屈不饶 :: 一格体力情况下，累积出闪100次
--
zgfunc[sgs.CardResponded].bqbr=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	if player:getHp() == 1 and data:toCardResponse().m_card:isKindOf("Jink") then
		addGlobalData(name,1)
		local zgquery=db:first_row("select gained from zhangong where id='"..name.."'")
		if getGlobalData(name)>=100 and zgquery and zgquery.gained==0 then
			addZhanGong(room,name)
		end
	end
end


-- bqk :: 兵器库 :: 在一局游戏中，累计装备过至少10次武器以及10次防具
--
zgfunc[sgs.CardFinished].bqk=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	local use=data:toCardUse()
	if use.card:isKindOf("Weapon") then
		addGameData(name.."_weapon", 1)
		if getGameData(name.."_weapon")>=10 and getGameData(name.."_armor")>=10 then
			addZhanGong(room,name)
			setGameData(name.."_weapon", -100)
		end
	elseif use.card:isKindOf("Armor") then
		addGameData(name.."_armor", 1)
		if getGameData(name.."_weapon")>=10 and getGameData(name.."_armor")>=10 then
			addZhanGong(room,name)
			setGameData(name.."_armor", -100)
		end
	end
end


-- brz :: 百人斩 :: 累积杀死100人
--
zgfunc[sgs.Death].brz=function(self, room, event, player, data,isowner,name)
	local damage=data:toDeath().damage
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() then
		addGlobalData(name,1)
		local zgquery=db:first_row("select gained from zhangong where id='"..name.."'")
		if getGlobalData(name)>=100 and zgquery and zgquery.gained==0 then
			addZhanGong(room,name)
		end
	end
end


zgfunc[sgs.GameOverJudge].callback.brz=function(room,player,data,name,result)
	local damage=data:toDeath().damage
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() then
		addGlobalData(name,1)
		local zgquery=db:first_row("select gained from zhangong where id='"..name.."'")
		if getGlobalData(name)>=100 and zgquery and zgquery.gained==0 then
			addZhanGong(room,name)
		end
	end
end


-- cqb :: 拆迁办 :: 在一个回合内使用卡牌过河拆桥/顺手牵羊累计4次
--
zgfunc[sgs.CardFinished].cqb=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	local use = data:toCardUse()
	if use.card:isKindOf("Dismantlement") or use.card:isKindOf("Snatch") then
		addTurnData(name,1)
		if getTurnData(name)==4 then addZhanGong(room,name) end
	end
end


-- cqdd :: 拆迁大队 :: 在一局游戏中，累计使用卡牌过河拆桥10次以上
--
zgfunc[sgs.CardFinished].cqdd=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	local use = data:toCardUse()
	if use.card:isKindOf("Dismantlement") then
		addGameData(name,1)
		if getGameData(name)==10 then addZhanGong(room,name) end
	end
end


-- dgxl :: 东宫西略 :: 在一局游戏中，身份为男性主公，而忠臣为两名女性武将并在女性忠臣全部存活的情况下获胜
--
zgfunc[sgs.GameOverJudge].callback.dgxl=function(room,player,data,name,result)
	if getGameData("hegemony")==1 then return false end
	local female_loyalist = 0
	local female_loyalist_alive = true
	for _,op in sgs.qlist(room:getPlayers()) do
		if op:getRole()=="loyalist" and op:isFemale() then
			female_loyalist = female_loyalist+1
			if not op:isAlive() then female_loyalist_alive = false end
		end
	end
	if result =='win' and room:getOwner():isLord() and room:getOwner():isMale()
			and female_loyalist>=2 and female_loyalist_alive then
		addZhanGong(room,name)
	end
end


-- gjcc :: 诡计重重 :: 在一局游戏中，累计使用锦囊牌至少20次
--
zgfunc[sgs.CardFinished].gjcc=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	local use = data:toCardUse()
	if use.card:isKindOf("TrickCard") then 
		addGameData(name,1)
		if getGameData(name)==20 then addZhanGong(room,name) end
	end
end


-- gn :: 果农 :: 游戏开始时，起手手牌全部是“桃”
--
zgfunc[sgs.AfterDrawInitialCards].gn=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	local count=0
	for _,cd in sgs.qlist(player:getHandcards()) do
		if not cd:isKindOf("Peach") then return false end
		count = count + 1
	end
	if getGameData(name,0)==0 and count>=3 and getGameData("turncount")==0 then
		setGameData(name,1)
		addZhanGong(room,name)
	end
end


-- htdl :: 黄天当立 :: 使用张角在一局游戏中从群雄武将处得到的闪不少于8张
--
zgfunc[sgs.CardsMoveOneTime].htdl=function(self, room, event, player, data,isowner,name)
	if not string.find(room:getOwner():getGeneralName(), "zhangjiao") then return false end
	if not isowner then return false end
	local move=data:toMoveOneTime()
	local ids=sgs.QList2Table(move.card_ids)
	local from_places=sgs.QList2Table(move.from_places)
	if table.contains(from_places,sgs.Player_PlaceHand) and move.to_place==sgs.Player_PlaceHand
			and move.to:objectName()==room:getOwner():objectName() and move.from:getKingdom()=='qun' then
		for i=1,#ids,1 do
			local card=sgs.Sanguosha:getCard(ids[i])
			if card:isKindOf("Jink") then
				addGameData(name,1)
				if getGameData(name)==8 then
					addZhanGong(room,name)
				end
			end
		end
	end
end


-- jdfy :: 绝对防御 :: 在一局游戏中，使用八挂累计出闪20次
--
zgfunc[sgs.FinishRetrial].jdfy=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	local judge=data:toJudge()
	if ((judge.reason=="EightDiagram") or (judge.reason == "bazhen")) and judge.who:objectName()==room:getOwner():objectName() and judge:isGood() then
		addGameData(name,1)
		if getGameData(name)==20 then
			addZhanGong(room,name)
		end
	end
end

-- jg :: 酒鬼 :: 出牌阶段开始时，手牌中至少有3张“酒”
--
zgfunc[sgs.EventPhaseStart].jg=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	if player:getPhase()==sgs.Player_Play and player:getHandcardNum()>2 then
		local analeptic_num=0
		for _,cd in sgs.qlist(player:getHandcards()) do
			if cd:isKindOf("Analeptic") then
				analeptic_num=analeptic_num+1
			end
		end
		if analeptic_num>=3 and getGameData(name)==0 then
			addGameData(name,1)
			addZhanGong(room,name)
		end
	end
end


-- jhlt :: 举火燎天 :: 在一局游戏中，造成火焰伤害累计10点以上，不含武将技能
--
zgfunc[sgs.Damage].jhlt=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	local damage=data:toDamage()
	if damage and damage.card and (not damage.card:isKindOf("SkillCard")) and damage.nature==sgs.DamageStruct_Fire then
		addGameData(name,damage.damage)
		if getGameData(name)>=10 then 
			addZhanGong(room,name) 
			setGameData(name, -100)
		end
	end
end


-- qrz :: 千人斩 :: 累积杀1000人
--
zgfunc[sgs.Death].qrz=function(self, room, event, player, data,isowner,name)
	local damage=data:toDeath().damage
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() then
		addGlobalData(name,1)
		local zgquery=db:first_row("select gained from zhangong where id='"..name.."'")
		if getGlobalData(name)>=1000 and zgquery and zgquery.gained==0 then
			addZhanGong(room,name)
		end
	end
end


zgfunc[sgs.GameOverJudge].callback.qrz=function(room,player,data,name,result)
	local damage=data:toDeath().damage
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() then
		addGlobalData(name,1)
		local zgquery=db:first_row("select gained from zhangong where id='"..name.."'")
		if getGlobalData(name)>=1000 and zgquery and zgquery.gained==0 then
			addZhanGong(room,name)
		end
	end
end


-- qshs :: 起死回生 :: 在一局游戏中，累计受过至少20点伤害且最后存活获胜
--
zgfunc[sgs.Damaged].qshs=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	local damage=data:toDamage()
	addGameData(name, damage.damage)
end


-- qshs :: 起死回生 :: 在一局游戏中，累计受过至少20点伤害且最后存活获胜
--
zgfunc[sgs.GameOverJudge].callback.qshs=function(room,player,data,name,result)
	if getGameData(name)>=20 and result=='win' and room:getOwner():isAlive() then addZhanGong(room,name) end
end


-- stzs :: 神偷再世 :: 在一局游戏中，累计使用卡牌顺手牵羊10次以上
--
zgfunc[sgs.CardFinished].stzs=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	local use = data:toCardUse()
	if use.card:isKindOf("Snatch") then
		addGameData(name,1)
		if getGameData(name)==10 then addZhanGong(room,name) end
	end
end


-- thy :: 桃花运 :: 当你的开局手牌全部为红桃时，体力上限加1
--
zgfunc[sgs.AfterDrawInitialCards].thy=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	local count=0
	for _,cd in sgs.qlist(player:getHandcards()) do
		if cd:getSuit()~=sgs.Card_Heart then return false end
		count=count+1
	end
	if getGameData(name,0) == 0 and count>=3 and getGameData("turncount")==0 then
		setGameData(name,1)
		addZhanGong(room,name)
		room:setPlayerProperty(player, "maxhp", sgs.QVariant(player:getMaxHp()+1))
	end
end


-- tyzy :: 桃园之义 :: 在一局游戏中，场上同时存在刘备、关羽、张飞三人且为队友，而你是其中一个并最后获胜
--
zgfunc[sgs.GameOverJudge].callback.tyzy=function(room,player,data,name,result)
	if result~='win' then return false end
	local has_liubei,has_guanyu,has_zhangfei,issjy=false,false,false,false
	local owner = room:getOwner()
	for _,ap in sgs.qlist(room:getPlayers()) do
		local gname = ap:getGeneralName()
		if isSameGroup(owner,ap) then
			if string.find(gname, "liubei") then
				has_liubei=true
				if owner:objectName()==ap:objectName() then issjy=true end
			elseif string.find(gname, "guanyu") then
				has_guanyu=true
				if owner:objectName()==ap:objectName() then issjy=true end
			elseif string.find(gname, "zhangfei") then
				has_zhangfei=true
				if owner:objectName()==ap:objectName() then issjy=true end
			end
		end
	end
	if has_liubei and has_guanyu and has_zhangfei and issjy then
		addZhanGong(room, name)
	end
end



-- wsww :: 为时未晚 :: 身为反贼，在一局游戏中杀死了除自己以外所有反贼并获得游戏的胜利
--
zgfunc[sgs.Death].wsww=function(self, room, event, player, data,isowner,name)
	local damage = data:toDeath().damage
	if not damage then return false end
	if getGameData("hegemony")==1 then return false end
	if room:getOwner():getRole()=="rebel" and damage.from and damage.from:objectName()==room:getOwner():objectName() 
		and damage.to:getRole()=="rebel" then
		addGameData(name,1)
	end	
end


-- wsww :: 为时未晚 :: 身为反贼，在一局游戏中杀死了除自己以外所有反贼并获得游戏的胜利
--
zgfunc[sgs.GameOverJudge].callback.wsww=function(room,player,data,name,result)
	if result~='win' then return false end
	if getGameData("hegemony")==1 then return false end
	local rebel_num=0
	for _,ap in sgs.qlist(room:getPlayers()) do
		--这里不能把自己计算在内
		if ap:getRole()=="rebel" and ap:objectName()~=room:getOwner():objectName() then
			if ap:isAlive() then 
				return false
			else
				rebel_num=rebel_num+1
			end
		end
	end
	if getGameData(name)==rebel_num and rebel_num>0 then addZhanGong(room,name) end
end


-- xcdz :: 星驰电走 :: 在一局游戏中，累计出闪20次
--
zgfunc[sgs.CardResponded].xcdz=function(self, room, event, player, data,isowner,name)
	if data:toCardResponse().m_card:isKindOf("Jink") and isowner then
		addGameData(name,1)
		if getGameData(name)==20 then addZhanGong(room,name) end
	end
end


-- xhjs :: 悬壶济世 :: 在一局游戏中，使用桃或技能累计将我方队友脱离濒死状态4次以上
--
zgfunc[sgs.HpRecover].xhjs=function(self, room, event, player, data,isowner,name)
	local recover = data:toRecover()
	if player:getHp()<=0 and recover.recover+player:getHp()>=1 and recover.who
			and recover.who:objectName()==room:getOwner():objectName() and isSameGroup(player,recover.who) then
		addGameData(name,1)
		if getGameData(name)==4 then addZhanGong(room,name) end
	end
end




-- xnhx :: 邪念惑心 :: 作为忠臣在一局游戏中，在场上没有反贼时手刃主公
--
zgfunc[sgs.GameOverJudge].callback.xnhx=function(room,player,data,name,result)
	local damage = data:toDeath().damage
	if not damage then return false end
	if getGameData("hegemony")==1 then return false end
	for _,ap in sgs.qlist(room:getAlivePlayers()) do
		if ap:getRole()=="rebel" then return false end
	end
	if damage.from and damage.from:objectName()==room:getOwner():objectName() and damage.from:getRole()=="loyalist"
		and damage.to:getRole()=="lord" then
		addZhanGong(room,name)
	end
end


-- ymds :: 驭马大师 :: 在一局游戏中，至少更换过8匹马
--
zgfunc[sgs.CardsMoveOneTime].ymds=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	local move=data:toMoveOneTime()
	if move.from_places:contains(sgs.Player_PlaceHand) and move.from:objectName()==room:getOwner():objectName()
		and move.to_place==sgs.Player_PlaceEquip and move.to:objectName()==room:getOwner():objectName() then
		for _,cdid in sgs.qlist(move.card_ids) do
			if sgs.Sanguosha:getCard(cdid):isKindOf("Horse") then
				addGameData(name,1)
				if getGameData(name)==8 then addZhanGong(room,name) end
			end
		end
	end
end


-- cqcz :: 此情常在 :: 在一局游戏中，布练师发动安恤4次并在阵亡情况下获胜
--
zgfunc[sgs.CardFinished].cqcz=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='bulianshi' then return false end
	if not isowner then return false end
	if data:toCardUse().card:isKindOf("AnxuCard") then 
		addGameData(name,1)
	end
end


-- cqcz :: 此情常在 :: 在一局游戏中，布练师发动安恤4次并在阵亡情况下获胜
--
zgfunc[sgs.GameOverJudge].callback.cqcz=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~='bulianshi' then return false end
	if result=='win' and getGameData(name)>=4 and room:getOwner():isDead() then
		addZhanGong(room,name)
	end
end


-- ctbc :: 拆桃不偿 :: 使用甘宁在一局游戏中至少拆掉对方5张桃
--
zgfunc[sgs.ChoiceMade].ctbc=function(self, room, event, player, data,isowner,name)
	if not string.find(room:getOwner():getGeneralName(), "ganning") then return false end
	if not isowner then return false end
	local choices= data:toString():split(":")
	if choices[1]=="cardChosen" and choices[2]=="dismantlement" and sgs.Sanguosha:getCard(choices[3]):isKindOf("Peach") then
		addGameData(name,1)
		if getGameData(name)==5 then
			addZhanGong(room,name)
		end
	end
end


-- dkjj :: 荡寇将军 :: 使用程普在一局游戏中，发动技能“疠火”杀死至少三名反贼最终获得胜利
--
zgfunc[sgs.Death].dkjj=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='chengpu' then return false end
	local damage=data:toDeath().damage
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() and damage.card
		and damage.card:getSkillName()=="lihuo" and damage.to:getRole()=="rebel" then
		addGameData(name,1)
	end
end


-- dkjj :: 荡寇将军 :: 使用程普在一局游戏中，发动技能“疠火”杀死至少三名反贼最终获得胜利
--
zgfunc[sgs.GameOverJudge].callback.dkjj=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~='chengpu' then return false end
	if result~='win' then return false end
	local damage=data:toDeath().damage
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() and damage.card
		and damage.card:getSkillName()=="lihuo" and damage.to:getRole()=="rebel" then
		addGameData(name,1)
	end
	if getGameData(name)>=3 then addZhanGong(room,name) end
end




-- gzwb :: 固政为本 :: 使用张昭张纮在一局游戏中利用技能“固政”获得累计至少40张牌
--
zgfunc[sgs.CardsMoveOneTime].gzwb=function(self, room, event, player, data,isowner,name)
	if room:getOwner():getGeneralName()~='erzhang' or not isowner then return false end
	if room:getCurrent():getPhaseString()~="discard"
		or room:getCurrent():objectName()==room:getOwner():objectName() then return false end

	local move=data:toMoveOneTime()
	local reason=move.reason
	local from_places=sgs.QList2Table(move.from_places)

	if move.to_place~=sgs.Player_PlaceHand or move.to:objectName()~=room:getOwner():objectName() then return false end

	if table.contains(from_places,sgs.Player_DiscardPile) then
		local ids=sgs.QList2Table(move.card_ids)
		for _,cid in ipairs(ids) do
			addGameData(name,1)
			if getGameData(name)>=40 then
				addZhanGong(room,name)
				setGameData(name,-100)
				return false
			end
		end
	end
end


-- jfhz :: 解烦护主 :: 使用韩当在一局游戏游戏中发动“解烦”救过队友孙权至少两次
--Fs: 此战功需要修改,因为韩当技能修改
zgfunc[sgs.CardFinished].jfhz=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='handang' then return false end
	if not isowner then return false end
	local use=data:toCardUse()
	local tos=sgs.QList2Table(use.to)
	if tos and #tos and tos[1]:getGeneralName()=="sunquan"
			and use.card:getSkillName()=="jiefan" and isSameGroup(player,tos[1]) then
		addGameData(name,1)
		if getGameData(name)==2 then addZhanGong(room, name) end
	end
end


-- jjh :: 交际花 :: 使用孙尚香和全部其他(且至少4个)角色皆使用过结姻
--
zgfunc[sgs.CardFinished].jjh=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='sunshangxiang' then return false end
	if not isowner then return false end
	local use=data:toCardUse()
	local tos=sgs.QList2Table(use.to)

	--这里用 mark不太好用，因为一个人死后会扔掉所有mark
	if tos and #tos and use.card:isKindOf("JieyinCard") then
		local objname=tos[1]:objectName()
		local value=getGameData(name,'')
		if not string.find(value,objname..',') then
			setGameData(name,value..objname..',')
			local list=getGameData(name):split(',')

			--无需 减1， 因为字符串最后正好多了个逗号
			if #list>=4 and #list==sgs.Sanguosha:getPlayerCount(room:getMode()) then
				addZhanGong(room,name)
			end
		end
	end
end


-- jjnh :: 禁军难护 :: 使用韩当在一局游戏中有角色濒死时发动“解烦”并出杀后均被闪避至少5次
--Fs:此战功需要修改,因为韩当技能修改
zgfunc[sgs.SlashMissed].jjnh=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='handang' then return false end
	if not isowner then return false end
	local effect=data:toSlashEffect()
	if effect.slash:hasFlag("jiefan-slash") then
		addGameData(name,1)
		if getGameData(name)==5 then addZhanGong(room,name) end
	end
end


-- jwrs :: 军威如山 :: 使用☆SP甘宁在一局游戏中发动军威累计得到过至少6张“闪”
--
zgfunc[sgs.ChoiceMade].jwrs=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="bgm_ganning" then return false end
	if not isowner then return false end
	local choices= data:toString():split(":")
	if choices[1]=="playerChosen"  and  choices[2]=="junweigive" then
		addGameData(name,1)
		if getGameData(name)==6 then addZhanGong(room,name) end
	end
end



-- jyh :: 解语花 :: 使用步练师在一局游戏中发动安恤摸八张牌以上
--
zgfunc[sgs.CardsMoveOneTime].jyh=function(self, room, event, player, data,isowner,name)
	if room:getOwner():getGeneralName()~="bulianshi" then return false end
	if room:getCurrent():getPhaseString()~="play"  then return false end

	local move=data:toMoveOneTime()
	local from_places=sgs.QList2Table(move.from_places)
	local reason=move.reason
	if reason.m_reason==sgs.CardMoveReason_S_REASON_GIVE and reason.m_playerId==room:getOwner():objectName()
			and isowner and room:getCurrent():objectName()==room:getOwner():objectName() then
		local ids=sgs.QList2Table(move.card_ids)
		for _,cid in ipairs(ids) do
			local card=sgs.Sanguosha:getCard(cid)
			if card:getSuit()~=sgs.Card_Spade  then
				addGameData(name,1)
				if getGameData(name)==8 then
					addZhanGong(room,name)
					return false
				end
			end
		end
	end
end




-- ssex :: 三思而行 :: 使用孙权在一局游戏中利用制衡获得至少4张无中生有以及4张桃
--
zgfunc[sgs.CardFinished].ssex=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='sunquan' then return false end
	if not isowner then return false end
	local x=player:getHandcardNum()
	local y=data:toCardUse().card:getSubcards():length()
	for i=0, y-1, 1 do
		if player:getHandcards():at(x-y+i):isKindOf("Peach") then
			addGameData(name.."_peach",1)
			if getGameData(name.."_peach")>=4 and getGameData(name.."_exnihilo")>=4 then 
				addZhanGong(room,name) 
				setGameData(name.."_peach", -100)
			end
		elseif player:getHandcards():at(x-y+i):isKindOf("ExNihilo") then
			addGameData(name.."_exnihilo",1)
			if getGameData(name.."_peach")>=4 and getGameData(name.."_exnihilo")>=4 then 
				addZhanGong(room,name) 
				setGameData(name.."_exnihilo", -100)
			end
		end
	end
end


-- sssl :: 深思熟虑 :: 使用孙权在一个回合内发动制衡的牌不少于10张
--
zgfunc[sgs.CardFinished].sssl=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='sunquan' then return false end
	if not isowner then return false end
	if data:toCardUse().card:getSubcards():length()>=10 then addZhanGong(room,name) end
end


-- syjh :: 岁月静好 :: 使用☆SP大乔在一局游戏中发动安娴五次并获胜
--
zgfunc[sgs.ChoiceMade].syjh=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="bgm_daqiao" then return false end
	if not isowner then return false end
	local choices= data:toString():split(":")
	if choices[1]=="skillInvoke"  and  choices[2]=="anxian" and choices[3]=="yes" then
		addGameData(name,1)
	end
	if choices[1]=="cardResponded"  and  choices[2]=="." and choices[3]=="@anxian-discard" and choices[4]~="_nil_" then
		addGameData(name,1)
	end
end

zgfunc[sgs.GameOverJudge].callback.syjh=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~='bgm_daqiao' then return false end
	if result=='win' and getGameData(name)>=5 then
		addZhanGong(room,name)
	end
end


-- xxf :: 小旋风 :: 使用凌统在一局游戏中发动技能“旋风”弃掉其他角色累计15张牌
--
zgfunc[sgs.ChoiceMade].xxf=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="lingtong" then return false end
	if not isowner then return false end
	local choices= data:toString():split(":")
	if choices[1]=="cardChosen" and choices[2]=="xuanfeng" then
		addGameData(name,1)
		if getGameData(name)==15 then
			addZhanGong(room,name)
		end
	end
end



-- ynnd :: 有难你当 :: 使用小乔在一局游戏中发动“天香”导致一名其他角色死亡
--
zgfunc[sgs.Death].ynnd=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='xiaoqiao' then return false end
	local damage=data:toDeath().damage
	if damage and damage.to:hasFlag("TianxiangTarget") then
		addZhanGong(room,name)
	end
end


zgfunc[sgs.GameOverJudge].callback.ynnd=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~='xiaoqiao' then return false end
	local damage=data:toDeath().damage
	if damage and damage.to:hasFlag("TianxiangTarget") then
		addZhanGong(room,name)
	end
end


-- dkzz :: 杜康之子 :: 使用曹植在一局游戏中发动酒诗后成功用杀造成伤害累计5次
--
zgfunc[sgs.CardFinished].dkzz=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='caozhi' then return false end
	if not isowner then return false end
	local use=data:toCardUse()
	if use.card:getSkillName()=="jiushi" and player:getPhase()==sgs.Player_Play then 
		addTurnData(name.."_analeptic",1) 
	end
	if use.card:isKindOf("Slash") and player:getPhase()==sgs.Player_Play and getTurnData(name.."_slash")>0 then
		setTurnData(name.."_slash",0)
	end
end


zgfunc[sgs.SlashHit].dkzz=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='caozhi' then return false end
	if not isowner then return false end
	local effect=data:toSlashEffect()
	if player:getPhase()==sgs.Player_Play and effect.drank and getTurnData(name.."_analeptic")==1 then
		addTurnData(name.."_slash",1)
	end
end


zgfunc[sgs.Damage].dkzz=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='caozhi' then return false end
	if not isowner then return false end
	local damage=data:toDamage()
	if damage.card and damage.card:isKindOf("Slash") and getTurnData(name.."_slash")>0 then
		setTurnData(name.."_slash",0)
		addGameData(name,1)
		if getGameData(name)==5 then addZhanGong(room,name) end
	end
end


-- dqzw :: 大权在握 :: 使用钟会在一局游戏中有超过8张权
--
zgfunc[sgs.DamageComplete].dqzw=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='zhonghui' then return false end
	if not isowner then return false end
	if player:getPile("power"):length()>=8 and getGameData(name)==0 then
		addGameData(name,1)
		addZhanGong(room,name)
	end
end


-- dym :: 大姨妈 :: 使用甄姬连续5回合洛神的第一次结果都是红色，不包括改判
--
zgfunc[sgs.EventPhaseEnd].dym=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='zhenji' then return false end
	if not isowner then return false end
	if player:getPhase()==sgs.Player_Start and getTurnData(name)==0 then setGameData(name, 0) end
end


-- dym :: 大姨妈 :: 使用甄姬连续5回合洛神的第一次结果都是红色，不包括改判
--
zgfunc[sgs.FinishRetrial].dym=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='zhenji' then return false end
	if not isowner then return false end
	local judge=data:toJudge()
	if judge.reason=="luoshen" and judge.who:objectName()==room:getOwner():objectName() then
		if judge:isGood() then 
			setGameData(name,0)
		else
			if room:getTag("retrial"):toBool()==false then --这个Tag是什么情况?我怎么在代码里没看到过
				addTurnData(name,1)
				addGameData(name,1)
				if getGameData(name)==5 then
					addZhanGong(room,name)
				end
			end
		end
	end
end


-- fynd :: 愤勇难当 :: 使用☆SP夏侯惇在一局游戏中，至少发动四次奋勇
--
zgfunc[sgs.ChoiceMade].fynd=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="bgm_xiahoudun" then return false end
	if not isowner then return false end
	local choices= data:toString():split(":")
	if choices[1]=="skillInvoke"  and  choices[2]=="fenyong" and choices[3]=="yes" then
		addGameData(name,1)
		if getGameData(name)==4 then
			addZhanGong(room,name)
		end
	end
end


-- glnc :: 刚烈难存 :: 使用夏侯惇在一局游戏中连续4次刚烈判定均为红桃
--
zgfunc[sgs.FinishRetrial].glnc=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='xiahoudun' then return false end
	if not isowner then return false end
	local judge = data:toJudge()
	if judge.reason=="ganglie" and judge.who:objectName()==room:getOwner():objectName() then
		if judge:isGood() then
			setGameData(name,0)
		else
			addGameData(name,1)
			if getGameData(name)==4 then addZhanGong(room,name) end
		end
	end
end


-- jcyd :: 将驰有度 :: 使用曹彰发动将驰的两种效果各连续两回合
--
zgfunc[sgs.ChoiceMade].jcyd=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="caozhang" then return false end
	if not isowner then return false end
	local choices= data:toString():split(":")
	for index, option in ipairs({"jiang","chi"}) do
		if choices[1]=="skillChoice"  and  choices[2]=="jiangchi" and choices[3]==option then
			setGameData(name..'_'..option,string.format("%s%d,",getGameData(name..'_'..option,''),getGameData('turncount')))
			local arr=string.sub(getGameData(name..'_'..option),1,-2):split(",")
			if #arr>=2 then
				if arr[#arr]-arr[#arr-1]==1 then
					addGameData(name..'_'..index,1)
					if getGameData(name..'_1')>=1 and getGameData(name..'_2')>=1 then
						addZhanGong(room,name)
						setGameData(name..'_'..index,-100)
					end
				end
			end
		end
	end
end



-- jsbc :: 坚守不出 :: 使用曹仁在一局游戏中连续8回合发动据守
--
zgfunc[sgs.ChoiceMade].jsbc=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="caoren" then return false end
	if not isowner then return false end
	local choices= data:toString():split(":")
	if choices[1]=="skillInvoke"  and  choices[2]=="jushou" and choices[3]=="yes" then
		setGameData(name,string.format("%s%d,",getGameData(name,''),getGameData('turncount')))
		local arr=string.sub(getGameData(name),1,-2):split(",")
		if #arr>=8 then
			for i=#arr,#arr-6,-1 do
				if arr[i]-arr[i-1]~=1 and arr[i]-arr[i-1]~=2 then return false end
			end
			addZhanGong(room,name)
			setGameData(name,'')
		end
	end
end




-- qbcs :: 七步成诗 :: 使用曹植在一局游戏中发动酒诗7次
--
zgfunc[sgs.CardFinished].qbcs=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='caozhi' then return false end
	if data:toCardUse().card:getSkillName()=="jiushi" then
		addGameData(name,1)
		if getGameData(name)==7 then addZhanGong(room,name) end
	end
end


-- qjbc :: 奇计百出 :: 使用荀攸在一局游戏中，发动“奇策”使用至少六种锦囊
--
zgfunc[sgs.CardFinished].qjbc=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='xunyou' then return false end
	if not isowner then return false end
	local use=data:toCardUse()
	if use.card:getSkillName()=="qice" and getGameData(name..'_'..use.card:objectName())==0 then
		addGameData(name,1)
		addGameData(name..'_'..use.card:objectName(),1)
		if getGameData(name)==6 then addZhanGong(room,name) end
	end
end


-- qmjj :: 奇谋九计 :: 使用王异在一局游戏中至少成功发动九次秘计并获胜。
--Fs:同韩当
zgfunc[sgs.FinishRetrial].qmjj=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='wangyi' then return false end
	if not isowner then return false end
	local judge=data:toJudge()
	if judge.reason=="miji" and judge:isGood() and judge.who:objectName()==room:getOwner():objectName() then
		addGameData(name,1)
		if getGameData(name)==9 then addZhanGong(room,name) end
	end
end


-- qqtx :: 权倾天下 :: 使用钟会在一局游戏中发动“排异”累计摸牌至少10张
--
zgfunc[sgs.AfterDrawNCards].qqtx=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='zhonghui' then return false end
	local x=data:toInt()
	if isowner and sgs.Sanguosha:getCard(x):hasFlag("paiyi") then
		addGameData(name, 1)
		if getGameData(name)==10 then addZhanGong(room, name) end
	end
end


-- tmnw :: 天命难违 :: 使用司马懿被自己挂的闪电劈死，不包括改判
--
zgfunc[sgs.CardFinished].tmnw=function(self, room, event, player, data,isowner,name)
	if not isowner or player:getGeneralName()~="simayi" then return false end
	local use=data:toCardUse()
	local card=use.card
	if card:isKindOf('Lightning') then
		room:setCardFlag(card, name)
	end
end

zgfunc[sgs.CardsMoveOneTime].tmnw=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='simayi' then return false end
	local move=data:toMoveOneTime()
	local ids=sgs.QList2Table(move.card_ids)
	local card=sgs.Sanguosha:getCard(ids[1])

	local from_places=sgs.QList2Table(move.from_places)
	if table.contains(from_places,sgs.Player_PlaceDelayedTrick) and move.to_place~=sgs.Player_PlaceDelayedTrick then
		if card:hasFlag(name) then
			room:setCardFlag(card, '-'..name)
		end
	end
end

zgfunc[sgs.FinishRetrial].tmnw=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='simayi' then return false end
	local judge=data:toJudge()
	if judge.reason=="lightning" and room:getTag("retrial"):toBool()==false 
			and judge.who:objectName()==room:getOwner():objectName() then
		setTurnData(name,1)
	else
		setTurnData(name,0)
	end
end

zgfunc[sgs.Death].tmnw=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='simayi' then return false end
	local damage = data:toDeath().damage
	if damage and damage.card and damage.card:isKindOf("Lightning") and damage.card:hasFlag(name)
			and player:objectName()==room:getOwner():objectName() then
		if getTurnData(name,0)==1 then
			addZhanGong(room,name)
		end
	end
end

zgfunc[sgs.GameOverJudge].callback.tmnw=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~='simayi' then return false end
	local damage = data:toDeath().damage
	if damage and damage.card and damage.card:isKindOf("Lightning") and damage.card:hasFlag(name)
			and player:objectName()==room:getOwner():objectName() then
		if getTurnData(name,0)==1 then
			addZhanGong(room,name)
		end
	end
end


-- tmzf :: 天命之罚 :: 在一局游戏中，使用司马懿更改闪电判定牌至少劈中其他角色两次
--
zgfunc[sgs.CardsMoveOneTime].tmzf=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='simayi' then return false end
	local move = data:toMoveOneTime()
	if move.from:objectName()==room:getOwner():objectName() and move.reason.m_reason==sgs.CardMoveReason_S_REASON_RETRIAL
		and move.reason.m_skillName=="guicai" then
		setTurnData(name.."_change", move.card_ids:first())
	end
end


zgfunc[sgs.FinishRetrial].tmzf=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='simayi' then return false end
	local judge=data:toJudge()
	if judge.reason=="lightning" and room:getTag("retrial"):toBool()==true
			and judge.who:objectName()~=room:getOwner():objectName() and judge:isBad() then
		if judge.card:getEffectiveId()==getTurnData(name.."_change") then
			addGameData(name,1)
			if getGameData(name)==2 then
				addZhanGong(room,name)
			end
		end
	end
	setTurnData(name.."_change", 0)
end


-- wzxj :: 稳重行军 :: 使用于禁在一局游戏中发动“毅重”抵御至少4次黑色杀
--
zgfunc[sgs.SlashEffected].wzxj=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='yujin' then return false end
	local effect= data:toSlashEffect()
	if effect.to:hasSkill("yizhong") and effect.to:objectName()==room:getOwner():objectName() and effect.slash:isBlack() 
		and effect.to:getArmor()==nil then
		addGameData(name,1)
		if getGameData(name)==4 then
			addZhanGong(room,name)
		end
	end
end


-- xhdc :: 雪痕敌耻 :: 使用☆SP夏侯惇在一局游戏中，发动雪痕杀死一名角色
--
zgfunc[sgs.Death].xhdc=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='bgm_xiahoudun' then return false end
	local damage=data:toDeath().damage
	if damage and damage.from and damage.card and damage.card:getSkillName()=="xuehen" 
		and damage.from:objectName()==room:getOwner():objectName() then
		addZhanGong(room,name)
	end
end


-- xhdc :: 雪恨敌耻 :: 使用☆SP夏侯惇在一局游戏中，发动雪恨杀死一名角色
--
zgfunc[sgs.GameOverJudge].callback.xhdc=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~='bgm_xiahoudun' then return false end
	local damage=data:toDeath().damage
	if damage and damage.from and damage.card and damage.card:getSkillName()=="xuehen" 
		and damage.from:objectName()==room:getOwner():objectName() then
		addZhanGong(room,name)
	end
end


-- xzxm :: 先知续命 :: 使用郭嘉在一局游戏中利用技能“天妒”收进至少4个桃
--
zgfunc[sgs.FinishRetrial].xzxm=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='guojia' then return false end
	local judge=data:toJudge()
	if player:hasSkill("tiandu") and judge.who:objectName()==room:getOwner():objectName() and judge.card:isKindOf("Peach") then
		addGameData(name,1)
		if getGameData(name)==4 then addZhanGong(room,name) end
	end
end


-- ybyt :: 义薄云天 :: 使用SP关羽在觉醒后杀死两个反贼并最后获胜
--
zgfunc[sgs.Death].ybyt=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='sp_guanyu' then return false end
	local damage=data:toDeath().damage
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() 
		and damage.from:getMark("danji")>0 and damage.to:getRole()=="rebel" then
		addGameData(name,1)
	end
end


-- ybyt :: 义薄云天 :: 使用SP关羽在觉醒后杀死两个反贼并最后获胜
--
zgfunc[sgs.GameOverJudge].callback.ybyt=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~='sp_guanyu' then return false end
	if result~='win' then return false end
	local damage=data:toDeath().damage
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() 
		and damage.from:getMark("danji")>0 and damage.to:getRole()=="rebel" then
		addGameData(name,1)
	end	
	if getGameData(name)>=2 then addZhanGong(room,name) end
end


-- ajnf :: 暗箭难防 :: 使用马岱在一局游戏中发动“潜袭”成功至少6次
--Fs:同韩当
zgfunc[sgs.FinishRetrial].ajnf=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='madai' then return false end
	local judge=data:toJudge()
	if judge.who:objectName()==room:getOwner():objectName() and judge.reason=="qianxi" and judge:isGood() then
		addGameData(name,1)
		if getGameData(name)==6 then addZhanGong(room,name) end
	end
end


-- cbhw :: 长坂虎威 :: 使用张飞在一回合内使用8张杀
--
zgfunc[sgs.CardFinished].cbhw=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='zhangfei' then return false end
	if player:objectName()~=room:getCurrent():objectName() then return false end
	local use=data:toCardUse()
	local card=use.card
	if card:isKindOf("Slash") then 
		addTurnData(name,1) 
		if getTurnData(name)==8 then
			addZhanGong(room,name)
		end
	end	
end


-- cbyx :: 长坂英雄 :: 使用赵云在一局游戏中，在刘禅为队友且存活情况下获胜
--
zgfunc[sgs.GameOverJudge].callback.cbyx=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~='zhaoyun' then return false end
	if result~='win' then return false end
	for _,ap in sgs.qlist(room:getAlivePlayers()) do
		if isSameGroup(room:getOwner(),ap) and ap:getGeneralName()=="liushan" then
			addZhanGong(room,name)
		end
	end
end


-- dcxj :: 雕虫小技 :: 使用卧龙在一局游戏中发动“看破”至少15次
--
zgfunc[sgs.CardFinished].dcxj=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='wolong' then return false end
	local use=data:toCardUse()
	if use.card:isKindOf("Nullification") and use.card:getSkillName()=="kanpo" then
		addGameData(name,1)
		if getGameData(name)==15 then addZhanGong(room,name) end
	end
end


-- dyzh :: 当阳之吼 :: 在一局游戏中，使用☆SP张飞累计两次发动大喝与一名角色拼点成功的回合中用红“杀”手刃该角色
--
zgfunc[sgs.Death].dyzh=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='bgm_zhangfei' then return false end
	local damage=data:toDeath().damage
	if damage and damage.from and damage.to:hasFlag("dahe") and damage.from:objectName()==room:getOwner():objectName() 
		and damage.card:isKindOf("Slash") and damage.card:isRed() then
		addGameData(name,1)
		if getGameData(name)==2 then addZhanGong(room,name) end
	end
end


-- dyzh :: 当阳之吼 :: 在一局游戏中，使用☆SP张飞累计两次发动大喝与一名角色拼点成功的回合中用红“杀”手刃该角色
--
zgfunc[sgs.GameOverJudge].callback.dyzh=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~='bgm_zhangfei' then return false end
	local damage=data:toDeath().damage
	if damage and damage.from and damage.to:hasFlag("dahe") and damage.from:objectName()==room:getOwner():objectName() 
		and damage.card:isKindOf("Slash") and damage.card:isRed() then
		addGameData(name,1)
		if getGameData(name)==2 then addZhanGong(room,name) end
	end
end


-- gmzc :: 过目之才 :: 使用☆SP庞统一回合内累计拿到至少16张牌
--
zgfunc[sgs.CardsMoveOneTime].gmzc=function(self, room, event, player, data,isowner,name)
	local move=data:toMoveOneTime()
	if room:getOwner():getGeneralName()=="bgm_pangtong" and room:getOwner():getHandcardNum()>=16 and getGameData(name)==0 then
		addZhanGong(room,name)
		setGameData(name,1)
	end
end


-- hlzms :: 挥泪斩马谡 :: 使用诸葛亮杀死马谡
--
zgfunc[sgs.Death].hlzms=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='zhugeliang' then return false end
	local damage=data:toDeath().damage
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() 
		and damage.to:getGeneralName()=="masu" then
		addZhanGong(room,name)
	end
end


-- hlzms :: 挥泪斩马谡 :: 使用诸葛亮杀死马谡
--
zgfunc[sgs.GameOverJudge].callback.hlzms=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~='zhugeliang' then return false end
	local damage=data:toDeath().damage
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() 
		and damage.to:getGeneralName()=="masu" then
		addZhanGong(room,name)
	end
end


-- hztx :: 虎子同心 :: 使用关兴张苞在父魂成功后，一个回合杀死至少三名反贼
--Fs:同韩当
zgfunc[sgs.Death].hztx=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='guanxingzhangbao' then return false end
	local damage=data:toDeath().damage
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() 
		and damage.from:hasFlag("fuhun") and damage.to:getRole()=="rebel" then
		addTurnData(name,1)
		if getTurnData(name)==3 then addZhanGong(room,name) end
	end
end


-- hztx :: 虎子同心 :: 使用关兴张苞在父魂成功后，一个回合杀死至少三名反贼
--
zgfunc[sgs.GameOverJudge].callback.hztx=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~='guanxingzhangbao' then return false end
	local damage=data:toDeath().damage
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() 
		and damage.from:hasFlag("fuhun") and damage.to:getRole()=="rebel" then
		addTurnData(name,1)
		if getTurnData(name)==3 then addZhanGong(room,name) end
	end
end


-- rxbz :: 仁心布众 :: 使用刘备在一局游戏中，累计仁德至少30张牌
--Fs:同韩当
zgfunc[sgs.CardFinished].rxbz=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='liubei' then return false end
	if not isowner then return false end
	local use=data:toCardUse()
	if use.from:objectName()==room:getOwner():objectName() and use.card:isKindOf("RendeCard") then
		for i=1, use.card:getSubcards():length(), 1 do
			addGameData(name,1)
			if getGameData(name)==30 then addZhanGong(room,name) end
		end
	end
end


-- wxwd :: 惟贤惟德 :: 使用刘备在一个回合内发动仁德给的牌不少于10张
--
zgfunc[sgs.CardFinished].wxwd=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='liubei' then return false end
	if not isowner then return false end
	local use=data:toCardUse()
	if use.from:objectName()==room:getOwner():objectName() and use.card:isKindOf("RendeCard") then
		for i=1, use.card:getSubcards():length(), 1 do
			addTurnData(name,1)
			if getTurnData(name)==10 then addZhanGong(room,name) end
		end
	end
end


-- wyyd :: 无言以对 :: 使用徐庶在一局游戏中发动“无言”躲过南蛮入侵或万箭齐发累计4次
--
zgfunc[sgs.CardEffected].wyyd=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='nos_xushu' then return false end
	if not isowner then return false end
	local effect=data:toCardEffect()
	if effect.to:hasSkill("noswuyan") and (effect.card:isKindOf("SavageAssault") or effect.card:isKindOf("ArcheryAttack")) then
		addGameData(name,1)
		if getGameData(name)==4 then addZhanGong(room,name) end
	end
end


-- xlwzy :: 星落五丈原 :: 使用诸葛亮，在司马懿为敌方时阵亡
--
zgfunc[sgs.Death].xlwzy=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='zhugeliang' then return false end
	if not isowner then return false end
	for _,ap in sgs.qlist(room:getPlayers()) do
		if not isSameGroup(room:getOwner(),ap) and (ap:getGeneralName()=="simayi" or ap:getGeneralName()=="shensimayi") then
			addZhanGong(room,name)
		end
	end
end


zgfunc[sgs.GameOverJudge].callback.xlwzy=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~='zhugeliang' then return false end
	if player:objectName()~=room:getOwner():objectName() then return false end
	for _,ap in sgs.qlist(room:getPlayers()) do
		if not isSameGroup(room:getOwner(),ap) and (ap:getGeneralName()=="simayi" or ap:getGeneralName()=="shensimayi") then
			addZhanGong(room,name)
		end
	end
end


-- ysadj :: 以死安大局 :: 使用马谡在一局游戏中发动“挥泪”使一名角色弃置8张牌
--
zgfunc[sgs.Death].ysadj=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='masu' then return false end
	if not isowner then return false end
	local damage=data:toDeath().damage
	if damage and damage.from and damage.to:hasSkill('huilei') then
		local num=damage.from:getHandcardNum()
		for i=0,3,1 do
			if damage.from:getEquip(i) then num = num + 1 end
		end
		if num>=8 then
			addZhanGong(room,name)
		end
	end
end

zgfunc[sgs.GameOverJudge].callback.ysadj=function(room,player,data,name,result)
	--杀死马谡而导致游戏结束，杀手不会弃牌
end


-- zlzn :: 昭烈之怒 :: 在一局游戏中，使用☆SP刘备发动昭烈杀死至少2人
--
zgfunc[sgs.Death].zlzn=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="bgm_liubei" then return false end
	local damage=data:toDeath().damage
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName()
		and damage.from:getGeneralName()=="bgm_liubei" and  not damage.card then
		addGameData(name,1)
		if getGameData(name)==2 then
			addZhanGong(room,name)
		end
	end
end

zgfunc[sgs.GameOverJudge].callback.zlzn=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~="bgm_liubei" then return false end
	local damage=data:toDeath().damage
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName()
		and damage.from:getGeneralName()=="bgm_liubei" and  not damage.card then
		addGameData(name,1)
		if getGameData(name)==2 then
			addZhanGong(room,name)
		end
	end
end


-- zmjzg :: 走马荐诸葛 :: 使用旧徐庶在一局游戏中至少有3次举荐诸葛且用于举荐的牌里必须有马
--
zgfunc[sgs.CardFinished].zmjzg=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='nos_xushu' then return false end
	if not isowner then return false end
	local use=data:toCardUse()
	local tos=sgs.QList2Table(use.to)
	if use.card:isKindOf("NosJujianCard") and tos and #tos
		and (tos[1]:getGeneralName()=="zhugeliang" or tos[1]:getGeneralName()=="wolong" or tos[1]:getGeneralName()=="shenzhugeliang") then
		local has_horse=false
		for _,cd in sgs.qlist(use.card:getSubcards()) do
			if sgs.Sanguosha:getCard(cd):isKindOf("Horse") then
				has_horse=true
			end
		end
		if has_horse then
			addGameData(name,1)
			if getGameData(name)==3 then addZhanGong(room,name) end
		end
	end
end


-- zzhs :: 智之化身 :: 使用黄月英在一局游戏发动20次集智至少20次
--
zgfunc[sgs.CardFinished].zzhs=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	if room:getOwner():getGeneralName()~='huangyueying' then return false end
	local use=data:toCardUse()
	local card=use.card
	if card:isNDTrick() then
		addGameData(name,1)
		if getGameData(name)==20 then
			addZhanGong(room,name)
		end
	end
end


-- bnzw :: 暴虐之王 :: 使用董卓在一局游戏中利用技能“暴虐”至少回血10次
--
zgfunc[sgs.HpRecover].bnzw=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='dongzhuo' then return false end
	if not isowner then return false end
	local recover=data:toRecover()
	if player:hasFlag("baonueused") then
		addGameData(name,1)
		if getGameData(name)==10 then addZhanGong(room,name) end
	end
end


-- lgzw :: 雷公助我 :: 使用张角在一局游戏中在未更改判定牌的情况下至少4次雷击成功
--
zgfunc[sgs.FinishRetrial].lgzw=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='zhangjiao' then return false end
	local judge=data:toJudge()
	if judge.reason=="leiji" and judge:isBad() and room:getTag("retrial"):toBool()==false then
		addGameData(name,1)
		if getGameData(name)==4 then
			addZhanGong(room,name)
		end
	end
end




-- jjyb :: 戒酒以备 :: 使用高顺在一局游戏中使用技能“禁酒”将至少6张酒当成杀使用或打出
--
zgfunc[sgs.CardFinished].jjyb=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	if player:getGeneralName()~="gaoshun" then return false end
	local use=data:toCardUse()
	local card=use.card
	if card:isKindOf("Analeptic") then
		addGameData(name,1)
		if getGameData(name)==6 then addZhanGong(room,name) end
	end
end



-- qldy :: 枪林弹雨 :: 使用袁绍在一回合内发动8次乱击
--
zgfunc[sgs.CardFinished].qldy=function(self, room, event, player, data,isowner,name)
	if not isowner or player:getGeneralName()~="yuanshao" then return false end
	local use=data:toCardUse()
	local card=use.card
	if card:getSkillName()=="luanji" then
		addTurnData(name,1)
		if getTurnData(name)==8 then
			addZhanGong(room,name)
		end
	end
end


-- sbfs :: 生不逢时 :: 使用双雄对关羽使用决斗，并因这个决斗被关羽杀死
--
zgfunc[sgs.Death].sbfs=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='yanliangwenchou' then return false end
	if not isowner then return false end
	local damage=data:toDeath().damage
	if not (damage and damage.from) then return false end
	local dname=damage.from:getGeneralName()
	if (dname=="guanyu" or dname=="sp_guanyu" or dname=="shenguanyu" or dname=="neo_guanyu") 
		and damage.card:isKindOf("Duel") then
		addZhanGong(room,name)
	end
end


zgfunc[sgs.GameOverJudge].callback.sbfs=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~='yanliangwenchou' then return false end
	local damage=data:toDeath().damage
	if not (damage and damage.from) then return false end
	local dname=damage.from:getGeneralName()
	if (dname=="guanyu" or dname=="sp_guanyu" or dname=="shenguanyu" or dname=="neo_guanyu") 
		and damage.card:isKindOf("Duel") then
		addZhanGong(room,name)
	end
end


-- syqd :: 恃勇轻敌 :: 使用华雄在一局游戏中，在没有马岱在场的情况下由于体力上限减至0而死亡
--

--因为 room:findPlayer 没有考虑副将，因此写一个 findPlayerByGeneralName
function findPlayerByGeneralName(room,name)
	for _, p in sgs.qlist(room:getPlayers()) do
		if p:getGeneralName()==name or p:getGeneral2Name()==name then return true end
	end
	return false
end

zgfunc[sgs.Death].syqd=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="huaxiong" then return false end
	if isowner and player:getMaxHp()<1 and not findPlayerByGeneralName(room,'madai') then
		addZhanGong(room,name)
	end
end

zgfunc[sgs.GameOverJudge].callback.syqd=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~="huaxiong" then return false end
	if player:objectName()==room:getOwner():objectName() and player:getMaxHp()<1 and not findPlayerByGeneralName(room,'madai') then
		addZhanGong(room,name)
	end
end


-- yzrx :: 医者仁心 :: 使用华佗在一局游戏中对4个身份的人都发动过青囊并最后获胜
--
zgfunc[sgs.CardFinished].yzrx=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	if  room:getOwner():getGeneralName()~='huatuo' then return false end
	local use=data:toCardUse()
	local card=use.card
	local tos=sgs.QList2Table(use.to)
	if card:getSkillName()=="qingnang" and #tos>0 then
		local role=tos[1]:getRole()
		if not string.find(getGameData(name,''),role) then
			setGameData(name,getGameData(name)..role..",")
		end
	end
end

zgfunc[sgs.GameOverJudge].callback.yzrx=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~='huatuo' then return false end
	local arr=string.sub(getGameData(name,','),1,-2):split(",")
	if result=='win' and #arr==4 then
		addZhanGong(room,name)
	end
end

-- zsbsh :: 宗室遍四海 :: 使用刘表在一局游戏中利用技能“宗室”提高4手牌上限
--
zgfunc[sgs.EventPhaseEnd].zsbsh=function(self, room, event, player, data,isowner,name)
	if not isowner or player:getGeneralName()~="liubiao" then return false end
	local getKingdoms=function()
		local kingdoms={}
		local kingdom_number=0
		local players=room:getAlivePlayers()
		for _,aplayer in sgs.qlist(players) do
			if not kingdoms[aplayer:getKingdom()] then
				kingdoms[aplayer:getKingdom()]=true
				kingdom_number=kingdom_number+1
			end
		end
		return kingdom_number
	end
	if getGameData(name)==0 and player:getPhase()~=sgs.Player_Discard and player:getHandcardNum()-player:getHp()>=4 and getKingdoms()==4 then
		setGameData(name,1)
		addZhanGong(room,name)
	end
end


-- gqzl :: 顾曲周郎 :: 使用神周瑜连续至少4回合发动琴音回复体力
--
zgfunc[sgs.ChoiceMade].gqzl=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="shenzhouyu" then return false end
	if not isowner then return false end
	local choices= data:toString():split(":")
	if choices[1]=="skillChoice"  and  choices[2]=="qinyin" and choices[3]=="up" then
		setGameData(name,string.format("%s%d,",getGameData(name,''),getGameData('turncount')))
		local arr=string.sub(getGameData(name),1,-2):split(",")
		if #arr>=4 then
			if arr[#arr]-arr[#arr-1]==1 and arr[#arr-1]-arr[#arr-2]==1 and arr[#arr-2]-arr[#arr-3]==1 then
				addZhanGong(room,name)
				setGameData(name,'')
			end
		end
	end
end



-- jjfs :: 绝境逢生 :: 使用神赵云在一局游戏中,当体力为一滴血的时候，一直保持一体力直到游戏获胜
--
zgfunc[sgs.HpRecover].jjfs=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='shenzhaoyun' then return false end
	if not isowner then return false end
	if player:getHp()==1 then
		addGameData(name,1)
	end
end

zgfunc[sgs.GameOverJudge].callback.jjfs=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~='shenzhaoyun' then return false end
	if result=='win' and getGameData(name)==0 and room:getOwner():getHp()==1 then
		addZhanGong(room,name)
	end
end


-- lpkd :: 连破克敌 :: 使用神司马懿在一局游戏中发动3次连破并最后获胜
--
zgfunc[sgs.ChoiceMade].lpkd=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="shensimayi" then return false end
	if not isowner then return false end
	local choices= data:toString():split(":")
	if choices[1]=="skillInvoke"  and  choices[2]=="lianpo" and choices[3]=="yes" then
		addGameData(name,1)
	end
end

zgfunc[sgs.GameOverJudge].callback.lpkd=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~='shensimayi' then return false end
	if result=='win' and getGameData(name)>=3 then
		addZhanGong(room,name)
	end
end


-- sfgj :: 三分归晋 :: 使用神司马懿杀死刘备，孙权，曹操各累计10次
--
zgfunc[sgs.Death].sfgj=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="shensimayi" then return false end
	local damage=data:toDeath().damage
	local victim=player:getGeneralName()
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() and
			(victim=='liubei' or victim=='sunquan' or victim=='caocao') then
		addGlobalData(name..'_'..victim,1)
		if getGlobalData(name..'_liubei')>=10 and getGlobalData(name..'_sunquan')>=10 and getGlobalData(name..'_caocao')>=10 then
			addZhanGong(room,name)
			setGlobalData(name..'_liubei',-100)
			setGlobalData(name..'_sunquan',-100)
			setGlobalData(name..'_caocao',-100)
		end
	end
end

zgfunc[sgs.GameOverJudge].callback.sfgj=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~="shensimayi" then return false end
	local damage=data:toDeath().damage
	local victim=player:getGeneralName()
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() and
			(victim=='liubei' or victim=='sunquan' or victim=='caocao') then
		addGlobalData(name..'_'..victim,1)
		if getGlobalData(name..'_liubei')>=10 and getGlobalData(name..'_sunquan')>=10 and getGlobalData(name..'_caocao')>=10 then
			addZhanGong(room,name)
			setGlobalData(name..'_liubei',-100)
			setGlobalData(name..'_sunquan',-100)
			setGlobalData(name..'_caocao',-100)
		end
	end
end

-- shgx :: 四海归心 :: 使用神曹操在一局游戏中受到2点伤害之后发动2次归心
--
zgfunc[sgs.ChoiceMade].shgx=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="shencaocao" then return false end
	if not isowner then return false end
	local choices= data:toString():split(":")
	if choices[1]=="skillInvoke"  and  choices[2]=="guixin" and choices[3]=="yes" then
		addTurnData(name,1)
		if getTurnData(name)==2 and getTurnData(name.."_damage")==1 then
			addZhanGong(room,name)
		end
	end
end

zgfunc[sgs.Damaged].shgx=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	if  room:getOwner():getGeneralName()~="shencaocao" then return false end
	local damage = data:toDamage()
	if damage.damage==2 then
		setTurnData(name.."_damage",1)
	end
end


-- swzs :: 神威之势 :: 使用神赵云发动各花色龙魂各两次并在存活的情况下取得游戏胜利
--
zgfunc[sgs.CardFinished].swzs=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='shenzhaoyun' then return false end
	if not isowner then return false end
	local use=data:toCardUse()
	if use.card:getSkillName()=="longhun" then
		setGameData(name..'_'..use.card:getSuitString(), math.min(2,getGameData(name..'_'..use.card:getSuitString())+1 ) )
		if getGameData(name..'_spade')==2 and getGameData(name..'_heart')==2 and getGameData(name..'_club')==2
			and getGameData(name..'_diamond')==2 then
			addZhanGong(room,name)
			setGameData(name..'_heart',-100)
		end
	end
end

zgfunc[sgs.CardResponded].swzs=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='shenzhaoyun' then return false end
	if not isowner then return false end
	local use= data:toCardResponse()
	local card=use.m_card
	if card:getSkillName()=="longhun" then
		setGameData(name..'_'..card:getSuitString(), math.min(2,getGameData(name..'_'..card:getSuitString())+1 ) )
		if getGameData(name..'_spade')==2 and getGameData(name..'_heart')==2 and getGameData(name..'_club')==2
			and getGameData(name..'_diamond')==2 then
			addZhanGong(room,name)
			setGameData(name..'_heart',-100)
		end
	end
end


-- tyzm :: 桃园之梦 :: 使用神关羽在一局游戏中阵亡后发动武魂判定结果为桃园结义
--
zgfunc[sgs.FinishRetrial].tyzm=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='shenguanyu' then return false end
	local judge=data:toJudge()
	if judge.reason=="wuhun" and judge.card:isKindOf("GodSalvation") then
		addZhanGong(room,name)
	end
end


-- wmsz :: 无谋竖子 :: 使用神吕布在一局游戏中发动无谋至少8次
--
zgfunc[sgs.CardFinished].wmsz=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	if room:getOwner():getGeneralName()~='shenlvbu' then return false end
	local use=data:toCardUse()
	local card=use.card
	if card:isNDTrick() then
		addGameData(name,1)
		if getGameData(name)==8 then
			addZhanGong(room,name)
		end
	end
end


-- yrbf :: 隐忍不发 :: 使用神司马懿在一局游戏中发动忍戒至少10次并获胜
--
zgfunc[sgs.CardsMoveOneTime].yrbf=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	if  room:getOwner():getGeneralName()~='shensimayi' then return false end

	local move = data:toMoveOneTime()
	local reason = move.reason
	if player:getPhase() ~= sgs.Player_Discard then return false end
	if move.from:objectName() ~= player:objectName() then return false end
	if bit32.band(reason.m_reason, sgs.CardMoveReason_S_MASK_BASIC_REASON) == sgs.CardMoveReason_S_REASON_DISCARD then return false end
	addGameData(name,move.card_ids:length())
end

zgfunc[sgs.Damaged].yrbf=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	if  room:getOwner():getGeneralName()~='shensimayi' then return false end
	local damage = data:toDamage()
	addGameData(name,damage.damage)
end

zgfunc[sgs.GameOverJudge].callback.yrbf=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~='shensimayi' then return false end
	if result=='win' and getGameData(name)>=10 then
		addZhanGong(room,name)
	end
end

-- zszn :: 战神之怒 :: 使用神吕布在一局游戏中发动至少4次神愤、3次无前
--
zgfunc[sgs.CardFinished].zszn=function(self, room, event, player, data,isowner,name)
	if room:getOwner():getGeneralName()~="shenlvbu" then return false end
	if not isowner then return false end
	local use=data:toCardUse()
	local card=use.card
	if card:isKindOf("ShenfenCard") then
		setGameData(name..'_shenfen',math.min(4,getGameData(name..'_shenfen')+1))
		if getGameData(name..'_shenfen')==4 and getGameData(name..'_wuqian')==3 then
			addZhanGong(room,name)
			setGameData(name..'_shenfen',-100)
		end
	end
	if card:isKindOf("WuqianCard") then
		setGameData(name..'_wuqian',math.min(3,getGameData(name..'_wuqian')+1))
		if getGameData(name..'_shenfen')==4 and getGameData(name..'_wuqian')==3 then
			addZhanGong(room,name)
			setGameData(name..'_shenfen',-100)
		end
	end
end




-- sxnj :: 神仙难救 :: 使用贾诩在你的回合中有至少3个角色阵亡
--
zgfunc[sgs.Death].sxnj=function(self, room, event, player, data,isowner,name)
	if room:getOwner():getGeneralName()~='jiaxu' then return false end
	if room:getCurrent():objectName()~=room:getOwner():objectName() then return false end
	addTurnData(name,1)
	if getTurnData(name)==3 then
		addZhanGong(room,name)
	end
end

zgfunc[sgs.GameOverJudge].callback.sxnj=function(room,player,data,name,result)
	if room:getOwner():getGeneralName()~='jiaxu' then return false end
	if room:getCurrent():objectName()~=room:getOwner():objectName() then return false end
	addTurnData(name,1)
	if getTurnData(name)==3 then
		addZhanGong(room,name)
	end
end


-- jzyf :: 见者有份 :: 使用杨修在一局游戏中发动技能“啖酪”至少6次
--
zgfunc[sgs.ChoiceMade].jzyf=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="yangxiu" then return false end
	if not isowner then return false end
	local choices= data:toString():split(":")
	if choices[1]=="skillInvoke"  and  choices[2]=="danlao" and choices[3]=="yes" then
		addGameData(name,1)
		if getGameData(name)==6 then
			addZhanGong(room,name)
		end
	end
end

-- xhrb :: 心如寒冰 :: 使用张春华在一局游戏中至少触发“绝情”10次以上
--
zgfunc[sgs.Predamage].xhrb=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="zhangchunhua" then return false end
	if not isowner then return false end
	addGameData(name,1)
	if getGameData(name)==10 then
		addZhanGong(room,name)
	end
end

-- lbss :: 乐不思蜀 :: 在对你的“乐不思蜀”生效后的回合弃牌阶段弃置超过8张手牌
--
zgfunc[sgs.FinishRetrial].lbss=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	local judge=data:toJudge()
	if judge.reason=="indulgence" and judge.who:objectName()==room:getOwner():objectName() and judge:isBad() then
		setTurnData(name,1)
	end
end

zgfunc[sgs.CardsMoveOneTime].lbss=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	if player:getPhase()~=sgs.Player_Discard then return false end
	if getTurnData(name)~=1 then return false end

	local move = data:toMoveOneTime()
	local reason = move.reason	
	if reason.m_reason ~= sgs.CardMoveReason_S_REASON_RULEDISCARD then return false end

	local count = 0
	for i = 0, move.card_ids:length()-1 do
		count=count +1
		if count==8 then addZhanGong(room,name) end
	end
end


-- ydqb :: 原地起爆 :: 回合开始阶段你1血0牌的情况下，一回合内杀死3名角色
--
zgfunc[sgs.EventPhaseStart].ydqb=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	if player:getPhase()==sgs.Player_Start and player:isKongcheng() and player:getHp()==1 then
		setTurnData(name..'_start',1)
	end
end

zgfunc[sgs.Death].ydqb=function(self, room, event, player, data,isowner,name)
	if room:getCurrent():objectName()~=room:getOwner():objectName() then return false end
	addTurnData(name,1)
	if getTurnData(name)==3 and getTurnData(name..'_start')==1 then
		addZhanGong(room,name)
	end
end

zgfunc[sgs.GameOverJudge].callback.ydqb=function(room,player,data,name,result)
	if room:getCurrent():objectName()~=room:getOwner():objectName() then return false end
	addTurnData(name,1)
	if getTurnData(name)==3 and getTurnData(name..'_start')==1 then
		addZhanGong(room,name)
	end
end

-- hyhs :: 红颜祸水 :: 使用SP貂蝉在一局游戏中，两次对主公和忠臣发动技能“离间”并导致2名忠臣阵亡
--
zgfunc[sgs.Death].hyhs=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="sp_diaochan" then return false end
	local damage=data:toDeath().damage
	if not damage then return false end
	if  room:getCurrent():objectName()==room:getOwner():objectName() and damage.card and damage.card:getSkillName()=="lijian"
			and damage.from:isLord() and damage.to:getRole()=='loyalist' then
		addGameData(name,1)
		if getGameData(name)==2 then
			addZhanGong(room,name)
		end
	end
end

zgfunc[sgs.GameOverJudge].callback.hyhs=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~="sp_diaochan" then return false end
	local damage=data:toDeath().damage
	if not damage then return false end
	if  room:getCurrent():objectName()==room:getOwner():objectName() and damage.card and damage.card:getSkillName()=="lijian"
			and damage.from:isLord() and damage.to:getRole()=='loyalist' then
		addGameData(name,1)
		if getGameData(name)==2 then
			addZhanGong(room,name)
		end
	end
end


-- wzsh :: 威震四海 :: 一次对其他角色造成至少5点伤害
--
zgfunc[sgs.Damage].wzsh=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	local damage=data:toDamage()
	if damage.damage>=5 and not damage.chain then
		addZhanGong(room,name)
	end
end

-- dsdnx :: 屌丝的逆袭 :: 身为虎牢关联军的先锋，第一回合就爆了虎牢布的菊花
--
zgfunc[sgs.HpChanged].dsdnx=function(self, room, event, player, data,isowner,name)
	if room:getMode()~="04_1v3" or not player:isLord() then return false end
	if room:getCurrent():objectName()~=room:getOwner():objectName() or getGameData("turncount")>1 then return false end
	if room:getOwner():getSeat()==2 and player:getHp()<= 4 and player:getMark("secondMode") == 0 then
		addZhanGong(room,name)
	end
end

-- yfnzmk :: 元芳，你怎么看 :: 元芳，你怎么看？大人，这不科学。
--
--
--
-- 这是一个隐藏描述的战功,如果你已经看到这里，请不要向任何人透露该战功的达成条件。
--
zgfunc[sgs.CardFinished].yfnzmk=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	local use=data:toCardUse()
	local card=use.card
	if card:isKindOf("KurouCard") then setTurnData(name,1) end
end

zgfunc[sgs.GameOverJudge].yfnzmk=function(self, room, event, player, data,isowner,name)
	if getGameData("hegemony")==1 then return false end
	local damage=data:toDeath().damage
	if isowner and damage and damage.from and room:getOwner():isLord() and getGameData("turncount")==1
			and room:getCurrent():objectName()==room:getOwner():objectName() and getTurnData(name)==0 then
		addZhanGong(room,name)
	end
end

-- kdzz :: 坑爹自重 :: 使用刘禅，孙权&孙策，曹丕&曹植坑了自己的老爹
--
zgfunc[sgs.Death].kdzz=function(self, room, event, player, data,isowner,name)
	local damage=data:toDeath().damage
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() then
		local kengdie=false
		local from=damage.from:getGeneralName()
		local to=damage.to:getGeneralName()
		if string.match(to,'liubei') and from=='liushan' then kengdie=true end
		if string.match(to,'caocao') and (from=='caopi' or from=='caozhi') then kengdie=true end
		if string.match(to,'sunjian') and (from=='sunquan' or from=='sunce') then kengdie=true end
		if kengdie then
			addZhanGong(room,name)
		end
	end
end

zgfunc[sgs.GameOverJudge].callback.kdzz=function(room,player,data,name,result)
	local damage=data:toDeath().damage
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() then
		local kengdie=false
		local from=damage.from:getGeneralName()
		local to=damage.to:getGeneralName()
		if string.match(to,'liubei') and from=='liushan' then kengdie=true end
		if string.match(to,'caocao') and (from=='caopi' or from=='caozhi') then kengdie=true end
		if string.match(to,'sunjian') and (from=='sunquan' or from=='sunce') then kengdie=true end
		if kengdie then
			addZhanGong(room,name)
		end
	end
end



-- srxsm :: 射人先射马 :: 一局游戏中发动麒麟弓特效至少3次
-- 
zgfunc[sgs.ChoiceMade].srxsm=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	local choices= data:toString():split(":")
	if choices[1]=="skillInvoke"  and  choices[2]=="KylinBow" and choices[3]=="yes" then
		addGameData(name,1)
		if getGameData(name)==3 then
			addZhanGong(room,name)
		end
	end	
end



-- zqxj :: 朱雀星君 :: 一局游戏中发动朱雀羽扇特效至少3次
-- 
zgfunc[sgs.ChoiceMade].zqxj=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	local choices= data:toString():split(":")
	if choices[1]=="skillInvoke"  and  choices[2]=="Fan" and choices[3]=="yes" then
		addGameData(name,1)
		if getGameData(name)==3 then
			addZhanGong(room,name)
		end
	end	
end


-- srpz :: 势如破竹 :: 一局游戏中发动贯石斧特效至少3次
-- 
zgfunc[sgs.ChoiceMade].srpz=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	local choices= data:toString():split(":")
	if choices[1]=="cardResponded" and choices[2]=="@Axe" and choices[#choices]~="_nil_" then
		addGameData(name,1)
		if getGameData(name)==3 then
			addZhanGong(room,name)
		end
	end	
end


-- shd :: 杀很大 :: 一回合中发动诸葛连弩特效至少4次
-- 
zgfunc[sgs.CardFinished].shd=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	if player:objectName()~=room:getCurrent():objectName() then return false end
	local use=data:toCardUse()
	local card=use.card
	if player:getWeapon() and player:getWeapon():isKindOf("Crossbow") and card:isKindOf("Slash") then 
		addTurnData(name,1) 
		if getTurnData(name)==4 then
			addZhanGong(room,name)
		end
	end	
end


-- jdld :: 绝对零度 :: 一局游戏中发动寒冰剑特效至少3次
-- 
zgfunc[sgs.ChoiceMade].jdld=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	local choices= data:toString():split(":")
	if choices[1]=="skillInvoke"  and  choices[2]=="IceSword" and choices[3]=="yes" then
		addGameData(name,1)
		if getGameData(name)==3 then
			addZhanGong(room,name)
		end
	end	
end

-- hydt :: 鸿运当头 :: 在1个回合内使用至少3次无中生有
-- 
zgfunc[sgs.CardFinished].hydt=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	local use=data:toCardUse()
	local card=use.card
	if card:isKindOf("ExNihilo") then 
		addTurnData(name,1)
		if getTurnData(name)==3 then			 
			addZhanGong(room,name)
		end
	end
end


-- bgws :: 秉公无私 :: 身为主公在一局游戏中从未对忠臣造成伤害，并取得胜利
-- 
zgfunc[sgs.Damage].bgws=function(self, room, event, player, data,isowner,name)
	local damage = data:toDamage()
	if getGameData("hegemony")==1 then return false end
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() 
			and damage.from:isLord() and damage.to:getRole()=="loyalist" then
		addGameData("bgws",1)
	end		
end


-- bgws :: 秉公无私 :: 身为主公在一局游戏中从未对忠臣造成伤害，并取得胜利
-- 
zgfunc[sgs.GameOverJudge].callback.bgws=function(room,player,data,name,result)	
	if getGameData("hegemony")==1 then return false end
	if getGameData("bgws",0)==0 and room:getOwner():isLord() and result =='win' and string.match(sgs.Sanguosha:getRoles(room:getMode()),"C") then		 
		addZhanGong(room,name)
	end
end



-- ljxs :: 落井下石 :: 一局游戏中发动古锭刀特效至少3次
-- 
zgfunc[sgs.DamageCaused].ljxs=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	local damage = data:toDamage()
	if damage and damage.card and damage.card:isKindOf("Slash") and damage.to:isKongcheng() 
			and not damage.chain and not damage.transfer and damage.from and damage.from:hasWeapon("GudingBlade") then
		addGameData(name,1)
		if getGameData(name)==3 then			 
			addZhanGong(room,name)
		end
	end		
end


-- mbgj :: 命不该绝 :: 被闪电劈中但是没有死
-- 
zgfunc[sgs.Damaged].mbgj=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	local damage = data:toDamage()
	local playerName=player:objectName()
	local currentName=room:getCurrent():objectName()
	if damage and damage.card and damage.card:isKindOf("Lightning") and playerName==currentName then		
		setTurnData(name,1)
	end		
end


-- mbgj :: 命不该绝 :: 被闪电劈中但是没有死
-- 
zgfunc[sgs.EventPhaseEnd].mbgj=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	if player:getPhaseString()=="judge" and player:isAlive() and getTurnData(name,0)==1 then
		setTurnData(name,0)		 
		addZhanGong(room,name)
	end		
end


-- gainSkill ::  :: 杀死一个人后，随机获取一个技能卡,这个技能卡可在以后游戏开局的时候使用
-- 
zgfunc[sgs.Death].gainSkill=function(self, room, event, player, data,isowner,name)
	local damage = data:toDeath().damage
	if not damage then return false end
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() then
		gainSkill(room)
	end		
end


-- lczz :: 乱臣贼子 :: 身为反贼在1局游戏中，手刃至少2个忠臣或内奸
-- 
zgfunc[sgs.Death].lczz=function(self, room, event, player, data,isowner,name)
	local damage = data:toDeath().damage
	if not damage then return false end
	local killer=damage.from
	if not killer then return false end
	if getGameData("hegemony")==1 then return false end
	if killer:getRole()=="rebel" and (player:getRole()=="renegade" or player:getRole()=="loyalist") 
			and killer:objectName()==room:getOwner():objectName()  then
		addGameData(name,1)		
		if getGameData(name,0)==2 then 			 
			addZhanGong(room,name)
		end
		
	end		
end


-- lczz :: 乱臣贼子 :: 身为反贼在1局游戏中，手刃至少2个忠臣或内奸
-- 
zgfunc[sgs.GameOverJudge].callback.lczz=function(room,player,data,name,result)
	local damage = data:toDeath().damage
	if not damage then return false end
	local killer=damage.from
	if not killer then return false end
	if getGameData("hegemony")==1 then return false end
	if killer:getRole()=="rebel" and (player:getRole()=="renegade" or player:getRole()=="loyalist") 
			and killer:objectName()==room:getOwner():objectName()  then
		addGameData(name,1)		
		if getGameData(name)==2 then 			 
			addZhanGong(room,name)
		end
	end		
end



-- cdzx :: 赤胆忠心 :: 身为忠臣在1局游戏中，手刃至少2个反贼或内奸
-- 
zgfunc[sgs.Death].cdzx=function(self, room, event, player, data,isowner,name)
	local damage = data:toDeath().damage
	if not damage then return false end
	local killer=damage.from
	if not killer then return false end
	if getGameData("hegemony")==1 then return false end
	if killer:getRole()=="loyalist" and (player:getRole()=="renegade" or player:getRole()=="rebel") 
			and killer:objectName()==room:getOwner():objectName()  then
		addGameData(name,1)		
		if getGameData(name,0)==2  then 			 
			addZhanGong(room,name)
		end
	end		
end


-- cdzx :: 赤胆忠心 :: 身为忠臣在1局游戏中，手刃至少2个反贼或内奸
-- 
zgfunc[sgs.GameOverJudge].callback.cdzx=function(room,player,data,name,result)
	local damage = data:toDeath().damage
	if not damage then return false end
	local killer=damage.from
	if not killer then return false end
	if getGameData("hegemony")==1 then return false end
	if killer:getRole()=="loyalist" and (player:getRole()=="renegade" or player:getRole()=="rebel") 
			and killer:objectName()==room:getOwner():objectName()  then
		addGameData(name,1)		
		if getGameData(name)==2 then 			 
			addZhanGong(room,name)
		end
	end		
end


-- pfdj :: 平反大将 :: 在1局游戏中手刃4个反贼
-- 
zgfunc[sgs.Death].pfdj=function(self, room, event, player, data,isowner,name)
	local damage = data:toDeath().damage
	if not damage then return false end
	local killer=damage.from
	if not killer then return false end
	if getGameData("hegemony")==1 then return false end
	if player:getRole()=="rebel" and killer:objectName()==room:getOwner():objectName()  then
		addGameData(name,1)		
		if getGameData(name,0)==4 then 			 
			addZhanGong(room,name)
		end
	end		
end


-- pfdj :: 平反大将 :: 在1局游戏中手刃4个反贼
-- 
zgfunc[sgs.GameOverJudge].callback.pfdj=function(room,player,data,name,result)
	local damage = data:toDeath().damage
	if not damage then return false end
	local killer=damage.from
	if not killer then return false end
	if getGameData("hegemony")==1 then return false end
	if player:getRole()=="rebel" and killer:objectName()==room:getOwner():objectName()  then
		addGameData(name,1)
		if getGameData(name)==4 then 			 
			addZhanGong(room,name)
		end
	end		
end




-- lsch :: 辣手摧花 :: 一局游戏中杀死至少2名女性角色
-- 
zgfunc[sgs.Death].lsch=function(self, room, event, player, data,isowner,name)
	local damage = data:toDeath().damage
	if not damage then return false end
	local killer=damage.from
	if not killer then return false end
	if player:isFemale() and killer:objectName()==room:getOwner():objectName()  then
		addGameData(name,1)		
		if getGameData(name,0)==2 then 			 
			addZhanGong(room,name)
		end
	end		
end


-- lsch :: 辣手摧花 :: 一局游戏中杀死至少2名女性角色
-- 
zgfunc[sgs.GameOverJudge].callback.lsch=function(room,player,data,name,result)
	local damage = data:toDeath().damage
	if not damage then return false end
	local killer=damage.from
	if not killer then return false end
	if player:isFemale() and killer:objectName()==room:getOwner():objectName()  then
		addGameData(name,1)
		if getGameData(name)==2 then 			 
			addZhanGong(room,name)
		end
	end		
end



-- djyd :: 打酱油的 :: 在1局游戏中，在自己的回合开始前就死亡
-- 
zgfunc[sgs.Death].djyd=function(self, room, event, player, data,isowner,name)
	local damage = data:toDeath().damage	
	if getGameData("turncount")==0 and player:objectName()==room:getOwner():objectName()   then
		addZhanGong(room,name)
	end		
end


-- djyd :: 打酱油的 :: 在1局游戏中，在自己的回合开始前就死亡
-- 
zgfunc[sgs.GameOverJudge].callback.djyd=function(room,player,data,name,result)
	local damage = data:toDeath().damage
	if getGameData("turncount")==0 and player:objectName()==room:getOwner():objectName()  then
		addZhanGong(room,name)
	end		
end



-- xbtc :: 先拔头筹 :: 一局游戏中，自己的首回合结束前杀死至少一名非本方武将
-- 
zgfunc[sgs.Death].xbtc=function(self, room, event, player, data,isowner,name)
	local damage = data:toDeath().damage
	if not damage then return false end
	local killer=damage.from
	if not killer then return false end

	local killerName=killer:objectName()
	local role1=killer:getRole()
	local role2=player:getRole()
	if role1=="lord" then role1="loyalist" end
	if role2=="lord" then role2="loyalist" end
	if room:getMode() == "06_3v3" then
		if role1=="renegade" then role1="rebel" end
		if role2=="renegade" then role2="rebel" end
	end
	local diffgroup =false
	if role1~=role2 then diffgroup=true end
	if role1=="renegade" or role2=="renegade" then diffgroup=true end

	if getGameData("turncount")==1 and getGameData(name)==0 and diffgroup and killerName==room:getOwner():objectName() 
			and killerName==room:getCurrent():objectName() then
		addZhanGong(room,name)
		setGameData(name,1)
	end		
end


-- xbtc :: 先拔头筹 :: 一局游戏中，自己的首回合结束前杀死至少一名非本方武将
-- 
zgfunc[sgs.GameOverJudge].callback.xbtc=function(room,player,data,name,result)
	local damage = data:toDeath().damage
	if not damage then return false end
	local killer=damage.from
	if not killer then return false end
	local killerName=killer:objectName()
	local role1=killer:getRole()
	local role2=player:getRole()
	if role1=="lord" then role1="loyalist" end
	if role2=="lord" then role2="loyalist" end
	if room:getMode() == "06_3v3" then
		if role1=="renegade" then role1="rebel" end
		if role2=="renegade" then role2="rebel" end
	end
	local diffgroup =false
	if role1~=role2 then diffgroup=true end
	if role1=="renegade" or role2=="renegade" then diffgroup=true end

	if getGameData("turncount")==1 and getGameData(name)==0 and diffgroup and killerName==room:getOwner():objectName() 
			and killerName==room:getCurrent():objectName() then
		addZhanGong(room,name)
		setGameData(name,1)
	end	
end



-- jlsj :: 极乐世界 :: 在1局游戏中，累计3次被乐不思蜀后判定牌都是红桃
-- 
zgfunc[sgs.FinishRetrial].jlsj=function(self, room, event, player, data,isowner,name)
		local judge=data:toJudge()
	if judge.reason=="indulgence" and judge.who:objectName()==room:getOwner():objectName() 
			and not judge:isBad() then
		addGameData(name,1)
		if getGameData(name)==3 then 			 
			addZhanGong(room,name)
		end
	end
end


-- alg :: 安乐公 :: 在1局游戏中，累计3次被乐不思蜀后判定牌都不是红桃
-- 
zgfunc[sgs.FinishRetrial].alg=function(self, room, event, player, data,isowner,name)
		local judge=data:toJudge()
	if judge.reason=="indulgence" and judge.who:objectName()==room:getOwner():objectName() 
			and judge:isBad() then
		addGameData(name,1)
		if getGameData(name)==3 then 			 
			addZhanGong(room,name)
		end
	end
end


-- bjlz :: 兵精粮足 :: 在1局游戏中，累计3次被兵粮寸断后判定牌都是草花
-- 
zgfunc[sgs.FinishRetrial].bjlz=function(self, room, event, player, data,isowner,name)
		local judge=data:toJudge()
	if judge.reason=="supply_shortage" and judge.who:objectName()==room:getOwner():objectName() 
			and not judge:isBad() then
		addGameData(name,1)
		if getGameData(name)==3 then 			 
			addZhanGong(room,name)
		end
	end
end


-- jcll :: 饥肠辘辘 :: 在1局游戏中，累计3次被兵粮寸断后判定牌都不是草花
-- 
zgfunc[sgs.FinishRetrial].jcll=function(self, room, event, player, data,isowner,name)
		local judge=data:toJudge()
	if judge.reason=="supply_shortage" and judge.who:objectName()==room:getOwner():objectName() 
			and judge:isBad() then
		addGameData(name,1)
		if getGameData(name)==3 then 			 
			addZhanGong(room,name)
		end
	end
end



-- tq :: 天谴 :: 不被改判定牌的情况下被闪电劈死
-- 
zgfunc[sgs.FinishRetrial].tq=function(self, room, event, player, data,isowner,name)
		local judge=data:toJudge()
	if judge.reason=="lightning" and room:getTag("retrial"):toBool()==false 
			and judge.who:objectName()==room:getOwner():objectName() then
		setTurnData(name,1)
	else
		setTurnData(name,0)
	end
end


-- tq :: 天谴 :: 不被改判定牌的情况下被闪电劈死
-- 
zgfunc[sgs.Death].tq=function(self, room, event, player, data,isowner,name)
	local damage = data:toDeath().damage
	if damage and damage.card and damage.card:isKindOf("Lightning") and player:objectName()==room:getOwner():objectName() then
		if getTurnData(name,0)==1 then 			 
			addZhanGong(room,name)
		end
	end		
end


-- tq :: 天谴 :: 不被改判定牌的情况下被闪电劈死
-- 
zgfunc[sgs.GameOverJudge].callback.tq=function(room,player,data,name,result)
	local damage = data:toDeath().damage
	if damage and damage.card and damage.card:isKindOf("Lightning") and player:objectName()==room:getOwner():objectName() then
		if getTurnData(name,0)==1 then
			addZhanGong(room,name)
		end
	end		
end

-- add luckycard
-- 
zgfunc[sgs.GameOverJudge].callback.luckycard=function(room,player,data,name,result)
	if result =='win' then		
		local arr={1,1,1,1,1,1,1,2,2,3}
		local num=arr[1+ os.time()%10]
		broadcastMsg(room,"#gainLuckycard", num )
		sqlexec("update zgcard set gained = gained + %d where id='%s'",num,'luckycard')
	end	
end


-- 完成N盘游戏获得战功
-- 
for zgname, count in pairs({ccml=1,csss=5,xsnd=10,xymq=20,fmbl=30,xysc=100,xlfm=1000}) do
	zgfunc[sgs.GameOverJudge].callback[zgname]=function(room,player,data,name,result)
		local zgquery=db:first_row("select gained from zhangong where id='"..zgname.."'")
		local sql=string.format("select count(id) as num from results where result<>'-'")
		for row in db:rows(sql) do
			if row.num>=count and zgquery and zgquery.gained==0 then
				addZhanGong(room,name)
			end
		end
	end
end


-- hsqj :: 横扫千军 :: 在1局游戏中，手刃7名角色并且获得胜利
-- 
zgfunc[sgs.Death].hsqj=function(self, room, event, player, data,isowner,name)
	local damage = data:toDeath().damage
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() then
		addGameData(name,1)
	end		
end


-- hsqj :: 横扫千军 :: 在1局游戏中，手刃7名角色并且获得胜利
-- 
zgfunc[sgs.GameOverJudge].callback.hsqj=function(room,player,data,name,result)
	local damage = data:toDeath().damage
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() then
		addGameData(name,1)
	end	
	if result =='win' and getGameData(name)==7 then addZhanGong(room,name) end	
end


-- lmss :: 老谋深算 :: 身为内奸在1局游戏中手刃至少4个反贼或忠臣并且取得胜利
-- 
zgfunc[sgs.Death].lmss=function(self, room, event, player, data,isowner,name)
	local damage = data:toDeath().damage
	if getGameData("hegemony")==1 then return false end
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() 
		and damage.from:getRole()=="renegade" and (player:getRole()=="rebel" or player:getRole()=="loyalist") then
		addGameData(name,1)
	end		
end


-- lmss :: 老谋深算 :: 身为内奸在1局游戏中手刃至少4个反贼或忠臣并且取得胜利
-- 
zgfunc[sgs.GameOverJudge].callback.lmss=function(room,player,data,name,result)
	local damage = data:toDeath().damage
	if getGameData("hegemony")==1 then return false end
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() 
		and damage.from:getRole()=="renegade" and (player:getRole()=="rebel" or player:getRole()=="loyalist") then
		addGameData(name,1)
	end		
	if result =='win' and getGameData(name)>=4 then addZhanGong(room,name) end
end



-- jzjz :: 竭智尽忠 :: 身为忠臣在1局游戏中，在自己的首回合中手刃一个反贼或内奸，最后取得胜利
-- 
zgfunc[sgs.Death].jzjz=function(self, room, event, player, data,isowner,name)
	local damage = data:toDeath().damage
	if getGameData("hegemony")==1 then return false end
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName()
		and damage.from:getRole()=="loyalist" and (player:getRole()=="rebel" or player:getRole()=="renegade") 
		and getGameData("turncount")==1 and damage.from:objectName()==room:getCurrent():objectName() then
			setGameData(name,1)
	end		
end


-- jzjz :: 竭智尽忠 :: 身为忠臣在1局游戏中，在自己的首回合中手刃一个反贼或内奸，最后取得胜利
-- 
zgfunc[sgs.GameOverJudge].callback.jzjz=function(room,player,data,name,result)
	if getGameData("hegemony")==1 then return false end
	if result =='win' and getGameData(name)==1 then addZhanGong(room,name) end
end



-- cxer :: 趁虚而入 :: 身为反贼在1局游戏中，在自己的第1回合时手刃主公
-- 
zgfunc[sgs.GameOverJudge].callback.cxer=function(room,player,data,name,result)
	local damage = data:toDeath().damage
	if not damage then return false end
	if getGameData("hegemony")==1 then return false end
	if result=='win' and damage.from and damage.from:objectName()==room:getOwner():objectName()
		and damage.from:getRole()=="rebel" and player:getRole()=="lord"
		and getGameData("turncount")==1 and damage.from:objectName()==room:getCurrent():objectName() then
			addZhanGong(room,name)
	end		
end


-- ljjh :: 老奸巨猾 :: 身为内奸在1局游戏中，在主公杀死过忠臣的情况下取得胜利
-- 
zgfunc[sgs.Death].ljjh=function(self, room, event, player, data,isowner,name)
	local damage = data:toDeath().damage
	if getGameData("hegemony")==1 then return false end
	if damage and damage.from and damage.from:isLord() and player:getRole()=="loyalist" then
		setGameData(name,1)
	end		
end


-- ljjh :: 老奸巨猾 :: 身为内奸在1局游戏中，在主公杀死过忠臣的情况下取得胜利
-- 
zgfunc[sgs.GameOverJudge].callback.ljjh=function(room,player,data,name,result)
	if getGameData("hegemony")==1 then return false end
	if result =='win' and getGameData(name)==1 and room:getOwner():getRole()=="renegade" then 
		addZhanGong(room,name) 
	end
end




-- jcfs :: 绝处逢生 :: 身为反贼在1局游戏中，在其他反贼全部死亡且忠臣全部存活的情况下获胜
-- 
zgfunc[sgs.Death].jcfs=function(self, room, event, player, data,isowner,name)
	local damage = data:toDeath().damage
	if not damage then return false end
	if getGameData("hegemony")==1 then return false end
	if room:getOwner():getRole()=="rebel" then
		local others = room:getPlayers()
		local loyalist_alive,loyalist_dead=0,0
		local rebel_alive,rebel_dead=0,0
		for _, p in sgs.qlist(others) do
			if p:getRole()=="rebel" then
				if p:isAlive() then rebel_alive=rebel_alive+1 else rebel_dead=rebel_dead+1 end
			end
			if p:getRole()=="loyalist" then
				if p:isAlive() then loyalist_alive=loyalist_alive+1 else loyalist_dead=loyalist_dead+1 end
			end
		end
		if loyalist_dead==0 and loyalist_alive>0 and rebel_dead>0 and rebel_alive==1 then
			setGameData(name,1)
		end
	end		
end


-- jcfs :: 绝处逢生 :: 身为反贼在1局游戏中，在其他反贼全部死亡且忠臣全部存活的情况下获胜
-- 
zgfunc[sgs.GameOverJudge].callback.jcfs=function(room,player,data,name,result)
	if getGameData("hegemony")==1 then return false end
	if result =='win' and getGameData(name)==1 then addZhanGong(room,name) end
end



-- tdwy :: 天道威仪 :: 身为主公在1局游戏中，在忠臣全部死亡后杀死至少3名角色，取得胜利
-- 
zgfunc[sgs.Death].tdwy=function(self, room, event, player, data,isowner,name)
	local damage = data:toDeath().damage
	if not damage then return false end
	if getGameData("hegemony")==1 then return false end
	if room:getOwner():isLord() and damage.from and damage.from:objectName()==room:getOwner():objectName() 
		and (damage.to:getRole()=="rebel" or damage.to:getRole()=="renegade") then
		local players = room:getPlayers()
		local loyalist_alive,loyalist_dead=0,0
		for _, p in sgs.qlist(players) do
			if p:getRole()=="loyalist" then
				if p:isAlive() then loyalist_alive=loyalist_alive+1 else loyalist_dead=loyalist_dead+1 end
			end
		end
		if loyalist_dead>0 and loyalist_alive==0 then addGameData(name,1) end
	end		
end


-- tdwy :: 天道威仪 :: 身为主公在1局游戏中，在忠臣全部死亡后杀死至少3名角色，取得胜利
-- 
zgfunc[sgs.GameOverJudge].callback.tdwy=function(room,player,data,name,result)
	if getGameData("hegemony")==1 then return false end
	if result =='win' and getGameData(name)>=3 then addZhanGong(room,name) end
end




-- zgyd :: 忠肝义胆 :: 身为忠臣在1局游戏中存活，并且主公满体力的情况下取得胜利
-- 
zgfunc[sgs.GameOverJudge].callback.zgyd=function(room,player,data,name,result)	
	local owner=room:getOwner()
	if getGameData("hegemony")==1 then return false end
	if result =='win' and not room:getLord():isWounded() and owner:isAlive() and owner:getRole()=="loyalist" then 
		addZhanGong(room,name) 
	end	
end


-- csjj :: 常胜将军 :: 连续胜利10局
-- 
zgfunc[sgs.GameOverJudge].callback.csjj=function(room,player,data,name,result)
	if result ~='win' then return false end
	local sql=string.format("select result from results order by id desc limit 10")	
	local count=0
	for row in db:rows(sql) do
		if row.result=='win' then count=count+1 end
	end
	if count==10 then addZhanGong(room,name) end	
end

-- dqbr :: 刀枪不入 :: 一局游戏中发动仁王盾特效3次
-- 
zgfunc[sgs.SlashEffected].dqbr=function(self, room, event, player, data,isowner,name)
	local effect= data:toSlashEffect()
	local armor= effect.to:hasArmorEffect("RenwangShield")
	if armor and effect.to:objectName()==room:getOwner():objectName() and effect.slash:isBlack() then
		addGameData(name,1)
		if getGameData(name)==3 then 			 
			addZhanGong(room,name)
		end
	end
end


-- qkds :: 旗开得胜 :: 一局游戏中，在自己的首回合结束前获胜 
-- 
zgfunc[sgs.GameOverJudge].callback.qkds=function(room,player,data,name,result)
	local owner=room:getOwner()
	if result =='win' and ( getGameData("turncount")==0 or 
			( getGameData("turncount")==1 and owner:objectName()==room:getCurrent():objectName() ) ) then 
		addZhanGong(room,name) 
	end	
end


-- gycc :: 苟延残喘 :: 在1局游戏中被救活至少5次 
-- 
zgfunc[sgs.HpRecover].gycc=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	local recov = data:toRecover()
	if recov.recover>=1 and player:getHp()==0  then
		addGameData(name,1)
		if getGameData(name)==5 then
			addZhanGong(room,name)
		end
	end
end

-- ph :: 炮灰 :: 被南蛮入侵或万箭齐发打死累计10次 
-- 
zgfunc[sgs.Death].ph=function(self, room, event, player, data,isowner,name)
	local damage = data:toDeath().damage
	if not damage then return false end
	if player:objectName()==room:getOwner():objectName() and damage.card and damage.card:isKindOf("AOE") then
		addGlobalData(name,1)
		local zgquery=db:first_row("select gained from zhangong where id='"..name.."'")
		if getGlobalData(name)>=10 and zgquery and zgquery.gained==0 then
			addZhanGong(room,name)
		end
	end		
end

zgfunc[sgs.GameOverJudge].callback.ph=function(room,player,data,name,result)
	local damage = data:toDeath().damage
	if not damage then return false end
	if player:objectName()==room:getOwner():objectName() and damage.card and damage.card:isKindOf("AOE") then
		addGlobalData(name,1)
		local zgquery=db:first_row("select gained from zhangong where id='"..name.."'")
		if getGlobalData(name)>=10 and zgquery and zgquery.gained==0 then
			addZhanGong(room,name)
		end
	end	
end



-- gddph :: 更大的炮灰 :: 被南蛮入侵或万箭齐发打死累计50次 
-- 
zgfunc[sgs.Death].gddph=function(self, room, event, player, data,isowner,name)
	local damage = data:toDeath().damage
	if not damage then return false end
	if player:objectName()==room:getOwner():objectName() and damage.card and damage.card:isKindOf("AOE") then
		addGlobalData(name,1)
		local zgquery=db:first_row("select gained from zhangong where id='"..name.."'")
		if getGlobalData(name)>=50 and zgquery and zgquery.gained==0 then
			addZhanGong(room,name)
		end
	end		
end

zgfunc[sgs.GameOverJudge].callback.gddph=function(room,player,data,name,result)
	local damage = data:toDeath().damage
	if not damage then return false end
	if player:objectName()==room:getOwner():objectName() and damage.card and damage.card:isKindOf("AOE") then
		addGlobalData(name,1)
		local zgquery=db:first_row("select gained from zhangong where id='"..name.."'")
		if getGlobalData(name)>=50 and zgquery and zgquery.gained==0 then
			addZhanGong(room,name)
		end
	end	
end


-- yqt :: 一骑讨 :: 与人决斗胜利累计30次 
-- 
zgfunc[sgs.PreDamageDone].yqt=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	local damage = data:toDamage()
	if damage and damage.card and damage.card:isKindOf("Duel") and player:objectName()==damage.from:objectName() then
		addGlobalData(name,1)
		local zgquery=db:first_row("select gained from zhangong where id='"..name.."'")
		if getGlobalData(name)>=30 and zgquery and zgquery.gained==0 then
			addZhanGong(room,name)
		end
	end	
end


-- bszj :: 搬石砸脚 :: 与人决斗失败累计10次 
-- 
zgfunc[sgs.PreDamageDone].bszj=function(self, room, event, player, data,isowner,name)	
	local damage = data:toDamage()
	if damage and damage.card and damage.card:isKindOf("Duel") and damage.to:objectName()==room:getOwner():objectName() and player:objectName()==damage.from:objectName() then
		addGlobalData(name,1)
		local zgquery=db:first_row("select gained from zhangong where id='"..name.."'")
		if getGlobalData(name)>=10 and zgquery and zgquery.gained==0 then
			addZhanGong(room,name)
		end
	end	
end


-- dtj :: 打铁匠 :: 累计将铁索连环重铸30次 
-- 
zgfunc[sgs.CardsMoveOneTime].dtj=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	local move=data:toMoveOneTime()
	if move.from and move.from:objectName()~=player:objectName() then return end
	local reason=move.reason.m_reason	
	if reason==sgs.CardMoveReason_S_REASON_RECAST then 
		addGlobalData(name,1) 
		local zgquery=db:first_row("select gained from zhangong where id='"..name.."'")
		if getGlobalData(name)>=30 and zgquery and zgquery.gained==0 then
			addZhanGong(room,name)
		end	
	end
end



-- tw :: 桃王 :: 在1局游戏中给自己吃过5个或者更多得桃（不包括华佗的技能） 
-- 
zgfunc[sgs.CardFinished].tw=function(self, room, event, player, data, isowner, name)
	if not isowner then return false end
	local use = data:toCardUse()
	local card = use.card
	if card:getSkillName()~="jijiu" and card:isKindOf("Peach") and use.to:contains(player) then
		addGameData(name, 1)
		if getGameData(name) == 5 then
			addZhanGong(room, name)
		end
	end
end


-- tx :: 桃仙 :: 在1局游戏中，使用桃救人至少5次（不包括华佗的技能） 
-- 
zgfunc[sgs.CardFinished].tx=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	local use=data:toCardUse()
	local card=use.card
	local tos=sgs.QList2Table(use.to)
	if card:getSkillName()~="jijiu" and card:isKindOf("Peach") and #tos>0 and tos[1]:objectName()~=player:objectName() then 
		addGameData(name,1) 
		if getGameData(name)==5 then 			 
			addZhanGong(room,name)
		end	
	end
end


-- bmjs :: 八门金锁 :: 在1局游戏中，装备八卦阵连续判定红色花色至少5次 
-- 
zgfunc[sgs.FinishRetrial].bmjs=function(self, room, event, player, data,isowner,name)
	local judge=data:toJudge()
	if judge.reason=="EightDiagram" and judge.who:objectName()==room:getOwner():objectName() then
		if judge:isBad() then			
			setGameData(name,0)
		else
			addGameData(name,1)
		end
		if getGameData(name)==5 then 			 
			addZhanGong(room,name)
			setGameData(name,0)
		end
	end
end


-- yzzf :: 异族之愤 :: 使用1次南蛮入侵打死至少3名角色 
-- 
zgfunc[sgs.Death].yzzf=function(self, room, event, player, data,isowner,name)
	local damage = data:toDeath().damage
	if damage and damage.card and damage.card:isKindOf("SavageAssault") and room:getOwner():objectName()==room:getCurrent():objectName() then
		local key=name..damage.card:getEffectiveId()
		addTurnData(key,1)
		if getTurnData(key)==3 then 			 
			addZhanGong(room,name)
		end
	end		
end

-- yzzf :: 异族之愤 :: 使用1次南蛮入侵打死至少3名角色 
-- 
zgfunc[sgs.GameOverJudge].callback.yzzf=function(room,player,data,name,result)
	local damage = data:toDeath().damage
	if damage and damage.card and damage.card:isKindOf("SavageAssault") and room:getOwner():objectName()==room:getCurrent():objectName() then
		local key=name..damage.card:getEffectiveId()
		addTurnData(key,1)
		if getTurnData(key)==3 then 			 
			addZhanGong(room,name)
		end
	end	
end



-- jwxf :: 箭无虚发 :: 使用1次万箭齐发打死至少3名角色 
-- 
zgfunc[sgs.Death].jwxf=function(self, room, event, player, data,isowner,name)
	local damage = data:toDeath().damage
	if damage and damage.card and damage.card:isKindOf("ArcheryAttack") and room:getOwner():objectName()==room:getCurrent():objectName() then
		local key=name..damage.card:getEffectiveId()
		addTurnData(key,1)
		if getTurnData(key)==3 then 			 
			addZhanGong(room,name)
		end
	end		
end

-- jwxf :: 箭无虚发 :: 使用1次万箭齐发打死至少3名角色 
-- 
zgfunc[sgs.GameOverJudge].callback.jwxf=function(room,player,data,name,result)
	local damage = data:toDeath().damage
	if damage and damage.card and damage.card:isKindOf("ArcheryAttack") and room:getOwner():objectName()==room:getCurrent():objectName() then
		local key=name..damage.card:getEffectiveId()
		addTurnData(key,1)
		if getTurnData(key)==3 then 			 
			addZhanGong(room,name)
		end
	end	
end


-- zszm :: 至圣至明 :: 身为主公在一局游戏中手刃所有反贼和内奸，并在忠臣全部存活的情况下获胜 
-- 
zgfunc[sgs.Death].zszm=function(self, room, event, player, data,isowner,name)
	local damage = data:toDeath().damage
	if not damage then return false end
	if getGameData("hegemony")==1 then return false end
	if (player:getRole()=="rebel" or player:getRole()=="renegade") and damage and damage.from 
			and damage.from:objectName()==room:getOwner():objectName() and damage.from:isLord() then
		addGameData(name,1)
	end
end

zgfunc[sgs.GameOverJudge].callback.zszm=function(room,player,data,name,result)
	local damage = data:toDeath().damage
	if result~="win" then return false end
	if getGameData("hegemony")==1 then return false end
	if not room:getOwner():isLord() then return false end
	if (player:getRole()=="rebel" or player:getRole()=="renegade") and damage and damage.from 
			and damage.from:objectName()==room:getOwner():objectName() and damage.from:isLord() then
		addGameData(name,1)
	end
	if sgs.Sanguosha:getPlayerCount(room:getMode())- room:alivePlayerCount()==getGameData(name) 
			and string.match(sgs.Sanguosha:getRoles(room:getMode()),"C") then
		addZhanGong(room,name)
	end	
end


-- tjb :: 藤甲兵 :: 一局游戏中发动藤甲效果抵挡杀、南蛮入侵或万箭齐发至少3次 
-- 
zgfunc[sgs.CardEffected].tjb=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	local effect=data:toCardEffect()
	if (effect.card:isKindOf("AOE") or (effect.card:objectName() == "Slash")) and player:hasArmorEffect("Vine") then
		addGameData(name,1)
		if getGameData(name)==3 then 			 
			addZhanGong(room,name)
		end
	end
end


-- dshx :: 大事化小 :: 一局游戏中发动白银狮子特效减少伤害至少1次 
-- 
zgfunc[sgs.DamageInflicted].dshx=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	local damage = data:toDamage()	
	if damage and damage.damage>1 and player:hasArmorEffect("SilverLion") then
		addGameData(name,1)
		if getGameData(name)==1 then 			 
			addZhanGong(room,name)
		end
	end

end


-- swsm :: 塞翁失马 :: 一局游戏中，失去白银狮子回复体力至少2次 
-- 
zgfunc[sgs.HpRecover].swsm=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	local recov = data:toRecover()
	if recov.recover>=1 and recov.card and recov.card:isKindOf("SilverLion") then
		addGameData(name,1)
		if getGameData(name)==2 then 			 
			addZhanGong(room,name)
		end
	end
end


-- rhss :: 惹火上身 :: 一局游戏中，装备藤甲的时受到至少3次火焰伤害 
-- 
zgfunc[sgs.Damaged].rhss=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	local damage = data:toDamage()
	if damage and damage.nature == sgs.DamageStruct_Fire and player:getArmor() and player:getArmor():isKindOf("Vine") then		
		addGameData(name,1)
		if getGameData(name)==3 then 			 
			addZhanGong(room,name)
		end
	end		
end


-- hyjy :: 何以解忧 :: 一局游戏中，使用酒回复体力至少2次 
-- 
zgfunc[sgs.HpRecover].hyjy=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	local recov = data:toRecover()
	if recov.recover>=1 and player:getHp()==0 and recov.card and recov.card:isKindOf("Analeptic") then
		addGameData(name,1)
		if getGameData(name)==2 then 			 
			addZhanGong(room,name)
		end
	end
end


-- wydk :: 唯有杜康 :: 一局游戏中，使用酒后成功使用杀造成伤害至少3次 
-- 
zgfunc[sgs.Damage].wydk=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	local damage = data:toDamage()
	if damage and damage.card and (damage.to:getMark("SlashIsDrank") > 0) and damage.card:isKindOf("Slash") then
		addGameData(name,1)
		if getGameData(name)==3 then 			 
			addZhanGong(room,name)
		end
	end
end


-- gqbb :: 攻其不备 :: 一局游戏中，成功使用火攻造成伤害至少3次 
-- 
zgfunc[sgs.Damage].gqbb=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	local damage = data:toDamage()
	if damage and damage.card and damage.card:isKindOf("FireAttack") and (not damage.chain) and (not damage.transfer) and damage.by_user then
		addGameData(name,1)
		if getGameData(name)==3 then 			 
			addZhanGong(room,name)
		end
	end
end


-- bkclm :: 被看穿了吗 :: 一局游戏中，使用火攻失败至少3次 
-- 
zgfunc[sgs.ChoiceMade].bkclm=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	local choices= data:toString():split(":")
	if choices[1]=="cardResponded"  and  string.match(choices[3],"@fire%-attack") and choices[#choices]=="_nil_" then
		addGameData(name,1)
		if getGameData(name)==3 then
			addZhanGong(room,name)
		end
	end	
end


-- yntd :: 有难同当 :: 1局游戏中，使用铁索连环累计横置其他角色至少6次 
-- 
zgfunc[sgs.CardFinished].yntd=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	local use=data:toCardUse()
	local card=use.card
	local tos=sgs.QList2Table(use.to)
	if card:isKindOf("IronChain") and #tos>=1 then
		for i=1,#tos,1 do
			if (tos[i]:isChained()) then
				addGameData(name,1) 
				if getGameData(name)==6 then 			 
					addZhanGong(room,name)
				end	
			end
		end		
	end
end

-- fj :: 飞将 :: 使用吕布在1局游戏中发动方天画戟特效杀死至少2名角色 
-- 
zgfunc[sgs.SlashHit].fj=function(self, room, event, player, data,isowner,name)
	if room:getOwner():getGeneralName()~="lvbu" then return false end
	if not isowner then return false end
	local effect= data:toSlashEffect()
	if player:isKongcheng() and player:hasWeapon("Halberd") then
		effect.slash:setFlags(name)		
	end	
end


zgfunc[sgs.CardFinished].fj=function(self, room, event, player, data,isowner,name)
	if room:getOwner():getGeneralName()~="lvbu" then return false end
	if not isowner then return false end
	local use=data:toCardUse()
	local card=use.card	
	if card:isKindOf("Slash") and card:hasFlag(name) then
		effect.slash:setFlags("-"..name)	
	end
end


zgfunc[sgs.Death].fj=function(self, room, event, player, data,isowner,name)
	if room:getOwner():getGeneralName()~="lvbu" then return false end
	local damage=data:toDeath().damage
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() 
		and damage.from:getGeneralName()=="lvbu" and damage.card:hasFlag(name) then
		addGameData(name,1)	
		if getGameData(name)==2 then
			addZhanGong(room,name)
		end
	end	
end

zgfunc[sgs.GameOverJudge].callback.fj=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~="lvbu" then return false end
	local damage=data:toDeath().damage
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() 
		and damage.from:getGeneralName()=="lvbu" and damage.card:hasFlag(name) then
		addGameData(name,1)	
		if getGameData(name)==2 then
			addZhanGong(room,name)
		end
	end
end



-- qgqc :: 倾国倾城 :: 使用貂蝉在1局游戏中发动离间造成至少3名角色死亡 
-- 
zgfunc[sgs.Death].qgqc=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="diaochan" then return false end
	local damage=data:toDeath().damage
	if not damage then return false end
	if  room:getCurrent():objectName()==room:getOwner():objectName() and damage.card and damage.card:getSkillName()=="_lijian" then
		addGameData(name,1)	
		if getGameData(name)==3 then
			addZhanGong(room,name)
		end
	end	
end

zgfunc[sgs.GameOverJudge].callback.qgqc=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~="diaochan" then return false end
	local damage=data:toDeath().damage
	if not damage then return false end
	if  room:getCurrent():objectName()==room:getOwner():objectName() and damage.card and damage.card:getSkillName()=="_lijian" then
		addGameData(name,1)	
		if getGameData(name)==3 then
			addZhanGong(room,name)
		end
	end	
end


-- lsmy :: 乱世名医 :: 使用华佗在1局游戏中发动急救使至少3个不同的角色脱离濒死状态 
-- 
zgfunc[sgs.CardFinished].lsmy=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="huatuo" then return false end
	if not isowner then return false end
	local use=data:toCardUse()
	local card=use.card
	local tos=sgs.QList2Table(use.to)
	
	if card:getSkillName()=="jijiu" and tos[1]:getHp()>=1 then 
		if getGameData(name,0)==0 then setGameData(name,"") end
		local to=tos[1]:objectName()
		local val=getGameData(name)
		if not string.find(val,to..",") then 
			setGameData(name,val..to..",") 
			if string.match(getGameData(name),"^%w+,%w+,%w+,$") then
				addZhanGong(room,name)
			end
		end		
	end
end

-- lsdjx :: 乱世的奸雄 :: 使用曹操在1局游戏中发动奸雄得到至少3张南蛮入侵和1张万箭齐发 
-- 
zgfunc[sgs.CardsMoveOneTime].lsdjx=function(self, room, event, player, data,isowner,name)
	if room:getOwner():getGeneralName()~='caocao' or not isowner then return false end
	local move=data:toMoveOneTime()	
	local reason=move.reason
	local from_places=sgs.QList2Table(move.from_places)

	if move.to_place~=sgs.Player_PlaceHand or move.to:objectName()~=room:getOwner():objectName() then return false end
	if table.contains(from_places,sgs.Player_PlaceTable) then
		local ids=sgs.QList2Table(move.card_ids)
		for _,cid in ipairs(ids) do
			local card=sgs.Sanguosha:getCard(cid)
			if card:isKindOf("SavageAssault") then 
				addGameData(name.."SavageAssault",1) 
			end
			if card:isKindOf("ArcheryAttack") then 
				addGameData(name.."ArcheryAttack",1)
			end	
			if getGameData(name.."SavageAssault")>=3 and getGameData(name.."ArcheryAttack")>=1 then
				addZhanGong(room,name)
				setGameData(name.."SavageAssault",-100)
				setGameData(name.."ArcheryAttack",-100)
				return false
			end
		end
	end
end

-- yqwb :: 掩其无备 :: 使用张辽在1局游戏中发动至少10次突袭 
-- 
zgfunc[sgs.CardFinished].yqwb=function(self, room, event, player, data,isowner,name)
	if room:getOwner():getGeneralName()~="zhangliao" then return false end
	if not isowner then return false end
	local use=data:toCardUse()
	local card=use.card	
	if card:isKindOf("TuxiCard") then
		addGameData(name,1)
		if getGameData(name)==10 then
			addZhanGong(room,name)
		end	
	end
end


-- nswh :: 你死我活 :: 使用夏侯惇在1局游戏中发动刚烈杀死至少1名角色 
-- 
zgfunc[sgs.Death].nswh=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="xiahoudun" then return false end
	local damage=data:toDeath().damage
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() 
		and damage.from:getGeneralName()=="xiahoudun" and damage.reason == "ganglie" then
		addGameData(name,1)	
		if getGameData(name)==1 then
			addZhanGong(room,name)
		end
	end	
end

zgfunc[sgs.GameOverJudge].callback.nswh=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~="xiahoudun" then return false end
	local damage=data:toDeath().damage
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() 
		and damage.from:getGeneralName()=="xiahoudun" and  not damage.card then
		addGameData(name,1)	
		if getGameData(name)==1 then
			addZhanGong(room,name)
		end
	end	
end



-- mwl :: 妈，我冷 :: 使用许褚在1局游戏中发动裸衣至少2次并在裸衣的回合中杀死过至少2名角色 
-- 
zgfunc[sgs.ChoiceMade].mwl=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="xuchu" then return false end
	if not isowner then return false end
	local choices= data:toString():split(":")
	if choices[1]=="skillInvoke"  and  choices[2]=="luoyi" and choices[3]=="yes" then
		addGameData(name,1)
	end	
end

zgfunc[sgs.Death].mwl=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="xuchu" then return false end
	local damage=data:toDeath().damage
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() 
		and damage.from:hasFlag("luoyi") and getGameData(name)>=2 and damage.card 
		and (damage.card:isKindOf("Slash") or damage.card:isKindOf("Duel")) then
		addGameData(name.."kill",1)	
		if getGameData(name.."kill")==2 then
			addZhanGong(room,name)
		end
	end	
end

zgfunc[sgs.GameOverJudge].callback.mwl=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~="xuchu" then return false end
	local damage=data:toDeath().damage
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() 
		and damage.from:hasFlag("luoyi") and getGameData(name)>=2 and damage.card 
		and (damage.card:isKindOf("Slash") or damage.card:isKindOf("Duel")) then
		addGameData(name.."kill",1)	
		if getGameData(name.."kill")==2 then
			addZhanGong(room,name)
		end
	end		
end


-- byyl :: 不遗余力 :: 使用郭嘉在1局游戏中发动遗计发牌至少5次 
-- 
zgfunc[sgs.ChoiceMade].byyl=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="guojia" then return false end
	if not isowner then return false end
	local choices= data:toString():split(":")
	if choices[1]=="skillInvoke"  and  choices[2]=="yiji" and choices[3]=="yes" then
		addGameData(name,1)
		if getGameData(name)==5 then
			addZhanGong(room,name)
		end
	end	
end


-- sytt :: 手眼通天 :: 使用司马懿在1局游戏中有至少2次发动反馈都抽到对方1张桃 
-- 
zgfunc[sgs.ChoiceMade].sytt=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="simayi" then return false end
	if not isowner then return false end
	local choices= data:toString():split(":")
	if choices[1]=="cardChosen" and choices[2]=="fankui" and sgs.Sanguosha:getCard(choices[3]):isKindOf("Peach") then
		addGameData(name,1)
		if getGameData(name)==2 then
			addZhanGong(room,name)
		end
	end	
end




-- lsf :: 洛神赋 :: 使用甄姬一回合内发动洛神在不被改变判定牌的情况下连续判定黑色花色至少8次 
-- 
zgfunc[sgs.FinishRetrial].lsf=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="zhenji" then return false end
	if not isowner then return false end
	local judge=data:toJudge()
	if judge.reason=="luoshen" and judge.who:objectName()==room:getOwner():objectName() then
		if judge:isBad() then 
			setTurnData(name,0)
			return false
		end
		if room:getTag("retrial"):toBool()==false then			
			addTurnData(name,1)
			if getTurnData(name)==8 then 			 
				addZhanGong(room,name)			
			end
		end
	end
end


-- jjzx :: 纠结之心 :: 使用刘备在1局游戏中至少发动5次雌雄双股剑特效 
-- 
zgfunc[sgs.ChoiceMade].jjzx=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="liubei" then return false end
	if not isowner then return false end
	local choices= data:toString():split(":")
	if choices[1]=="skillInvoke"  and  choices[2]=="DoubleSword" and choices[3]=="yes" then
		addGameData(name,1)
		if getGameData(name)==5 then
			addZhanGong(room,name)
		end
	end	
end



-- yrdpx :: 燕人的咆哮 :: 使用张飞在1局游戏中发动丈八蛇矛特效杀死至少1名角色 
-- 
zgfunc[sgs.Death].yrdpx=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="zhangfei" then return false end
	local damage=data:toDeath().damage
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() 
		and damage.card and damage.card:getSkillName()=="Spear" then
		addGameData(name,1)	
		if getGameData(name)==1 then
			addZhanGong(room,name)
		end
	end	
end

zgfunc[sgs.GameOverJudge].callback.yrdpx=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~="zhangfei" then return false end
	local damage=data:toDeath().damage
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() 
		and damage.card and damage.card:getSkillName()=="Spear" then
		addGameData(name,1)	
		if getGameData(name)==1 then
			addZhanGong(room,name)
		end
	end	
end


-- qjtj :: 全军突击 :: 使用马超在1局游戏中发动铁骑连续判定红色花色至少5次 
-- 
zgfunc[sgs.FinishRetrial].qjtj=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="machao" then return false end
	local judge=data:toJudge()
	if judge.reason=="tieji" and judge.who:objectName()==room:getOwner():objectName() then
		if judge:isBad() then			
			setGameData(name,0)
		else
			addGameData(name,1)
		end
		if getGameData(name)==5 then 			 
			addZhanGong(room,name)
			setGameData(name,0)
		end
	end
end


-- wsxl :: 武圣显灵 :: 使用关羽在1局游戏中发动武圣至少杀死3名角色 
-- 
zgfunc[sgs.Death].wsxl=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="guanyu" then return false end
	local damage=data:toDeath().damage
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() 
		and damage.card and damage.card:getSkillName()=="wusheng" then
		addGameData(name,1)	
		if getGameData(name)==3 then
			addZhanGong(room,name)
		end
	end	
end

zgfunc[sgs.GameOverJudge].callback.wsxl=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~="guanyu" then return false end
	local damage=data:toDeath().damage
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() 
		and damage.card and damage.card:getSkillName()=="wusheng" then
		addGameData(name,1)	
		if getGameData(name)==3 then
			addZhanGong(room,name)
		end
	end	
end


-- hssd :: 浑身是胆 :: 使用赵云在1局游戏中发动龙胆至少杀死3名角色 
-- 
zgfunc[sgs.Death].hssd=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="zhaoyun" then return false end
	local damage=data:toDeath().damage
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() 
		and damage.card and damage.card:getSkillName()=="longdan" then
		addGameData(name,1)	
		if getGameData(name)==3 then
			addZhanGong(room,name)
		end
	end	
end

zgfunc[sgs.GameOverJudge].callback.hssd=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~="zhaoyun" then return false end
	local damage=data:toDeath().damage
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() 
		and damage.card and damage.card:getSkillName()=="longdan" then
		addGameData(name,1)	
		if getGameData(name)==3 then
			addZhanGong(room,name)
		end
	end	
end


-- jnd :: 锦囊袋 :: 使用黄月英在1个回合内发动至少10次集智 
-- 
zgfunc[sgs.CardFinished].jnd=function(self, room, event, player, data,isowner,name)
	if not isowner or player:getGeneralName()~="huangyueying" then return false end
	local use=data:toCardUse()
	local card=use.card
	if card:isNDTrick() then 
		addTurnData(name,1) 
		if getTurnData(name)==10 then 			 
			addZhanGong(room,name)
		end	
	end
	
end

-- kcjc :: 空城绝唱 :: 使用诸葛亮在1局游戏中有至少5个回合结束时是空城状态 
-- 
zgfunc[sgs.EventPhaseEnd].kcjc=function(self, room, event, player, data,isowner,name)
	if not isowner or player:getGeneralName()~="zhugeliang" then return false end
	if player:getPhaseString()=="finish" and player:isKongcheng() then
		addGameData(name,1)
		if getGameData(name)==5 then 			 
			addZhanGong(room,name)
		end			
	end
end


-- lbsd :: 老不死的 :: 使用孙权在1局游戏中被吴国武将用桃救活至少3次 
-- 
zgfunc[sgs.HpRecover].lbsd=function(self, room, event, player, data,isowner,name)
	if player:getGeneralName()~="sunquan" then return false end	
	if not isowner then return false end
	local recov = data:toRecover()
	if recov.card and recov.card:isKindOf("Peach") and (player:getHp()==0 or player:getHp()==-1)
		and recov.card:hasFlag("jiuyuan") then
		addGameData(name,1)
		if getGameData(name)==3 then			 
			addZhanGong(room,name)
		end
	end
end

-- scgm :: 神出鬼没 :: 使用甘宁在1个回合内发动至少6次奇袭 
-- 
zgfunc[sgs.CardFinished].scgm=function(self, room, event, player, data,isowner,name)
	if not isowner or player:getGeneralName()~="ganning" then return false end
	local use=data:toCardUse()
	local card=use.card
	if card:getSkillName()=="qixi" then 
		addTurnData(name,1) 
		if getTurnData(name)==6 then 			 
			addZhanGong(room,name)
		end	
	end
end


-- wjdbt :: 无尽的鞭挞 :: 使用黄盖1个回合内发动至少8次苦肉 
-- 
zgfunc[sgs.CardFinished].wjdbt=function(self, room, event, player, data,isowner,name)
	if not isowner or player:getGeneralName()~="huanggai" then return false end
	local use=data:toCardUse()
	local card=use.card
	if card:isKindOf("KurouCard") then
		addTurnData(name,1) 
		if getTurnData(name)==8 then 			 
			addZhanGong(room,name)
		end	
	end
end


-- sjdf :: 伺机待发 :: 使用吕蒙将手牌囤积到20张 
-- 
zgfunc[sgs.CardsMoveOneTime].sjdf=function(self, room, event, player, data,isowner,name)
	local move=data:toMoveOneTime()
	if room:getOwner():getGeneralName()=="lvmeng" and room:getOwner():getHandcardNum()>=20 and getGameData(name)==0 then 		 			 
		addZhanGong(room,name)
		setGameData(name,1)
	end
end


-- yhjm :: 移花接木 :: 使用大乔在一局游戏中累计发动5次流离 
-- 
zgfunc[sgs.CardFinished].yhjm=function(self, room, event, player, data,isowner,name)
	if not isowner or player:getGeneralName()~="daqiao" then return false end
	local use=data:toCardUse()
	local card=use.card
	if card:isKindOf('LiuliCard') then 
		addGameData(name,1) 
		if getGameData(name)==5 then 			 
			addZhanGong(room,name)
		end	
	end
end


-- yhdf :: 因祸得福 :: 使用孙尚香在1局游戏中累计失去至少5张已装备的装备牌
-- 
zgfunc[sgs.CardsMoveOneTime].yhdf=function(self, room, event, player, data,isowner,name)
	if room:getOwner():getGeneralName()~="sunshangxiang" then return false end
	if player:getGeneralName()~="sunshangxiang" then return false end
	local move=data:toMoveOneTime()
	local from_places=sgs.QList2Table(move.from_places)
	if move and move.from and move.from:objectName() == room:getOwner():objectName() and table.contains(from_places,sgs.Player_PlaceEquip) then
		for _, place in ipairs(from_places) do
			if place==sgs.Player_PlaceEquip then
				addGameData(name,1)
				if getGameData(name)==5 then 			 
					addZhanGong(room,name)
				end	
			end
		end
	end
end


-- wjdzz :: 无尽的挣扎 :: 使用周瑜在1局游戏中使用反间杀死至少3名角色 
-- 
zgfunc[sgs.Death].wjdzz=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="zhouyu" then return false end
	local damage=data:toDeath().damage
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() 
		and damage.from:getGeneralName()=="zhouyu" and  not damage.card then
		addGameData(name,1)	
		if getGameData(name)==3 then
			addZhanGong(room,name)
		end
	end	
end

zgfunc[sgs.GameOverJudge].callback.wjdzz=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~="zhouyu" then return false end
	local damage=data:toDeath().damage
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() 
		and damage.from:getGeneralName()=="zhouyu" and  not damage.card then
		addGameData(name,1)	
		if getGameData(name)==3 then
			addZhanGong(room,name)
		end
	end	
end


-- lmbj :: 连绵不绝 :: 使用陆逊在1个回合内发动至少10次连营 
-- 
zgfunc[sgs.ChoiceMade].lmbj=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="luxun" then return false end
	if not isowner then return false end
	local choices= data:toString():split(":")
	if choices[1]=="skillInvoke"  and  choices[2]=="lianying" and choices[3]=="yes" then
		addTurnData(name,1)
		if getTurnData(name)==10 then
			addZhanGong(room,name)
		end
	end	
end


-- fcdc :: 风驰电掣 :: 使用夏侯渊在1局游戏中，有连续至少3个回合每个回合都发动2次神速 
-- 
zgfunc[sgs.CardFinished].fcdc=function(self, room, event, player, data,isowner,name)
	if not isowner or player:getGeneralName()~="xiahouyuan" then return false end
	local use=data:toCardUse()
	local card=use.card
	if card:isKindOf("ShensuCard") then
		addTurnData(name,1)	
		if getTurnData(name)==2 and getGameData(name)==2 then
			addZhanGong(room,name)
			setGameData(name,0)
		end
	end
end

-- fcdc :: 风驰电掣 :: 使用夏侯渊在1局游戏中，有连续至少3个回合每个回合都发动2次神速 
-- 如果本回合已经发动两次神速, gamedata计算器+1
zgfunc[sgs.EventPhaseEnd].fcdc=function(self, room, event, player, data,isowner,name)
	if not isowner or player:getGeneralName()~="xiahouyuan" then return false end
	if player:getPhaseString()=="finish" then
		if getTurnData(name)==2 then 			 
			addGameData(name,1)
		else
			setGameData(name,0)
		end			
	end
end


-- ljdnx :: 老将的逆袭 :: 使用黄忠在1局游戏中，剩余1点体力时累计发动烈弓杀死至少3名角色 
--  
-- 这个战功仍然有bug,因为lua无法访问 QVariantList liegongList， 暂且这样
--

zgfunc[sgs.SlashEffected].ljdnx = function(self, room, event, player, data, isowner, name)
	if room:getOwner():getGeneralName() ~= "huangzhong" then return false end
	local effect = data:toSlashEffect()
	if (effect.from:objectName() == room:getOwner():objectName() and effect.jink_num == 0) then
		effect.from:setFlags("Liegong_" .. effect.slash:toString() .. "_" .. effect.to:objectName())
	end
end

zgfunc[sgs.Death].ljdnx=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="huangzhong" then return false end
	local damage=data:toDeath().damage
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() 
		and damage.from:getGeneralName()=="huangzhong" and damage.card:isKindOf("Slash") 
		and damage.from:hasFlag("Liegong_" .. damage.card:toString() .. "_" .. damage.to:objectName()) and damage.from:getHp()==1 then
		addGameData(name,1)	
		if getGameData(name)==3 then
			addZhanGong(room,name)
		end
	end	
end

-- ljdnx :: 老将的逆袭 :: 使用黄忠在1局游戏中，剩余1点体力时累计发动烈弓杀死至少3名角色 
-- 
zgfunc[sgs.GameOverJudge].callback.ljdnx=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~="huangzhong" then return false end
	local damage=data:toDeath().damage
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() 
		and damage.from:getGeneralName()=="huangzhong" and damage.card:isKindOf("Slash") 
		and damage.from:hasFlag("Liegong_" .. damage.card:toString() .. "_" .. damage.to:objectName()) and damage.from:getHp()==1 then
		addGameData(name,1)	
		if getGameData(name)==3 then
			addZhanGong(room,name)
		end
	end	
end

-- jqbd :: 金枪不倒 :: 使用周泰在1局游戏中拥有过至少9张不屈牌并且未死 
-- 
zgfunc[sgs.DamageComplete].jqbd=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="zhoutai" then return false end
	if not isowner then return false end
	local buqu=sgs.QList2Table(player:getPile("buqu"))
	if #buqu>=9 and getGameData(name)==0 then
		addZhanGong(room,name)
		setGameData(name,1)
	end	
end

-- sxcx :: 嗜血成性 :: 使用魏延在1回合内发动狂骨回复至少3点体力 
--  因为我们这个优先级比系统的高，所以先执行我们这个，系统才将 InvokeKuanggu置为false
zgfunc[sgs.Damage].sxcx=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="weiyan" then return false end
	if not isowner then return false end
	local damage=data:toDamage()
	if player:getTag("InvokeKuanggu"):toBool() and player:isWounded() then
		addTurnData(name,damage.damage)	
		if getTurnData(name)>=3 then
			addZhanGong(room,name)
			setTurnData(name,-100)
		end		
	end	
end


-- grjt :: 固若金汤 :: 使用曹仁在一局游戏中发动至少3次据守，并且在损失体力不多于3点的情况下获胜。 
-- 
zgfunc[sgs.ChoiceMade].grjt=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="caoren" then return false end
	if not isowner then return false end
	local choices= data:toString():split(":")
	if choices[1]=="skillInvoke"  and  choices[2]=="jushou" and choices[3]=="yes" then
		addGameData(name,1)
	end	
end

zgfunc[sgs.GameOverJudge].callback.grjt=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~="caoren" then return false end
	if result=='win' and getGameData(name)>=3 and room:getOwner():getLostHp()<=3 then
		addZhanGong(room,name)
	end		
end

-- lxxy :: 怜香惜玉 :: 使用小乔在一局游戏中发动天香让某名男性武将摸牌至少15张 
-- 
zgfunc[sgs.DamageComplete].lxxy=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="xiaoqiao" then return false end
	if player:hasFlag("TianxiangTarget") and player:isAlive() then
		addGameData(name,player:getLostHp())
		if getGameData(name)>=15 then
			addZhanGong(room,name)
			setGameData(name,-100)
		end
	end
end


-- kbdwn :: 狂奔的蜗牛 :: 使用张角在1局游戏发动雷击杀死至少3名角色 
-- 
zgfunc[sgs.Death].kbdwn=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="zhangjiao" then return false end
	local damage=data:toDeath().damage
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() 
		and damage.from:getGeneralName()=="zhangjiao" and damage.reason == "leiji" and damage.nature == sgs.DamageStruct_Thunder then
		addGameData(name,1)	
		if getGameData(name)==3 then
			addZhanGong(room,name)
		end
	end	
end

zgfunc[sgs.GameOverJudge].callback.kbdwn=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~="zhangjiao" then return false end
	local damage=data:toDeath().damage
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() 
		and damage.from:getGeneralName()=="zhangjiao" and damage.reason == "leiji" and damage.nature == sgs.DamageStruct_Thunder then
		addGameData(name,1)	
		if getGameData(name)==3 then
			addZhanGong(room,name)			
		end
	end	
end



-- sgmc :: 神鬼莫测 :: 使用于吉在1局游戏中累计蛊惑假牌至少成功3次 
-- 
zgfunc[sgs.CardFinished].sgmc=function(self, room, event, player, data,isowner,name)
	if room:getOwner():getGeneralName() ~="yuji" then return false end
	if not isowner then return false end	
	local use=data:toCardUse()
	local card=use.card
	local part=card:toString():split(":")
	if part and #part==3 and string.find(part[2],"guhuo%[") then
		local card2 = nil
		local arr=part[3]:split("=")
		if arr[2]=="." then
			return false
		else
			card2=sgs.Sanguosha:getCard(arr[2])
		end
		if card2 and part[1]~=card2:objectName()  then
			addGameData(name,1)
			if getGameData(name)==3 then
				addZhanGong(room,name)
			end
		end
	end
end


-- sssg :: 四世三公 :: 使用袁术在1回合内消灭场上4个势力中的3个 
-- 
zgfunc[sgs.Death].sssg=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="yuanshu" then return false end
	local owner=room:getOwner()
	local damage=data:toDeath().damage
	if damage and damage.from and damage.from:objectName()==owner:objectName() then
		local kingdom=player:getKingdom()
		local same=false
		for _,p in sgs.qlist(room:getAlivePlayers()) do
			if p:getKingdom()==kingdom then same=true end
		end
		if not same then
			addTurnData(name,1)
		end
		if getTurnData(name)==3 then
			addZhanGong(room,name)
			setTurnData(name,0)
		end
	end
end

zgfunc[sgs.GameOverJudge].callback.sssg=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~="yuanshu" then return false end
	local owner=room:getOwner()
	local damage=data:toDeath().damage
	if damage and damage.from and damage.from:objectName()==owner:objectName() then
		local kingdom=player:getKingdom()
		local same=false
		for _,p in sgs.qlist(room:getAlivePlayers()) do
			if p:getKingdom()==kingdom then same=true end
		end
		if not same then
			addTurnData(name,1)
		end
		if getTurnData(name)==3 then
			addZhanGong(room,name)
			setTurnData(name,0)
		end
	end
end

-- bmyc :: 白马义从 :: 使用公孙瓒在体力大于2的情况下杀死至少3名角色，并且在体力1的情况下存活并获胜。 
-- 
zgfunc[sgs.Death].bmyc=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="gongsunzan" then return false end
	local owner=room:getOwner()
	local damage=data:toDeath().damage
	if damage and damage.from and damage.from:objectName()==owner:objectName() and owner:getHp()>2 then
		addGameData(name,1)	
	end	
end

zgfunc[sgs.GameOverJudge].callback.bmyc=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~="gongsunzan" then return false end
	local owner=room:getOwner()
	if result=="win" and owner:getHp()==1 and getGameData(name)>=3 then
		addZhanGong(room,name)
	end
end


-- yfdg :: 一夫当关 :: 使用典韦在1局游戏中发动至少5次强袭 
-- 
zgfunc[sgs.CardFinished].yfdg=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="dianwei" then return false end
	if not isowner then return false end
	local use=data:toCardUse()
	local card=use.card	
	if card:isKindOf("QiangxiCard") then
		addGameData(name,1)
		if getGameData(name)==5 then
			addZhanGong(room,name)
		end
	end
end



-- qhtl :: 驱虎吞狼 :: 使用荀彧在1局游戏中至少发动5次驱虎并拼点成功
-- 
zgfunc[sgs.ChoiceMade].qhtl=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="xunyu" then return false end
	if not isowner then return false end
	local choices= data:toString():split(":")
	if choices[1]=="playerChosen"  and  choices[2]=="quhu" then
		addGameData(name,1)
		if getGameData(name)==5 then
			addZhanGong(room,name)
		end
	end	
end

-- tslz :: 铁锁连舟 :: 使用庞统在1回合内发动连环横置至少6名角色
-- 
zgfunc[sgs.CardFinished].tslz=function(self, room, event, player, data,isowner,name)
	if room:getOwner():getGeneralName()~="pangtong" then return false end
	if not isowner then return false end
	local use=data:toCardUse()
	local card=use.card
	local tos=sgs.QList2Table(use.to)
	if card:isKindOf("IronChain") and card:getSkillName()=="lianhuan" and #tos>=1 then
		for i=1,#tos,1 do
			if (tos[i]:isChained()) then
				addTurnData(name,1) 
				if getTurnData(name)==6 then 			 
					addZhanGong(room,name)
				end	
			end
		end		
	end
end


-- thly :: 天火燎原 :: 使用卧龙诸葛亮在1回合内发动火计造成至少6点伤害 
-- 
zgfunc[sgs.Damage].thly=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="wolong" then return false end
	if not isowner then return false end
	local damage = data:toDamage()
	if damage and damage.card and damage.card:getSkillName()=="huoji" then
		addTurnData(name,damage.damage)
		if getTurnData(name)>=6 then 			 
			addZhanGong(room,name)
			setTurnData(name,-100)
		end
	end
end


-- jdzh :: 江东之虎 :: 使用太史慈在1回合内发动天义拼点胜利后，使用【杀】杀死至少3名角色 
-- 
zgfunc[sgs.Death].jdzh=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="taishici" then return false end
	local owner=room:getOwner()
	local damage=data:toDeath().damage
	if damage and damage.from and damage.from:objectName()==owner:objectName() 
		and damage.card and damage.card:isKindOf("Slash") and damage.from:hasFlag("TianyiSuccess") then
		addTurnData(name,1)
		if getTurnData(name)==3 then
			addZhanGong(room,name)
		end
	end	
end

zgfunc[sgs.GameOverJudge].callback.jdzh=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~="taishici" then return false end
	local owner=room:getOwner()
	local damage=data:toDeath().damage
	if damage and damage.from and damage.from:objectName()==owner:objectName() 
		and damage.card and damage.card:isKindOf("Slash") and damage.from:hasFlag("TianyiSuccess") then
		addTurnData(name,1)
		if getTurnData(name)==3 then
			addZhanGong(room,name)
		end
	end	
end


-- ljsd :: 乱箭肃敌 :: 使用袁绍在1回合内发动乱击至少6次 
-- 
zgfunc[sgs.CardFinished].ljsd=function(self, room, event, player, data,isowner,name)
	if not isowner or player:getGeneralName()~="yuanshao" then return false end
	local use=data:toCardUse()
	local card=use.card
	if card:getSkillName()=="luanji" then 
		addTurnData(name,1) 
		if getTurnData(name)==6 then 			 
			addZhanGong(room,name)
		end	
	end
end


-- qldj :: 其利断金 :: 使用颜良文丑在1局游戏中发动双雄至少3次并在双雄的回合中杀死过至少3名角色 
-- 
zgfunc[sgs.ChoiceMade].qldj=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="yanliangwenchou" then return false end
	if not isowner then return false end
	local choices= data:toString():split(":")
	if choices[1]=="skillInvoke"  and  choices[2]=="shuangxiong" and choices[3]=="yes" then
		addGameData(name,1)
		setTurnData(name,1)
	end	
end

zgfunc[sgs.Death].qldj=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="yanliangwenchou" then return false end
	local owner=room:getOwner()
	local damage=data:toDeath().damage
	if damage and damage.from and damage.from:objectName()==owner:objectName() and getTurnData(name)==1 then
		addGameData(name.."kill",1)
		if getGameData(name.."kill")==3 then
			addZhanGong(room,name)
		end
	end	
end

zgfunc[sgs.GameOverJudge].callback.qldj=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~="yanliangwenchou" then return false end
	local owner=room:getOwner()
	local damage=data:toDeath().damage
	if damage and damage.from and damage.from:objectName()==owner:objectName() and getTurnData(name)==1 then
		addGameData(name.."kill",1)
		if getGameData(name.."kill")==3 then
			addZhanGong(room,name)
		end
	end	
end


-- zkzj :: 周苛之节 :: 使用庞德在1局游戏中发动猛进至少5次
-- 
zgfunc[sgs.ChoiceMade].zkzj=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="pangde" then return false end
	if not isowner then return false end
	local choices= data:toString():split(":")
	if choices[1]=="skillInvoke"  and  choices[2]=="mengjin" and choices[3]=="yes" then
		addGameData(name,1)
		if getGameData(name)==5 then
			addZhanGong(room,name)
		end
	end	
end


-- bsyz :: 背水一战 :: 身为主帅，在本方两名前锋阵亡的情况下，杀死对方3人后获胜 (3v3)
-- 
zgfunc[sgs.Death].bsyz=function(self, room, event, player, data,isowner,name)
	if room:getMode()~="06_3v3" then return false end	
	local alives=sgs.QList2Table(room:getAlivePlayers())
	local isLastAlive=true
	local myRole=room:getOwner():getRole()
	if myRole=='loyalist' or myRole=='rebel' then return false end
	for i=1,#alives,1 do
		if myRole=='lord' and alives[i]:getRole()=='loyalist'  then isLastAlive=false end
		if myRole=='renegade' and alives[i]:getRole()=='rebel' then isLastAlive=false end
	end
	if isLastAlive and #alives==4 then setGameData(name,1) end
end


zgfunc[sgs.GameOverJudge].callback.bsyz=function(room,player,data,name,result)
	if room:getMode()~="06_3v3" then return false end	
	if not result=="win" then return false end
	local myRole=room:getOwner():getRole()
	if myRole=='loyalist' or myRole=='rebel' then return false end
	
	local alives=sgs.QList2Table(room:getAlivePlayers())
	
	if getGameData(name)==1 and #alives==1 then
		addZhanGong(room,name)
	end	
end



-- ygzq :: 一鼓作气 :: 一回合内杀死对方3名角色 (3v3)
-- 
zgfunc[sgs.Death].ygzq=function(self, room, event, player, data,isowner,name)
	if room:getMode()~="06_3v3" then return false end
	local owner=room:getOwner()
	local damage=data:toDeath().damage
	local role1=owner:getRole()
	local role2=player:getRole()
	if ((string.find("lord,loyalist",role1) and role2=="rebel") or (string.find("rebel,renegade",role1) and role2=="loyalist"))
			and room:getCurrent():objectName()==room:getOwner():objectName() 
			and damage and damage.from and damage.from:objectName()==owner:objectName() then
		addTurnData(name,1)
	end
end

zgfunc[sgs.GameOverJudge].callback.ygzq=function(room,player,data,name,result)
	if room:getMode()~="06_3v3" then return false end	
	if not result=="win" then return false end
	local damage=data:toDeath().damage
	if room:getCurrent():objectName()==room:getOwner():objectName() and getTurnData(name)==2
			and damage and damage.from and damage.from:objectName()==room:getOwner():objectName() then
		addZhanGong(room,name)
	end
end


-- swjd :: 肆无忌惮 :: 一回合内使用至少3张南蛮入侵或万箭齐发 (3v3)
-- 
zgfunc[sgs.CardFinished].swjd=function(self, room, event, player, data,isowner,name)
	if room:getMode()~="06_3v3" then return false end	
	if not isowner then return false end
	local use=data:toCardUse()
	local card=use.card
	if card:isKindOf("SavageAssault") or card:isKindOf("ArcheryAttack") then 
		addTurnData(name,1) 
		if getTurnData(name)==3 then
			addZhanGong(room,name)
		end
	end	
end


-- bfh :: 暴发户 :: 一回合内获得至少10张手牌 (3v3)
-- 
zgfunc[sgs.EventPhaseStart].bfh=function(self, room, event, player, data,isowner,name)
	if room:getMode()~="06_3v3" then return false end	
	if not isowner then return false end
	if player:getPhaseString()=="start" then
		setTurnData(name,player:getHandcardNum())
	end		
end

zgfunc[sgs.CardsMoveOneTime].bfh=function(self, room, event, player, data,isowner,name)
	if room:getMode()~="06_3v3" then return false end
	if not room:getOwner():objectName()==room:getCurrent():objectName() then return false end
	local move=data:toMoveOneTime()
	if room:getOwner():getHandcardNum() - getTurnData(name)>=10 then 		 			 
		addZhanGong(room,name)
		setTurnData(name,100)		
	end
end


-- ssqy :: 舍生取义 :: 身为前锋，被本方角色杀死累计10次 (3v3)
-- 
zgfunc[sgs.Death].ssqy=function(self, room, event, player, data,isowner,name)
	if room:getMode()~="06_3v3" then return false end
	if not isowner then return false end
	local damage=data:toDeath().damage
	local killerRole=damage.from and damage.from:getRole() or ""
	if (player:getRole()=="loyalist" and (killerRole=="lord" or killerRole=="loyalist")) or 
			(player:getRole()=="rebel" and (killerRole=="rebel" or killerRole=="renegade")) then
		addGlobalData(name,1)
		local zgquery=db:first_row("select gained from zhangong where id='"..name.."'")
		if getGlobalData(name)>=10 and zgquery and zgquery.gained==0 then
			addZhanGong(room,name)
		end
	end
end


-- zdhl :: 直捣黄龙 :: 在对方两名前锋都没有受伤的情况下杀死对方主帅 (3v3)
-- 
zgfunc[sgs.GameOverJudge].callback.zdhl=function(room,player,data,name,result)
	if room:getMode()~="06_3v3" then return false end	
	if not result=="win" then return false end
	local ownerRole = room:getOwner():getRole()
	local guardRole = (ownerRole=="lord" or ownerRole=="loyalist") and "rebel" or "loyalist"
	local num=0
	for _, p in sgs.qlist(room:getPlayers()) do
		if p:getRole()==guardRole and p:isAlive() and not p:isWounded() then num=num+1 end
	end
	if num==2 then
		addZhanGong(room,name)
	end	
end

-- szsj :: 速战速决 :: 在自己的首回合结束前获得胜利 (3v3)
-- 
zgfunc[sgs.GameOverJudge].callback.szsj=function(room,player,data,name,result)
	if room:getMode()~="06_3v3" then return false end	
	if not result=="win" then return false end	
	if getGameData("turncount")==0 or (getGameData("turncount")==1 and room:getCurrent():objectName()==room:getOwner():objectName()) then
		addZhanGong(room,name)
	end	
end


-- cjz :: 持久战 :: 在自己的第5回合结束后获得胜利 (3v3)
-- 
zgfunc[sgs.GameOverJudge].callback.cjz=function(room,player,data,name,result)
	if room:getMode()~="06_3v3" then return false end	
	if not result=="win" then return false end	
	if getGameData("turncount")>5 or (getGameData("turncount")==5 and room:getCurrent():objectName()~=room:getOwner():objectName()) then
		addZhanGong(room,name)
	end	
end


-- mlgr :: 谋略过人 :: 选择了3名3血武将并且获胜 (1v1)
-- 
zgfunc[sgs.GameStart].mlgr=function(self, room, event, player, data,isowner,name)
	if not isowner or room:getMode()~="02_1v1" then return false end
	if sgs.GetConfig("1v1/Rule", "")  == "OL" then return false end
	local list = room:getOwner():getTag("1v1Arrange"):toStringList()
	local n=0
	for _, generalname in ipairs(list) do
		local general = sgs.Sanguosha:getGeneral(generalname)
		if general:getMaxHp()==3 then n=n+1 end
	end
	if player:getMaxHp()==3 then n=n+1 end
	if n==3 then
		setGameData(name,1)
	end
end

zgfunc[sgs.GameOverJudge].callback.mlgr=function(room,player,data,name,result)
	if result=='win' and getGameData(name)==1 then
		addZhanGong(room,name)
	end		
end


-- ymgr :: 勇猛过人 :: 选择了3名4血武将并且获胜 (1v1)
-- 
zgfunc[sgs.GameStart].ymgr=function(self, room, event, player, data,isowner,name)
	if not isowner or room:getMode()~="02_1v1" then return false end
	if sgs.GetConfig("1v1/Rule", "")  == "OL" then return false end
	local list = room:getOwner():getTag("1v1Arrange"):toStringList()
	local n=0
	for _, generalname in ipairs(list) do
		local general = sgs.Sanguosha:getGeneral(generalname)
		if general:getMaxHp()==4 then n=n+1 end
	end
	if player:getMaxHp()==4 then n=n+1 end
	if n==3 then
		setGameData(name,1)
	end
end

zgfunc[sgs.GameOverJudge].callback.ymgr=function(room,player,data,name,result)
	if result=='win' and getGameData(name)==1 then
		addZhanGong(room,name)
	end		
end



-- bbxr :: 兵不血刃 :: 对方3名武将都在他们各自的回合阵亡 (1v1)
-- 
zgfunc[sgs.Death].bbxr=function(self, room, event, player, data,isowner,name)
	if room:getMode()~="02_1v1" then return false end
	if room:getCurrent():objectName()==player:objectName() then
		addGameData(name,1)
	end 
end

zgfunc[sgs.GameOverJudge].callback.bbxr=function(room,player,data,name,result)
	if result=='win' and room:getCurrent():objectName()==player:objectName() then
		addGameData(name,1)
		if getGameData(name)==3 then
			addZhanGong(room,name)
		end
	end		
end

-- jgyx :: 巾帼英雄 :: 选择3名女性武将并且获胜 (1v1)
-- 
zgfunc[sgs.GameStart].jgyx=function(self, room, event, player, data,isowner,name)
	if not isowner or room:getMode()~="02_1v1" then return false end
	if sgs.GetConfig("1v1/Rule", "")  == "OL" then return false end
	local list = room:getOwner():getTag("1v1Arrange"):toStringList()
	local n=0
	for _, generalname in ipairs(list) do
		local general = sgs.Sanguosha:getGeneral(generalname)
		if general:isFemale() then n=n+1 end
	end
	if player:isFemale() then n=n+1 end
	if n==3 then
		setGameData(name,1)
	end
end

zgfunc[sgs.GameOverJudge].callback.jgyx=function(room,player,data,name,result)
	if result=='win' and getGameData(name)==1 then
		addZhanGong(room,name)
	end		
end


-- hgjs :: 护国军师 :: 以诸葛亮、司马懿、周瑜为上场武将的情况下获胜 (1v1)
-- 
zgfunc[sgs.GameStart].hgjs=function(self, room, event, player, data,isowner,name)
	if not isowner or room:getMode()~="02_1v1" then return false end
	if sgs.GetConfig("1v1/Rule", "")  == "OL" then return false end
	local list = table.concat(room:getOwner():getTag("1v1Arrange"):toStringList(),",")
	local n=0
	list=list..","..player:getGeneralName()
	for _, generalname in ipairs({"zhugeliang","simayi","zhouyu"}) do
		if string.match(list,generalname) then n=n+1 end
	end
	if n==3 then
		setGameData(name,1)
	end
end

zgfunc[sgs.GameOverJudge].callback.hgjs=function(room,player,data,name,result)
	if result=='win' and getGameData(name)==1 then
		addZhanGong(room,name)
	end		
end


-- hfws :: 毫发无伤 :: 在本方所有武将满体力的情况下胜利 (1v1)
-- 
zgfunc[sgs.GameOverJudge].callback.hfws = function(room, player, data, name, result)
	if room:getMode()~="02_1v1" then return false end
	local count = sgs.GetConfig("1v1/Rule", "")  == "OL" and 5 or 2
	local list = room:getOwner():getTag("1v1Arrange"):toStringList()
	if result == 'win' and not room:getOwner():isWounded() and #list == count then
		addZhanGong(room, name)
	end
end

-- jtnz :: 惊天逆转 :: 在本方剩余1名武将时，杀死对方3名武将获胜 (1v1)
-- 
zgfunc[sgs.Death].jtnz=function(self, room, event, player, data,isowner,name)
	if room:getMode()~="02_1v1" then return false end
	if sgs.GetConfig("1v1/Rule", "")  == "OL" then return false end
	local list = room:getOwner():getTag("1v1Arrange"):toStringList()
	local list2 = room:getOwner():getNext():getTag("1v1Arrange"):toStringList()

	if #list==1 and #list2==2 and player:objectName()==room:getOwner():objectName() then
		setGameData(name,1)
	end 
end

zgfunc[sgs.GameOverJudge].callback.jtnz=function(room,player,data,name,result)
	if result=='win' and getGameData(name)==1 then
		addZhanGong(room,name)
	end		
end


-- yywm :: 有勇无谋 :: 以吕布、张飞、许褚为上场武将的情况下获胜 (1v1)
-- 
zgfunc[sgs.GameStart].yywm=function(self, room, event, player, data,isowner,name)
	if not isowner or room:getMode()~="02_1v1" then return false end
	if sgs.GetConfig("1v1/Rule", "")  == "OL" then return false end
	local list = table.concat(room:getOwner():getTag("1v1Arrange"):toStringList(),",")
	local n=0
	list=list..","..player:getGeneralName()
	for _, generalname in ipairs({"lvbu","zhangfei","xuchu"}) do
		if string.match(list,generalname) then n=n+1 end
	end
	if n==3 then
		setGameData(name,1)
	end
end

zgfunc[sgs.GameOverJudge].callback.yywm=function(room,player,data,name,result)
	if result=='win' and getGameData(name)==1 then
		addZhanGong(room,name)
	end		
end


-- zysq :: 智勇双全 :: 以关羽、赵云、黄忠为上场武将的情况下获胜 (1v1)
-- 
zgfunc[sgs.GameStart].zysq=function(self, room, event, player, data,isowner,name)
	if not isowner or room:getMode()~="02_1v1" then return false end
	if sgs.GetConfig("1v1/Rule", "")  == "OL" then return false end
	local list = table.concat(room:getOwner():getTag("1v1Arrange"):toStringList(),",")
	local n=0
	list=list..","..player:getGeneralName()
	for _, generalname in ipairs({"guanyu","zhaoyun","huangzhong"}) do
		if string.match(list,generalname) then n=n+1 end
	end
	if n==3 then
		setGameData(name,1)
	end
end

zgfunc[sgs.GameOverJudge].callback.zysq=function(room,player,data,name,result)
	if result=='win' and getGameData(name)==1 then
		addZhanGong(room,name)
	end		
end


-- wwd2 :: 魏文帝 :: 使用曹丕在1局游戏中发动行殇获得锦囊牌至少6张 
--
zgfunc[sgs.CardsMoveOneTime].wwd2=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='caopi' or not isowner then return false end
	local move=data:toMoveOneTime()
	if move.to and move.to:objectName()~=room:getOwner():objectName() then return end
	local reason=move.reason.m_reason	
	local ids=sgs.QList2Table(move.card_ids)
	if reason==sgs.CardMoveReason_S_REASON_RECYCLE then 
		for _,cid in ipairs(ids) do
			local card=sgs.Sanguosha:getCard(cid)
			if card:isKindOf("TrickCard") then
				addGameData(name,1)
				if getGameData(name)==6 then
					addZhanGong(room,name)
				end
			end
		end
	end
end


-- djlj :: 粮尽援绝 :: 使用徐晃在1局游戏中用装备区的牌发动断粮至少4次 
--
zgfunc[sgs.CardsMoveOneTime].djlj=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='xuhuang' then return false end
	local move=data:toMoveOneTime()
	if move.from and move.from:objectName()~=room:getOwner():objectName() then return end
	local ids=sgs.QList2Table(move.card_ids)
	local card=sgs.Sanguosha:getCard(ids[1])

	local from_places=sgs.QList2Table(move.from_places)
	if table.contains(from_places,sgs.Player_PlaceEquip) then
		for _, place in ipairs(from_places) do
			if place==sgs.Player_PlaceEquip and move.to_place == sgs.Player_PlaceDelayedTrick then
				addGameData(name,1)
				if getGameData(name)==4 then 			 
					addZhanGong(room,name)
				end	
			end
		end
	end	
end



-- qqqz :: 七擒七纵 :: 使用孟获在1局游戏中发动再起回复体力至少7点 
--
zgfunc[sgs.CardsMoveOneTime].qqqz=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='menghuo' or not isowner then return false end
	local move=data:toMoveOneTime()
	if room:getCurrent():objectName()~=room:getOwner():objectName() then return end
	local reason=move.reason.m_reason
	local ids=sgs.QList2Table(move.card_ids)
	if reason==sgs.CardMoveReason_S_REASON_NATURAL_ENTER and move.reason.m_skillName=="zaiqi" then 
		for _,cid in ipairs(ids) do
			local card=sgs.Sanguosha:getCard(cid)
			if card:getSuit()==sgs.Card_Heart then
				addGameData(name,1)
				if getGameData(name)==7 then
					addZhanGong(room,name)
				end
			end
		end
	end
end



-- cmr :: 刺美人 :: 使用祝融在1局游戏中对一名男性发动烈刃并拼点赢至少3次 
--
zgfunc[sgs.Pindian].cmr=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='zhurong' then return false end
	if not isowner then return false end
	local pindian=data:toPindian()
	if pindian.from:getGeneralName()=='zhurong' and pindian.to:isMale() and pindian.reason=='lieren' 
			and pindian.from_card:getNumber() > pindian.to_card:getNumber() then
		addGameData(name,1)
		if getGameData(name)==3 then
			addZhanGong(room,name)
		end
	end
end


-- pndjj :: 破虏大将军 :: 使用孙坚连续至少3回合在1体力时发动英魂 
--
zgfunc[sgs.ChoiceMade].pndjj=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='sunjian' then return false end
	if not isowner then return false end
	local choices= data:toString():split(":")
	if choices[1]=="skillChoice"  and  choices[2]=="yinghun" and player:getHp()==1 then
		local count=name.."count"
		if getGameData(count,0)==0 then			
			addGameData(name,1)
		else
			if getGameData("turncount")-getGameData(count,0)==1 then
				addGameData(name,1)				
			else
				setGameData(name,1)	
			end			
		end
		setGameData(count,getGameData("turncount"))
		if getGameData(name)==3 then
			addZhanGong(room,name)
		end
	end	
end


-- zqxz :: 指囷相赠 :: 使用鲁肃在1局游戏中发动好施分给其他角色至少15张牌 
--
zgfunc[sgs.CardFinished].zqxz=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='lusu' then return false end
	if not isowner then return false end
	local use=data:toCardUse()
	local card=use.card
	if card:isKindOf('HaoshiCard') then
		addGameData(name,card:subcardsLength())
		if getGameData(name)>=15 then
			addZhanGong(room,name)
			setGameData(name,-1000)
		end
	end
end


-- rs :: 肉山 :: 使用董卓在1局游戏中使用杀杀死至少3名女性角色 
--
zgfunc[sgs.Death].rs=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='dongzhuo' then return false end
	local damage = data:toDeath().damage
	if not damage then return false end
	local killer=damage.from
	if not killer then return false end
	if player:isFemale() and killer:objectName()==room:getOwner():objectName() and damage.card and damage.card:isKindOf("Slash") then
		addGameData(name,1)		
		if getGameData(name,0)==3 then
			addZhanGong(room,name)
		end
	end		
end


-- rs :: 肉山 :: 使用董卓在1局游戏中使用杀杀死至少3名女性角色 
--
zgfunc[sgs.GameOverJudge].callback.rs=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~='dongzhuo' then return false end
	local damage = data:toDeath().damage
	if not damage then return false end
	local killer=damage.from
	if not killer then return false end
	if player:isFemale() and killer:objectName()==room:getOwner():objectName() and damage.card and damage.card:isKindOf("Slash") then
		addGameData(name,1)
		if getGameData(name)==3 then 			 
			addZhanGong(room,name)
		end
	end		
end


-- lsgj :: 乱世歌姬 :: 使用蔡文姬在一局中发动悲歌至少4次 发动断肠并最终获胜 
--
zgfunc[sgs.ChoiceMade].lsgj=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='caiwenji' then return false end
	if not isowner then return false end
	local choices= data:toString():split(":")
	if choices[1]=="skillInvoke"  and  choices[2]=="beige" and choices[3]=="yes" then
		addGameData(name,1)
	end
end

zgfunc[sgs.Death].lsgj=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="caiwenji" then return false end
	local damage=data:toDeath().damage
	if damage and damage.from and damage.from:objectName()~=room:getOwner():objectName() 
			and damage.to:objectName()==room:getOwner():objectName() then
		setGameData(name.."duanchang",1)	
	end	
end

zgfunc[sgs.GameOverJudge].callback.lsgj=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~='caiwenji' then return false end
	if result=='win' and getGameData(name)>=4 and getGameData(name.."duanchang")==1 then
		addZhanGong(room,name)
	end		
end



-- fwjj :: 辅吴将军 :: 使用张昭&张纮在一局中发动直谏将至少5张装备牌置于吴势力武将装备区 
--[[
zgfunc[sgs.CardsMoveOneTime].fwjj=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='erzhang' then return false end
	local move=data:toMoveOneTime()
	if room:getCurrent():objectName()~=room:getOwner():objectName() then return end
	local reason=move.reason.m_reason
	if reason==sgs.CardMoveReason_S_REASON_USE and move.reason.m_skillName=="zhijian" and move.to:getKingdom()=='wu'
			and isowner and room:getCurrent():objectName()==room:getOwner():objectName() then
		addGameData(name,1)
		if getGameData(name)==5 then
			addZhanGong(room,name)
		end		
	end
end]]

zgfunc[sgs.CardFinished].fwjj = function(self, room, event, player, data, isowner, name)
	if room:getOwner():getGeneralName() ~= "erzhang" then return false end
	if room:getCurrent():objectName() ~= room:getOwner():objectName() then return end
	local use = data:toCardUse()
	local to = use.to:first()
	if (use.card:isKindOf("ZhijianCard") and to:getKingdom() == "wu" and isowner) then
		addGameData(name, 1)
		if getGameData(name) == 5 then
			addZhangong(room, name)
		end
	end
end


-- dzry :: 大智若愚 :: 使用刘禅每回合都发动放权并最终获胜 
--
zgfunc[sgs.ChoiceMade].dzry=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='liushan' then return false end
	if not isowner then return false end
	local choices= data:toString():split(":")
	if choices[1]=="skillInvoke"  and  choices[2]=="fangquan" and choices[3]=="no" then
		setGameData(name,1)
	end
end

zgfunc[sgs.GameOverJudge].callback.dzry=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~='liushan' then return false end
	if result=='win' and getGameData(name,0)==0 then			 
		addZhanGong(room,name)
	end		
end



-- mrgs :: 猛锐盖世 :: 使用孙策在一局游戏中发动激昂摸牌至少5张并发动技能魂姿 
--
zgfunc[sgs.ChoiceMade].mrgs=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='sunce' then return false end
	if not isowner then return false end
	local choices= data:toString():split(":")
	if choices[1]=="skillInvoke"  and  choices[2]=="jiang" and choices[3]=="yes" then
		setGameData(name..'jiang',math.min(5,getGameData(name..'jiang')+1))
		if getGameData(name..'jiang')==5 and getGameData(name..'hunzi')==1 then
			addZhanGong(room,name)
			setGameData(name..'hunzi',0)
		end
	end
end

zgfunc[sgs.EventPhaseStart].mrgs=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='sunce' then return false end
	if not isowner then return false end
	if player:getPhaseString()=="start" and player:getMark("hunzi")==0 and player:getHp() == 1 then
		setGameData(name..'hunzi',1)
		if getGameData(name..'jiang')==5 then
			addZhanGong(room,name)
			setGameData(name..'hunzi',0)
		end
	end		
end



-- bzcq :: 变拙成巧 :: 使用张郃在一局游戏中发动巧变移动判定区的牌及装备区的牌各至少3张 
--
zgfunc[sgs.CardsMoveOneTime].bzcq=function(self, room, event, player, data,isowner,name)
	if room:getOwner():getGeneralName()~="zhanghe" then return false end
	local move=data:toMoveOneTime()
	local from_places=sgs.QList2Table(move.from_places)
	local reason=move.reason
	if reason.m_reason==sgs.CardMoveReason_S_REASON_TRANSFER and reason.m_playerId==room:getOwner():objectName() 
		and reason.m_skillName=="qiaobian" and isowner and room:getCurrent():objectName()==room:getOwner():objectName() then
		if table.contains(from_places,sgs.Player_PlaceEquip) then 
			setGameData(name..'equip',math.min(3,getGameData(name..'equip')+1))
		end
		if table.contains(from_places,sgs.Player_PlaceDelayedTrick) then 
			setGameData(name..'judge',math.min(3,getGameData(name..'judge')+1))
		end
		if getGameData(name..'equip')==3 and getGameData(name..'judge')==3 then
			addZhanGong(room,name)
			setGameData(name..'judge',-100)
		end
	end
end


-- szzjz :: 蜀之终结者 :: 使用邓艾在一回合内发动急袭至少4次 
--
zgfunc[sgs.CardFinished].szzjz=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='dengai' then return false end
	if not isowner then return false end
	local use=data:toCardUse()
	local card=use.card
	if card:getSkillName()=="jixi" then
		addTurnData(name,1)
		if getTurnData(name)==4 then
			addZhanGong(room,name)
		end
	end
end


-- cjww :: 才兼文武 :: 使用姜维在一局游戏中发动挑衅弃掉牌至少4张并发动观星至少2次 
--
zgfunc[sgs.ChoiceMade].cjww=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='jiangwei' then return false end
	if not isowner then return false end
	local choices= data:toString():split(":")
	if choices[1]=="cardChosen"  and  choices[2]=="tiaoxin" then
		setGameData(name..'tiaoxin',math.min(4,getGameData(name..'tiaoxin')+1))
		if getGameData(name..'tiaoxin')==4 and getGameData(name..'guanxing')==2 then
			addZhanGong(room,name)
			setGameData(name..'tiaoxin',-100)
		end
	end
end


zgfunc[sgs.ChoiceMade].cjww=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='jiangwei' then return false end
	if not isowner then return false end
	local choices= data:toString():split(":")
	if choices[1]=="skillInvoke"  and  choices[2]=="guanxing" and choices[3]=="yes" then
		setGameData(name..'guanxing',math.min(2,getGameData(name..'guanxing')+1))
		if getGameData(name..'tiaoxin')==4 and getGameData(name..'guanxing')==2 then
			addZhanGong(room,name)
			setGameData(name..'tiaoxin',-100)
		end
	end
end


-- dhhs :: 大幻化师 :: 使用左慈在一局游戏中获得化身牌至少10张 
--
zgfunc[sgs.Damaged].dhhs=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	if  room:getOwner():getGeneralName()~='zuoci' then return false end
	local damage = data:toDamage()	
	addGameData(name,damage.damage)
	if getGameData(name)>=10 then
		addZhanGong(room,name)
		setGameData(name,-100)
	end

end



-- lyws :: 炼狱武神 :: 使用神关羽在一局游戏中使用红桃花色的杀杀死至少3名角色 
--
zgfunc[sgs.Death].lyws=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="shenguanyu" then return false end
	local damage=data:toDeath().damage
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() 
		and damage.card and damage.card:isKindOf("Slash") and damage.card:getSuit()==sgs.Card_Heart then
		addGameData(name,1)	
		if getGameData(name)==3 then
			addZhanGong(room,name)
		end
	end	
end

zgfunc[sgs.GameOverJudge].callback.lyws=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~="shenguanyu" then return false end
	local damage=data:toDeath().damage
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() 
		and damage.card and damage.card:isKindOf("Slash") and damage.card:getSuit()==sgs.Card_Heart then
		addGameData(name,1)	
		if getGameData(name)==3 then
			addZhanGong(room,name)
		end
	end	
end


-- dcyq :: 洞察一切 :: 使用神吕蒙在一局游戏中发动攻心将至少5张无中生有或桃置于牌堆顶 
--
zgfunc[sgs.CardsMoveOneTime].dcyq=function(self, room, event, player, data,isowner,name)
	if room:getOwner():getGeneralName()~="shenlvmeng" then return false end
	local move=data:toMoveOneTime()
	local reason=move.reason
	if room:getCurrent():objectName()~=room:getOwner():objectName() then return end
	if reason.m_skillName == "gongxin" and move.to_place == sgs.Player_DrawPile then
		local ids=sgs.QList2Table(move.card_ids)
		for _,cid in ipairs(ids) do
			local card=sgs.Sanguosha:getCard(cid)
			if card:isKindOf("Peach") or card:isKindOf("ExNihilo") then
				addGameData(name,1)
				if getGameData(name)==5 then
					addZhanGong(room,name)
				end
			end
		end
	end
end

-- hlyh :: 红莲业火 :: 使用神周瑜在一回合发动业炎造成至少5点伤害 
--
zgfunc[sgs.Damage].hlyh=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="shenzhouyu" then return false end
	if not isowner then return false end
	if room:getCurrent():objectName()~=room:getOwner():objectName() then return end
	local damage = data:toDamage()
	if damage and damage.reason == "yeyan" and damage.nature == sgs.DamageStruct_Fire then
		addTurnData(name,damage.damage)
		if getTurnData(name)>=5 then 			 
			addZhanGong(room,name)
			setTurnData(name,-100)
		end
	end
end


-- hdyx :: 换斗移星 :: 使用神诸葛在一局游戏中让至少一名狂风状态的角色被火攻杀死 
--
zgfunc[sgs.Death].hdyx=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="shenzhugeliang" then return false end
	local damage=data:toDeath().damage
	if damage and damage.card and damage.card:isKindOf("FireAttack") and player:getMark("@gale") > 0 then
		addGameData(name,1)	
		if getGameData(name)==1 then
			addZhanGong(room,name)
		end
	end	
end

zgfunc[sgs.GameOverJudge].callback.hdyx=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~="shenzhugeliang" then return false end
	local damage=data:toDeath().damage
	if damage and damage.card and damage.card:isKindOf("FireAttack") and player:getMark("@gale") > 0 then
		addGameData(name,1)	
		if getGameData(name)==1 then
			addZhanGong(room,name)
		end
	end	
end



-- txgx :: 天下归心 :: 使用神曹操在一局游戏中发动归心获得至少10张牌 
--
zgfunc[sgs.ChoiceMade].txgx=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='shencaocao' then return false end
	if not isowner then return false end
	local choices= data:toString():split(":")
	if choices[1]=="cardChosen"  and  choices[2]=="guixin"  then
		addGameData(name,1)
		if getGameData(name)==10 then
			addZhanGong(room,name)
		end
	end
end


-- sgws :: 神鬼无双 :: 使用神吕布在一局游戏中发动神愤至少2次 
--
zgfunc[sgs.CardFinished].sgws=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='shenlvbu' then return false end
	if not isowner then return false end
	local use=data:toCardUse()
	local card=use.card
	if card:isKindOf('ShenfenCard') then
		addGameData(name,1)
		if getGameData(name)==2 then
			addZhanGong(room,name)
		end
	end
end


-- xltj :: 西凉铁骑 :: 使用SP马超在一局游戏中至少发动5次铁骑并判定为红色 
--
zgfunc[sgs.FinishRetrial].xltj=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="sp_machao" then return false end
	local judge=data:toJudge()
	if judge.reason=="tieji" and judge.who:objectName()==room:getOwner():objectName() then
		if not judge:isBad() then			
			addGameData(name,1)
		end
		if getGameData(name)==5 then 			 
			addZhanGong(room,name)
		end
	end
end


-- njnt :: 能进能退 :: 使用☆SP赵云在一局游戏中至少发动冲阵获得6张牌并获胜 
--
zgfunc[sgs.ChoiceMade].njnt=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='bgm_zhaoyun' then return false end
	if not isowner then return false end
	local choices= data:toString():split(":")
	if choices[1]=="skillInvoke"  and  choices[2]=="chongzhen" and choices[3]=="yes" then
		addGameData(name,1)
	end
end


zgfunc[sgs.GameOverJudge].callback.njnt=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~='bgm_zhaoyun' then return false end
	if result=='win' and getGameData(name,0)>=6 then			 
		addZhanGong(room,name)
	end		
end


-- sll :: 失礼了 :: 使用☆SP貂蝉在一局游戏中至少发动3次离魂并获胜 
--
zgfunc[sgs.CardFinished].sll=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='bgm_diaochan' then return false end
	if not isowner then return false end
	local use=data:toCardUse()
	local card=use.card
	if card:isKindOf('LihunCard') then
		addGameData(name,1)
	end
end

zgfunc[sgs.GameOverJudge].callback.sll=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~='bgm_diaochan' then return false end
	if result=='win' and getGameData(name,0)>=3 then			 
		addZhanGong(room,name)
	end		
end


-- pzzj :: 破阵斩将 :: 使用高顺在一局游戏中发动陷阵拼点赢的情况下杀死至少两名角色并获胜 
--
zgfunc[sgs.Death].pzzj=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="gaoshun" then return false end
	local damage=data:toDeath().damage
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() 
			and damage.from:hasFlag("XianzhenSuccess") then
		addGameData(name,1)	
	end	
end

zgfunc[sgs.GameOverJudge].callback.pzzj=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~="gaoshun" then return false end
	local damage=data:toDeath().damage
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() 
			and damage.from:hasFlag("XianzhenSuccess") then
		addGameData(name,1)	
	end
	if result=='win' and getGameData(name)>=2 then
		addZhanGong(room,name)
	end
end

-- bykt :: 霸业可图 :: 使用陈宫在一局游戏中对吕布发动明策至少2次 
--
zgfunc[sgs.CardEffect].bykt=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='chengong' then return false end
	if not isowner then return false end
	local effect=data:toCardEffect()
	if effect.card:isKindOf("MingceCard") and effect.to:getGeneralName()=="lvbu" then
		addGameData(name,1)
		if getGameData(name)==2 then 			 
			addZhanGong(room,name)
		end
	end
end

-- djzc :: 大军在此 :: 使用徐盛在一局游戏中发动破军至少3次并获胜 
--
zgfunc[sgs.ChoiceMade].djzc=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='xusheng' then return false end
	if not isowner then return false end
	local choices= data:toString():split(":")
	if choices[1]=="skillInvoke"  and  choices[2]=="pojun" and choices[3]=="yes" then
		addGameData(name,1)
	end
end

zgfunc[sgs.GameOverJudge].callback.djzc=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~="xusheng" then return false end
	if result=='win' and getGameData(name)>=3 then
		addZhanGong(room,name)
	end
end


-- wgzm :: 吴国之母 :: 使用吴国太在一局游戏中发动补益使至少3名不同的吴国武将脱离频死状态 
--
zgfunc[sgs.ChoiceMade].wgzm=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='wuguotai' then return false end
	if not isowner then return false end
	local choices= data:toString():split(":")
	if choices[1]=="skillInvoke"  and  choices[2]=="buyi" and choices[3]=="yes" then
		setTurnData(name,1)
	end
end

zgfunc[sgs.HpRecover].wgzm=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='wuguotai' then return false end	
	if getTurnData(name,0)==0 then return false end
	local recov = data:toRecover()
	if not recov.card and player:getHp()==0 and recov.who:objectName()==room:getOwner():objectName() and player:getKingdom()=='wu' then
		if getGameData(name,0)==0 then setGameData(name,"") end
		local to=player:objectName()
		local val=getGameData(name)
		if not string.find(val,to..",") then 
			setGameData(name,val..to..",")
			if string.match(getGameData(name),"^%w+,%w+,%w+,$") then
				addZhanGong(room,name)
			end
		end	
	end
end

-- xyzj :: 须臾之间 :: 使用凌统在一局游戏中发动旋风至少弃置敌方角色装备区的牌至少8张 
--
zgfunc[sgs.ChoiceMade].xyzj=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="lingtong" then return false end
	if not isowner then return false end
	local choices= data:toString():split(":")
	local role1=player:getRole()
	if role1=='lord' then role1='loyalist' end
	if choices[1]=="cardChosen" and choices[2]=="xuanfeng" and room:getCardPlace(tonumber(choices[3]))==sgs.Player_PlaceEquip then
		local role2=room:getCardOwner(tonumber(choices[3])):getRole()
		if role2=='lord' then role2='loyalist' end
		if role1~=role2 or role1=='renegade' or role2=='renegade' then
			addGameData(name,1)
		end
		if getGameData(name)==8 then
			addZhanGong(room,name)
		end
	end	
end



-- wkhn :: 我看好你 :: 使用徐庶在一局游戏中发动举荐至少6次 
--
zgfunc[sgs.CardFinished].wkhn=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='xushu' then return false end
	if not isowner then return false end
	local use=data:toCardUse()
	local card=use.card
	if card:isKindOf('JujianCard') then
		addGameData(name,1)
		if getGameData(name)==6 then
			addZhanGong(room,name)
		end
	end
end


-- txbf :: 通晓兵法 :: 使用马谡在一局游戏中发动心战获得桃和无中生有至少各2张 
--
zgfunc[sgs.ChoiceMade].txbf=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='masu' then return false end
	if not isowner then return false end
	local choices= data:toString():split(":")
	if choices[1]=="AGChosen"  and  choices[2]=="xinzhan" then
		local card=sgs.Sanguosha:getCard(tonumber(choices[3]))
		if card:isKindOf("Peach") then
			setGameData(name..'Peach',math.min(2,getGameData(name..'Peach')+1))
			if getGameData(name..'Peach')==2 and getGameData(name..'ExNihilo')==2 then
				addZhanGong(room,name)
				setGameData(name..'Peach',-100)
			end
		end
		if card:isKindOf("ExNihilo") then
			setGameData(name..'ExNihilo',math.min(2,getGameData(name..'ExNihilo')+1))
			if getGameData(name..'Peach')==2 and getGameData(name..'ExNihilo')==2 then
				addZhanGong(room,name)
				setGameData(name..'Peach',-100)
			end
		end
	end
end



-- sbfh :: 十倍奉还 :: 使用法正在一局游戏中发动眩惑获得其他角色至少3张桃 
--
zgfunc[sgs.ChoiceMade].sbfh=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="fazheng" then return false end
	if not isowner then return false end
	local choices= data:toString():split(":")
	if choices[1]=="cardChosen" and choices[2]=="xuanhuo" and sgs.Sanguosha:getCard(choices[3]):isKindOf("Peach") then
		addGameData(name,1)
		if getGameData(name)==3 then
			addZhanGong(room,name)
		end
	end	
end


-- styj :: 身体要紧 :: 在主公是刘备的情况下，使用SP孙尚香做内奸取得胜利 
--
zgfunc[sgs.GameOverJudge].callback.styj=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~="sp_sunshangxiang" then return false end
	if result=='win' and room:getLord():getGeneralName()=='liubei' and room:getOwner():getRole()=='renegade' then
		addZhanGong(room,name)
	end
end


-- wjjh :: 文姬归汉 :: 在主公是曹操的情况下，使用SP蔡文姬做内奸取得胜利 
--
zgfunc[sgs.GameOverJudge].callback.wjjh=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~="sp_caiwenji" then return false end
	if result=='win' and room:getLord():isCaoCao() and room:getOwner():getRole()=='renegade' then
		addZhanGong(room,name)
	end
end


-- yzkw :: 严整溃围 :: 使用☆SP曹仁在一局游戏中发动溃围摸牌至少11张并发动严整至少4次 
--
zgfunc[sgs.ChoiceMade].yzkw=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='bgm_caoren' then return false end
	if not isowner then return false end
	local choices= data:toString():split(":")
	if choices[1]=="skillInvoke"  and  choices[2]=="kuiwei" and choices[3]=="yes" then
		local n=2
		for _,p in sgs.qlist(room:getAlivePlayers()) do
			if p:getWeapon() then n=n+1 end
		end
		setGameData(name..'kuiwei',math.min(11,getGameData(name..'kuiwei')+n))
		if getGameData(name..'kuiwei')==11 and getGameData(name..'yanzheng')==4 then
			addZhanGong(room,name)
			setGameData(name..'yanzheng',-100)
		end
	end
end


zgfunc[sgs.CardFinished].yzkw=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='bgm_caoren' then return false end
	if not isowner then return false end
	local use=data:toCardUse()
	local card=use.card
	if card:isKindOf('Nullification') and card:getSkillName()=='yanzheng' then
		setGameData(name..'yanzheng',math.min(4,getGameData(name..'yanzheng')+1))
		if getGameData(name..'kuiwei')==11 and getGameData(name..'yanzheng')==4 then
			addZhanGong(room,name)
			setGameData(name..'yanzheng',-100)
		end
	end
end


-- gsy :: 狗屎运 :: 当你的开局4牌的颜色全为黑色时,清除你的N盘逃跑记录(N为5-10的随机数)
--
zgfunc[sgs.AfterDrawInitialCards].gsy=function(self, room, event, player, data,isowner,name)
	if not isowner or getGameData("turncount",0)>0 or player:isKongcheng() then return false end
	if getGameData(name,0)==1 then return false end
	local cards=sgs.QList2Table(player:getHandcards())
	local num= 5 + (os.time() % 6)
	for i=1,#cards,1 do
		if cards[i]:isRed() then return false end
	end
	local sql=string.format("select id from results where result='-' and id<>%d order by id asc limit %d",getGameData("roomid"),num)
	local count=0
	for row in db:rows(sql) do
		sqlexec("delete from results where id=%d",row.id)
		count = count +1
	end
	local desc="当你的开局4牌的颜色全为黑色时,清除你的N盘逃跑记录(N为5-10的随机数)"
	sqlexec("update zhangong set description='%s' where id='%s'",desc,name)
	addZhanGong(room,name)
	setGameData(name,1)
	broadcastMsg(room,"#gsyNum",count)
end

--('fbrq', '法不容情', 10, '使用满宠在一局游戏中对魏势力角色发动至少4次峻刑', 0, 'wei',  'manchong', 0, 0);

zgfunc[sgs.CardFinished].fbrq = function(self, room, event, player, data, isowner, name)
	if room:getOwner():getGeneralName() ~= "manchong" then return false end
	if not isowner then return false end
	
	local use = data:toCardUse()
	if use.card:isKindOf("JunxingCard") and use.from:objectName() == room:getOwner():objectName() then
		for _, p in sgs.qlist(use.to) do
			if p:getKingdom() == "wei" then
				addGameData(name .. "junxing", 1)
				if getGameData(name .. "junxing", 0) >= 4 then
					addZhanGong(room, name)
					setGameData(name .. "junxing", -10000)
				end
			end
		end
	end
end

-- ('mfrx', '妙法仁心', 10, '使用曹冲在一局游戏中对魏势力角色发动仁心至少3次', 0, 'wei',  'caochong', 0, 0);
zgfunc[sgs.CardFinished].mfrx = function(self, room, event, player, data, isowner, name)
	if room:getOwner():getGeneralName() ~= "caochong" then return false end
	if not isowner then return false end
	local use = data:toCardUse()
	if use.from:objectName() == room:getOwner():objectName() and use.card:isKindOf("RenxinCard") then
		for _, to in sgs.qlist(use.to) do
			if to:getKingdom() == "wei" then
				addGameData(name, 1)
				if getGameData(name) == 3 then
					addZhanGong(room, name)
				end
				break
			end
		end
	end
end


-- ('fdw', '封悼王', 10, '使用sp曹昂在一局游戏中发动慷忾摸到装备牌至少3张', 0, 'wei',  'caoang', 0, 0);
zgfunc[sgs.ChoiceMade].fdw = function(self, room, event, player, data, isowner, name)
	if room:getOwner():getGeneralName() ~= "caoang" then return false end
	if not isowner then return false end
	local choices = data:toString():split(":")
	if choices[1] == "skillInvoke" and choices[2] == "kangkai" and choices[3] == "yes" then
		local pile = room:getDrawPile()
		if not pile:isEmpty() then
			local id = pile:first()
			if sgs.Sanguosha:getCard(id):getTypeId() == sgs.Card_TypeEquip then
				addGameData(name, 1)
				if getGameData(name) == 3 then
					addZhanGong(room, name)
				end
			end
		end
	end
end


-- ('yjdx', '一骑当先', 10, '使用乐进在一局游戏中发动骁果杀死至少2名角色并获胜', 0, 'wei',  'yuejin', 0, 0);
zgfunc[sgs.Death].yjdx = function(self, room, event, player, data, isowner, name)
	if not string.find(room:getOwner():getGeneralName(), "yuejin") then return false end
	local damage = data:toDeath().damage
	if damage and damage.from and damage.from:objectName() == room:getOwner():objectName() and damage.reason == "xiaoguo" then
		addGameData(name, 1)
		if getGameData(name) == 2 then
			addZhanGong(room, name)
		end
	end
end

-- ('yjdx', '一骑当先', 10, '使用乐进在一局游戏中发动骁果杀死至少2名角色并获胜', 0, 'wei',  'yuejin', 0, 0);
--
zgfunc[sgs.GameOverJudge].callback.yjdx = function(room, player, data, name, result)
	if not string.find(room:getOwner():getGeneralName(), 'yuejin') then return false end
	if result ~= 'win' then return false end
	local damage = data:toDeath().damage
	if damage and damage.from and damage.from:objectName() == room:getOwner():objectName() and damage.reason == "xiaoguo" then
		addGameData(name, 1)
		if getGameData(name) == 2 then
			addZhanGong(room, name)
		end
	end
end


-- ('fujiang', '福将', 10, '使用曹洪在一局游戏中发动援护总计回复两点体力', 0, 'wei',  'caohong', 0, 0);
zgfunc[sgs.CardFinished].fujiang = function(self, room, event, player, data, isowner, name)
	if string.find(room:getOwner():getGeneralName(), "caohong") then return false end
	if not isowner then return false end
	local use = data:toCardUse()
	if use.from:objectName() == room:getOwner():objectName() and use.card:isKindOf("YuanhuCard") then
		local card = sgs.Sanguosha:getCard(use.card:getSubcards():first())
		if card:isKindOf("Horse") then
			addGameData(name, 1)
			if getGameData(name) == 3 then
				addZhanGong(room, name)
			end
		end
	end
end

-- ('pzzz', '破竹之咒', 10, '使用陈琳在一局游戏中对曹操使用笔伐，并使用颂词使其摸两张牌', 0, 'wei',  'chenlin', 0, 0);
zgfunc[sgs.CardUsed].pzzz = function(self, room, event, player, data, isowner, name)
	if room:getOwner():getGeneralName() ~= "chenlin" then return false end
	if not isowner then return false end
	local use = data:toCardUse()
	if use.from:objectName() == room:getOwner():objectName() then
		if use.card:isKindOf("SongciCard") then
			for _, to in sgs.qlist(use.to) do
				if string.find(to:getGeneralName() ,"caocao") and to:getHandcardNum() < to:getHp() then
					addGameData(name .. "songci", 1)
					break
				end
			end
		elseif use.card:isKindOf("BifaCard") then
			for _, to in sgs.qlist(use.to) do
				if string.find(to:getGeneralName() ,"caocao") then
					addGameData(name .. "bifa", 1)
					break
				end
			end
		end
		if getGameData(name .. "songci") >= 1 and getGameData(name .. "bifa") >= 1 then
			setGameData(name .. "bifa", -1000)
			setGameData(name .. "songci", -1000)
			addZhanGong(room, name)
		end
	end
end


-- ('xzqs', '险中求胜', 10, '使用夏侯霸在自己只剩下1体力的情况下获得游戏胜利', 0, 'shu',  'xiahouba', 0, 0);
zgfunc[sgs.GameOverJudge].callback.xzqs = function(room, player, data, name, result)
	if room:getOwner():getGeneralName() ~= "xiahouba" then return false end
	if result ~= 'win' then return false end
	if room:getOwner():getHp() == 1 then
		addZhanGong(room, name)
	end
end

-- ('wj', '武姬', 10, '使用关银屏在一局游戏中发动技能虎啸3次，血祭1次', 0, 'shu',  'guanyinping', 0, 0);
zgfunc[sgs.CardUsed].wj = function(self, room, event, player, data, isowner, name)
	if room:getOwner():getGeneralName() ~= "guanyinping" then return false end
	if not isowner then return false end
	local use = data:toCardUse()
	if use.from:objectName() == room:getOwner():objectName() then
		if use.card:isKindOf("XuejiCard") then
			addGameData(name .. "xueji", 1)
			if getGameData(name .. "huxiao") >= 3 and getGameData(name .. "xueji") >= 1 then
				setGameData(name .. "huxiao", -1000)
				setGameData(name .. "xueji", -1000)
				addZhanGong(room, name)
			end
		elseif use.card:isKindOf("Slash") and player:getMark("huxiao") > 0 then
			addGameData(name .. "huxiao", 1)
			if getGameData(name .. "huxiao") >= 3 and getGameData(name .. "xueji") >= 1 then
				setGameData(name .. "huxiao", -1000)
				setGameData(name .. "xueji", -1000)
				addZhanGong(room, name)
			end
		end
	end
end

-- ('scxh', '身曹心汉', 10, '使用新徐庶在一局游戏中对蜀势力角色发动举荐至少3次', 0, 'shu',  'xushu', 0, 0);
zgfunc[sgs.CardFinished].scxh = function(self, room, event, player, data, isowner, name)
	if room:getOwner():getGeneralName() ~= "xushu" then return false end
	if not isowner then return false end
	local use = data:toCardUse()
	if use.from:objectName() == room:getOwner():objectName() and use.card:isKindOf("JujianCard") then
		for _, to in sgs.qlist(use.to) do
			if to:getKingdom() == "shu" then
				addGameData(name, 1)
				if getGameData(name) == 3 then
					addZhanGong(room, name)
				end
				break
			end
		end
	end
end

-- ('eyfm', '恩怨分明', 10, '使用新法正在一局游戏中分别获得卡牌和受到伤害时发动技能恩怨各2次', 0, 'shu',  'fazheng', 0, 0);
zgfunc[sgs.ChoiceMade].eyfm = function(self, room, event, player, data, isowner, name)
	if room:getOwner():getGeneralName() ~= "fazheng" then return false end
	if not isowner then return false end
	local choices = data:toString():split(":")
	if choices[1] == "skillInvoke" and choices[2] == "enyuan" and choices[3] == "yes" then
		local enyuan_type = "damage"
		for _, p in sgs.qlist(room:getOtherPlayers(player)) do
			if p:hasFlag("EnyuanDrawTarget") then
				enyuan_type = "draw"
				break
			end
		end
		addGameData(name .. enyuan_type, 1)
		if getGameData(name .. "damage") >= 2 and getGameData(name .. "draw") >= 2 then
			setGameData(name .. "damage", -1000)
			setGameData(name .. "draw", -1000)
			addZhanGong(room, name)
		end
	end
end

-- ('sclh', '舌灿莲花', 10, '使用简雍在一局游戏中，发动巧说拼点赢后，为桃、顺手牵羊和决斗各额外选择一名目标', 0, 'shu',  'jianyong', 0, 0);
zgfunc[sgs.ChoiceMade].sclh = function(self, room, event, player, data, isowner, name)
	if room:getOwner():getGeneralName() ~= "jianyong" then return false end
	if not isowner then return false end
	local choices = data:toString():split(":")
	if choices[1] == "skillChoice" and choices[2] == "qiaoshui" then
		if choices[3] == "add" then
			setGameData(name .. "add", 1)
		else
			setGameData(name .. "add", 0)
		end
	end
end

-- ('sclh', '舌灿莲花', 10, '使用简雍在一局游戏中，发动巧说拼点赢后，为桃、顺手牵羊和决斗各额外选择一名目标', 0, 'shu',  'jianyong', 0, 0);
zgfunc[sgs.CardFinished].sclh = function(self, room, event, player, data, isowner, name)
	if room:getOwner():getGeneralName() ~= "jianyong" then return false end
	if not isowner then return false end
	local use = data:toCardUse()
	if use.from:objectName() == room:getOwner():objectName() and getGameData(name .. "add") >= 1 then
		setGameData(name .. "add", 0)
		if use.to:length() > 1 and (use.card:isKindOf("Peach") or use.card:isKindOf("Duel") or use.card:isKindOf("Snatch")) then
			addGameData(name .. use.card:getClassName(), 1)
			if getGameData(name .. "Peach") >= 1 and getGameData(name .. "Duel") >= 1 and getGameData(name .. "Snatch") >= 1 then
				setGameData(name .. "Peach", -1000)
				setGameData(name .. "Duel", -1000)
				setGameData(name .. "Snatch", -1000)
				addZhanGong(room, name)
			end
		end
	end
end

-- ('xzjz', '先主假子', 10, '使用刘封在一局游戏中发动陷嗣使得“逆”的数量达到8张并获得胜利', 0, 'shu',  'liufeng', 0, 0);
zgfunc[sgs.CardFinished].xzjz = function(self, room, event, player, data, isowner, name)
	if room:getOwner():getGeneralName() ~= "liufeng" then return false end
	if not isowner then return false end
	local use = data:toCardUse()
	if use.from:objectName() == room:getOwner():objectName() and use.card:isKindOf("XiansiCard") then
		if player:getPile("counter"):length() >= 8 then
			addGameDate(name, 1)
		end
	end
end

-- ('xzjz', '先主假子', 10, '使用刘封在一局游戏中发动陷嗣使得“逆”的数量达到8张并获得胜利', 0, 'shu',  'liufeng', 0, 0);
zgfunc[sgs.GameOverJudge].callback.xzjz = function(room, player, data, name, result)
	if  room:getOwner():getGeneralName() ~= "liufeng" then return false end
	if result ~= 'win' then return false end
	if getGameData(name) >= 1 then
		addZhanGong(room, name)
	end
end


-- ('lyjx', '龙吟九霄', 10, '使用关平在一局游戏中发动龙吟至少4次，并在本局游戏中杀死至少3名角色', 0, 'shu',  'guanping', 0, 0);
zgfunc[sgs.ChoiceMade].lyjx = function(self, room, event, player, data, isowner, name)
	if room:getOwner():getGeneralName() ~= "guanping" then return false end
	if not isowner then return false end
	local choices = data:toString():split(":")
	if choices[1] == "cardResponded" and choices[2] == "@longyin" and choice[#choice] ~= "_nil_" then
		addGameData(name .. "longyin", 1)
		if getGameData(name .. "longyin") >= 4 and getGameData(name .. "kill") >= 3 then
			setGameData(name .. "longyin", -1000)
			setGameData(name .. "kill", -1000)
			addZhanGong(room, name)
		end
	end
end

-- ('lyjx', '龙吟九霄', 10, '使用关平在一局游戏中发动龙吟至少4次，并在本局游戏中杀死至少3名角色', 0, 'shu',  'guanping', 0, 0);
zgfunc[sgs.Death].lyjx = function(self, room, event, player, data, isowner, name)
	if room:getOwner():getGeneralName() ~= 'guanping' then return false end
	local death = data:toDeath()
	local damage = death.damage
	if damage and damage.from and damage.from:objectName() == room:getOwner():objectName() then
		addGameData(name .. "kill", 1)
		if getGameData(name .. "longyin") >= 4 and getGameData(name .. "kill") >= 3 then
			setGameData(name .. "longyin", -1000)
			setGameData(name .. "kill", -1000)
			addZhanGong(room, name)
		end
	end
end

-- ('lyjx', '龙吟九霄', 10, '使用关平在一局游戏中发动龙吟至少4次，并在本局游戏中杀死至少3名角色', 0, 'shu',  'guanping', 0, 0);
zgfunc[sgs.GameOverJudge].callback.lyjx = function(room, player, data, name, result)
	if  room:getOwner():getGeneralName() ~= "guanping" then return false end
	if result ~= 'win' then return false end
	local death = data:toDeath()
	local damage = death.damage
	if damage and damage.from and damage.from:objectName() == room:getOwner():objectName() then
		addGameData(name .. "kill", 1)
		if getGameData(name .. "longyin") >= 4 and getGameData(name .. "kill") >= 3 then
			addZhanGong(room, name)
		end
	end
end


-- ('xjcz', '兴家赤族', 10, '使用诸葛恪在一局游戏中发动技能黩武令两名角色进入濒死状态', 0, 'wu',  'zhugeke', 0, 0);
zgfunc[sgs.Dying].xjcz = function(self, room, event, player, data, isowner, name)
	if not isowner then return false end
	if player:getGeneralName() ~= "zhugeke" then return false end
	local dying = data:toDying()
	if dying.who:objectName() ~= player:objectName() and dying.damage and dying.damage:getReason() == "duwu" then
		addGameData(name, 1)
		if getGameData(name) == 2 then
			addZhanGong(room, name)
		end
	end
end

-- ('jiangdongzhihua', '江东之花', 10, '使用大乔小乔在一局游戏中发动技能星舞造成4点伤害', 0, 'wu',  'erqiao', 0, 0);
zgfunc[sgs.Damage].jiangdongzhihua = function(self, room, event, player, data, isowner, name)
	if not isowner then return false end
	local damage = data:toDamage()
	if not damage.from or damage.from:objectName() ~= player:objectName() or damage.from:getGeneralName() ~= "erqiao" then return end
	if damage.reason == "xingwu" then
		addZhanGong(room, name)
	end
end

-- ('wmxt', '微妙玄通', 10, '使用虞翻在一局游戏中发动直言令其他角色摸到装备牌至少3张', 0, 'wu',  'yufan', 0, 0);
zgfunc[sgs.ChoiceMade].wmxt=function(self, room, event, player, data, isowner, name)
	if room:getOwner():getGeneralName() ~= "yufan" then return false end
	if not isowner then return false end
	local choices = data:toString():split(":")
	if choices[1] == "playerChosen" and choices[2] == "zhiyan" then
		local pile = room:getDrawPile()
		if not pile:isEmpty() then
			local id = pile:first()
			if sgs.Sanguosha:getCard(id):getTypeId() == sgs.Card_TypeEquip then
				addGameData(name, 1)
				if getGameData(name) == 3 then
					addZhanGong(room, name)
				end
			end
		end
	end
end


-- ('sjss', '上将杀手', 10, '使用潘璋＆马忠在一局游戏中杀死关羽和黄忠并获胜', 0, 'wu',  'panzhangmazhong', 0, 0);
--
zgfunc[sgs.Death].sjss=function(self, room, event, player, data, isowner, name)
	if room:getOwner():getGeneralName() ~= 'panzhangmazhong' then return false end
	local death = data:toDeath()
	local damage = death.damage
	if damage and damage.from and damage.from:objectName() == room:getOwner():objectName() then
		if string.find(death.who:getGeneralName(), "guangyu") then
			addGameData(name .. "guangyu", 1)
		elseif string.find(death.who:getGeneralName(), "huangzhong") then
			addGameData(name .. "huangzhong", 1)
		end
		if getGameData(name .. "huangzhong") > 0 and getGameData(name .. "guangyu") > 0 then
			addZhanGong(room, name)
		end
	end
end


-- ('sjss', '上将杀手', 10, '使用潘璋＆马忠在一局游戏中杀死关羽和黄忠并获胜', 0, 'wu',  'panzhangmazhong', 0, 0);
--
zgfunc[sgs.GameOverJudge].callback.sjss=function(room, player, data, name, result)
	if  room:getOwner():getGeneralName() ~= "panzhangmazhong" then return false end
	if result ~= 'win' then return false end
	local death = data:toDeath()
	local damage = death.damage
	if damage and damage.from and damage.from:objectName() == room:getOwner():objectName() then
		if string.find(death.who:getGeneralName(), "guangyu") then
			addGameData(name .. "guangyu", 1)
		elseif string.find(death.who:getGeneralName(), "huangzhong") then
			addGameData(name .. "huangzhong", 1)
		end
		if getGameData(name .. "huangzhong") > 0 and getGameData(name .. "guangyu") > 0 then
			addZhanGong(room, name)
		end
	end
end


-- ('schs', '石城侯使', 10, '用韩当在一局游戏中发动技能弓骑弃置他人共计3张牌', 0, 'wu',  'handang', 0, 0);
zgfunc[sgs.ChoiceMade].schs=function(self, room, event, player, data, isowner, name)
	if room:getOwner():getGeneralName() ~= "handang" then return false end
	if not isowner then return false end
	local choices = data:toString():split(":")
	if choices[1] == "playerChosen" and choices[2] == "gongqi" then
		addGameData(name, 1)
		if getGameData(name) == 3 then
			addZhanGong(room, name)
		end
	end
end


-- dxrs :: 胆小如鼠 ：： 一局游戏内连续发动胆守至少7次
--
zgfunc[sgs.ChoiceMade].dxrs=function(self, room, event, player, data, isowner, name)
	if room:getOwner():getGeneralName() ~= "zhuran" then return false end
	if not isowner then return false end
	local choices = data:toString():split(":")
	if choices[1] == "skillInvoke" and choices[2] == "danshou" then
		if choices[3] == "yes" then
			addGameData(name, 1)
			if getGameData(name) == 7 then
				addZhanGong(room, name)
			end
		else
			setGameData(name, 0)
		end
	end
end

-- ('dcs', '毒策士', 10, '使用李儒在一局游戏中，发动绝策杀死至少2名角色并发动焚城杀死至少2名角色', 0, 'qun',  'liru', 0, 0);
zgfunc[sgs.Death].dcs = function(self, room, event, player, data, isowner, name)
	if room:getOwner():getGeneralName() ~= 'liru' then return false end
	local damage = data:toDeath().damage
	if damage and damage.from and damage.from:objectName() == room:getOwner():objectName() then
		if damage.reason == "fencheng" then
			addGameData(name .. "fencheng", 1)
		elseif damage.reason == "juece" then
			addGameData(name .. "juece", 1)
		end
		if getGameData(name .. "fencheng") >= 2 and getGameData(name .. "juece") >= 2 then
			setGameData(name .. "fencheng", -1000)
			setGameData(name .. "juece", -1000)
			addZhanGong(room, name)
		end
	end
end

-- ('dcs', '毒策士', 10, '使用李儒在一局游戏中，发动绝策杀死至少2名角色并发动焚城杀死至少2名角色', 0, 'qun',  'liru', 0, 0);
zgfunc[sgs.GameOverJudge].callback.dcs = function(room, player, data, name, result)
	if  room:getOwner():getGeneralName() ~= "liru" then return false end
	if result ~= 'win' then return false end
	local damage = data:toDeath().damage
	if damage and damage.from and damage.from:objectName() == room:getOwner():objectName() then
		if damage.reason == "fencheng" then
			addGameData(name .. "fencheng", 1)
		elseif damage.reason == "juece" then
			addGameData(name .. "juece", 1)
		end
		if getGameData(name .. "fencheng") >= 2 and getGameData(name .. "juece") >= 2 then
			addZhanGong(room, name)
		end
	end
end

-- ('ysbq', '与世不侵', 10, '使用伏皇后在一局游戏中发动惴恐拼点赢至少4次', 0, 'qun',  'fuhuanghou', 0, 0);
zgfunc[sgs.ChoiceMade].ysbq = function(self, room, event, player, data, isowner, name)
	if not isowner then return false end
	if room:getOwner():getGeneralName() ~= 'fuhuanghou' then return false end
	local choices = data:toString():split(":")
	if choices[1] == "pindian" and choices[2] == "zhuikong" and choices[3] == player:objectName() then
		local num_from = sgs.Sanguosha:getCard(choices[4]):getNumber()
		local num_to = sgs.Sanguosha:getCard(choices[6]):getNumber()
		if num_from > num_to then
			addGameData(name, 1)
			if getGameData(name) == 4 then
				addZhanGong(room, name)
			end
		end
	end
end

-- ('ntgm', '逆天改命', 10, '使用张宝在一局游戏中发动咒缚4次，影兵2次', 0, 'qun',  'zhangbao', 0, 0);
zgfunc[sgs.ChoiceMade].ntgm = function(self, room, event, player, data, isowner, name)
	if room:getOwner():getGeneralName() ~= "zhuran" then return false end
	if not isowner then return false end
	local choices = data:toString():split(":")
	if choices[1] == "skillInvoke" and choices[2] == "yingbing" then
		if choices[3] == "yes" then
			addGameData(name .. "yingbing", 1)
			if getGameData(name .. "yingbing") >= 2 and getGameData(name .. "zhoufu") >= 2 then
				setGameData(name .. "yingbing", -1000)
				setGameData(name .. "zhoufu", -1000)
				addZhanGong(room, name)
			end
		end
	end
end

-- ('ntgm', '逆天改命', 10, '使用张宝在一局游戏中发动咒缚4次，影兵2次', 0, 'qun',  'zhangbao', 0, 0);
zgfunc[sgs.CardFinished].ntgm = function(self, room, event, player, data, isowner, name)
	if room:getOwner():getGeneralName() ~= "manchong" then return false end
	if not isowner then return false end
	local use = data:toCardUse()
	if use.card:isKindOf("ZhoufuCard") and use.from:objectName() == room:getOwner():objectName() then
		addGameData(name .. "zhoufu", 1)
		if getGameData(name .. "yingbing") >= 2 and getGameData(name .. "zhoufu") >= 4 then
			setGameData(name .. "yingbing", -1000)
			setGameData(name .. "zhoufu", -1000)
			addZhanGong(room, name)
		end
	end
end

-- ('yyym', '有勇有谋', 10, '使用伏完在一局游戏中发动谋溃弃掉3张闪', 0, 'qun',  'fuwan', 0, 0);
zgfunc[sgs.ChoiceMade].yyym=function(self, room, event, player, data,isowner,name)
	if not string.find(room:getOwner():getGeneralName(), "fuwan") then return false end
	if not isowner then return false end
	local choices= data:toString():split(":")
	if choices[1] == "cardChosen" and choices[2] == "moukui" and sgs.Sanguosha:getCard(choices[3]):isKindOf("Jink") then
		addGameData(name, 1)
		if getGameData(name) == 3 then
			addZhanGong(room, name)
		end
	end
end


-- ('zmtz', '真命天子', 10, '使用刘协在一局游戏中发动密诏4次，天命4次，并最终胜利', 0, 'qun',  'liuxie', 0, 0);
zgfunc[sgs.ChoiceMade].zmtz = function(self, room, event, player, data, isowner, name)
	if room:getOwner():getGeneralName() ~= "zhuran" then return false end
	if not isowner then return false end
	local choices = data:toString():split(":")
	if choices[1] == "skillInvoke" and choices[2] == "tianming" then
		if choices[3] == "yes" then
			addGameData(name .. "tianming", 1)
			if getGameData(name .. "tianming") >= 4 and getGameData(name .. "mizhao") >= 4 then
				setGameData(name .. "tianming", -1000)
				setGameData(name .. "mizhao", -1000)
				addZhanGong(room, name)
			end
		end
	end
end

-- ('zmtz', '真命天子', 10, '使用刘协在一局游戏中发动密诏4次，天命4次，并最终胜利', 0, 'qun',  'liuxie', 0, 0);
zgfunc[sgs.CardFinished].zmtz = function(self, room, event, player, data, isowner, name)
	if room:getOwner():getGeneralName() ~= "liuxie" then return false end
	if not isowner then return false end
	local use = data:toCardUse()
	if use.card:isKindOf("MizhaoCard") and use.from:objectName() == room:getOwner():objectName() then
		addGameData(name .. "mizhao", 1)
		if getGameData(name .. "mizhao") >= 4 and getGameData(name .. "tianming") >= 4 then
			setGameData(name .. "tianming", -1000)
			setGameData(name .. "mizhao", -1000)
			addZhanGong(room, name)
		end
	end
end




zgfunc[sgs.TurnStart].hulao=function(self, room, event, player, data,isowner,name)
	if room:getMode()=="04_1v3" and player:isLord() and player:getMark("secondMode")==1 and player:getGeneral2() and player:getMark("changeHulao2")==0 then
		if player:hasSkill("wushuang") then room:detachSkillFromPlayer(player, "wushuang") end
		room:setPlayerMark(player, "changeHulao2", 1)

		if player:getMaxHp()~=4 then
			room:setPlayerProperty(player, "maxhp", sgs.QVariant(4))
			room:setPlayerProperty(player, "hp", sgs.QVariant(4))
		end
		local reason=sgs.CardMoveReason()
		reason.m_reason   = sgs.CardMoveReason_S_REASON_NATURAL_ENTER
		reason.m_playerId = player:objectName()
		reason.m_targetId = player:objectName()

		local weapon=player:getWeapon()
		if weapon and not weapon:isKindOf("Crossbow") then
			room:moveCardTo(weapon, nil, nil, sgs.Player_DiscardPile, reason)
		end
	end

	if room:getMode()=="04_1v3" and player:isLord() and player:getMark("secondMode")==1 and not player:faceUp() then
		player:turnOver()
	end
end





function gainSkill(room)	
	local skillname 
	local count=0
	local row
	if enableSkillCard==0 then return false end
	repeat
		row=db:first_row("select skillname from skills where 1 order by random() limit 1")
		if sgs.Sanguosha:getSkill(row.skillname) then skillname=row.skillname end
		count=count+1
	until skillname or count>=10
	if not skillname then return broadcastMsg(room,"#canntGainSkill",row.skillname) end
	broadcastMsg(room,"#gainSkill",skillname)
	sqlexec("update skills set gained=gained+1 where skillname='%s'",skillname)
	room:getOwner():speak(string.format("恭喜获得技能卡【<font color='green'><b>%s</b></font>】",sgs.Sanguosha:translate(skillname)))	
end

function broadcastMsg(room,info,...)
	local log= sgs.LogMessage()
	log.type = info
	log.from = room:getOwner()
	local arg = {...}
	if #arg>0 then log.arg = arg[1] end
	if #arg>1 then log.arg2 =arg[2] end
	room:sendLog(log)
	return true
end

function addZhanGong(room,name)
	sqlexec("update zhangong set gained=gained+1,lasttime=datetime('now','localtime') where id='%s'",name)
	setGameData("myzhangong", getGameData("myzhangong","")..name..":")
	sqlexec("update results set zhangong='%s' where id='%d'",getGameData("myzhangong",""),getGameData("roomid"))
	broadcastMsg(room,"#zhangong_"..name)	
	room:getOwner():speak(string.format("恭喜获得战功【<font color='yellow'><b>%s</b></font>】",sgs.Sanguosha:translate(name)))
end

--[[
	GlobalData  永久保存到数据库中的数据
	用于保存类似， 被南蛮入侵打死N次， 3v3前锋被主帅打死N次等类似战功的数据存储
]]
function addGlobalData(key,val)
	getGlobalData(key)
	sqlexec("update gamedata set num=num+%d where id='%s'",val,key)
end

function setGlobalData(key,val)	
	getGlobalData(key)
	sqlexec("update gamedata set num=%d where id='%s'",val,key)
end

function getGlobalData(key,...)
	local arg = {...}
	local defval= #arg>=1 and arg[1] or 0
	local row=db:first_row(string.format("select id,num from gamedata where id='%s'",key))
	if (not row) or row.id==nil then
		sqlexec("insert into gamedata values('%s',0)",key)
		return defval
	else
		return row.num
	end
end

--[[
	GameData  某盘游戏的全局变量
	游戏开始时，GameData变量清0，游戏结束后，GameData变量的数据消失	
]]
function addGameData(key,val)
	if not zggamedata[key] then zggamedata[key]=0 end
	zggamedata[key]=zggamedata[key]+val
end

function setGameData(key,val)	
	zggamedata[key]=val
end

function getGameData(key,...)
	local arg = {...}
	if not zggamedata[key] then return #arg>=1 and arg[1] or 0 end
	return zggamedata[key]
end


--[[
	TurnData  回合变量
	房主每一个回合开始时，所有TurnData变量清0，	
]]
function addTurnData(key,val)
	if not zgturndata[key] then zgturndata[key]=0 end
	zgturndata[key]=zgturndata[key]+val
end

function setTurnData(key,val)
	zgturndata[key]=val
end

function getTurnData(key,...)
	local arg = {...}
	if not zgturndata[key] then return #arg>=1 and arg[1] or 0 end
	return zgturndata[key]
end


function useSkillCard(room,owner)
	local zgquery=db:first_row("select count(id) as num from zhangong where gained>0")
	local limitnum= math.ceil(zgquery.num / 20)
	local myskill={"'.'"}
	for _,skill in sgs.qlist(owner:getVisibleSkillList()) do
		table.insert(myskill,"'"..skill:objectName().."'")
	end	
	local myskills=table.concat(myskill,",")	
	local skilldata=db:rows("select skillname from skills where gained>used and skillname not in ("..myskills..") order by random() limit "..limitnum)
	local skills={}
	for row in skilldata do
		if row.skillname and sgs.Sanguosha:getSkill(row.skillname) then table.insert(skills,row.skillname) end
	end
	if #skills>0 then
		local choice=room:askForChoice(owner,"@chooseskill","cancel+"..table.concat(skills,"+"))
		if choice ~= "cancel" then
			room:acquireSkill(owner,choice)
			if not owner:hasSkill("ruoyu") then room:loseHp(owner) end
			sqlexec("update skills set  used=used+1 where skillname='%s'",choice)
		end
	end
end
--[[
function useLuckyCard(room,owner)
	if owner:hasSkill("tuntian") then return false end
	local zgquery=db:first_row("select count(id) as num from zhangong where gained>0")
	local numquery=db:first_row("select gained - used as num from zgcard where id='luckycard'")
	local limitnum= math.ceil(zgquery.num / 20)
	
	if numquery.num<=0 then return false end
	limitnum = math.min(numquery.num,limitnum)

	--防止使用手气卡的时候触发【落英】
	local reason=sgs.CardMoveReason()
	reason.m_reason   = sgs.CardMoveReason_S_REASON_PUT
	reason.m_playerId = owner:objectName()
	reason.m_targetId = owner:objectName()

	for i=math.max(1,limitnum),1,-1 do
		if owner:askForSkillInvoke("useLuckyCard") then
			local n=owner:getHandcardNum()
			if owner:hasSkill("lianying") or owner:hasSkill("beifa") or owner:hasSkill("sijian") then n=n-1 end
			for j=n,1,-1 do
				room:moveCardTo(owner:getRandomHandCard(), nil, nil, sgs.Player_DiscardPile, reason)
			end
			owner:drawCards(n)
			sqlexec("update zgcard set used = used + 1 where id='%s'",'luckycard')
			broadcastMsg(room,"#LuckyCardNum",i-1)
		else
			break
		end
	end
end
]]
function useHulaoCard(room,owner)
	if room:getMode()~='04_1v3' or not owner:askForSkillInvoke("useHulaoCrad") then return false end
	local generalnames=sgs.Sanguosha:getRandomGenerals(999)
	
	local banlist={"shenguanyu", "shenzhugeliang","shenzhouyu","shenlvbu","bgm_diaochan","sp_pangde"}
	for _,p in sgs.qlist(room:getAllPlayers()) do
		table.insert(banlist,p:getGeneralName())
	end
	table.removeTable(generalnames, banlist)

	local shuffle=function(arr)
		local count = #arr
		math.randomseed(os.time()+count)
		for i = 1, count do
			local j = math.random( 1, count )
			arr[j], arr[i] = arr[i], arr[j]
		end
		return arr
	end
	
	local count=1
	local choice
	shuffle(generalnames)
	for _,p in sgs.qlist(room:getAllPlayers()) do
		if p:isLord() then
			local names=table.concat(generalnames,"+",1,10)
			local namslist= names:split("+")
			local choice=room:askForChoice(owner,"@chooseGeneral0","cancel+randSelect+"..names)
			if choice=="randSelect" then choice=namslist[ 1 + (os.time() % 10)] end
			if choice ~= "cancel" then
				room:detachSkillFromPlayer(p, "wushuang")
				room:changeHero(p,choice,false,false,true,true)
				if p:getMaxHp()~=8 then
					room:setPlayerProperty(p, "maxhp", sgs.QVariant(8))
					room:setPlayerProperty(p, "hp", sgs.QVariant(8))
				end				
			end
		else
			local names=table.concat(generalnames,"+",1,10)
			local choice=room:askForChoice(owner,"@chooseGeneral"..count,"cancel+"..names)
			if choice ~= "cancel" then
				room:changeHero(p,choice,true,false,false,true)
				room:setPlayerProperty(p, "kingdom", sgs.QVariant(p:getGeneral():getKingdom()))
				p:setGender(p:getGeneral():getGender())
			end
			count=count+1
		end
		if choice ~= "cancel" then
			table.removeOne(generalnames,choice)
			shuffle(generalnames)
		end
	end
end

function init_gamestart(self, room, event, player, data, isowner)
	local config=sgs.Sanguosha:getSetupString():split(":")
	local count=0
	local mode=config[2]
	local flags=config[6]
	local owner=room:getOwner()
	if not isowner or getGameData("status")==1 then return false end
	
	for _, p in sgs.qlist(room:getAllPlayers()) do
		if p:getState() ~= "robot" then 
			count=count+1
		else
			room:detachSkillFromPlayer(p, "#zgzhangong1")
			room:detachSkillFromPlayer(p, "#zgzhangong2")
		end
	end
	if count>1 then
		setGameData("status",0)
		return false
	end
	if string.find(config[2],"mini") or string.find(config[2],"custom") then
		setGameData("status",0)
		return false
	end
	if string.find(flags,"C") then
		setGameData("status",0)
		return false
	end

	for key,val in pairs(zggamedata) do
		zggamedata[key]=0
	end

	setGameData("status",1)
	setGameData("myzhangong","")
	if sgs.GetConfig("EnableHegemony", false) then setGameData("hegemony", 1) end

	if getGameData("roomid")==0 then 
		setGameData("roomid",os.time())
		setTurnData("wen",0)
		setTurnData("wu",0)
		setTurnData("expval",0)
		sqlexec("insert into results values(%d,'%s','%s','%s','%d','%s',0,1,'-',0,0,0,'')",
				getGameData("roomid"),player:getGeneralName(),player:getRole(),
				player:getKingdom(),getGameData("hegemony"),room:getMode())
	end	

	--if enableLuckyCard==1 then useLuckyCard(room,owner) end
	if enableSkillCard==1 then useSkillCard(room,owner) end
	if enableHulaoCard==1 then useHulaoCard(room,owner) end

	return true
end

zgzhangong1 = sgs.CreateTriggerSkill{
	name = "#zgzhangong1",
	events ={
			sgs.PreDamageDone,
			sgs.Damage,
			sgs.DamageCaused,
			sgs.DamageComplete,
			sgs.Damaged,
			sgs.DamageInflicted,
			sgs.Death,
			sgs.FinishRetrial,
			sgs.GameOverJudge,
			sgs.HpChanged,
			sgs.HpRecover,
			sgs.TurnStart,
			},
	priority = 6,
	can_trigger = function()
		return true
	end,

	on_trigger = function(self, event, player, data)
		local room = player:getRoom()
		local owner= room:getOwner():objectName()==player:objectName()
		
		local callbacks=zgfunc[event]
		if callbacks and getGameData("status")==1 then
			for name, func in pairs(callbacks) do
				if type(func)=="function" then
					if event == sgs.Death then
						if data:toDeath().who:objectName() == player:objectName() then
							func(self, room, event, player, data, owner,name)
						end
					else
						func(self, room, event, player, data, owner,name)
					end
				end
			end
		end
		--[[
		if event ==sgs.Death then
			if owner and data:toDeath().who:objectName() == player:objectName() then askForGiveUp(room,room:getOwner()) end
		end
		]]
		return false
	end,
}

zgzhangong2 = sgs.CreateTriggerSkill{
	name = "#zgzhangong2",
	events = {
		sgs.GameStart,
		sgs.AfterDrawInitialCards, 
		sgs.CardEffect,
		sgs.CardEffected,
		sgs.CardFinished,
		sgs.CardUsed,
		sgs.AfterDrawNCards,
		sgs.CardResponded,
		sgs.CardsMoveOneTime,
		sgs.ChoiceMade,
		sgs.EventPhaseStart,
		sgs.EventPhaseEnd,
		sgs.Pindian,
		sgs.Predamage,
		sgs.SlashEffected,
		sgs.SlashHit,
		sgs.SlashMissed,
		sgs.Dying,

		},
	priority = 6,
	on_trigger = function(self, event, player, data)
		local room = player:getRoom()
		local owner= room:getOwner():objectName()==player:objectName()
		
		if event ==sgs.GameStart and owner and room:getTag("zg_init_game"):toBool()==false then
			room:setTag("zg_init_game",sgs.QVariant(true))
			local log= sgs.LogMessage()
			if init_gamestart(self, room, event, player, data, owner) then
				log.type = "#enableZhangong"
				player:speak(string.format("<font color='green'>战功包已开启 ver:%s</font>",zgver))
			else
				log.type = "#disableZhangong"
				player:speak(string.format("<font color='red'>战功包已禁用 ver:%s</font>",zgver))
			end
			room:sendLog(log)
		end
		
		
		local callbacks=zgfunc[event]
		if callbacks and getGameData("status")==1 then
			for name, func in pairs(callbacks) do
				if type(func)=="function" then 						
					func(self, room, event, player, data, owner,name) 
				end				
			end
		end
		return false
	end,
}
--[[
function askForGiveUp(room,owner)
	local mode=room:getMode()
	local role=owner:getRole()

	if mode=="02_1v1" or not owner:askForSkillInvoke("giveup") then return false end
	
	if getGameData("hegemony")==1 then	
		for _, p in sgs.qlist(room:getAlivePlayers()) do
			if p:getRole()==role then room:killPlayer(p) end
		end
		local alives=sgs.QList2Table(room:getAlivePlayers())
		local winner=alives[#alives]
		if winner:getGeneralName()=="anjiang" then
			local names= room:getTag(winner:objectName()):toStringList()
			room:changeHero(winner, names[1], false, false, false, false)
			if #names==2 then
				room:changeHero(winner, names[2], false, false, true, false)
			end			
			room:setPlayerProperty(winner, "kingdom", sgs.QVariant(winner:getGeneral():getKingdom()))
			room:removeTag(winner:objectName())			
		end
		for i=1,#alives-1,1 do
			room:killPlayer(alives[i])			
		end
		room:getThread():trigger(sgs.GameOverJudge, room, owner)
		return false
	end

	if role=="loyalist" or role=="renegade" then
		room:killPlayer(room:getLord())
	elseif role=="rebel" then
		for _, p in sgs.qlist(room:getAlivePlayers()) do
			if not p:isLord() then room:killPlayer(p) end
		end
	end
	room:getThread():trigger(sgs.GameOverJudge, room, owner)
end
]]

function getWinner(room,victim)
	local mode=room:getMode()
	local role=victim:getRole()

	if mode == "02_1v1" then
		local list = victim:getTag("1v1Arrange"):toStringList()
		local rule = sgs.GetConfig("1v1/Rule", "")
		if #list > (rule == "OL" and 3 or 0) then return false end
	end

	local alives=sgs.QList2Table(room:getAlivePlayers())
	
	
	if getGameData("hegemony")==1 then
		local has_anjiang = false
		local has_diff_kingdoms = false
		local init_kingdom
		for _, p in sgs.qlist(room:getAlivePlayers()) do
			local list = room:getTag(p:objectName()):toStringList()
			if list and (p:getGeneral2() and #list == 2 or #list == 1) then
				has_anjiang = true
			end
			if init_kingdom == nil then 
				init_kingdom = p:getKingdom()
			elseif init_kingdom ~= p:getKingdom() then
				has_diff_kingdoms = true
			end
		end

		if not has_anjiang and  not has_diff_kingdoms then
			local winners={}
			local aliveKingdom = alives[1]:getKingdom()

			for _, p in sgs.qlist(room:getAllPlayers()) do
				if p:isAlive() then 
					table.insert(winners , p:objectName()) 
				else
					if p:getKingdom() == aliveKingdom then
						local generals = room:getTag(p:objectName()):toString()
						if (not (generals and not string.find(flags,"S"))) or (not string.find(generals,",")) then
							table.insert(winners , p:objectName())
						end
					end
				end
			end
			return #winners and table.concat(winners,"+") or false
		end
		return
	end
	
	
	if mode == "06_3v3" then
		if role=="lord" then return "renegade+rebel" end
		if role=="renegade" then return "lord+loyalist" end
		return false
	else
		local alive_roles = room:aliveRoles(victim)
		if role=="lord" then
			return #alives==1 and alives[1]:getRole()== "renegade" and alives[1]:objectName() or "rebel"
		elseif role=="rebel" or role=="renegade" then
			local alive_roles_str = table.concat(alive_roles,",")
			if (not string.find(alive_roles_str,"rebel")) and (not string.find(alive_roles_str,"renegade")) then
				return "lord+loyalist"
			end
		end
	end
	return false
end

function initZhangong()	
	local generalnames=sgs.Sanguosha:getLimitedGeneralNames()
	local packages={}
	for _, pack in ipairs(config.package_names) do
		if pack == "NostalStandard" then table.insert(packages,"nostal_standard") end
		if pack == "HFormation" then table.insert(packages,"h_formation") end
		if pack == "HMomentum" then table.insert(packages,"h_momentum") end
		if pack == "HegemonySP" then table.insert(packages,"hegemony_sp") end
		if pack == "NostalWind" then table.insert(packages,"nostal_wind") end
		if pack == "NostalYJCM" then table.insert(packages,"nostal_yjcm") end
		if pack == "NostalYJCM2012" then table.insert(packages,"nostal_yjcm2012") end
		if pack == "TaiwanSP" then table.insert(packages,"taiwan_sp") end
		table.insert(packages, string.lower(pack))
	end
	local hidden = {"anjiang", "shenlvbu1", "shenlvbu2", "sp_heg_zhouyu", "sp_heg_xiaoqiao", "wz_xiaoqiao", "wz_daqiao" }
	table.insertTable(generalnames,hidden)
	for _, generalname in ipairs(generalnames) do
		local general = sgs.Sanguosha:getGeneral(generalname)
		if general then
			local packname = string.lower(general:getPackage())
			if table.contains(packages, packname) then
				general:addSkill("#zgzhangong1")
				general:addSkill("#zgzhangong2")
			end
		end
		local spgeneral = sgs.Sanguosha:getGeneral("sp_" .. generalname)
		if spgeneral then
			local packname = string.lower(spgeneral:getPackage())
			if table.contains(packages, packname) then
				spgeneral:addSkill("#zgzhangong1")
				spgeneral:addSkill("#zgzhangong2")
			end
		end
		local twgeneral = sgs.Sanguosha:getGeneral("tw_" .. generalname)
		if twgeneral then
			local packname = string.lower(twgeneral:getPackage())
			if table.contains(packages, packname) then
				twgeneral:addSkill("#zgzhangong1")
				twgeneral:addSkill("#zgzhangong2")
			end
		end
	end
end

function initDB()
	require "sqlite3"
	db = sqlite3.open("./zhangong/zhangong.data")

	local tblquery=db:first_row("select count(name) as tblnum from sqlite_master  where type='table' and name='card';")
	if tblquery.tblnum==0 then
		db:exec("CREATE TABLE zgcard([id] varchar(20) NOT NULL,[gained] int(11) NOT NULL,[used] int(11) NOT NULL, Primary Key(id) ON CONFLICT Ignore);")
		db:exec("insert into zgcard values('luckycard',100,0);")
	end

	local content=(io.open "./zhangong/zhangong.sql"):read("*a")

	local zgquery=db:first_row("select count(name) as tblnum from sqlite_master  where type='table' and name='zhangong';")
	if zgquery.tblnum==0 then
		local sqltbl = content:split("\n")
		for _,line in ipairs(sqltbl) do
			db:exec(line)
		end
	end
	
	if string.find(content, "%-%-new%-zhangong%-%-") then
		local rowquery = db:first_row("select count(*) as rowcount from zhangong;")
		if rowquery.rowcount < 389 then
			local arr=content:split("%/%*%-%-new%-zhangong%-%-%*%/")
			local sqlarr = arr[3]:split("\n")
			for _, line in ipairs(sqlarr) do
				db:exec(line)
			end
		end
	end
	
	-- 修正简雍舌灿莲花
	sqlexec("update zhangong set category='shu' where id='sclh'")
	sqlexec("update zhangong set general ='jianyong' where id='sclh'")

	-- 所有武将的 获得N场胜利 取得相应战功的代码  
	--
	for query in db:rows("select * from zhangong where num>0 ") do
		zgfunc[sgs.GameOverJudge].callback[query.id]=function(room,player,data,name,result)			
			local mode=room:getMode()
			local kingdoms={["wu"]=1,["shu"]=1,["wei"]=1,["qun"]=1,["god"]=1}
			if result ~='win' then return false end
			if query.category=="3v3" and room:getMode()~="06_3v3" then return false end
			if query.category=="1v1" and room:getMode()~="02_1v1" then return false end
			if kingdoms[query.category] and	(mode=="06_3v3" or mode=="02_1v1" or getGameData("hegemony")==1) then
				return false
			end
			local flag=false
			local role=room:getOwner():getRole()
			local sql="select count(id) as num from results where result='win' "

			if query.general=="-" then
				sql=sql..string.format("and 1 ")
			elseif query.general==room:getOwner():getGeneralName() then
				sql=sql..string.format("and general='%s' ",query.general)
			elseif query.general==role then
				sql=sql..string.format("and role='%s' ",query.general)
			elseif query.general==room:getOwner():getKingdom() then
				sql=sql..string.format("and kingdom='%s' ",query.general)
			elseif query.general=="leader" and (role=="lord" or role =="renegade") and mode=="06_3v3" then
				sql=sql..string.format("and mode='06_3v3' and (role=='lord' or role =='renegade') ")
			elseif query.general=="guard" and (role=="loyalist" or role =="rebel") and mode=="06_3v3" then
				sql=sql..string.format("and mode='06_3v3' and (role=='loyalist' or role =='rebel') ")
			else
				return false
			end

			if query.category=="3v3" then sql=sql.."and mode=='06_3v3' " end
			if query.category=="1v1" then sql=sql.."and mode=='02_1v1' " end
			if kingdoms[query.category] then 
				sql=sql.." and hegemony=0 and mode not in ('06_3v3','02_1v1') "
			end

			for row in db:rows(sql) do
				if row.num>=query.num and query.gained==0 then addZhanGong(room,name) end
				sqlexec("update zhangong set count=%d where id='%s'",row.num,query.id)
			end
		end
	end


	local genTranslation = function()
		local zgTrList={}
		for row in db:rows("select id,name,description from zhangong") do
			zgTrList["#zhangong_"..row.id]="%from 获得了战功【<b><font color='yellow'>"..row.name.."</font></b>】,"..row.description
			zgTrList[row.id]=row.name
		end
		return zgTrList
	end
	sgs.LoadTranslationTable(genTranslation())
end

zganjiang:addSkill(zgzhangong1)
zganjiang:addSkill(zgzhangong2)

initDB()
initZhangong()



sgs.LoadTranslationTable {
	["zhangong"] ="战功包",
	["#gainWen"] ="%from获得【%arg】点文功",
	["#gainWu"] ="%from获得【%arg】点武功",
	["#gainExp"] ="%from获得【%arg】点经验",
	["#gainLuckycard"] ="%from获得【%arg】张手气卡",
	
	["#canntGainSkill"]= "【警告】无法获得技能【%arg】",
	["#gainSkill"]="%from获得了技能卡【%arg】",
	["#gsyNum"]="%from清除了【%arg】盘逃跑记录",
	["@chooseskill"]="流失体力获得技能",
	["cancel"] = "取消",
	--["giveup"] = "立即认输并结束游戏",
	["#enableZhangong"]="【<b><font color='green'>提示</font></b>】: 本局游戏开启了战功统计",
	["#disableZhangong"]="【<b><font color='red'>提示</font></b>】: 本局游戏禁止了战功统计",
	--["useLuckyCard"]  ="手气卡",
	["useHulaoCrad"]  ="点将卡",
	["@chooseGeneral0"]  ="请为主公选将",
	["@chooseGeneral1"]  ="请为先锋选将",
	["@chooseGeneral2"]  ="请为中坚选将",
	["@chooseGeneral3"]  ="请为大将选将",
	["randSelect"]  ="随机选择",
	

	["#LuckyCardNum"]  ="【<b><font color='yellow'>手气卡</font></b>】: 本局还有【%arg】次换牌机会",
	
}
