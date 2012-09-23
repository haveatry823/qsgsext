var data={};
var zglist=["zhonghe","wei","shu","wu","qun","god","3v3","1v1"];
var db=null;


(function(){		
	try{
		db = new ActiveXObject("LiteX.LiteConnection");
	}catch(x){
		return alert("请先运行zhangong/sqlite.bat文件注册sqlite3.dll")
	}
	db.open("./zhangong/zhangong.data");
	var ds = new ActiveXObject("LiteX.LiteStatement");
	ds.ActiveConnection = db

	var sql = "select skillname,gained,used,gained-used as remainnum from skills order by remainnum desc";
	var collist="skillname,gained,used,remainnum";
	data.skills=dbquery(sql,collist);

	var sql = "select datetime(id,'unixepoch','localtime') as gametime,* from results order by id desc limit 300";
	var collist="gametime,id,general,role,kingdom,hegemony,mode,turncount,alive,result,wen,wu,expval";
	data.results=dbquery(sql,collist);
	
	

	$.each(zglist,function(i,val){
		var sql = "select * from zhangong where category='"+val+"' order by general asc";
		var collist="id,name,score,description,gained,category,lasttime,general,num";
		data["zg"+val]=dbquery(sql,collist);
	});
	
	var info={v3:{},role:{},hegemony:{},v1:{},hulao:{},total:{},wen:{},wu:{},expval:{},zg:{}};
	
	function getResult(mode,cond,ratearr){
		info[mode].winnum=db.execute("select count(id) from results where " + cond +" and result='win'");
		info[mode].losenum=db.execute("select count(id) from results where " + cond +" and result='lose'");
		info[mode].escnum=db.execute("select count(id) from results where " + cond +" and result='-'");
		info[mode].totalnum=(info[mode].winnum + info[mode].losenum + info[mode].escnum) || 1;
		info[mode].winrate=(100 *info[mode].winnum/info[mode].totalnum).toFixed(1)+"%";
		for(var i=0;i<ratearr.length;i++){
			info[mode]["winnum_"+(i+1)]	 = db.execute("select count(id) from results where " + cond +" and result='win' and "+ratearr[i]);
			info[mode]["totalnum_"+(i+1)]= db.execute("select count(id) from results where " + cond +"  and "+ratearr[i]) || 1;
			info[mode]["winrate_"+(i+1)] = (100*info[mode]["winnum_"+(i+1)] / info[mode]["totalnum_"+(i+1)]).toFixed(1)+"%";
		}
	}
	getResult("hulao","mode='04_1v3' and hegemony=0",["role='lord'","role='rebel'"]);
	getResult("v3",  "mode='06_3v3' and hegemony=0",["role in ('lord','renegade')","role in ('loyalist','rebel')"]);
	getResult("v1",  "mode='02_1v1' and hegemony=0",["role='renegade'","role='lord'"]);
	getResult("role","mode like '__p%' and hegemony=0",["role='lord'","role='loyalist'","role='renegade'","role='rebel'"]);		
	getResult("hegemony","hegemony=1",["kingdom='wei'","kingdom='shu'","kingdom='wu'","kingdom='qun'"]);	
	getResult("total","1",[]);	
	
	info.wen.score=db.execute("select sum(wen) from results") || 0;
	info.wu.score=db.execute("select sum(wu) from results") || 0;
	
	info.expval.score=db.execute("select sum(expval) from results") || 0;
	info.expval.level=Math.ceil(Math.pow(info.expval.score,1/3));
	
	info.zg.num=db.execute("select count(id) from zhangong where gained>0");
	info.zg.total=db.execute("select count(id) from zhangong");
	info.zg.score=db.execute("select sum(score*gained) from zhangong where gained>0") || 0;

	info.wen.level=db.execute("select level from gongxun where category='wen' and score>=? order by score asc limit 1",info.wen.score);
	info.wen.name=db.execute("select name from gongxun where category='wen' and score>=? order by score asc limit 1",info.wen.score);
	
	info.wu.level=db.execute("select level from gongxun where category='wu' and score>=? order by score asc limit 1",info.wu.score)
	info.wu.name=db.execute("select name from gongxun where category='wu' and score>=? order by score asc limit 1",info.wu.score)
	
	info.total.starttime=db.execute("select datetime(min(id),'unixepoch','localtime') from results") || "尚未开始统计";

	data.info=info;
	function dbquery(sql,collist){
		var ds=db.prepare(sql);
		var ret=[]
		while (!ds.Step()){
			var arr=[];
			var cols=collist.split(",")
			for (var i=0;i<cols.length;i++){
				arr[ds.ColumnName(i)]=ds.ColumnValue(cols[i])
			}
			ret.push(arr);
		}
		return ret;
	}		
	ds.close();
	ds=null;
	setTimeout(function(){try{db.close();}catch(x){}},100)
})()	

function resetDB(){
	if (!confirm("你确认要清除所有游戏记录，技能卡，以及战功记录吗?")) return false;	
	db.open("./zhangong/zhangong.data");
	db.execute("delete from results;");		
	db.execute("update gamedata set num=0;");
	db.execute("update skills set gained=0,used=0;");
	db.execute("update zhangong set gained=0;");
	db.execute("vacuum");	
	alert("操作成功")
	try{
		db.close();
	}catch(x){}
	location.reload();
	return false;
}


function clearEsc(){
	if (!confirm("即将删除所有回合数小于5的逃跑记录，要继续吗?")) return false;	
	db.open("./zhangong/zhangong.data");
	db.execute("delete from results where result='-' and turncount<5;");		
	db.execute("vacuum");		
	try{
		db.close();
	}catch(x){}
	alert("操作成功")
	location.reload();
	return false;
}

