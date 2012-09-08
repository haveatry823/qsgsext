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

zgfunc[sgs.CardFinished]={}
zgfunc[sgs.ChoiceMade]={}

zgfunc[sgs.Damage]={}
zgfunc[sgs.DamageCaused]={}
zgfunc[sgs.Damaged]={}

zgfunc[sgs.Death]={}
zgfunc[sgs.EventPhaseEnd]={}

zgfunc[sgs.FinishRetrial]={}

zgfunc[sgs.GameOverJudge]={}
zgfunc[sgs.GameOverJudge]["callback"]={}
zgfunc[sgs.SlashEffected]={}

zgfunc[sgs.TurnStart]={}

sgs.todo=9999
zgfunc[sgs.todo]={}

require "sqlite3"
db = sqlite3.open("./zhangong/zhangong.data")

function logmsg(fmt,...)
	local fp = io.open("zhangong.txt","ab")
	if type(fmt)=="boolean" then fmt = fmt and "true" or "false" end
	fp:write(string.format(fmt, unpack(arg)).."\r\n")
	fp:close()
end

function sqlexec(sql,...)
	local sqlstr=string.format(sql, unpack(arg))
	db:exec(sqlstr)
	logmsg(sqlstr.."\r\n")	
end


-- srxsm :: 射人先射马 :: 一局游戏中发动麒麟弓特效至少3次
-- 
zgfunc[sgs.ChoiceMade].srxsm=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	local choices= data:toString():split(":")
	if choices[1]=="skillInvoke"  and  choices[2]=="KylinBow" and choices[3]=="yes" then
		addGameData(name,1)
		if getGameData(name)>=3 then
			addZhanGong(room,name)
			setGameData(name,-100)
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
		if getGameData(name)>=3 then
			addZhanGong(room,name)
			setGameData(name,-100)
		end
	end	
end


-- srpz :: 势如破竹 :: 一局游戏中发动贯石斧特效至少3次
-- 
zgfunc[sgs.ChoiceMade].srpz=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	local choices= data:toString():split(":")
	if choices[1]=="cardResponsed" and choices[2]=="@Axe" then
		addGameData(name,1)
		if getGameData(name)>=3 then
			addZhanGong(room,name)
			setGameData(name,-100)
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
		if getTurnData(name)>=4 then
			addZhanGong(room,name)
			setTurnData(name,-100)
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
		if getGameData(name)>=3 then
			addZhanGong(room,name)
			setGameData(name,-100)
		end
	end	
end


-- wenwu ::  :: 每打出或使用一个【杀】,增加一点武功;  每打出或使用一个锦囊,增加一点文功
-- 
zgfunc[sgs.CardFinished].wenwu=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	local use=data:toCardUse()
	local card=use.card
	if card:isKindOf("TrickCard") then addTurnData("wen",1) end
	if card:isKindOf("Slash")	  then addTurnData("wu",1) end	
end


-- hydt :: 鸿运当头 :: 在1个回合内使用至少3次无中生有
-- 
zgfunc[sgs.CardFinished].hydt=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	local use=data:toCardUse()
	local card=use.card
	if card:isKindOf("ExNihilo") then 
		addTurnData(name,1)
		if getTurnData(name)>=3 then			 
			addZhanGong(room,name)
			setTurnData(name,-100)
		end
	end
end



-- expval ::  :: 每造成一点伤害，增加一点经验，最高限8点
-- 
zgfunc[sgs.Damage].expval=function(self, room, event, player, data,isowner,name)
	local damage = data:toDamage()
	if damage.from and damage.from:objectName()==room:getOwner():objectName() then
		addTurnData("expval",math.min(damage.damage,8))
	end		
end


-- bgws :: 秉公无私 :: 身为主公在一局游戏中从未对忠臣造成伤害，并取得胜利
-- 
zgfunc[sgs.Damage].bgws=function(self, room, event, player, data,isowner,name)
	local damage = data:toDamage()
	if damage.from and damage.from:objectName()==room:getOwner():objectName() 
			and damage.from:isLord() and damage.to:getRole()=="loyalist" then
		addGameData("bgws",1)
	end		
end


-- bgws :: 秉公无私 :: 身为主公在一局游戏中从未对忠臣造成伤害，并取得胜利
-- 
zgfunc[sgs.GameOverJudge].callback.bgws=function(room,player,data,name,result)	
	if getGameData("bgws",0)==0 and result =='win' then		 
		addZhanGong(room,name)
	end
end



-- ljxs :: 落井下石 :: 一局游戏中发动古锭刀特效至少3次
-- 
zgfunc[sgs.DamageCaused].ljxs=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	local damage = data:toDamage()
	if damage.card and damage.card:isKindOf("Slash") and damage.to:isKongcheng() 
			and not damage.chain and not damage.transfer then
		addGameData(name,1)
		if getGameData(name)>=3 then			 
			addZhanGong(room,name)
			setGameData(name,-100)
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
	if damage.card and damage.card:isKindOf("Lightning") and playerName==currentName then		
		setTurnData("mbgj",1)
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
	local damage = data:toDamageStar()
	if damage.from and damage.from:objectName()==room:getOwner():objectName() then
		gainSkill(room)
	end		
end


-- lczz :: 乱臣贼子 :: 身为反贼在1局游戏中，手刃至少2个忠臣或内奸
-- 
zgfunc[sgs.Death].lczz=function(self, room, event, player, data,isowner,name)
	local damage = data:toDamageStar()
	local killer=damage.from
	if not killer then return false end
	if killer:getRole()=="rebel" and (player:getRole()=="renegade" or player:getRole()=="loyalist") 
			and killer:objectName()==room:getOwner():objectName()  then
		addGameData(name,1)		
		if getGameData(name,0)>=2 then 			 
			addZhanGong(room,name)
			setGameData(name,-100)
		end
		
	end		
end


-- lczz :: 乱臣贼子 :: 身为反贼在1局游戏中，手刃至少2个忠臣或内奸
-- 
zgfunc[sgs.GameOverJudge].callback.lczz=function(room,player,data,name,result)
	local damage = data:toDamageStar()
	local killer=damage.from
	if not killer then return false end
	if killer:getRole()=="rebel" and (player:getRole()=="renegade" or player:getRole()=="loyalist") 
			and killer:objectName()==room:getOwner():objectName()  then
		addGameData(name,1)		
		if getGameData(name)>=2 then 			 
			addZhanGong(room,name)
			setGameData(name,-100)
		end
	end		
