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

require "sqlite3"
db = sqlite3.open("zhangong.db3")

function logmsg(fmt,...)
	local fp = io.open("zhangong.log","ab")
	if type(fmt)=="boolean" then fmt = fmt and "true" or "false" end
	fp:write(string.format(fmt, unpack(arg)).."\r\n")
	fp:close()
end

function sqlexec(sql,...)
	local sqlstr=string.format(sql, unpack(arg))
	db:exec(sqlstr)
	logmsg(sqlstr.."\r\n")	
end

zgfunc[sgs.ChoiceMade].srxsm=function(self, room, event, player, data,isOwner)
	if not isOwner then return false end
	local choices= data:toString():split(":")
	if choices[1]=="skillInvoke" and and choices[2]=="KylinBow" and choices[3]=="yes" then
		local name="srxsm"
		addGameData(name,1)
		if getGameData(name)>=3 then
			addZhanGong(room,name)
			setGameData(name,-100)
		end
	end	
end


zgfunc[sgs.ChoiceMade].zqxj=function(self, room, event, player, data,isOwner)
	if not isOwner then return false end
	local choices= data:toString():split(":")
	if choices[1]=="skillInvoke" and and choices[2]=="Fan" and choices[3]=="yes" then
		local name="zqxj"
		addGameData(name,1)
		if getGameData(name)>=3 then
			addZhanGong(room,name)
			setGameData(name,-100)
		end
	end	
end

zgfunc[sgs.ChoiceMade].srpz=function(self, room, event, player, data,isOwner)
	if not isOwner then return false end
	local choices= data:toString():split(":")
	if choices[1]=="cardResponsed" and choices[2]=="@Axe" then
		local name="srpz"
		addGameData(name,1)
		if getGameData(name)>=3 then
			addZhanGong(room,name)
			setGameData(name,-100)
		end
	end	
end

zgfunc[sgs.CardFinished].shd=function(self, room, event, player, data,isOwner)
	if not isOwner then return false end
	if player:objectName()~=room:getCurrent():objectName() then return false end
	local use=data:toCardUse()
	local card=use.card
	if player:getWeapon() and player:getWeapon():isKindOf("Crossbow") and card:isKindOf("Slash") then 
		local name="shd"
		addTurnData(name,1) 
		if getTurnData(name)>=4 then
			addZhanGong(room,name)
			setTurnData(name,-100)
		end
	end	
end

zgfunc[sgs.ChoiceMade].jdld=function(self, room, event, player, data,isOwner)
	if not isOwner then return false end
	local choices= data:toString():split(":")
	if choices[1]=="skillInvoke" and and choices[2]=="IceSword" and choices[3]=="yes" then
		local name="jdld"
		addGameData(name,1)
		if getGameData(name)>=3 then
			addZhanGong(room,name)
			setGameData(name,-100)
		end
	end	
end

zgfunc[sgs.CardFinished].wenwu=function(self, room, event, player, data,isOwner)
	if not isOwner then return false end
	local use=data:toCardUse()
	local card=use.card
	if card:isKindOf("TrickCard") then addTurnData("wen",1) end
	if card:isKindOf("Slash")	  then addTurnData("wu",1) end	
end

zgfunc[sgs.CardFinished].hydt=function(self, room, event, player, data,isOwner)
	if not isOwner then return false end
	local use=data:toCardUse()
	local card=use.card
	local name="hydt"
	if card:isKindOf("ExNihilo") then 
		addTurnData(name,1)
		if getTurnData(name)>=3 then			 
			addZhanGong(room,name)
			setTurnData(name,-100)
		end
	end
end


zgfunc[sgs.Damage].expval=function(self, room, event, player, data,isOwner)
	local damage = data:toDamage()
	if damage.from and damage.from:objectName()==room:getOwner():objectName() then
		addTurnData("expval",math.min(damage.damage,8))
	end		
end

zgfunc[sgs.Damage].bgws=function(self, room, event, player, data,isOwner)
	local damage = data:toDamage()
	if damage.from and damage.from:objectName()==room:getOwner():objectName() 
			and damage.from:isLord() and damage.to:getRole()=="loyalist" then
		addGameData("bgws",1)
	end		
