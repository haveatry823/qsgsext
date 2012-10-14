enableSkillCard = 1		-- 是否开启技能卡， 1:开启, 0:不开启 
enableLuckyCard = 1		-- 是否开启手气卡,  1:开启, 0:不开启
enableHulaoCard = 1		-- 是否开启虎牢关点将卡,  1:开启, 0:不开启

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
zgfunc[sgs.CardsMoveOneTime]={}
zgfunc[sgs.ChoiceMade]={}


zgfunc[sgs.ConfirmDamage]={}
zgfunc[sgs.Damage]={}
zgfunc[sgs.DamageCaused]={}
zgfunc[sgs.Damaged]={}
zgfunc[sgs.DamageComplete]={}
zgfunc[sgs.DamageInflicted]={}


zgfunc[sgs.Death]={}
zgfunc[sgs.EventPhaseEnd]={}
zgfunc[sgs.EventPhaseStart]={}

zgfunc[sgs.FinishRetrial]={}

zgfunc[sgs.GameStart]={}
zgfunc[sgs.GameOverJudge]={}
zgfunc[sgs.GameOverJudge]["callback"]={}
zgfunc[sgs.HpRecover]={}

zgfunc[sgs.SlashEffect]={}
zgfunc[sgs.SlashEffected]={}

zgfunc[sgs.TurnStart]={}
zgfunc[sgs.Pindian]={}



require "sqlite3"
db = sqlite3.open("./zhangong/zhangong.data")
local tblquery=db:first_row("select count(name) as tblnum from sqlite_master  where type='table';")
if tblquery.tblnum==0 then
	local sqltbl = (io.open "./zhangong/zhangong.sql"):read("*a"):split("\n")
	for _,line in ipairs(sqltbl) do
		db:exec(line)
	end
end

function logmsg(fmt,...)
	local fp = io.open("zgdebug.log","ab")
	if type(fmt)=="boolean" then fmt = fmt and "true" or "false" end
	fp:write(string.format(fmt, unpack(arg)).."\r\n")
	fp:close()
end

function sqlexec(sql,...)
	local sqlstr=string.format(sql, unpack(arg))
	db:exec(sqlstr)
end


