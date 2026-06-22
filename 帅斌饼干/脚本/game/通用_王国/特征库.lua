local KingdomFeatureLib = {}

local home = {
	feature = {"1380|60|f7e5cb-101010,59|323|b3001b-101010,96|825|fbed78-101010,274|838|85b7f7-101010,1535|854|2f4c6c-101010,1311|845|d99f26-101010" , 0.9} ,
	eventBtn = {256 , 800 , 269 , 831} ,
	squareBtn = {589 , 811 , 616 , 830},
	adventureBtn = {1371,812,1403,831}
}

local event = {
	feature = {"1311|843|261d06-101010,722|820|2d1f00-101010,235|825|2d2718-101010,69|805|252625-101010,71|332|2e2a1f-101010,795|140|b59756-101010,1290|65|2a1c0f-101010,1551|69|36a3e3-101010" , 0.9} ,
	mineBtn = {1228 , 578 , 1253 , 601} ,
	seasideMarketBtn = {574 , 582 , 593 , 604}
}

local adventure = {
	feature = {"40|61|61a1eb-101010,59|50|dde7e7-101010,28|72|f3cf4e-101010,71|73|d7ad37-101010,1552|70|36a5e3-101010,1066|65|07b3fb-101010,782|62|eba900-101010",0.9},
	arenaOcr = {39,201,1592,282}
}

function KingdomFeatureLib.home()
	return home
end

function KingdomFeatureLib.event()
	return event
end

function KingdomFeatureLib.adventure()
	return adventure
end

return KingdomFeatureLib