end

zgfunc[sgs.GameOverJudge].callback.bgws=function(room,player,data,name,result)	
	if getGameData("bgws",0)==0 and result =='win' then		 
		addZhanGong(room,name)
	end
end


zgfunc[sgs.DamageCaused].ljxs=function(self, room, event, player, data,isOwner)
	if not isOwner then return false end
	local damage = data:toDamage()
	if damage.card and damage.card:isKindOf("Slash") and damage.to:isKongcheng() 
			and not damage.chain and not damage.transfer then
		local name="ljxs"
		addGameData(name,1)
		if getGameData(name)>=3 then			 
			addZhanGong(room,name)
			setGameData(name,-100)
		end
	end		
end

zgfunc[sgs.Damaged].mbgj=function(self, room, event, player, data,isOwner)
	if not isOwner then return false end
	local damage = data:toDamage()
	local playerName=player:objectName()
	local currentName=room:getCurrent():objectName()
	if damage.card and damage.card:isKindOf("Lightning") and playerName==currentName then		
		setTurnData("mbgj",1)
	end		
end

zgfunc[sgs.EventPhaseEnd].mbgj=function(self, room, event, player, data,isOwner)
	if not isOwner then return false end
	local name="mbgj"
	if player:getPhaseString()=="judge" and player:isAlive() and getTurnData(name,0)==1 then
		setTurnData(name,0)		 
		addZhanGong(room,name)
	end		
end

zgfunc[sgs.Death].gainSkill=function(self, room, event, player, data,isOwner)
	local damage = data:toDamageStar()
	if damage.from and damage.from:objectName()==room:getOwner():objectName() then
		gainSkill(room)
	end		
end

zgfunc[sgs.Death].lczz=function(self, room, event, player, data,isOwner)
	local damage = data:toDamageStar()
	local killer=damage.from
	if not killer then return false end
	if killer:getRole()=="rebel" and (player:getRole()=="renegade" or player:getRole()=="loyalist") 
			and killer:objectName()==room:getOwner():objectName()  then
		local name="lczz"
		addGameData(name,1)		
		if getGameData(name,0)>=2 then 			 
			addZhanGong(room,name)
			setGameData(name,-100)
		end
		
	end		
end

zgfunc[sgs.GameOverJudge].callback.lczz=function(room,player,data,name,result)
	local damage = data:toDamageStar()
	local killer=damage.from
	if not killer then return false end
	if killer:getRole()=="rebel" and (player:getRole()=="renegade" or player:getRole()=="loyalist") 
			and killer:objectName()==room:getOwner():objectName()  then
		local name="lczz"
		addGameData(name,1)		
		if getGameData(name)>=2 then 			 
			addZhanGong(room,name)
			setGameData(name,-100)
		end
	end		
end


zgfunc[sgs.Death].cdzx=function(self, room, event, player, data,isOwner)
	local damage = data:toDamageStar()
	local killer=damage.from
	if not killer then return false end
	if killer:getRole()=="loyalist" and (player:getRole()=="renegade" or player:getRole()=="rebel") 
			and killer:objectName()==room:getOwner():objectName()  then
		local name="cdzx"
		addGameData(name,1)		
		if getGameData(name,0)>=2  then 			 
			addZhanGong(room,name)
			setGameData(name,-100)
		end
	end		
end

zgfunc[sgs.GameOverJudge].callback.cdzx=function(room,player,data,name,result)
	local damage = data:toDamageStar()
	local killer=damage.from
	if not killer then return false end
	if killer:getRole()=="loyalist" and (player:getRole()=="renegade" or player:getRole()=="rebel") 
			and killer:objectName()==room:getOwner():objectName()  then
		local name="cdzx"
		addGameData(name,1)		
		if getGameData(name)>=2 then 			 
			addZhanGong(room,name)
			setGameData(name,-100)
		end

	end		
end