function database2js()
	local zglist={'zhonghe','wei','shu','wu','qun','god','3v3','1v1'}
	local ret={}
	table.insert(ret,"var zglist=['zhonghe','wei','shu','wu','qun','god','3v3','1v1'];")
	table.insert(ret,"var data={};")

	local dbquery=function(sql,collist)
		local arr={}
		for row in db:rows(sql) do
			local item={}
			for _,col in ipairs(collist) do
				table.insert(item,string.format('"%s":"%s"',col,row[col]))
			end
			table.insert(arr,string.format("{%s}",table.concat(item,",")))
		end
		return table.concat(arr,",\r\n")
	end

	local sql = "select datetime(id,'unixepoch','localtime') as gametime,* from results order by id desc limit 300";
	local collist={'gametime','id','general','role','kingdom','hegemony','mode','turncount','alive','result','wen','wu','expval','zhangong'}
	table.insert(ret,string.format("data.results=[%s];",dbquery(sql,collist)))

	local sql = "select skillname,gained,used,gained-used as remainnum from skills order by remainnum desc"
	local collist={'skillname','gained','used','remainnum'}
	table.insert(ret,string.format("data.skills=[%s];",dbquery(sql,collist)))

	local sql = "select level,name,score,category as cat from gongxun where level>0 order by category,level"
	local collist={'level','name','score','cat'}
	table.insert(ret,string.format("data.gongxun=[%s];",dbquery(sql,collist)))

	for _,zgcat in ipairs(zglist) do
		local sql = "select * from zhangong where category='"..zgcat.."' order by general asc"
		local collist={'id','name','description','score','gained','category','lasttime','general','num','count'}
		table.insert(ret,string.format("data['zg"..zgcat.."']=[%s];",dbquery(sql,collist)))
	end
	local zgtrans="$.each(zglist,function(i,val){$.each(data['zg'+val],function(index,item){trans[item.id]=[item.name];})});"
	table.insert(ret,zgtrans)

	local getinfodata=function()
		local arr={""}		
		table.insert(arr,"var info={v3:{},role:{},hegemony:{},v1:{},hulao:{},total:{},wen:{},wu:{},expval:{},zg:{}};")

		local getVal=function(sql,...)
			local query=db:first_row(string.format(sql, unpack(arg)))
			if not query then return 0 end
			for _,p in pairs(query) do 
				return p
			end			
			return 0
		end	

		local getData=function(col,val,valtype)
			if valtype=="str" then
				table.insert(arr,string.format("info.%s='%s';",col,val))
			else
				table.insert(arr,string.format("info.%s=%d;",col,val))
			end
		end

		local getResult=function(mode,cond,ratearr)
			local winnum = getVal("select count(id) from results where %s and result='win'",cond)
			local losenum= getVal("select count(id) from results where %s and result='lose'",cond)
			local escnum = getVal("select count(id) from results where %s and result='-'",cond)
			local totalnum= winnum+losenum+escnum
			if totalnum==0 then totalnum=1 end
			table.insert(arr,string.format("info['%s'].winnum=%d;",mode,winnum))	
			table.insert(arr,string.format("info['%s'].losenum=%d;",mode,losenum))	
			table.insert(arr,string.format("info['%s'].escnum=%d;",mode,escnum))
			table.insert(arr,string.format("info['%s'].totalnum=%d;",mode,totalnum))
			table.insert(arr,string.format("info['%s'].winrate='%.1f%%';",mode,100*winnum/totalnum))	
			for i,ratecond in ipairs(ratearr) do 
				local win=getVal("select count(id) from results where %s and result='win' and %s",cond,ratecond)
				local total=getVal("select count(id) from results where %s and 1 and %s",cond,ratecond)
				if total==0 then total=1 end
				table.insert(arr,string.format("info['%s']['winnum_%d']=%d;",mode,i,win))
				table.insert(arr,string.format("info['%s']['totalnum_%d']=%d;",mode,i,total))
				table.insert(arr,string.format("info['%s']['winrate_%d']='%.1f%%';",mode,i,100*win/total))	
			end			
		end

		getResult("hulao","mode='04_1v3' and hegemony=0",{"role='lord'","role='rebel'"})
		getResult("v3",  "mode='06_3v3' and hegemony=0",{"role in ('lord','renegade')","role in ('loyalist','rebel')"})
		getResult("v1",  "mode='02_1v1' and hegemony=0",{"role='renegade'","role='lord'"})
		getResult("role","mode like '__p%' and hegemony=0",{"role='lord'","role='loyalist'","role='renegade'","role='rebel'"})
		getResult("hegemony","hegemony=1",{"kingdom='wei'","kingdom='shu'","kingdom='wu'","kingdom='qun'"})
		getResult("total","1",{})

		local wen=getVal("select sum(wen) from results")
		local wu=getVal("select sum(wu) from results")
		local expval=getVal("select sum(expval) from results")
		getData("wen.score",wen)
		getData("wu.score",wu)		
		getData("expval.score",expval)
		getData("expval.level",math.floor(math.pow(expval,1/3)))

		getData("zg.num",getVal("select count(id) from zhangong where gained>0"))
		getData("zg.total",getVal("select count(id) from zhangong"))
		getData("zg.score",getVal("select sum(score*gained) from zhangong where gained>0"))
		getData("wen.level",getVal("select level from gongxun where category='wen' and score<=%d order by score desc limit 1",wen))
		getData("wen.name",getVal("select name from gongxun where category='wen' and score<=%d order by score desc limit 1",wen),"str")
		
		getData("wu.level",getVal("select level from gongxun where category='wu' and score<=%d order by score desc limit 1",wu))
		getData("wu.name",getVal("select name from gongxun where category='wu' and score<=%d order by score desc limit 1",wu),"str")

		local starttime=getVal("select datetime(min(id),'unixepoch','localtime') from results")
		if starttime==0 then starttime="尚未开始统计" end
		getData("total.starttime",starttime,"str")
		
		table.insert(arr,"return info;")
		return table.concat(arr,"\r\n")
	end
	table.insert(ret,string.format("data.info=(function(){%s})();",getinfodata()))

	local fp = io.open("./zhangong/js/zg.js","wb")
	fp:write(table.concat(ret,"\r\n"))
	fp:close()

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
	if choices[1]=="cardResponsed" and choices[2]=="@Axe" and choices[#choices]~="_nil_" then
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
		if getTurnData(name)==3 then			 
			addZhanGong(room,name)
		end
	end
end


-- expval ::  :: 每造成一点伤害，增加一点经验，最高限8点
-- 
zgfunc[sgs.Damage].expval=function(self, room, event, player, data,isowner,name)
	local damage = data:toDamage()
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() then
		addTurnData("expval",math.min(damage.damage,8))
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
	if not damage then return false end
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() then
		gainSkill(room)
	end		
end


-- lczz :: 乱臣贼子 :: 身为反贼在1局游戏中，手刃至少2个忠臣或内奸
-- 
zgfunc[sgs.Death].lczz=function(self, room, event, player, data,isowner,name)
	local damage = data:toDamageStar()
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
	local damage = data:toDamageStar()
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
	local damage = data:toDamageStar()
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
	local damage = data:toDamageStar()
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
	local damage = data:toDamageStar()
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
	local damage = data:toDamageStar()
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
	local damage = data:toDamageStar()
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
	local damage = data:toDamageStar()
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
	local damage = data:toDamageStar()
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
	local damage = data:toDamageStar()
	if damage and damage.card and damage.card:isKindOf("Lightning") and player:objectName()==room:getOwner():objectName() then
		if getTurnData(name,0)==1 then 			 
			addZhanGong(room,name)
		end
	end		
end


-- tq :: 天谴 :: 不被改判定牌的情况下被闪电劈死
-- 
zgfunc[sgs.GameOverJudge].callback.tq=function(room,player,data,name,result)
	local damage = data:toDamageStar()
	if damage and damage.card and damage.card:isKindOf("Lightning") and player:objectName()==room:getOwner():objectName() then
		if getTurnData(name,0)==1 then
			addZhanGong(room,name)
		end
	end		
end




-- 游戏结束判断代码， 
-- 因为游戏结束的时候，当前阵亡的人的 sgs.Death 事件不会被触发，sgs.cardFinished也不会被触发，这里额外处理
-- zgfunc[sgs.GameOverJudge]["callback"] 处理最后一个阵亡的人的 Death事件
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

	setGameData("enable",0)
	database2js()
end


-- 完成N盘游戏获得战功
-- 
for zgname, count in pairs({ccml=1,csss=5,xsnd=10,xymq=20,fmbl=30}) do
	zgfunc[sgs.GameOverJudge].callback[zgname]=function(room,player,data,name,result)
		
		local sql=string.format("select count(id) as num from results where result<>'-'")	
		for row in db:rows(sql) do
			if row.num==count then 			 
				addZhanGong(room,name)
			end
		end
	end
end


-- hsqj :: 横扫千军 :: 在1局游戏中，手刃7名角色并且获得胜利
-- 
zgfunc[sgs.Death].hsqj=function(self, room, event, player, data,isowner,name)
	local damage = data:toDamageStar()
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() then
		addGameData(name,1)
	end		
end


-- hsqj :: 横扫千军 :: 在1局游戏中，手刃7名角色并且获得胜利
-- 
zgfunc[sgs.GameOverJudge].callback.hsqj=function(room,player,data,name,result)
	local damage = data:toDamageStar()
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() then
		addGameData(name,1)
	end	
	if result =='win' and getGameData(name)==7 then addZhanGong(room,name) end	
end


-- lmss :: 老谋深算 :: 身为内奸在1局游戏中手刃至少4个反贼或忠臣并且取得胜利
-- 
zgfunc[sgs.Death].lmss=function(self, room, event, player, data,isowner,name)
	local damage = data:toDamageStar()
	if getGameData("hegemony")==1 then return false end
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() 
		and damage.from:getRole()=="renegade" and (player:getRole()=="rebel" or player:getRole()=="loyalist") then
		addGameData(name,1)
	end		
end


-- lmss :: 老谋深算 :: 身为内奸在1局游戏中手刃至少4个反贼或忠臣并且取得胜利
-- 
zgfunc[sgs.GameOverJudge].callback.lmss=function(room,player,data,name,result)
	local damage = data:toDamageStar()
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
	local damage = data:toDamageStar()
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
	local damage = data:toDamageStar()
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
	local damage = data:toDamageStar()
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
	local damage = data:toDamageStar()
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
	local damage = data:toDamageStar()
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

-- 所有武将的 获得N场胜利 取得相应战功的代码  
--
for query in db:rows("select id,category,general,num,description from zhangong where num>0 ") do
	zgfunc[sgs.GameOverJudge].callback[query.id]=function(room,player,data,name,result)			
		local mode=room:getMode()
		local kingdoms={["wu"]=1,["shu"]=1,["wei"]=1,["qun"]=1,["god"]=1}
		if result ~='win' then return false end
		if query.category=="3v3" and room:getMode()~="06_3v3" then return false end
		if query.category=="1v1" and room:getMode()~="02_1v1" then return false end
		if kingdoms[query.category] and
				(mode=="06_3v3" or mode=="02_1v1" or mode=="04_1v3" or getGameData("hegemony")==1) then
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
			sql=sql.." and hegemony=0 and mode not in ('06_3v3','02_1v1','04_1v3') "
		end

		for row in db:rows(sql) do
			if row.num==query.num then addZhanGong(room,name) end
			sqlexec("update zhangong set count=%d where id='%s'",row.num,query.id)
		end
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
	database2js()
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
	local damage = data:toDamageStar()
	if not damage then return false end
	if player:objectName()==room:getOwner():objectName() and damage.card and damage.card:isKindOf("AOE") then
		addGlobalData(name,1)
		if getGlobalData(name)==10 then
			addZhanGong(room,name)
		end
	end		
end

zgfunc[sgs.GameOverJudge].callback.ph=function(room,player,data,name,result)
	local damage = data:toDamageStar()
	if not damage then return false end
	if player:objectName()==room:getOwner():objectName() and damage.card and damage.card:isKindOf("AOE") then
		addGlobalData(name,1)
		if getGlobalData(name)==10 then
			addZhanGong(room,name)
		end
	end	
end



-- gddph :: 更大的炮灰 :: 被南蛮入侵或万箭齐发打死累计50次 
-- 
zgfunc[sgs.Death].gddph=function(self, room, event, player, data,isowner,name)
	local damage = data:toDamageStar()
	if not damage then return false end
	if player:objectName()==room:getOwner():objectName() and damage.card and damage.card:isKindOf("AOE") then
		addGlobalData(name,1)
		if getGlobalData(name)==50 then
			addZhanGong(room,name)
		end
	end		
end

zgfunc[sgs.GameOverJudge].callback.gddph=function(room,player,data,name,result)
	local damage = data:toDamageStar()
	if not damage then return false end
	if player:objectName()==room:getOwner():objectName() and damage.card and damage.card:isKindOf("AOE") then
		addGlobalData(name,1)
		if getGlobalData(name)==50 then
			addZhanGong(room,name)
		end
	end	
end


-- yqt :: 一骑讨 :: 与人决斗胜利累计30次 
-- 
zgfunc[sgs.ConfirmDamage].yqt=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	local damage = data:toDamage()
	if damage and damage.card and damage.card:isKindOf("Duel") and player:objectName()==damage.from:objectName() then
		addGlobalData(name,1)
		if getGlobalData(name)==30 then
			addZhanGong(room,name)
		end
	end	
end


-- bszj :: 搬石砸脚 :: 与人决斗失败累计10次 
-- 
zgfunc[sgs.ConfirmDamage].bszj=function(self, room, event, player, data,isowner,name)	
	local damage = data:toDamage()
	if damage and damage.card and damage.card:isKindOf("Duel") and damage.to:objectName()==room:getOwner():objectName() and player:objectName()==damage.from:objectName() then
		addGlobalData(name,1)
		if getGlobalData(name)==10 then
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
		if getGlobalData(name)==30 then 			 
			addZhanGong(room,name)
		end	
	end
end



-- tw :: 桃王 :: 在1局游戏中给自己吃过5个或者更多得桃（不包括华佗的技能） 
-- 
zgfunc[sgs.CardFinished].tw=function(self, room, event, player, data,isowner,name)
	if not isowner then return false end
	local use=data:toCardUse()
	local card=use.card
	local tos=sgs.QList2Table(use.to)
	if card:getSkillName()~="jijiu" and card:isKindOf("Peach") and #tos==0 then 
		addGameData(name,1) 
		if getGameData(name)==5 then 			 
			addZhanGong(room,name)
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
	local damage = data:toDamageStar()
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
	local damage = data:toDamageStar()
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
	local damage = data:toDamageStar()
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
	local damage = data:toDamageStar()
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
	local damage = data:toDamageStar()
	if not damage then return false end
	if getGameData("hegemony")==1 then return false end
	if (player:getRole()=="rebel" or player:getRole()=="renegade") and damage and damage.from 
			and damage.from:objectName()==room:getOwner():objectName() and damage.from:isLord() then
		addGameData(name,1)
	end
end

zgfunc[sgs.GameOverJudge].callback.zszm=function(room,player,data,name,result)
	local damage = data:toDamageStar()
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
	if effect.card:isKindOf("AOE") and player:hasArmorEffect("Vine") then
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
	if damage and damage.card and damage.card:hasFlag("drank") and damage.card:isKindOf("Slash") then
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
	if damage and damage.card and damage.card:isKindOf("FireAttack") and not (damage.transfer or damage.chain) then
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
	if choices[1]=="cardResponsed"  and  string.match(choices[3],"@fire%-attack") and choices[#choices]=="_nil_" then
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
zgfunc[sgs.SlashEffect].fj=function(self, room, event, player, data,isowner,name)
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
	local damage=data:toDamageStar()
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
	local damage=data:toDamageStar()
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
	local damage=data:toDamageStar()
	if not damage then return false end
	if  room:getCurrent():objectName()==room:getOwner():objectName() and damage.card and damage.card:getSkillName()=="lijian" then
		addGameData(name,1)	
		if getGameData(name)==3 then
			addZhanGong(room,name)
		end
	end	
end

zgfunc[sgs.GameOverJudge].callback.qgqc=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~="diaochan" then return false end
	local damage=data:toDamageStar()
	if not damage then return false end
	if  room:getCurrent():objectName()==room:getOwner():objectName() and damage.card and damage.card:getSkillName()=="lijian" then
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
zgfunc[sgs.ChoiceMade].lsdjx=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="caocao" then return false end
	if not isowner then return false end
	local choices= data:toString():split(":")
	if choices[1]=="skillInvoke"  and  choices[2]=="jianxiong" and choices[3]=="yes" then
		local card=data:toCard()
		local carditem={}
		if not card then return false end
		if card:subcardsLength()>0 then
			local cids=sgs.QList2Table(card:getSubcards())
			for i=1,#cids,1 do
				table.insert(carditem,cids[i])	
			end
		else
			table.insert(carditem,card:getEffectiveId())
		end
		for i=1,#carditem,1 do
			local thecard=sgs.Sanguosha:getCard(carditem[i])
			if thecard:isKindOf("SavageAssault") then addGameData(name.."SavageAssault",1) end
			if thecard:isKindOf("ArcheryAttack") then addGameData(name.."ArcheryAttack",1) end
		end		
		if getGameData(name.."SavageAssault")>=3 and getGameData(name.."ArcheryAttack")>=1 then
			addZhanGong(room,name)
			setGameData(name.."SavageAssault",-100)
			setGameData(name.."ArcheryAttack",-100)
		end
	end	
end


-- yqwb :: 掩其无备 :: 使用张辽在1局游戏中发动至少10次突袭 
-- 
zgfunc[sgs.ChoiceMade].yqwb=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="zhangliao" then return false end
	if not isowner then return false end
	local choices= data:toString():split(":")
	if choices[1]=="cardResponsed"  and  choices[2]=="@@tuxi" and choices[#choices]~="_nil_" then
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
	local damage=data:toDamageStar()
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() 
		and damage.from:getGeneralName()=="xiahoudun" and  not damage.card then
		addGameData(name,1)	
		if getGameData(name)==1 then
			addZhanGong(room,name)
		end
	end	
end

zgfunc[sgs.GameOverJudge].callback.nswh=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~="xiahoudun" then return false end
	local damage=data:toDamageStar()
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
	local damage=data:toDamageStar()
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
	local damage=data:toDamageStar()
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
	local damage=data:toDamageStar()
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
	local damage=data:toDamageStar()
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
	local damage=data:toDamageStar()
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
	local damage=data:toDamageStar()
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
	local damage=data:toDamageStar()
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
	local damage=data:toDamageStar()
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
		and recov.card:hasFlag("jiuyuan") and player:hasFlag("jiuyuan") then
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
	if card:getSkillName()=="kurou" then 
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
	local damage=data:toDamageStar()
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
	local damage=data:toDamageStar()
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
	if card:getSkillName()=="shensu" then 
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
		end			
	end
end


-- ljdnx :: 老将的逆袭 :: 使用黄忠在1局游戏中，剩余1点体力时累计发动烈弓杀死至少3名角色 
--  
-- 这个战功仍然有bug,因为lua无法访问 QVariantList liegongList， 暂且这样
--
zgfunc[sgs.Death].ljdnx=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="huangzhong" then return false end
	local damage=data:toDamageStar()
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() 
		and damage.from:getGeneralName()=="huangzhong" and damage.card:isKindOf("Slash") 
		and player:getTag("Liegong") and damage.from:getHp()==1 then
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
	local damage=data:toDamageStar()
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() 
		and damage.from:getGeneralName()=="huangzhong" and damage.card:isKindOf("Slash") 
		and player:getTag("Liegong") and damage.from:getHp()==1 then
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
	local damage=data:toDamageStar()
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() 
		and damage.from:getGeneralName()=="zhangjiao" and  not damage.card and damage.nature == sgs.DamageStruct_Thunder then
		addGameData(name,1)	
		if getGameData(name)==3 then
			addZhanGong(room,name)
		end
	end	
end

zgfunc[sgs.GameOverJudge].callback.kbdwn=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~="zhangjiao" then return false end
	local damage=data:toDamageStar()
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() 
		and damage.from:getGeneralName()=="zhangjiao" and  not damage.card and damage.nature == sgs.DamageStruct_Thunder then
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
		local arr=part[3]:split("=")
		local card2=sgs.Sanguosha:getCard(arr[2])
		if part[1]~=card2:objectName() then
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
	local damage=data:toDamageStar()
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
		end
	end
end

zgfunc[sgs.GameOverJudge].callback.sssg=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~="yuanshu" then return false end
	local owner=room:getOwner()
	local damage=data:toDamageStar()
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
		end
	end
end

-- bmyc :: 白马义从 :: 使用公孙瓒在体力大于2的情况下杀死至少3名角色，并且在体力1的情况下存活并获胜。 
-- 
zgfunc[sgs.Death].bmyc=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~="gongsunzhan" then return false end
	local owner=room:getOwner()
	local damage=data:toDamageStar()
	if damage and damage.from and damage.from:objectName()==owner:objectName() and owner:getHp()>2 then
		addGameData(name,1)		
	end	
end

zgfunc[sgs.GameOverJudge].callback.bmyc=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~="gongsunzhan" then return false end
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
	local damage=data:toDamageStar()
	if damage and damage.from and damage.from:objectName()==owner:objectName() 
		and damage.card and damage.card:isKindOf("Slash") and damage.from:hasFlag("tianyi_success") then
		addTurnData(name,1)
		if getTurnData(name)==3 then
			addZhanGong(room,name)
		end
	end	
end

zgfunc[sgs.GameOverJudge].callback.jdzh=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~="taishici" then return false end
	local owner=room:getOwner()
	local damage=data:toDamageStar()
	if damage and damage.from and damage.from:objectName()==owner:objectName() 
		and damage.card and damage.card:isKindOf("Slash") and damage.from:hasFlag("tianyi_success") then
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
	local damage=data:toDamageStar()
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
	local damage=data:toDamageStar()
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
	local damage=data:toDamageStar()
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
	local damage=data:toDamageStar()
	if room:getCurrent():objectName()==room:getOwner():objectName() and getTurnData(name)==2
			and damage and damage.from and damage.from:objectName()==owner:objectName() then
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
	local damage=data:toDamageStar()
	local killerRole=damage.from and damage.from:getRole() or ""
	if (player:getRole()=="loyalist" and (killerRole=="lord" or killerRole=="loyalist")) or 
			(player:getRole()=="rebel" and (killerRole=="rebel" or killerRole=="renegade")) then
		addGlobalData(name,1)
		if getGlobalData(name)==10 then
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
	local list = room:getOwner():getTag("1v1Arrange"):toStringList()
	local n=0
	for _, generalname in ipairs(list) do
		local general = sgs.Sanguosha:getGeneral(generalname)
		if general:isFemale() then n=n+1 end
	end
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
	local list = table.concat(room:getOwner():getTag("1v1Arrange"):toStringList(),",")
	local n=0
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
zgfunc[sgs.GameOverJudge].callback.hfws=function(room,player,data,name,result)
	local list = room:getOwner():getTag("1v1Arrange"):toStringList()
	if result=='win' and not room:getOwner():isWounded() and #list==2 then
		addZhanGong(room,name)
	end		
end

-- jtnz :: 惊天逆转 :: 在本方剩余1名武将时，杀死对方3名武将获胜 (1v1)
-- 
zgfunc[sgs.Death].jtnz=function(self, room, event, player, data,isowner,name)
	if room:getMode()~="02_1v1" then return false end
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
	local list = table.concat(room:getOwner():getTag("1v1Arrange"):toStringList(),",")
	local n=0
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
	local list = table.concat(room:getOwner():getTag("1v1Arrange"):toStringList(),",")
	local n=0
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
	if  room:getOwner():getGeneralName()~='caopi' then return false end
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
			if place==sgs.Player_PlaceEquip and card:getSkillName()=="duanliang" then
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
	if  room:getOwner():getGeneralName()~='menghuo' then return false end
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
	local damage = data:toDamageStar()
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
	local damage = data:toDamageStar()
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

zgfunc[sgs.GameOverJudge].callback.lsgj=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~='caiwenji' then return false end
	if result=='win' and getGameData(name)==4 and not room:getOwner():isAlive() then			 
		addZhanGong(room,name)
	end		
end



-- fwjj :: 辅吴将军 :: 使用张昭&张纮在一局中发动直谏将至少5张装备牌置于吴势力武将装备区 
--
zgfunc[sgs.CardsMoveOneTime].fwjj=function(self, room, event, player, data,isowner,name)
	if  room:getOwner():getGeneralName()~='erzhang' then return false end
	local move=data:toMoveOneTime()
	if room:getCurrent():objectName()~=room:getOwner():objectName() then return end
	local reason=move.reason.m_reason
	if reason==sgs.CardMoveReason_S_REASON_USE and move.reason.m_skillName=="zhijian" and move.to:getKingdom()=='wu' then
		addGameData(name,1)
		if getGameData(name)==5 then
			addZhanGong(room,name)
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
	if reason.m_reason==sgs.CardMoveReason_S_REASON_TRANSFER and reason.m_playerId==room:getOwner():objectName() and reason.m_skillName=="qiaobian" then
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
	local damage=data:toDamageStar()
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
	local damage=data:toDamageStar()
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
	if reason.m_reason==sgs.CardMoveReason_S_REASON_PUT and reason.m_playerId==room:getOwner():objectName() then
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
	--bug: 其实lua没办法判断是否是业炎造成的伤害，暂且只能这样
	if damage and not damage.card and damage.nature == sgs.DamageStruct_Fire then
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
	local damage=data:toDamageStar()
	if damage and damage.card and damage.card:isKindOf("FireAttack") and player:getMark("@gale") > 0 then
		addGameData(name,1)	
		if getGameData(name)==1 then
			addZhanGong(room,name)
		end
	end	
end

zgfunc[sgs.GameOverJudge].callback.hdyx=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~="shenzhugeliang" then return false end
	local damage=data:toDamageStar()
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
	local damage=data:toDamageStar()
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() 
			and damage.from:hasFlag("xianzhen_success") then
		addGameData(name,1)	
	end	
end

zgfunc[sgs.GameOverJudge].callback.pzzj=function(room,player,data,name,result)
	if  room:getOwner():getGeneralName()~="gaoshun" then return false end
	local damage=data:toDamageStar()
	if damage and damage.from and damage.from:objectName()==room:getOwner():objectName() 
			and damage.from:hasFlag("xianzhen_success") then
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


-- gsy :: 狗屎运 :: 当你的开局4牌的颜色全为黑色时,清除你的N盘逃跑记录(N为4牌点数之和)
--
zgfunc[sgs.GameStart].gsy=function(self, room, event, player, data,isowner,name)
	if not isowner or getGameData("turncount",0)>0 or player:isKongcheng() then return false end
	local cards=sgs.QList2Table(player:getHandcards())
	local num=0
	for i=1,#cards,1 do
		if cards[i]:isRed() then return false end
		num = num + cards[i]:getNumber()
	end
	--sqlexec("delete from results where result='-' and id<>%d limit %d",getGameData("roomid"),num)
	local sql=string.format("select id from results where result='-' and id<>%d order by id asc limit %d",getGameData("roomid"),num)
	local count=0
	for row in db:rows(sql) do
		sqlexec("delete from results where id=%d",row.id)
		count = count +1
	end
	addZhanGong(room,name)
	broadcastMsg(room,"#gsyNum",count)
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
	database2js()
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
	setGameData("myzhangong", getGameData("myzhangong","")..name..":")
	sqlexec("update results set zhangong='%s' where id='%d'",getGameData("myzhangong",""),getGameData("roomid"))
	broadcastMsg(room,"#zhangong_"..name)	
	room:getOwner():speak(string.format("恭喜获得战功【<font color='yellow'><b>%s</b></font>】",sgs.Sanguosha:translate(name)))
	database2js()
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
	if not zgturndata[key] then return #arg>=1 and arg[1] or 0 end
	return zgturndata[key]
end


function useSkillCard(room,owner)
	local zgquery=db:first_row("select count(id) as num from zhangong where gained>0")
	local limitnum= math.ceil(zgquery.num / 20)
	local skilldata=db:rows("select skillname from skills where gained>used order by random() limit "..limitnum)
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

function useLuckyCard(room,owner)
	if owner:hasSkill("tuntian") then return false end
	local zgquery=db:first_row("select count(id) as num from zhangong where gained>0")
	local limitnum= math.ceil(zgquery.num / 20)

	--防止使用手气卡的时候触发【落英】
	local reason=sgs.CardMoveReason()
	reason.m_reason   = sgs.CardMoveReason_S_REASON_PUT
	reason.m_playerId = owner:objectName()
	reason.m_targetId = owner:objectName()

	for i=math.max(1,limitnum),1,-1 do
		if owner:askForSkillInvoke("useLuckyCard") then
			local n=owner:getHandcardNum()
			if owner:hasSkill("lianying") then n=n-1 end
			for j=n,1,-1 do
				room:moveCardTo(owner:getRandomHandCard(), nil, nil, sgs.Player_DiscardPile, reason)
			end
			owner:drawCards(n,true)
			broadcastMsg(room,"#LuckyCardNum",i-1)
		else
			break
		end
	end
end

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
		math.randomseed(os.time())
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
			end
			count=count+1
		end
		if choice ~= "cancel" then			
			table.removeTable(generalnames, {choice})
			shuffle(generalnames)
		end
	end
end

function init_gamestart(self, room, event, player, data, isowner)
	local config=sgs.Sanguosha:getSetupString():split(":")
	local mode=config[2]
	local flags=config[5]
	local owner=room:getOwner()

	if not isowner or getGameData("enable")==1 then return false end
	
	if not string.find(mode,"^[01]%d[p_]") or string.find(flags,"[F]") then		
		setGameData("enable",0)
		return false
	end
	
	local count=0
	for _, p in sgs.qlist(room:getAllPlayers()) do
		if p:getState() ~= "robot" then 
			count=count+1			
		else
			room:detachSkillFromPlayer(p, "#zgzhangong1")
			room:detachSkillFromPlayer(p, "#zgzhangong2")
		end
	end
	if count>1 then
		setGameData("enable",0)
		return false
	end

	for key,val in pairs(zggamedata) do
		zggamedata[key]=0
	end

	setGameData("enable",1)
	setGameData("myzhangong","")
	if string.find(flags,"H") then setGameData("hegemony",1) end

	if getGameData("roomid")==0 then 
		setGameData("roomid",os.time())
		setTurnData("wen",0)
		setTurnData("wu",0)
		setTurnData("expval",0)
		sqlexec("insert into results values(%d,'%s','%s','%s','%d','%s',0,1,'-',0,0,0,'')",
				getGameData("roomid"),player:getGeneralName(),player:getRole(),
				player:getKingdom(),getGameData("hegemony"),room:getMode())
	end	

	if enableLuckyCard==1 then useLuckyCard(room,owner) end
	if enableSkillCard==1 then useSkillCard(room,owner) end
	if enableHulaoCard==1 then useHulaoCard(room,owner) end

	return true
end


zgzhangong1 = sgs.CreateTriggerSkill{
	name = "#zgzhangong1",
	events = {sgs.GameStart,sgs.Damage,sgs.GameOverJudge,
			sgs.Death,
			sgs.DamageCaused,sgs.DamageComplete,sgs.TurnStart,
			sgs.HpRecover,sgs.DamageInflicted,sgs.ConfirmDamage,sgs.Damaged},
	priority = 6,
	can_trigger = function()
		return true
	end,

	on_trigger = function(self, event, player, data)
		local room = player:getRoom()
		local owner= room:getOwner():objectName()==player:objectName()
		
		if event ==sgs.GameStart and owner and room:getTag("zg_init_game"):toBool()==false then
			room:setTag("zg_init_game",sgs.QVariant(true))
			local log= sgs.LogMessage()
				if init_gamestart(self, room, event, player, data, owner) then
				log.type = "#enableZhangong"
			else
				log.type = "#disableZhangong"
			end
			room:sendLog(log)
		end

		local callbacks=zgfunc[event]
		if callbacks and getGameData("enable")==1 then
			for name, func in pairs(callbacks) do
				if type(func)=="function" then 						
					func(self, room, event, player, data, owner,name) 
				end				
			end
		end
		
		if event ==sgs.Death and owner  then
			askForGiveUp(room,player)
		end	

		return false
	end,
}

zgzhangong2 = sgs.CreateTriggerSkill{
	name = "#zgzhangong2",
	events = {sgs.CardFinished,sgs.ChoiceMade,sgs.EventPhaseStart,sgs.EventPhaseEnd,sgs.Pindian,sgs.CardEffect,
		sgs.CardEffected,sgs.SlashEffected,sgs.SlashEffect,sgs.CardsMoveOneTime,sgs.FinishRetrial},
	priority = 6,
	on_trigger = function(self, event, player, data)
		local room = player:getRoom()
		local owner= room:getOwner():objectName()==player:objectName()

		local callbacks=zgfunc[event]
		if callbacks and getGameData("enable")==1 then
			for name, func in pairs(callbacks) do
				if type(func)=="function" then 						
					func(self, room, event, player, data, owner,name) 
				end				
			end
		end
		return false
	end,
}

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


function getWinner(room,victim)
	local mode=room:getMode()
	local role=victim:getRole()

	if mode == "02_1v1" then
		local list = victim:getTag("1v1Arrange"):toStringList()		
		if #list >0  then return false end
	end

	local alives=sgs.QList2Table(room:getAlivePlayers())
	
	
	if getGameData("hegemony")==1 then				
        local has_anjiang = false
		local has_diff_kingdoms = false
        local init_kingdom
		for _, p in sgs.qlist(room:getAlivePlayers()) do
			if room:getTag(p:objectName()):toString()~="" then 
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
		if pack=="NostalGeneral" then table.insert(packages,"nostal_general") end
		table.insert(packages,string.lower(pack))
	end
	local hidden={"sp_diaochan","sp_sunshangxiang","sp_pangde","sp_caiwenji","sp_machao","sp_jiaxu","anjiang","shenlvbu1","shenlvbu2"}
	table.insertTable(generalnames,hidden)
	for _, generalname in ipairs(generalnames) do
		local general = sgs.Sanguosha:getGeneral(generalname)
		if general then
			local packname = string.lower(general:getPackage())		
			if table.contains(packages,packname) then
				general:addSkill("#zgzhangong1")
				general:addSkill("#zgzhangong2")
			end
		end
	end
end

zganjiang:addSkill(zgzhangong1)
zganjiang:addSkill(zgzhangong2)
initZhangong()


function genTranslation()
	local zgTrList={}	
	for row in db:rows("select id,name,description from zhangong") do
		zgTrList["#zhangong_"..row.id]="%from 获得了战功【<b><font color='yellow'>"..row.name.."</font></b>】,"..row.description
		zgTrList[row.id]=row.name
	end
	return zgTrList
end


sgs.LoadTranslationTable(genTranslation())

sgs.LoadTranslationTable {
	["zhangong"] ="战功包",
	["#gainWen"] ="%from获得【%arg】点文功",
	["#gainWu"] ="%from获得【%arg】点武功",
	["#gainExp"] ="%from获得【%arg】点经验",
	["#canntGainSkill"]= "【警告】无法获得技能【%arg】",
	["#gainSkill"]="%from获得了技能卡【%arg】",
	["#gsyNum"]="%from清除了【%arg】盘逃跑记录",
	["@chooseskill"]="流失体力获得技能",
	["cancel"] = "取消",
	["giveup"] = "立即认输并结束游戏",
	["#enableZhangong"]="【<b><font color='green'>提示</font></b>】: 本局游戏开启了战功统计",
	["#disableZhangong"]="【<b><font color='red'>提示</font></b>】: 本局游戏禁止了战功统计",
	["useLuckyCard"]  ="手气卡",
	["useHulaoCrad"]  ="点将卡",
	["@chooseGeneral0"]  ="请为主公选将",
	["@chooseGeneral1"]  ="请为先锋选将",
	["@chooseGeneral2"]  ="请为中坚选将",
	["@chooseGeneral3"]  ="请为大将选将",
	["randSelect"]  ="随机选择",
	

	["#LuckyCardNum"]  ="【<b><font color='yellow'>手气卡</font></b>】: 本局还有【%arg】次换牌机会",
	
}
