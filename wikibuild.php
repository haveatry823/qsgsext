<? 
error_reporting(0xffff);
if (!extension_loaded('pdo')) dl('php_pdo.dll');
if (!extension_loaded('pdo_sqlite')) dl('php_pdo_sqlite.dll');

$dbfile="./zhangong/zhangong.data";

$db = new PDO("sqlite:$dbfile"); 
if (!$db){
	echo "can not load dbfile\r\n";	
	exit(1);
}

if (isset($argv[1]) && is_callable($argv[1])){
	call_user_func($argv[1],array_slice($argv,2));
}else{
	echo "params error\r\n";
	exit(2);
}

function zhangong($arg=array()){
	global $db;
	$zglist=array("zhonghe","wei","shu","wu","qun","god","3v3","1v1");
	$count=0;
	foreach ($zglist as $key => $value) {
		$query=$db->query("select * from zhangong where category='$value' order by general asc");
		foreach ($query as $row){
			extract($row);
			$catestr= ($category=="3v3" or $category=="1v1") ? "(限{$category})" : "";
			if (in_array($category, array("wei","shu","wu","qun","god"))){
				$imgstr="";
			}else{
				$imgstr="![$name](https://qsgsext.googlecode.com/svn/trunk/zhangong/img/$id.png)";
			}			
			$count++;
			$item="
$count. $imgstr
$name
`$id: $description{$catestr}`
";			
			file_put_contents("zhangong.wiki", $item, FILE_APPEND);
		} 	
	}	
}