zgfunc[sgs.Death].pfdj=function(self, room, event, player, data,isOwner)
	local damage = data:toDamageStar()
	local killer=damage.from
	if not killer then return false end
	if player:getRole()=="rebel" and killer:objectName()==room:getOwner():objectName()  then
		local name="pfdj"
		addGameData(name,1)		
		if getGameData(name,0)==4 then 			 
			addZhanGong(room,name)
			setGameData(name,-100)
		end
	end		
end

zgfunc[sgs.GameOverJudge].callback.pfdj=function(room,player,data,name,result)
	local damage = data:toDamageStar()
	local killer=damage.from
	if not killer then return false end
	if player:getRole()=="rebel" and killer:objectName()==room:getOwner():objectName()  then
		local name="pfdj"
		addGameData(name,1)
		if getGameData(name)==4 then 			 
			addZhanGong(room,name)
			setGameData(name,-100)
		end
	end		
end



zgfunc[sgs.Death].lsch=function(self, room, event, player, data,isOwner)
	local damage = data:toDamageStar()
	local killer=damage.from
	if not killer then return false end
	if player:isFemale() and killer:objectName()==room:getOwner():objectName()  then
		local name="lsch"
		addGameData(name,1)		
		if getGameData(name,0)>=2 then 			 
			addZhanGong(room,name)
			setGameData(name,-100)
		end
	end		
end

zgfunc[sgs.GameOverJudge].callback.lsch=function(room,player,data,name,result)
	local damage = data:toDamageStar()
	local killer=damage.from
	if not killer then return false end
	if player:isFemale() and killer:objectName()==room:getOwner():objectName()  then
		local name="lsch"
		addGameData(name,1)
		if getGameData(name)>=2 then 			 
			addZhanGong(room,name)
			setGameData(name,-100)
		end
	end		
end


zgfunc[sgs.Death].djyd=function(self, room, event, player, data,isOwner)
	local damage = data:toDamageStar()
	if getGameData("turncount")==0 and player:objectName()==room:getOwner():objectName()   then
		local name="djyd"
		addZhanGong(room,name)
	end		
end

zgfunc[sgs.GameOverJudge].callback.djyd=function(room,player,data,name,result)
	local damage = data:toDamageStar()
	if getGameData("turncount")==0 and player:objectName()==room:getOwner():objectName()  then
		local name="djyd"
		addZhanGong(room,name)
	end		
end


zgfunc[sgs.Death].xbtc=function(self, room, event, player, data,isOwner)
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

	if getGameData("turncount")==1 and diffgroup and killerName==room:getOwner():objectName() 
			and killerName==room:getCurrent():objectName() then
		local name="xbtc"
		addZhanGong(room,name)
	end		
end

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

	if getGameData("turncount")==1 and diffgroup and killerName==room:getOwner():objectName() 
			and killerName==room:getCurrent():objectName() then
		local name="xbtc"
		addZhanGong(room,name)
	end	
end


zgfunc[sgs.FinishRetrial].jlsj=function(self, room, event, player, data,isOwner)
	local name="jlsj"
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

zgfunc[sgs.FinishRetrial].alg=function(self, room, event, player, data,isOwner)
	local name="alg"
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

zgfunc[sgs.FinishRetrial].bjlz=function(self, room, event, player, data,isOwner)
	local name="bjlz"
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

zgfunc[sgs.FinishRetrial].jcll=function(self, room, event, player, data,isOwner)
	local name="jcll"
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


zgfunc[sgs.FinishRetrial].tq=function(self, room, event, player, data,isOwner)
	local name="tq"
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

zgfunc[sgs.Death].tq=function(self, room, event, player, data,isOwner)
	local damage = data:toDamageStar()
	if damage.card and damage.card:isKindOf("Lightning") and player:objectName()==room:getOwner():objectName() then
		local name="tq"
		if getTurnData(name,0)==1 then 			 
			addZhanGong(room,name)
		end
	end		
end

