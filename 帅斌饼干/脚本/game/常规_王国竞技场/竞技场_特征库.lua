--[[
模块: 王国竞技场特征库
路径: game.常规_王国竞技场.竞技场_特征库
--]]

return {
	lobby = {
		feature = {"74|186|33f2f8-101010,75|173|ffe400-101010,74|313|cf7b34-101010,75|512|be6928-101010,72|389|ef8421-101010" , 0.95} ,
		closeBtn = {1530 , 14 , 1584 , 77} ,
		medalTicketOcr = {876 , 20 , 1270 , 77} ,
		trophyOcr = {177 , 733 , 359 , 777} ,
		refreshOcr = {1345 , 733 , 1549 , 777} ,
		freeRefreshOcr = {1361 , 734 , 1541 , 774} ,
		freeRefreshTap = {1421 , 758} ,
		buyTicketBtn = {1213 , 48} ,
		buyTicketSlider = {605 , 635 , 731 , 635} ,
		buyTicketConfirm = {1056 , 609} ,
	} ,
	opponent = {
		findDef = {560 , 478 , 1589 , 556 , "1cc2e2-101010" , "-1|7|fbcf00-101010|-1|-12|c65d00-101010|-11|-2|e32840-101010|1|18|fedd00-101010" , 0 , 0.95} ,
		baseSite = {643 , 531} ,
		powerRect = {665 , 484 , 803 , 512} ,
		trophyRect = {664 , 521 , 806 , 556} ,
		resultOffset = {83 , -109} ,
		resultColors = { win = "ccff33" , draw = "66ffff" , lose = "ff9999" } ,
		numberOcr = {
			recType = "number" ,
			detScaleRatio = 1.8 ,
			detUnclipRatio = 1.9 ,
			recScoreThreshold = 0.2 ,
			binaryThresh = 130 ,
			runMode = "slow" ,
			filterBg = "black" ,
		} ,
	} ,
	teamSelect = {
		feature = {"424|840|7ace0e-101010,42|835|3db8e5-101010,1477|794|7ace0e-101010,1264|825|e5b129-101010" , 0.95} ,
		startBattle = {1408 , 823} ,
	} ,
	dialog = {
		missingTopping = {
			feature = {"620|682|0ca6df-101010,1008|680|7ace0e-101010,807|195|363d5f-101010,809|804|ffffff-101010" , 0.95} ,
			confirm = {946 , 678} ,
		} ,
		deployMore = {
			feature = {"908|632|7ace0e-101010,695|632|0ca6df-101010,824|246|363d5f-101010" , 0.95} ,
			confirm = {960 , 636} ,
		} ,
	} ,
	battle = {
		startFeature = {"385|30|42cd0b-101010,1211|29|7c0cfb-101010,1558|44|cbcbcb-101010,1578|45|c1c1bf-101010" , 0.95} ,
	} ,
	settlement = {
		feature = {"1454|46|333333-101010,1451|49|ffffff-101010,1442|49|6786bd-101010,1467|56|1b2850-101010,835|94|ffff66-101010" , 0.9} ,
		resultOcr = {736 , 118 , 881 , 176} ,
		leaveFeature = {"1523|811|0ca6df-101010,1158|809|f67b4b-101010,1532|38|34a0e4-101010,1149|781|ffffff-101010" , 0.9} ,
		leaveRetryTap = {1460 , 812} ,
		leaveTap = {1464 , 792} ,
		promotionSkip = {699 , 852} ,
	} ,
	pagination = {
		swipeLeft = {1524 , 534 , 877 , 533} ,
		swipeRight = {877 , 533 , 1524 , 534} ,
	} ,
}
