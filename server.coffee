exports.client_addGame = (bggId) !->
	gamesDb = Db.shared.ref 'collection'
	if not gamesDb.get bggId
		log 'adding new game', bggId
		Db.shared.set 'collection', bggId, 'addedTime', App.time()

	# update anyway (?)
	url = 'https://www.boardgamegeek.com/xmlapi/boardgame/'+bggId
	Http.get
		url: url
		cb: ['setGameInfo', bggId]

exports.setGameInfo = (bggId, data) !->
	# called when the Http API has the result for the above request
	if data.status != '200 OK'
		log 'failed to get game info for ' + bggId
		log 'Error code: ' + data.status
		log 'Error msg: ' + data.error
	else
		tree = Xml.decode data.body
		result = {}

		unless bg = Xml.search(tree, '*. boardgame')[0]
			return

		if meta = Xml.search(bg, '*.', {tag: 'name', primary:'true'})[0]
			result.name = meta.innerText

		if meta = Xml.search(bg, '*.', {tag: 'yearpublished'})[0]
			result.yearpublished = meta.innerText

		if meta = Xml.search(bg, '*.', {tag: 'image'})[0]
			result.image = 'http:' + meta.innerText

		if meta = Xml.search(bg, '*.', {tag: 'thumbnail'})[0]
			result.thumbnail = 'http:' + meta.innerText

		if meta = Xml.search(bg, '*.', {tag: 'description'})[0]
			result.description = meta.innerText

		result.url = "https://boardgamegeek.com/boardgame/#{bggId}/"

		Db.shared.merge 'collection', bggId, result

exports.client_rateGame = (bggId, rating) !->
	if game = Db.shared.ref 'collection', bggId
		game.set 'ratings', App.userId(), rating
	else
		log 'user', App.userId(), 'tried to rate game', bggId

exports.client_addPlay = (gameId, playerIds, winnerId) !->
	obj =
		gameId: gameId
		playerIds: playerIds
		winnerId: winnerId
		time: App.time()
		addedBy: App.userId()
	maxId = Db.shared.incr 'plays', 'maxId'
	Db.shared.set 'plays', maxId, obj

updateCollection = !->
	Db.shared.iterate 'collection', (game) !->
		url = 'https://www.boardgamegeek.com/xmlapi/boardgame/' + game.key()
		Http.get
			url: url
			cb: ['setGameInfo', +game.key()]

exports.onUpgrade = !->
	if Db.shared.get('games')
		Db.shared.merge 'collection', Db.shared.get('games')
		Db.shared.merge 'games', null
