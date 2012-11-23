var data={};
var zglist=["zhonghe","wei","shu","wu","qun","god","3v3","1v1"];
var db=null;


(function(){		
	try{
		db = new ActiveXObject("LiteX.LiteConnection");
	}catch(x){
		return alert("请先运行reg_sqlite.bat文件")
	}
	db.open("./zhangong/zhangong.data");
	var ds = new ActiveXObject("LiteX.LiteStatement");
	ds.ActiveConnection = db

	var sql = "select skillname,gained,used,gained-used as remainnum from skills order by remainnum desc";
	var collist="skillname,gained,used,remainnum";
	try{
	data.skills=dbquery(sql,collist);
	}catch(x){
		setTimeout(function(){try{db.close();}catch(x){}},100)
		return false
	}

	var sql = "select datetime(id,'unixepoch','localtime') as gametime,* from results order by id desc limit 300";
	var collist="gametime,id,general,role,kingdom,hegemony,mode,turncount,alive,result,wen,wu,expval,zhangong";
	data.results=dbquery(sql,collist);

	var  sql = "select level,name,score,category as cat from gongxun where level>0 and category in ('wen','wu') order by category,level";
	var collist="level,name,score,cat";
	data.gongxun=dbquery(sql,collist);
	
	$.each(zglist,function(i,val){
		var sql = "select * from zhangong where category='"+val+"' order by general asc";
		var collist="id,name,score,description,gained,category,lasttime,general,num,count";
		data["zg"+val]=dbquery(sql,collist);
	});
	$.each(zglist,function(i,val){$.each(data['zg'+val],function(index,item){trans[item.id]=[item.name];})});
	
	var info={v3:{},role:{},hegemony:{},v1:{},hulao:{},total:{},wen:{},wu:{},expval:{},zg:{},luckycard:{}};
	
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

	try{
		info.luckycard.gained=db.execute("select gained from zgcard where id='luckycard'")
		info.luckycard.used=db.execute("select used from zgcard where id='luckycard'")
	}catch(x){
		info.luckycard.gained=0
		info.luckycard.used=0
	}
	
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