end



-- cdzx :: 赤胆忠心 :: 身为忠臣在1局游戏中，手刃至少2个反贼或内奸
-- 
zgfunc[sgs.Death].cdzx=function(self, room, event, player, data,isowner,name)
	local damage = data:toDamageStar()
	local killer=damage.from
	if not killer then return false end
	if killer:getRole()=="loyalist" and (player:getRole()=="renegade" or player:getRole()=="rebel") 
			and killer:objectName()==room:getOwner():objectName()  then
		addGameData(name,1)		
		if getGameData(name,0)>=2  then 			 
			addZhanGong(room,name)
			setGameData(name,-100)
		end
	end		
end


-- cdzx :: 赤胆忠心 :: 身为忠臣在1局游戏中，手刃至少2个反贼或内奸
-- 
zgfunc[sgs.GameOverJudge].callback.cdzx=function(room,player,data,name,result)
	local damage = data:toDamageStar()
	local killer=damage.from
	if not killer then return false end
	if killer:getRole()=="loyalist" and (player:getRole()=="renegade" or player:getRole()=="rebel") 
			and killer:objectName()==room:getOwner():objectName()  then
		addGameData(name,1)		
		if getGameData(name)>=2 then 			 
			addZhanGong(room,name)
			setGameData(name,-100)
		end

	end		
end


-- pfdj :: 平反大将 :: 在1局游戏中手刃4个反贼
-- 
zgfunc[sgs.Death].pfdj=function(self, room, event, player, data,isowner,name)
	local damage = data:toDamageStar()
	local killer=damage.from
	if not killer then return false end
	if player:getRole()=="rebel" and killer:objectName()==room:getOwner():objectName()  then
		addGameData(name,1)		
		if getGameData(name,0)==4 then 			 
			addZhanGong(room,name)
			setGameData(name,-100)
		end
	end		
end


-- pfdj :: 平反大将 :: 在1局游戏中手刃4个反贼
-- 
zgfunc[sgs.GameOverJudge].callback.pfdj=function(room,player,data,name,result)
	local damage = data:toDamageStar()
	local killer=damage.from
	if not killer then return false end
	if player:getRole()=="rebel" and killer:objectName()==room:getOwner():objectName()  then
		addGameData(name,1)
		if getGameData(name)==4 then 			 
			addZhanGong(room,name)
			setGameData(name,-100)
		end
	end		
end




-- lsch :: 辣手摧花 :: 一局游戏中杀死至少2名女性角色
-- 
zgfunc[sgs.Death].lsch=function(self, room, event, player, data,isowner,name)
	local damage = data:toDamageStar()
	local killer=damage.from
	if not killer then return false end
	if player:isFemale() and killer:objectName()==room:getOwner():objectName()  then
		addGameData(name,1)		
		if getGameData(name,0)>=2 then 			 
			addZhanGong(room,name)
			setGameData(name,-100)
		end
	end		
end


-- lsch :: 辣手摧花 :: 一局游戏中杀死至少2名女性角色
-- 
zgfunc[sgs.GameOverJudge].callback.lsch=function(room,player,data,name,result)
	local damage = data:toDamageStar()
	local killer=damage.from
	if not killer then return false end
	if player:isFemale() and killer:objectName()==room:getOwner():objectName()  then
		addGameData(name,1)
		if getGameData(name)>=2 then 			 
			addZhanGong(room,name)
			setGameData(name,-100)
		end
	end		
end



-- djyd :: 打酱油的 :: 在1局游戏中，在自己的回合开始前就死亡
-- 
zgfunc[sgs.Death].djyd=function(self, room, event, player, data,isowner,name)
	local damage = data:toDamageStar()
	if getGameData("turncount")==0 and player:objectName()==room:getOwner():objectName()   then
		addZhanGong(room,name)
	end		
end


-- djyd :: 打酱油的 :: 在1局游戏中，在自己的回合开始前就死亡
-- 
zgfunc[sgs.GameOverJudge].callback.djyd=function(room,player,data,name,result)
	local damage = data:toDamageStar()
	if getGameData("turncount")==0 and player:objectName()==room:getOwner():objectName()  then
		addZhanGong(room,name)
	end		
end



-- xbtc :: 先拔头筹 :: 一局游戏中，自己的首回合结束前杀死至少一名非本方武将
-- 
zgfunc[sgs.Death].xbtc=function(self, room, event, player, data,isowner,name)
	local damage = data:toDamageStar()
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
	local damage = data:toDamageStar()
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
		if getGameData(name)>=3 then 			 
			addZhanGong(room,name)
			setGameData(name,-100)
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
		if getGameData(name)>=3 then 			 
			addZhanGong(room,name)
			setGameData(name,-100)
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
		if getGameData(name)>=3 then 			 
			addZhanGong(room,name)
			setGameData(name,-100)
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
		if getGameData(name)>=3 then 			 
			addZhanGong(room,name)
			setGameData(name,-100)
		end
	end
end



-- tq :: 天谴 :: 不被改判定牌的情况下被闪电劈死
-- 
zgfunc[sgs.FinishRetrial].tq=function(self, room, event, player, data,isowner,name)
		local judge=data:toJudge()
	room:output(judge.reason)
	room:output(room:getTag("retrial"):toBool() and "retrial" or "no retrial")
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
	local damage = data:toDamageStar()
	if damage.card and damage.card:isKindOf("Lightning") and player:objectName()==room:getOwner():objectName() then
		if getTurnData(name,0)==1 then 			 
			addZhanGong(room,name)
		end
	end		
end


-- tq :: 天谴 :: 不被改判定牌的情况下被闪电劈死
-- 
zgfunc[sgs.GameOverJudge].callback.tq=function(room,player,data,name,result)
	local damage = data:toDamageStar()
	if damage.card and damage.card:isKindOf("Lightning") and player:objectName()==room:getOwner():objectName() then
		if getTurnData(name,0)==1 then
			addZhanGong(room,name)
		end
	end		
end




