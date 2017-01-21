exports.client_addGame = (bggId) !->
	gamesDb = Db.shared.ref 'games'
	if not gamesDb.get bggId
		log 'adding new game', bggId
		Db.shared.set 'games', bggId, 'addedTime', App.time()

	# update anyway (?)
	url = 'https://www.boardgamegeek.com/xmlapi/boardgame/'+bggId
	Http.get
		url: url
		cb: ['setGameInfo', bggId]

exports.setGameInfo = (bggId, data) !->
	log 'got response', data.status
	# called when the Http API has the result for the above request
	if data.status != '200 OK'
		log 'failed to get game info for ' + bggId
		log 'Error code: ' + data.status
		log 'Error msg: ' + data.error
	else
		log data.body.substr 50, 150
		tree = Xml.decode data.body
		result = {}

		unless bg = Xml.search(tree, '*. boardgame')[0]
			return

		log 'the search is on...'
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

		log 'total result:', result
		Db.shared.merge 'games', bggId, result

exports.client_rateGame = (bggId, rating) !->
	unless game = Db.shared.ref 'games', bggId
		log 'user', App.userId(), 'tried to rate game', bggId
		return
	game.set 'ratings', App.userId(), rating

exports.onUpgrade = !->
	Db.shared.iterate 'games', (game) !->
		url = 'https://www.boardgamegeek.com/xmlapi/boardgame/' + game.key()
		Http.get
			url: url
			cb: ['setGameInfo', +game.key()]
