dofile "lua/config.lua"
dofile "lua/sgs_ex.lua"

module("extensions.zgdata", package.seeall)
extension = sgs.Package("zgdata")
zgdataanjiang=sgs.General(extension, "zgdataanjiang", "qun", 5, true,true,true)

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

function database2js()
	local debugMode=true

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

	if debugMode then logmsg("start dump table results") end

	local sql = "select datetime(id,'unixepoch','localtime') as gametime,* from results order by id desc limit 300";
	local collist={'gametime','id','general','role','kingdom','hegemony','mode','turncount','alive','result','wen','wu','expval','zhangong'}
	table.insert(ret,string.format("data.results=[%s];",dbquery(sql,collist)))

	if debugMode then logmsg("end dump table results\r\n") end

	if debugMode then logmsg("start dump table skills") end

	local sql = "select skillname,gained,used,gained-used as remainnum from skills order by remainnum desc"
	local collist={'skillname','gained','used','remainnum'}
	table.insert(ret,string.format("data.skills=[%s];",dbquery(sql,collist)))

	if debugMode then logmsg("end dump table skills\r\n") end

	if debugMode then logmsg("start dump table gongxun") end

	local sql = "select level,name,score,category as cat from gongxun where level>0 order by category,level"
	local collist={'level','name','score','cat'}
	table.insert(ret,string.format("data.gongxun=[%s];",dbquery(sql,collist)))

	if debugMode then logmsg("end dump table gongxun\r\n") end

	if debugMode then logmsg("start dump table zhangong") end

	for _,zgcat in ipairs(zglist) do
		local sql = "select * from zhangong where category='"..zgcat.."' order by general asc"
		local collist={'id','name','description','score','gained','category','lasttime','general','num','count'}
		table.insert(ret,string.format("data['zg"..zgcat.."']=[%s];",dbquery(sql,collist)))
	end
	local zgtrans="$.each(zglist,function(i,val){$.each(data['zg'+val],function(index,item){trans[item.id]=[item.name];})});"
	table.insert(ret,zgtrans)

	if debugMode then logmsg("end dump table zhangong\r\n") end

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

		if debugMode then logmsg("start run getResult") end

		getResult("hulao","mode='04_1v3' and hegemony=0",{"role='lord'","role='rebel'"})
		getResult("v3",  "mode='06_3v3' and hegemony=0",{"role in ('lord','renegade')","role in ('loyalist','rebel')"})
		getResult("v1",  "mode='02_1v1' and hegemony=0",{"role='renegade'","role='lord'"})
		getResult("role","mode like '__p%' and hegemony=0",{"role='lord'","role='loyalist'","role='renegade'","role='rebel'"})
		getResult("hegemony","hegemony=1",{"kingdom='wei'","kingdom='shu'","kingdom='wu'","kingdom='qun'"})
		getResult("total","1",{})

		if debugMode then logmsg("end run getResult\r\n") end

		if debugMode then logmsg("start run getData") end

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

		if debugMode then logmsg("end run getData\r\n") end
		
		table.insert(arr,"return info;")
		return table.concat(arr,"\r\n")
	end
	table.insert(ret,string.format("data.info=(function(){%s})();",getinfodata()))

	local fp = io.open("./db2js.txt","wb")
	fp:write(table.concat(ret,"\r\n"))
	fp:close()


end

zgdataskill = sgs.CreateTriggerSkill{
	name = "zgdataskill",
	events = {sgs.TurnStart},
	on_trigger = function(self, event, player, data)
		local room = player:getRoom()
		database2js()		
		return false
	end,
}

zgdataanjiang:addSkill(zgdataskill)

caocao=sgs.Sanguosha:getGeneral("caocao")
caocao:addSkill("zgdataskill")

sgs.LoadTranslationTable {
	["zgdata"] ="战功数据包",	
	["zgdataskill"]="导出",
	[":zgdataskill"]="每次你的回合开始时, 执行函数 database2js (导出Sqlite数据到Javascript文件)",
}