-- tongji ::  :: 
-- 
zgfunc[sgs.GameOverJudge].tongji=function(self, room, event, player, data,isowner,name)
	local winner=getWinner(room,player)	
	if not winner then return false end
	local winlist= winner:split("+")
	local owner=room:getOwner()
	local result = (table.contains(winlist, owner:getRole()) or table.contains(winlist, owner:objectName())) and 'win' or 'lose'
	local alive=owner:isAlive() and 1 or 0	
	local damage =data:toDamageStar()
	
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() then
		addTurnData("expval", math.min(damage.damage,8))
		if damage.card then
			if damage.card:isKindOf("TrickCard") then addTurnData("wen",1) end
			if damage.card:isKindOf("Slash")	 then addTurnData("wu",1) end
		end	
		gainSkill(room)
	end
	setGameData("enable",0)
	sqlexec("update results set general='%s',turncount=%d,alive=%d,result='%s',wen=wen+%d,wu=wu+%d,expval=expval+%d where id=%d",
			owner:getGeneralName(),getGameData("turncount"),alive,result,getTurnData("wen"),
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
end

for zgname, count in pairs({ccml=1,csss=5,xsnd=10,xymq=20,fmbl=30}) do
	zgfunc[sgs.GameOverJudge].callback.zgname=function(room,player,data,name,result)
		local sql=string.format("select count(id) as num from results where result<>'-'")	
		for row in db:rows(sql) do
			if row.num==count then 			 
				addZhanGong(room,zgname)
			end
		end
	end
end


-- hsqj :: 横扫千军 :: 在1局游戏中，手刃7名角色并且获得胜利
-- 
zgfunc[sgs.Death].hsqj=function(self, room, event, player, data,isowner,name)
	local damage = data:toDamageStar()
	if damage.from and damage.from:objectName()==room:getOwner():objectName() then
		addGameData(name,1)
	end		
end


-- hsqj :: 横扫千军 :: 在1局游戏中，手刃7名角色并且获得胜利
-- 
zgfunc[sgs.GameOverJudge].callback.hsqj=function(room,player,data,name,result)
	local damage = data:toDamageStar()
	if damage.from and damage.from:objectName()==room:getOwner():objectName() then
		addGameData(name,1)
	end	
	if result =='win' and getGameData(name)==7 then addZhanGong(room,name) end	
end


-- lmss :: 老谋深算 :: 身为内奸在1局游戏中手刃至少4个反贼或忠臣并且取得胜利
-- 
zgfunc[sgs.Death].lmss=function(self, room, event, player, data,isowner,name)
	local damage = data:toDamageStar()
	if damage.from and damage.from:objectName()==room:getOwner():objectName() 
		and damage.from:getRole()=="renegade" and (player:getRole()=="rebel" or player:getRole()=="loyalist") then
		addGameData(name,1)
	end		
end


-- lmss :: 老谋深算 :: 身为内奸在1局游戏中手刃至少4个反贼或忠臣并且取得胜利
-- 
zgfunc[sgs.GameOverJudge].callback.lmss=function(room,player,data,name,result)
	local damage = data:toDamageStar()
	if damage.from and damage.from:objectName()==room:getOwner():objectName() then
		addGameData(name,1)
	end	
	if result =='win' and getGameData(name)>=4 then addZhanGong(room,name) end
end



-- jzjz :: 竭智尽忠 :: 身为忠臣在1局游戏中，在自己的首回合中手刃一个反贼或内奸，最后取得胜利
-- 
zgfunc[sgs.Death].jzjz=function(self, room, event, player, data,isowner,name)
	local damage = data:toDamageStar()
	if damage.from and damage.from:objectName()==room:getOwner():objectName()
		and damage.from:getRole()=="loyalist" and (player:getRole()=="rebel" or player:getRole()=="renegade") 
		and getGameData("turncount")==1 and damage.from:objectName()==room:getCurrent():objectName() then
			setGameData(name,1)
	end		
end


-- jzjz :: 竭智尽忠 :: 身为忠臣在1局游戏中，在自己的首回合中手刃一个反贼或内奸，最后取得胜利
-- 
zgfunc[sgs.GameOverJudge].callback.jzjz=function(room,player,data,name,result)
	if result =='win' and getGameData(name)==1 then addZhanGong(room,name) end
end



-- cxer :: 趁虚而入 :: 身为反贼在1局游戏中，在自己的第1回合时手刃主公
-- 
zgfunc[sgs.GameOverJudge].callback.cxer=function(room,player,data,name,result)
	local damage = data:toDamageStar()
	if result=='win' and damage.from and damage.from:objectName()==room:getOwner():objectName()
		and damage.from:getRole()=="rebel" and player:getRole()=="lord"
		and getGameData("turncount")==1 and damage.from:objectName()==room:getCurrent():objectName() then
			addZhanGong(room,name)
	end		
end


-- ljjh :: 老奸巨猾 :: 身为内奸在1局游戏中，在主公杀死过忠臣的情况下取得胜利
-- 
zgfunc[sgs.Death].ljjh=function(self, room, event, player, data,isowner,name)
	local damage = data:toDamageStar()
	if damage.from and damage.from:isLord() and player:getRole()=="loyalist" then
		setGameData(name,1)
	end		
end


-- ljjh :: 老奸巨猾 :: 身为内奸在1局游戏中，在主公杀死过忠臣的情况下取得胜利
-- 
zgfunc[sgs.GameOverJudge].callback.ljjh=function(room,player,data,name,result)
	if result =='win' and getGameData(name)==1 and room:getOwner():getRole()=="renegade" then 
		addZhanGong(room,name) 
	end
end




-- jcfs :: 绝处逢生 :: 身为反贼在1局游戏中，在其他反贼全部死亡且忠臣全部存活的情况下获胜
-- 
zgfunc[sgs.Death].jcfs=function(self, room, event, player, data,isowner,name)
	local damage = data:toDamageStar()
	if room:getOwner():getRole()=="rebel" then
		local others = room:getOtherPlayers(room:getOwner())
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
		if loyalist_dead==0 and loyalist_alive>0 and rebel_dead>0 and rebel_alive==0 then
			setGameData(name,1)
		end
	end		
end


-- jcfs :: 绝处逢生 :: 身为反贼在1局游戏中，在其他反贼全部死亡且忠臣全部存活的情况下获胜
-- 
zgfunc[sgs.GameOverJudge].callback.jcfs=function(room,player,data,name,result)
	if result =='win' and getGameData(name)==1 then addZhanGong(room,name) end
end



-- tdwy :: 天道威仪 :: 身为主公在1局游戏中，在忠臣全部死亡后杀死至少3名角色，取得胜利
-- 
zgfunc[sgs.Death].tdwy=function(self, room, event, player, data,isowner,name)
	local damage = data:toDamageStar()
	if room:getOwner():isLord() and damage.from and damage.from:objectName()==room:getOwner():objectName() 
		and (damage.to:getRole()=="rebel" or damage.to:getRole()=="renegade") then
		local others = room:getOtherPlayers(room:getOwner())
		local loyalist_alive,loyalist_dead=0,0
		for _, p in sgs.qlist(others) do
			if p:getRole()=="loyalist" then
				if p:isAlive() then loyalist_alive=loyalist_alive+1 else loyalist_dead=loyalist_dead+1 end
			end
		end
		if loyalist_dead>0 and loyalist_alive==0 then addtGameData(name,1) end
	end		
end


-- tdwy :: 天道威仪 :: 身为主公在1局游戏中，在忠臣全部死亡后杀死至少3名角色，取得胜利
-- 
zgfunc[sgs.GameOverJudge].callback.tdwy=function(room,player,data,name,result)
	if result =='win' and getGameData(name)>=3 then addZhanGong(room,name) end
end




-- zgyd :: 忠肝义胆 :: 身为忠臣在1局游戏中存活，并且主公满体力的情况下取得胜利
-- 
zgfunc[sgs.GameOverJudge].callback.zgyd=function(room,player,data,name,result)	
	local owner=room:getOwner()
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

-- 所有武将的 获得N场胜利 取得相应战功的代码  
--
for data in db:rows("select id,category,general,num from zhangong where num>0 ") do
	zgfunc[sgs.GameOverJudge].callback[data.id]=function(room,player,data,name,result)			
		local mode=room:getMode()
		local kingdoms={["wu"]=1,["shu"]=1,["wei"]=1,["qun"]=1,["god"]=1}
		if result ~='win' then return false end
		if data.category=="3v3" and room:getMode()~="06_3v3" then return false end
		if data.category=="1v1" and room:getMode()~="02_1v1" then return false end
		if kingdoms[data.category] and
				(mode=="06_3v3" or mode=="02_1v1" or mode=="04_1v3" or getGameData("hegemony")==1) then
			return false
		end
		local flag=false		
		local role=player:getRole()
		local sql="select count(id) as num from results where result='win' "

		if data.general=="-" then
			sql=sql..string.format("and 1 ")
		elseif data.general==player:getGeneralName() then
			sql=sql..string.format("and general='%s' ",data.general)
		elseif data.general==player:getRole() then
			sql=sql..string.format("and role='%s' ",data.general)
		elseif data.general==player:getKingdom() then
			sql=sql..string.format("and kingdom='%s' ",data.general)
		elseif data.general=="leader" and (role=="lord" or role =="renegade") and mode=="06_3v3" then
			sql=sql..string.format("and mode='06_3v3' and (role=='lord' or role =='renegade') ")
		elseif data.general=="guard" and (role=="loyalist" or role =="rebel") and mode=="06_3v3" then
			sql=sql..string.format("and mode='06_3v3' and (role=='loyalist' or role =='rebel') ")
		else
			return false
		end

		if data.category=="3v3" then sql=sql.."and mode=='06_3v3' " end
		if data.category=="1v1" then sql=sql.."and mode=='02_1v1' " end
		if kingdoms[data.category] then 
			sql=sql.." and hegemony=0 and mode not in ('06_3v3','02_1v1','04_1v3') "
		end
		
		for row in db:rows(sql) do
			if row.num==data.num then addZhanGong(room,name) end
		end
	end
end


-- init ::  :: 更新results, 将所有的 turndata重置为0
-- 
zgfunc[sgs.TurnStart].init=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	addGameData("turncount",1)
	local alive=room:getOwner():isAlive() and 1 or 0
	sqlexec("update results set general='%s',kingdom='%s',turncount=%d,alive=%d,wen=wen+%d,wu=wu+%d,expval=expval+%d where id=%d",
			room:getOwner():getGeneralName(),room:getOwner():getKingdom(),getGameData("turncount"), alive,getTurnData("wen"),
			getTurnData("wu"),getTurnData("expval"),getGameData("roomid"))
	for key,val in pairs(zgturndata) do
		zgturndata[key]=0
	end	
end



-- dqbr :: 刀枪不入 :: 一局游戏中发动仁王盾特效3次
-- 
zgfunc[sgs.SlashEffected].dqbr=function(self, room, event, player, data,isowner,name)
	local effect= data:toSlashEffect()
	local armor= (effect.to:getArmor() and effect.to:getArmor():isKindOf("RenwangShield")) 
			or ((not effect.to:getArmor()) and effect.to:hasSkill("yizhong"))
	if effect.to:getMark("qinggang") then armor=false end
	if armor and effect.to:objectName()==room:getOwner():objectName() and effect.slash:isBlack() then
		addGameData(name,1)
		if getGameData(name)>=3 then 			 
			addZhanGong(room,name)
			setGameData(name,-100)
		end
	end
end


-- qkds :: 旗开得胜 :: 一局游戏中，在自己的首回合结束前获胜 
-- 
zgfunc[sgs.todo].qkds=function(self, room, event, player, data,isowner,name)
	
end


-- gycc :: 苟延残喘 :: 在1局游戏中被救活至少5次 
-- 
zgfunc[sgs.todo].gycc=function(self, room, event, player, data,isowner,name)

end


-- ph :: 炮灰 :: 被南蛮入侵或万箭齐发打死累计10次 
-- 
zgfunc[sgs.todo].ph=function(self, room, event, player, data,isowner,name)
	
end


-- gddph :: 更大的炮灰 :: 被南蛮入侵或万箭齐发打死累计50次 
-- 
zgfunc[sgs.todo].gddph=function(self, room, event, player, data,isowner,name)
	
end


-- yqt :: 一骑讨 :: 与人决斗胜利累计30次 
-- 
zgfunc[sgs.todo].yqt=function(self, room, event, player, data,isowner,name)
	
end


-- tw :: 桃王 :: 在1局游戏中给自己吃过5个或者更多得桃（不包括华佗的技能） 
-- 
zgfunc[sgs.todo].tw=function(self, room, event, player, data,isowner,name)
	
end


-- tx :: 桃仙 :: 在1局游戏中，使用桃救人至少5次（不包括华佗的技能） 
-- 
zgfunc[sgs.todo].tx=function(self, room, event, player, data,isowner,name)
	
end


-- bmjs :: 八门金锁 :: 在1局游戏中，装备八卦阵连续判定红色花色至少5次 
-- 
zgfunc[sgs.todo].bmjs=function(self, room, event, player, data,isowner,name)
	
end


-- yzzf :: 异族之愤 :: 使用1次南蛮入侵打死至少3名角色 
-- 
zgfunc[sgs.todo].yzzf=function(self, room, event, player, data,isowner,name)
	
end


-- jwxf :: 箭无虚发 :: 使用1次万箭齐发打死至少3名角色 
-- 
zgfunc[sgs.todo].jwxf=function(self, room, event, player, data,isowner,name)
	
end


-- zszm :: 至圣至明 :: 身为主公在一局游戏中手刃所有反贼和内奸，并在忠臣全部存活的情况下获胜 
-- 
zgfunc[sgs.todo].zszm=function(self, room, event, player, data,isowner,name)
	
end


-- bszj :: 搬石砸脚 :: 与人决斗失败累计10次 
-- 
zgfunc[sgs.todo].bszj=function(self, room, event, player, data,isowner,name)
	
end


-- tjb :: 藤甲兵 :: 一局游戏中发动藤甲效果抵挡杀、南蛮入侵或万箭齐发至少3次 
-- 
zgfunc[sgs.todo].tjb=function(self, room, event, player, data,isowner,name)
	
end


-- dshx :: 大事化小 :: 一局游戏中发动白银狮子特效减少伤害至少1次 
-- 
zgfunc[sgs.todo].dshx=function(self, room, event, player, data,isowner,name)
	
end


-- swsm :: 塞翁失马 :: 一局游戏中，失去白银狮子回复体力至少2次 
-- 
zgfunc[sgs.todo].swsm=function(self, room, event, player, data,isowner,name)
	
end


-- rhss :: 惹火上身 :: 一局游戏中，装备藤甲的时受到至少3次火焰伤害 
-- 
zgfunc[sgs.todo].rhss=function(self, room, event, player, data,isowner,name)
	
end


-- hyjy :: 何以解忧 :: 一局游戏中，使用酒回复体力至少2次 
-- 
zgfunc[sgs.todo].hyjy=function(self, room, event, player, data,isowner,name)
	
end


-- wydk :: 唯有杜康 :: 一局游戏中，使用酒后成功使用杀造成伤害至少3次 
-- 
zgfunc[sgs.todo].wydk=function(self, room, event, player, data,isowner,name)
	
end


-- gqbb :: 攻其不备 :: 一局游戏中，成功使用火攻造成伤害至少3次 
-- 
zgfunc[sgs.todo].gqbb=function(self, room, event, player, data,isowner,name)
	
end


-- bkclm :: 被看穿了吗 :: 一局游戏中，使用火攻失败至少3次 
-- 
zgfunc[sgs.todo].bkclm=function(self, room, event, player, data,isowner,name)
	
end


-- dtj :: 打铁匠 :: 累计将铁索连环重铸30次 
-- 
zgfunc[sgs.todo].dtj=function(self, room, event, player, data,isowner,name)
	
end


-- yntd :: 有难同当 :: 1局游戏中，使用铁索连环累计横置其他角色至少6次 
-- 
zgfunc[sgs.todo].yntd=function(self, room, event, player, data,isowner,name)
	
end


-- fj :: 飞将 :: 使用吕布在1局游戏中发动方天画戟特效杀死至少2名角色 
-- 
zgfunc[sgs.todo].fj=function(self, room, event, player, data,isowner,name)
	
end


-- qgqc :: 倾国倾城 :: 使用貂蝉在1局游戏中发动离间造成至少3名角色死亡 
-- 
zgfunc[sgs.todo].qgqc=function(self, room, event, player, data,isowner,name)
	
end


-- lsmy :: 乱世名医 :: 使用华佗在1局游戏中发动急救使至少3个不同的角色脱离濒死状态 
-- 
zgfunc[sgs.todo].lsmy=function(self, room, event, player, data,isowner,name)
	
end


-- lsdjx :: 乱世的奸雄 :: 使用曹操在1局游戏中发动奸雄得到至少3张南蛮入侵和1张万箭齐发 
-- 
zgfunc[sgs.todo].lsdjx=function(self, room, event, player, data,isowner,name)
	
end


-- yqwb :: 掩其无备 :: 使用张辽在1局游戏中发动至少10次突袭 
-- 
zgfunc[sgs.todo].yqwb=function(self, room, event, player, data,isowner,name)
	
end


-- nswh :: 你死我活 :: 使用夏侯惇在1局游戏中发动刚烈杀死至少1名角色 
-- 
zgfunc[sgs.todo].nswh=function(self, room, event, player, data,isowner,name)
	
end


-- mwl :: 妈，我冷 :: 使用许褚在1局游戏中发动裸衣至少2次并在裸衣的回合中杀死过至少2名角色 
-- 
zgfunc[sgs.todo].mwl=function(self, room, event, player, data,isowner,name)
	
end


-- byyl :: 不遗余力 :: 使用郭嘉在1局游戏中发动遗计发牌至少5次 
-- 
zgfunc[sgs.todo].byyl=function(self, room, event, player, data,isowner,name)
	
end


-- sytt :: 手眼通天 :: 使用司马懿在1局游戏中有至少2次发动反馈都抽到对方1张桃 
-- 
zgfunc[sgs.todo].sytt=function(self, room, event, player, data,isowner,name)
	
end


-- lsf :: 洛神赋 :: 使用甄姬一回合内发动洛神在不被改变判定牌的情况下连续判定黑色花色至少8次 
-- 
zgfunc[sgs.todo].lsf=function(self, room, event, player, data,isowner,name)
	
end


-- jjzx :: 纠结之心 :: 使用刘备在1局游戏中发动雌雄双股剑特效杀死至少1名女性角色 
-- 
zgfunc[sgs.todo].jjzx=function(self, room, event, player, data,isowner,name)
	
end


-- yrdpx :: 燕人的咆哮 :: 使用张飞在1局游戏中发动丈八蛇矛特效杀死至少1名角色 
-- 
zgfunc[sgs.todo].yrdpx=function(self, room, event, player, data,isowner,name)
	
end


-- qjtj :: 全军突击 :: 使用马超在1局游戏中发动铁骑连续判定红色花色至少5次 
-- 
zgfunc[sgs.todo].qjtj=function(self, room, event, player, data,isowner,name)
	
end


-- wsxl :: 武圣显灵 :: 使用关羽在1局游戏中发动青龙偃月刀特效杀死至少1名角色 
-- 
zgfunc[sgs.todo].wsxl=function(self, room, event, player, data,isowner,name)
	
end


-- hssd :: 浑身是胆 :: 使用赵云在1局游戏中发动青钢剑特效杀死至少1名角色 
-- 
zgfunc[sgs.todo].hssd=function(self, room, event, player, data,isowner,name)
	
end


-- jnd :: 锦囊袋 :: 使用黄月英在1个回合内发动至少10次集智 
-- 
zgfunc[sgs.todo].jnd=function(self, room, event, player, data,isowner,name)
	
end


-- kcjc :: 空城绝唱 :: 使用诸葛亮在1局游戏中有至少5个回合结束时是空城状态 
-- 
zgfunc[sgs.todo].kcjc=function(self, room, event, player, data,isowner,name)
	
end


-- lbsd :: 老不死的 :: 使用孙权在1局游戏中被吴国武将用桃救至少3次 
-- 
zgfunc[sgs.todo].lbsd=function(self, room, event, player, data,isowner,name)
	
end


-- scgm :: 神出鬼没 :: 使用甘宁在1个回合内发动至少6次奇袭 
-- 
zgfunc[sgs.todo].scgm=function(self, room, event, player, data,isowner,name)
	
end


-- wjdbt :: 无尽的鞭挞 :: 使用黄盖1个回合内发动至少8次苦肉 
-- 
zgfunc[sgs.todo].wjdbt=function(self, room, event, player, data,isowner,name)
	
end


-- sjdf :: 伺机待发 :: 使用吕蒙将手牌囤积到20张 
-- 
zgfunc[sgs.todo].sjdf=function(self, room, event, player, data,isowner,name)
	
end


-- yhjm :: 移花接木 :: 使用大乔在一局游戏中连续发动流离至少5次 
-- 
zgfunc[sgs.todo].yhjm=function(self, room, event, player, data,isowner,name)
	
end


-- yhdf :: 因祸得福 :: 使用孙尚香在1局游戏中累计失去至少5张已装备的装备牌 
-- 
zgfunc[sgs.todo].yhdf=function(self, room, event, player, data,isowner,name)
	
end


-- wjdzz :: 无尽的挣扎 :: 使用周瑜在1局游戏中使用反间杀死至少3名角色 
-- 
zgfunc[sgs.todo].wjdzz=function(self, room, event, player, data,isowner,name)
	
end


-- lmbj :: 连绵不绝 :: 使用陆逊在1个回合内发动至少10次连营 
-- 
zgfunc[sgs.todo].lmbj=function(self, room, event, player, data,isowner,name)
	
end


-- fcdc :: 风驰电掣 :: 使用夏侯渊在1局游戏中，有连续至少3个回合每个回合都发动2次神速 
-- 
zgfunc[sgs.todo].fcdc=function(self, room, event, player, data,isowner,name)
	
end


-- ljdnx :: 老将的逆袭 :: 使用黄忠在1局游戏中，剩余1点体力时累计发动烈弓杀死至少3名角色 
-- 
zgfunc[sgs.todo].ljdnx=function(self, room, event, player, data,isowner,name)
	
end


-- jqbd :: 金枪不倒 :: 使用周泰在1局游戏中拥有过至少9张不屈牌并且未死 
-- 
zgfunc[sgs.todo].jqbd=function(self, room, event, player, data,isowner,name)
	
end


-- sxcx :: 嗜血成性 :: 使用魏延在1回合内发动狂骨回复至少3点体力 
-- 
zgfunc[sgs.todo].sxcx=function(self, room, event, player, data,isowner,name)
	
end


-- grjt :: 固若金汤 :: 使用曹仁在一局游戏中发动至少3次据守，并且在损失体力不多于3点的情况下获胜。 
-- 
zgfunc[sgs.todo].grjt=function(self, room, event, player, data,isowner,name)
	
end


-- lxxy :: 怜香惜玉 :: 使用小乔在一局游戏中发动天香让某名男性武将摸牌至少15张 
-- 
zgfunc[sgs.todo].lxxy=function(self, room, event, player, data,isowner,name)
	
end


-- kbdwn :: 狂奔的蜗牛 :: 使用张角在1局游戏发动雷击杀死至少3名角色 
-- 
zgfunc[sgs.todo].kbdwn=function(self, room, event, player, data,isowner,name)
	
end


-- sgmc :: 神鬼莫测 :: 使用于吉在1局游戏中累计蛊惑假牌至少成功3次 
-- 
zgfunc[sgs.todo].sgmc=function(self, room, event, player, data,isowner,name)
	
end


-- sssg :: 四世三公 :: 使用袁术在1回合内消灭场上4个势力中的3个 
-- 
zgfunc[sgs.todo].sssg=function(self, room, event, player, data,isowner,name)
	
end


-- bmyc :: 白马义从 :: 使用公孙瓒在体力大于2的情况下杀死至少3名角色，并且在体力1的情况下存活并获胜。 
-- 
zgfunc[sgs.todo].bmyc=function(self, room, event, player, data,isowner,name)
	
end


-- yfdg :: 一夫当关 :: 使用典韦在1局游戏中发动至少5次强袭，并用强袭至少杀死3名角色。 
-- 
zgfunc[sgs.todo].yfdg=function(self, room, event, player, data,isowner,name)
	
end


-- qhtl :: 驱虎吞狼 :: 使用荀彧在1局游戏中至少对3名不同角色发动驱虎，并且这些角色都死于驱虎造成的伤害 
-- 
zgfunc[sgs.todo].qhtl=function(self, room, event, player, data,isowner,name)
	
end


-- tslz :: 铁锁连舟 :: 使用庞统在1回合内发动连环横置至少6名角色 
-- 
zgfunc[sgs.todo].tslz=function(self, room, event, player, data,isowner,name)
	
end


-- thly :: 天火燎原 :: 使用卧龙诸葛亮在1回合内发动火计造成至少6点伤害 
-- 
zgfunc[sgs.todo].thly=function(self, room, event, player, data,isowner,name)
	
end


-- jdzh :: 江东之虎 :: 使用太史慈在1回合内发动天义拼点胜利后，使用【杀】杀死至少3名角色 
-- 
zgfunc[sgs.todo].jdzh=function(self, room, event, player, data,isowner,name)
	
end


-- ljsd :: 乱箭肃敌 :: 使用袁绍在1回合内发动乱击至少6次 
-- 
zgfunc[sgs.todo].ljsd=function(self, room, event, player, data,isowner,name)
	
end


-- qldj :: 其利断金 :: 使用颜良文丑在1局游戏中发动双雄至少3次并在双雄的回合中杀死过至少3名角色 
-- 
zgfunc[sgs.todo].qldj=function(self, room, event, player, data,isowner,name)
	
end


-- zkzj :: 周苛之节 :: 使用庞德在1局游戏中发动猛进至少5次 
-- 
zgfunc[sgs.todo].zkzj=function(self, room, event, player, data,isowner,name)
	
end


-- bsyz :: 背水一战 :: 身为主帅，在本方两名前锋阵亡的情况下，杀死对方3人后获胜 (3v3)
-- 
zgfunc[sgs.todo].bsyz=function(self, room, event, player, data,isowner,name)
	
end


-- ygzq :: 一鼓作气 :: 一回合内杀死对方3名角色 (3v3)
-- 
zgfunc[sgs.todo].ygzq=function(self, room, event, player, data,isowner,name)
	
end


-- swjd :: 肆无忌惮 :: 一回合内使用至少3张南蛮入侵或万箭齐发 (3v3)
-- 
zgfunc[sgs.todo].swjd=function(self, room, event, player, data,isowner,name)
	
end


-- bfh :: 暴发户 :: 一回合内获得至少10张手牌 (3v3)
-- 
zgfunc[sgs.todo].bfh=function(self, room, event, player, data,isowner,name)
	
end


-- ssqy :: 舍生取义 :: 身为前锋，被本方角色杀死累计10次 (3v3)
-- 
zgfunc[sgs.todo].ssqy=function(self, room, event, player, data,isowner,name)
	
end


-- zdhl :: 直捣黄龙 :: 在对方两名前锋都没有受伤的情况下杀死对方主帅 (3v3)
-- 
zgfunc[sgs.todo].zdhl=function(self, room, event, player, data,isowner,name)
	
end


-- szsj :: 速战速决 :: 在自己的首回合结束前获得胜利 (3v3)
-- 
zgfunc[sgs.todo].szsj=function(self, room, event, player, data,isowner,name)
	
end


-- cjz :: 持久战 :: 在自己的第5回合结束后获得胜利 (3v3)
-- 
zgfunc[sgs.todo].cjz=function(self, room, event, player, data,isowner,name)
	
end


-- mlgr :: 谋略过人 :: 选择了3名3血武将并且获胜 (1v1)
-- 
zgfunc[sgs.todo].mlgr=function(self, room, event, player, data,isowner,name)
	
end


-- ymgr :: 勇猛过人 :: 选择了3名4血武将并且获胜 (1v1)
-- 
zgfunc[sgs.todo].ymgr=function(self, room, event, player, data,isowner,name)
	
end


-- bbxr :: 兵不血刃 :: 对方3名武将都在他们各自的回合阵亡 (1v1)
-- 
zgfunc[sgs.todo].bbxr=function(self, room, event, player, data,isowner,name)
	
end


-- jgyx :: 巾帼英雄 :: 选择3名女性武将并且获胜 (1v1)
-- 
zgfunc[sgs.todo].jgyx=function(self, room, event, player, data,isowner,name)
	
end


-- hgjs :: 护国军师 :: 以诸葛亮、司马懿、周瑜为上场武将的情况下获胜 (1v1)
-- 
zgfunc[sgs.todo].hgjs=function(self, room, event, player, data,isowner,name)
	
end


-- hfws :: 毫发无伤 :: 在本方所有武将满体力的情况下胜利 (1v1)
-- 
zgfunc[sgs.todo].hfws=function(self, room, event, player, data,isowner,name)
	
end


-- jtnz :: 惊天逆转 :: 在本方剩余1名武将时，杀死对方3名武将获胜 (1v1)
-- 
zgfunc[sgs.todo].jtnz=function(self, room, event, player, data,isowner,name)
	
end


-- yywm :: 有勇无谋 :: 以吕布、张飞、许褚为上场武将的情况下获胜 (1v1)
-- 
zgfunc[sgs.todo].yywm=function(self, room, event, player, data,isowner,name)
	
end


-- zysq :: 智勇双全 :: 以关羽、赵云、黄忠为上场武将的情况下获胜 (1v1)
-- 
zgfunc[sgs.todo].zysq=function(self, room, event, player, data,isowner,name)
	
end



function gainSkill(room)
	local skilldata=db:rows("select skillname from skills where 1 order by random() limit 10")
	local skillname 
	for row in skilldata do
		if sgs.Sanguosha:getSkill(row.skillname) then 
			skillname=row.skillname
			break
		end
	end
	if not skillname then return broadcastMsg(room,"#canntGainSkill") end
	sqlexec("update skills set gained=gained+1 where skillname='%s'",skillname)
	broadcastMsg(room,"#gainSkill",skillname)
end


function broadcastMsg(room,info,...)
	local log= sgs.LogMessage()
	log.type = info
	log.from = room:getOwner()
	if #arg>0 then log.arg = arg[1] end
	if #arg>1 then log.arg2 =arg[2] end
	room:sendLog(log)
	return true
end

function addZhanGong(room,name)
	sqlexec("update zhangong set gained=gained+1,lasttime=datetime('now','localtime') where id='%s'",name)
	broadcastMsg(room,"#zhangong_"..name)
end

function addGameData(key,val)
	if not zggamedata[key] then zggamedata[key]=0 end
	zggamedata[key]=zggamedata[key]+val
end

function setGameData(key,val)	
	zggamedata[key]=val
end

function getGameData(key,...)
	if not zggamedata[key] then return #arg>=1 and arg[1] or 0 end
	return zggamedata[key]
end

function addTurnData(key,val)
	if not zgturndata[key] then zgturndata[key]=0 end
	zgturndata[key]=zgturndata[key]+val
end

function setTurnData(key,val)
	zgturndata[key]=val
end

function getTurnData(key,...)
	if not zgturndata[key] then return #arg>=1 and arg[1] or 0 end
	return zgturndata[key]
end

function init_gamestart(self, room, event, player, data, isowner)
	local config=sgs.Sanguosha:getSetupString():split(":")
	local mode=config[2]
	local flags=config[5]
	local owner=room:getOwner()

	if not isowner then return false end

	--[[
	if not string.find(mode,"^[01]%d[p_]") or string.find(flags,"[FHB]") then		
		setGameData("enable",0)
		return false
	end
	]]

	local count=0
	for _, p in sgs.qlist(room:getAllPlayers()) do
		if p:getState() ~= "robot" then count=count+1 end
	end
	if count>1 then
		setGameData("enable",0)
		return false
	end

	for key,val in pairs(zggamedata) do
		zggamedata[key]=0
	end

	setGameData("enable",1)
	if string.find(flags,"H") then setGameData("hegemony",1) end

	if getGameData("roomid")==0 then 
		setGameData("roomid",os.time())
		setTurnData("wen",0)
		setTurnData("wu",0)
		setTurnData("expval",0)
		sqlexec("insert into results values(%d,'%s','%s','%s','%d','%s',0,1,'-',0,0,0)",
				getGameData("roomid"),player:getGeneralName(),player:getRole(),
				player:getKingdom(),getGameData("hegemony"),room:getMode())
		sqlexec("update gamedata set num=0")
	end	
	local skilldata=db:rows("select skillname from skills where gained-used>0 order by random() limit 10")
	local skills={}
	for row in skilldata do
		if sgs.Sanguosha:getSkill(row.skillname) then table.insert(skills,row.skillname) end
	end
	if #skills then
		local choice=room:askForChoice(owner,"@choose_skill","cancel+"..table.concat(skills,"+"))
		if choice ~= "cancel" then
			room:acquireSkill(owner,choice)
			sqlexec("update skills set  used=used+1 where skillname='%s'",choice)
		end
	end
	return true
end



zgzhangong = sgs.CreateTriggerSkill{
	name = "#zgzhangong",
	events = {sgs.GameStart,sgs.TurnStart,sgs.CardFinished,sgs.Damage,sgs.GameOverJudge,
			sgs.Death,sgs.EventPhaseEnd,sgs.FinishRetrial,sgs.ChoiceMade,sgs.SlashEffected,
			sgs.DamageCaused},
	priority = 6,
	can_trigger = function()
		return true
	end,

	on_trigger = function(self, event, player, data)
		local room = player:getRoom()
		local owner= room:getOwner():objectName()==player:objectName()
		if event ==sgs.GameStart then
			if init_gamestart(self, room, event, player, data, owner) then
				local log= sgs.LogMessage()
				log.type = "#enable"					
				room:sendLog(log)
			end
		else
			local callbacks=zgfunc[event]
			if callbacks and getGameData("enable")==1 then
				for name, func in pairs(callbacks) do
					if type(func)=="function" then 						
						func(self, room, event, player, data, owner,name) 
					end				
				end
			end			
		end
		return false
	end,
}


function getWinner(room,victim)
	local mode=room:getMode()
	local role=victim:getRole()

	if mode == "02_1v1" then
		local list = victim:getTag("1v1Arrange"):toStringList()		
		if #list >0  then return false end
	end

	local alives=sgs.QList2Table(room:getAlivePlayers())
	
	--[[
	if getGameData("hegemony")==1 then		
        local has_anjiang = false
		local has_diff_kingdoms = false
        local init_kingdom
		for _, p in sgs.qlist(room:getAlivePlayers()) do
			if room:getTag(p:objectName()):toString() then 
				has_anjiang = true
            end
            if init_kingdom == nil then 
                init_kingdom = p:getKingdom()
            else if init_kingdom ~= p:getKingdom() then
                has_diff_kingdoms = true
            end
		end
        if not has_anjiang and  not has_diff_kingdoms then
            local winners={}
			local aliveKingdom = room:getAlivePlayers():at(1):getKingdom()

            for _, p in sgs.qlist(room:getAllPlayers()) do
                if p:isAlive() then table.insert(winners , p:objectName()) end
                if p:getKingdom() == aliveKingdom then
                    local generals = room:getTag(p:objectName()):toString()
                    if (not (generals and not string.find(flags,"S"))) or (not string.find(generals,",")) then
						table.insert(winners , p:objectName())
					end
                end
            end
            return #winners and table.concat(winners,"+") or false
        end	
	end
	]]
	
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
		if pack=="NostalGeneral" then table.insert(packages,"nostal_general") end
		table.insert(packages,string.lower(pack))
	end
	local hidden={"sp_diaochan","sp_sunshangxiang","sp_pangde","sp_caiwenji","sp_machao","sp_jiaxu"}	
	table.insertTable(generalnames,hidden)
	for _, generalname in ipairs(generalnames) do
		local general = sgs.Sanguosha:getGeneral(generalname)
		if general then
			local packname = string.lower(general:getPackage())		
			if table.contains(packages,packname) then
				general:addSkill("#zgzhangong")
			end
		end
	end
end


zganjiang:addSkill(zgzhangong)
initZhangong()


function genTranslation()
	local zgTrList={}	
	for row in db:rows("select id,name,description from zhangong") do
		zgTrList["#zhangong_"..row.id]="%from获得了战功【<font color='yellow'>"..row.name.."</font>】,"..row.description		
	end
	return zgTrList
end


sgs.LoadTranslationTable(genTranslation())

sgs.LoadTranslationTable {
	["zhangong"] ="战功包",
	["#gainWen"] ="%from获得【%arg】点文功",
	["#gainWu"] ="%from获得【%arg】点武功",
	["#gainExp"] ="%from获得【%arg】点经验",
	["#canntGainSkill"]= "【警告】技能列表为空，无法获得技能",
	["#gainSkill"]="%from获得了技能卡【%arg】",
}