zgfunc[sgs.GameOverJudge].callback.tq=function(room,player,data,name,result)
	local damage = data:toDamageStar()
	if damage.card and damage.card:isKindOf("Lightning") and player:objectName()==room:getOwner():objectName() then
		local name="tq"
		if getTurnData(name,0)==1 then
			addZhanGong(room,name)
		end
	end		
end



zgfunc[sgs.GameOverJudge].tongji=function(self, room, event, player, data,isOwner)
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

zgfunc[sgs.GameOverJudge].callback.ccml=function(room,player,data,name,result)
	local sql=string.format("select count(id) as num from results where result<>'-'")	
	for row in db:rows(sql) do
		if row.num==1 then 			 
			addZhanGong(room,name)
		end
	end
end

zgfunc[sgs.GameOverJudge].callback.csss=function(room,player,data,name,result)
	local sql=string.format("select count(id) as num from results where result<>'-'")
	for row in db:rows(sql) do
		if row.num==5 then 			
			addZhanGong(room,name)
		end
	end
end

zgfunc[sgs.GameOverJudge].callback.xsnd=function(room,player,data,name,result)
	local sql=string.format("select count(id) as num from results where result<>'-'")
	for row in db:rows(sql) do
		if row.num==10 then			 
			addZhanGong(room,name)
		end
	end
end

zgfunc[sgs.GameOverJudge].callback.xymq=function(room,player,data,name,result)
	local sql=string.format("select count(id) as num from results where result<>'-'")
	for row in db:rows(sql) do
		if row.num==20 then 			 
			addZhanGong(room,name)
		end
	end
end

zgfunc[sgs.GameOverJudge].callback.fmbl=function(room,player,data,name,result)
	local sql=string.format("select count(id) as num from results where result<>'-'")
	for row in db:rows(sql) do
		if row.num==30 then 			 
			addZhanGong(room,name)
		end
	end
end


zgfunc[sgs.GameOverJudge].callback.wwdz=function(room,player,data,name,result)	
	local sql=string.format("select count(id) as num from results where role='renegade' and result='win'")
	if result =='win' and room:getOwner():getRole()=="renegade" then 
		for row in db:rows(sql) do
			if row.num==1 then addZhanGong(room,name) end
		end
	end
end


zgfunc[sgs.GameOverJudge].callback.ycww=function(room,player,data,name,result)	
	local sql=string.format("select count(id) as num from results where role='renegade' and result='win'")
	if result =='win' and room:getOwner():getRole()=="renegade" then 
		for row in db:rows(sql) do
			if row.num==20 then addZhanGong(room,name) end
		end
	end
end

zgfunc[sgs.GameOverJudge].callback.zxgg=function(room,player,data,name,result)	
	local sql=string.format("select count(id) as num from results where role='loyalist' and result='win'")
	if result =='win' and room:getOwner():getRole()=="loyalist" then 
		for row in db:rows(sql) do
			if row.num==60 then addZhanGong(room,name) end
		end
	end
end


zgfunc[sgs.GameOverJudge].callback.cttz=function(room,player,data,name,result)	
	local sql=string.format("select count(id) as num from results where role='rebel' and result='win'")
	if result =='win' and room:getOwner():getRole()=="rebel" then 
		for row in db:rows(sql) do
			if row.num==100 then addZhanGong(room,name) end
		end
	end
end

zgfunc[sgs.GameOverJudge].callback.jltx=function(room,player,data,name,result)	
	local sql=string.format("select count(id) as num from results where role='lord' and result='win'")
	if result =='win' and room:getOwner():getRole()=="lord" then 
		for row in db:rows(sql) do
			if row.num==40 then addZhanGong(room,name) end
		end
	end
end


zgfunc[sgs.GameOverJudge].callback.ccsg=function(room,player,data,name,result)	
	local sql=string.format("select count(id) as num from results where result='win'")
	if result ~='win' then return false end
	for row in db:rows(sql) do
		if row.num==1 then 			 
			addZhanGong(room,name)
		end
	end
end

zgfunc[sgs.GameOverJudge].callback.cjss=function(room,player,data,name,result)
	local sql=string.format("select count(id) as num from results where result='win'")
	if result ~='win' then return false end	
	for row in db:rows(sql) do
		if row.num==5 then 			
			addZhanGong(room,name)
		end
	end
