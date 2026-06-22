local SeasideMarketFeatureLib = {
	page = {
		feature = {"37|723|f51b67-101010,189|95|14633c-101010,477|128|b2d155-101010,448|285|f5365e-101010,1409|828|895b3d-101010,1508|320|57432a-101010" , 0.9} ,
		refreshBtn = {1419 , 458 , 1459 , 480} ,
		refreshStatusOcr = {1298 , 447 , 1557 , 488} ,
		canRefreshOcr = {1358 , 449 , 1496 , 486} ,
		箭头 = {1524,616,1577,684,"000000-101010|000000-101010|000000-101010|030303-101010|030303-101010|12110d-101010",0,0.9}
	} ,
	dialogConfirm = {
		feature = {"120|127|126345-101010,38|720|7f0e37-101010,339|241|2e5825-101010,478|128|5a692a-101010,1152|237|36a6e8-101010,455|220|686f9d-101010,1471|829|44351e-101010" , 0.9} ,
		confirmBtn = {776 , 621 , 829 , 646} ,
		cancelBtn = {1143 , 211 , 1159 , 229}
	} ,
	itemShortageDialog = {
		feature = {"1559|854|261010-101010,27|717|710b2d-101010,131|222|1a3722-101010,351|273|7f7f55-101010,475|129|58682a-101010,517|246|68709d-101010,1092|265|36a5e5-101010" , 0.9} ,
		itemShortageOcr = {715 , 331 , 885 , 376} , 	-- 以下道具不足,
		cancelBtn = {1086 , 231 , 1102 , 253}
	}
}

local Stock = {
	-- 全部为findMultiColorT参数
	灿烂的光之碎片 = {3 , 602 , 1587 , 707 , "a9e4ff-101010" , "-7|-1|fffff3-101010|-34|-1|cfefb9-101010|14|1|cf97f6-101010|8|20|ef84a9-101010|-3|27|fad4a2-101010|-14|29|ee7fe3-101010|38|16|320f5d-101010|-24|-19|31105a-101010" , 0 , 0.9} ,
	十分钟加速券 = {3 , 602 , 1587 , 707 , "ffffff-101010" , "0|-1|ffffff-101010|-4|12|2bd0e9-101010|-1|-25|6786bd-101010|-19|24|4168ad-101010|-40|0|6496c9-101010|37|-12|f9ffff-101010|36|17|c8e9f6-101010" , 0 , 0.9}
}

SeasideMarketFeatureLib.page.closeBtn = SeasideMarketFeatureLib.page.closeBtn or {1530 , 14 , 1584 , 77}
SeasideMarketFeatureLib.page.refreshOcr = SeasideMarketFeatureLib.page.refreshOcr
or SeasideMarketFeatureLib.page.refreshStatusOcr

SeasideMarketFeatureLib.tab = SeasideMarketFeatureLib.tab or {
	itemExchange = {
		area = {559,831,643,862} ,
	}
}

SeasideMarketFeatureLib.list = SeasideMarketFeatureLib.list or {
	arrowRight = SeasideMarketFeatureLib.page["箭头"] ,
	arrowLeft = nil ,
	swipe = {x1 = 1500 , y1 = 650 , x2 = 100 , y2 = 650 , holdMs = 1200 , upMs = 1200} ,
	maxSwipes = 20 ,
}

SeasideMarketFeatureLib.slot = SeasideMarketFeatureLib.slot or {
	buyBtnOffsetY = 110 ,
	buyBtnHalfW = 105 ,
	buyBtnHalfH = 24 ,
	crateHalfW = 90 ,
	crateHalfH = 65 ,
	crateOffsetY = - 20 ,
}

SeasideMarketFeatureLib.stock = Stock
SeasideMarketFeatureLib.Stock = Stock

return SeasideMarketFeatureLib
