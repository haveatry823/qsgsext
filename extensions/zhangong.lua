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

zgfunc[sgs.CardFinished].wenwu=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	local use=data:toCardUse()
	local card=use.card
	if card:isKindOf("TrickCard") then addTurnData("wen",1) end
	if card:isKindOf("Slash")	  then addTurnData("wu",1) end	
end

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


zgfunc[sgs.Damage].expval=function(self, room, event, player, data,isowner,name)
	local damage = data:toDamage()
	if damage.from and damage.from:objectName()==room:getOwner():objectName() then
		addTurnData("expval",math.min(damage.damage,8))
	end		
end

zgfunc[sgs.Damage].bgws=function(self, room, event, player, data,isowner,name)
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

zgfunc[sgs.Damaged].mbgj=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	local damage = data:toDamage()
	local playerName=player:objectName()
	local currentName=room:getCurrent():objectName()
	if damage.card and damage.card:isKindOf("Lightning") and playerName==currentName then		
		setTurnData("mbgj",1)
	end		
end

zgfunc[sgs.EventPhaseEnd].mbgj=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	if player:getPhaseString()=="judge" and player:isAlive() and getTurnData(name,0)==1 then
		setTurnData(name,0)		 
		addZhanGong(room,name)
	end		
end

zgfunc[sgs.Death].gainSkill=function(self, room, event, player, data,isowner,name)
	local damage = data:toDamageStar()
	if damage.from and damage.from:objectName()==room:getOwner():objectName() then
		gainSkill(room)
	end		
end

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


zgfunc[sgs.Death].djyd=function(self, room, event, player, data,isowner,name)
	local damage = data:toDamageStar()
	if getGameData("turncount")==0 and player:objectName()==room:getOwner():objectName()   then
		addZhanGong(room,name)
	end		
end

zgfunc[sgs.GameOverJudge].callback.djyd=function(room,player,data,name,result)
	local damage = data:toDamageStar()
	if getGameData("turncount")==0 and player:objectName()==room:getOwner():objectName()  then
		addZhanGong(room,name)
	end		
end


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

	if getGameData("turncount")==1 and diffgroup and killerName==room:getOwner():objectName() 
			and killerName==room:getCurrent():objectName() then
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
		addZhanGong(room,name)
	end	
end


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

zgfunc[sgs.Death].tq=function(self, room, event, player, data,isowner,name)
	local damage = data:toDamageStar()
	if damage.card and damage.card:isKindOf("Lightning") and player:objectName()==room:getOwner():objectName() then
		if getTurnData(name,0)==1 then 			 
			addZhanGong(room,name)
		end
	end		
end

zgfunc[sgs.GameOverJudge].callback.tq=function(room,player,data,name,result)
	local damage = data:toDamageStar()
	if damage.card and damage.card:isKindOf("Lightning") and player:objectName()==room:getOwner():objectName() then
		if getTurnData(name,0)==1 then
			addZhanGong(room,name)
		end
	end		
end



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

zgfunc[sgs.Death].hsqj=function(self, room, event, player, data,isowner,name)
	local damage = data:toDamageStar()
	if damage.from and damage.from:objectName()==room:getOwner():objectName() then
		addGameData(name,1)
	end		
end

zgfunc[sgs.GameOverJudge].callback.hsqj=function(room,player,data,name,result)
	if result =='win' and getGameData(name)==7 then addZhanGong(room,name) end	
end

zgfunc[sgs.Death].lmss=function(self, room, event, player, data,isowner,name)
	local damage = data:toDamageStar()
	if damage.from and damage.from:objectName()==room:getOwner():objectName() 
		and damage.from:getRole()=="renegade" and (player:getRole()=="rebel" or player:getRole()=="loyalist") then
		addGameData(name,1)
	end		
end

zgfunc[sgs.GameOverJudge].callback.lmss=function(room,player,data,name,result)
	if result =='win' and getGameData(name)>=4 then addZhanGong(room,name) end
end


zgfunc[sgs.Death].jzjz=function(self, room, event, player, data,isowner,name)
	local damage = data:toDamageStar()
	if damage.from and damage.from:objectName()==room:getOwner():objectName()
		and damage.from:getRole()=="loyalist" and (player:getRole()=="rebel" or player:getRole()=="renegade") 
		and getGameData("turncount")==1 and damage.from:objectName()==room:getCurrent():objectName() then
			setGameData(name,1)
	end		
end

zgfunc[sgs.GameOverJudge].callback.jzjz=function(room,player,data,name,result)
	if result =='win' and getGameData(name)==1 then addZhanGong(room,name) end
end


zgfunc[sgs.GameOverJudge].callback.cxer=function(room,player,data,name,result)
	local damage = data:toDamageStar()
	if result=='win' and damage.from and damage.from:objectName()==room:getOwner():objectName()
		and damage.from:getRole()=="rebel" and player:getRole()=="lord"
		and getGameData("turncount")==1 and damage.from:objectName()==room:getCurrent():objectName() then
			addZhanGong(room,name)
	end		
end

zgfunc[sgs.Death].ljjh=function(self, room, event, player, data,isowner,name)
	local damage = data:toDamageStar()
	if damage.from and damage.from:isLord() and player:getRole()=="loyalist" then
		setGameData(name,1)
	end		
end

zgfunc[sgs.GameOverJudge].callback.ljjh=function(room,player,data,name,result)
	if result =='win' and getGameData(name)==1 and room:getOwner():getRole()=="renegade" then 
		addZhanGong(room,name) 
	end
end



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

zgfunc[sgs.GameOverJudge].callback.jcfs=function(room,player,data,name,result)
	if result =='win' and getGameData(name)==1 then addZhanGong(room,name) end
end


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

zgfunc[sgs.GameOverJudge].callback.tdwy=function(room,player,data,name,result)
	if result =='win' and getGameData(name)>=3 then addZhanGong(room,name) end
end



zgfunc[sgs.GameOverJudge].callback.zgyd=function(room,player,data,name,result)	
	local owner=room:getOwner()
	if result =='win' and not room:getLord():isWounded() and owner:isAlive() and owner:getRole()=="loyalist" then 
		addZhanGong(room,name) 
	end	
end

zgfunc[sgs.GameOverJudge].callback.csjj=function(room,player,data,name,result)
	if result ~='win' then return false end
	local sql=string.format("select result from results where order by id desc limit 10")	
	local count=0
	for row in db:rows(sql) do
		if row.result=='win' then count=count+1 end
	end
	if count==10 then addZhanGong(room,name) end	
end


for data in db:rows("select id,category,general,num from zhangong where num>0 ") do
	zgfunc[sgs.GameOverJudge].callback[data.id]=function(room,player,data,name,result)			
		local mode=room:getMode()
		if result ~='win' then return false end
		if data.category=="3v3" and room:getMode()~="06_3v3" then return false end
		if data.category=="1v1" and room:getMode()~="02_1v1" then return false end
		if data.category=="wujiang" and
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
		if data.category=="wujiang" then 
			sql=sql.." and hegemony=0 and mode not in ('06_3v3','02_1v1','04_1v3') "
		end
		
		for row in db:rows(sql) do
			if row.num==data.num then addZhanGong(room,name) end
		end
	end
end

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
		sqlexec("insert into results values(%d,'%s','%s' '%s','%d','%s',0,1,'-',0,0,0)",
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
		zgTrList["#zhangong_"..row.id]="%from获得了战功【"..row.name.."】,"..row.description		
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