end

zgfunc[sgs.GameOverJudge].callback.zjss=function(room,player,data,name,result)
	local sql=string.format("select count(id) as num from results where result='win'")
	if result ~='win' then return false end
	for row in db:rows(sql) do
		if row.num==10 then 			 
			addZhanGong(room,name)
		end
	end
end

zgfunc[sgs.GameOverJudge].callback.gjss=function(room,player,data,name,result)
	local sql=string.format("select count(id) as num from results where result='win'")
	if result ~='win' then return false end
	for row in db:rows(sql) do
		if row.num==20 then 			 
			addZhanGong(room,name)
		end
	end
end

zgfunc[sgs.GameOverJudge].callback.qzss=function(room,player,data,name,result)
	local sql=string.format("select count(id) as num from results where result='win'")
	if result ~='win' then return false end
	for row in db:rows(sql) do
		if row.num==30 then 			 
			addZhanGong(room,name)
		end
	end
end

zgfunc[sgs.TurnStart].init=function(self, room, event, player, data,isOwner)
	if not isOwner then return false end
	addGameData("turncount",1)
	local alive=room:getOwner():isAlive() and 1 or 0
	sqlexec("update results set general='%s',turncount=%d,alive=%d,wen=wen+%d,wu=wu+%d,expval=expval+%d where id=%d",
			room:getOwner():getGeneralName(),getGameData("turncount"), alive,getTurnData("wen"),
			getTurnData("wu"),getTurnData("expval"),getGameData("roomid"))
	for key,val in pairs(zgturndata) do
		zgturndata[key]=0
	end	
end


zgfunc[sgs.SlashEffected].dqbr=function(self, room, event, player, data,isOwner)
	local effect= data:toSlashEffect()
	local armor= (effect.to:getArmor() and effect.to:getArmor():isKindOf("RenwangShield")) 
			or ((not effect.to:getArmor()) and effect.to:hasSkill("yizhong"))
	if effect.to:getMark("qinggang") then armor=false end
	if armor and effect.to:objectName()==room:getOwner():objectName() and effect.slash:isBlack() then
		local name="dqbr"
		addGameData(name,1)
		if getGameData(name)>=3 then 			 
			addZhanGong(room,name)
			setGameData(name,-100)
		end
	end
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
	sqlexec("update zhangong set num=num+1,lasttime=datetime('now','localtime') where id='%s'",name)
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

function init_gamestart(self, room, event, player, data, isOwner)
	local config=sgs.Sanguosha:getSetupString():split(":")
	local mode=config[2]
	local flags=config[5]
	local owner=room:getOwner()

	if not isOwner then return false end

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

	if getGameData("roomid")==0 then 
		setGameData("roomid",os.time())
		setTurnData("wen",0)
		setTurnData("wu",0)
		setTurnData("expval",0)
		sqlexec("insert into results values(%d,'%s','%s','%s',0,1,'-',0,0,0)",
				getGameData("roomid"),player:getGeneralName(),player:getRole(),room:getMode())
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
				for _, func in pairs(callbacks) do
					if type(func)=="function" then 						
						func(self, room, event, player, data, owner) 
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
	if string.find(flags,"H") then		
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
addTranslation()

function addTranslation()
	local zgTrList={}
	local dbdata=db:rows("select id,name,description from zhangong")
	for row in dbdata do
		zgTrList["#zhangong_"..row.id]="%from获得了战功【"..row.name.."】,"..row.description
	end
	sgs.LoadTranslationTable(zgTrList)
end

sgs.LoadTranslationTable {
	["zhangong"] ="战功包",
	["#gainWen"] ="%from获得【%arg】点文功",
	["#gainWu"] ="%from获得【%arg】点武功",
	["#gainExp"] ="%from获得【%arg】点经验",
	["#canntGainSkill"]= "【警告】技能列表为空，无法获得技能",
	["#gainSkill"]="%from获得了技能卡【%arg】",
}
