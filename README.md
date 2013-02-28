lua 扩展for [太阳神三国杀](https://github.com/gaodayihao/QSanguosha)
===========================

版本与下载
--------

* 新神杀0224:  https://github.com/haveatry823/qsgsext/zipball/master
* 踏青，涅槃，高达，雪霁，金蛇： https://github.com/haveatry823/qsgsext/archive/niepan.zip

功能
----------

1. 战功成就系统
    * OL的251的战功全部用lua实现并移植到新神杀(刘备,关羽,赵云等少数N(N<5)个战功因为技术问题对战功做了修改)
    * 文功,武功,经验值,等级,官职系统的实现.
    * 技能卡: 游戏中每杀死一个人可随机获得一个武将技能，这些技能可以在以后的游戏开始时使用
    * 投降: 如果你阵亡,在死亡事件结算完毕后,系统会询问你是否投降并立即结束游戏,此举旨在降低逃跑率.
    * 游戏记录: 系统将记录你所有的游戏成绩,并显示最近300盘游戏成绩
    * 本系统用sqlite3作为数据库保存保存所有相关数据
    * 用hta作为前端结果显示与查看界面    

FAQ
----

1. 战功成就系统
   * 战功系统启用的前提是: 除了房主自己外，要求其他玩家均为AI. 战功系统只记录房主的成就
   * 以下情况下，战功系统不会被启用:  多人联机对战,  多开, 自定义小场景, 情景模式
   * 目前因为程序不完善需要测试，允许以作弊的方式(开启自由选将)取得战功,以后开启作弊将禁止战功
   * 战功系统支持游戏原生所有武将(测试包除外), 玩家自己DIY的武将不计算战功(指lua的武将)
   

安装
----

1. 战功成就系统
   * 下载本扩展包,解压后复制所有文件到神杀的游戏目录。
   * 保证 libluasqlite3.dll, lua5.1.dll, lua51.dll 和游戏主程序QSanguosha.exe 在同一个目录就好了
   * xp,win7,vista系统图文教程 http://tieba.baidu.com/p/2016100855
   * win8 系统图文教程 http://tieba.baidu.com/p/2015939724
   * 如果上述步骤都OK, 就可打开 zhangong.hta 来查看战功了.


截图
------
1. 战功成就系统
   * ![战功1](https://qsgsext.googlecode.com/svn-history/r23/wiki/overview.jpg)
   * 
   * ![战功2](https://qsgsext.googlecode.com/svn-history/r23/wiki/zhonghe.jpg)
   * 
   * ![战功2](https://qsgsext.googlecode.com/svn-history/r23/wiki/qun.jpg)
   * 
   * ![战功2](https://qsgsext.googlecode.com/svn-history/r23/wiki/results.jpg)
   * 
    


