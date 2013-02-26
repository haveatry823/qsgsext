sgs.ai_event_callback[sgs.GameStart].zhangong=function(self,player,data)
	if player:objectName() ~= self.room:getOwner():objectName() then return end
	for _,p in sgs.qlist(self.room:getAllPlayers()) do
		self.room:acquireSkill(p,"#zgzhangong1")
		self.room:acquireSkill(p,"#zgzhangong2")
	end
end