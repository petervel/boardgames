{tr} = require 'i18n'

exports.render = !->
	pageName = Page.state.get(0)
	switch pageName
		when 'collection'
			if gameId = Page.state.get(1)
				return renderGamePage +gameId
			else
				return renderCollectionPage()
		when 'addPlay'
			return renderAddPlayPage()
		else
			if gameId = +pageName
				return renderPlaypage gameId
	renderMainpage()

renderIcon = (url, style) !->
	Dom.div !->
		Dom.style
			width: '50px'
			height: '30px'
			marginRight: '10px'
			borderRadius: '3px'
			background: "transparent url(#{url}) no-repeat center center"
			backgroundSize: 'contain'
		Dom.style style if style

renderPlayerSelector = (unavailable, current, choose) !->
	Modal.show tr("Select player"), !->
		App.users.iterate (user) !->
			if +user.key isnt current
				return if +user.key() in unavailable or not user.get('symbol')
			Ui.item
				avatar: user.get('avatar')
				content: user.get('name')
				onTap: !->
					choose +user.key()
					Modal.remove()
			# TODO: sort by plays, e.g. -Db.shared.get('players', user.key(), 'matches') ? 0

renderGameSelector = (currentId) !->
	currentGame = Db.shared.ref 'collection', currentId.peek()
	Modal.show tr("Select game"), !->
		Db.shared.iterate 'collection', (game) !->
			Ui.item
				avatar: !-> renderIcon game.get('thumbnail')
				content: game.get('name')
				onTap: !->
					currentId.set +game.key()
					Modal.remove()
			# TODO: sort by plays, e.g. -Db.shared.get('players', user.key(), 'matches') ? 0

renderAddPlayPage = !->
	gameId = Obs.create()
	Ui.item !->
		Dom.style Box: 'horizontal middle', marginBottom: '30px'

		Dom.onTap !->
			renderGameSelector gameId

		if not gameId.get()
			Dom.div !->
				Dom.style height: '40px', width: '40px', lineHeight: '40px', fontSize: '20px', textAlign: 'center', borderRadius: '50%', background: '#ccc', marginRight: '10px', color: '#fff'
				Dom.text "?"
			Dom.span !->
				Dom.style color: '#ccc'
				Dom.text tr("Select game")
			return

		game = Db.shared.ref 'collection', gameId.get()

		renderIcon game.get('thumbnail')
		Dom.div !->
			Dom.style Flex: 1
			Dom.text "#{game.get('name')} (#{game.get('yearpublished')})"


	# default to the user adding being one of the players
	players = Obs.create {0: App.userId()}
	playerIds = Obs.create []
	Obs.observe !-> playerIds.set (+v for k,v of players.get())

	Dom.div !-> Dom.text tr("Players:")

	players.iterate (player) !->
		Ui.item !->
			if player.get()
				Ui.avatar App.memberAvatar(player.get())
				Dom.text App.userName(player.get())
			else
				Ui.avatar(0, '#ccc')

			if playerIds.get().length < App.users.count().get()
				Dom.onTap !->
					renderPlayerSelector playerIds.get(), +player.key(), (chosen) !->
						players.set player.key(), chosen
	, (player) -> +player.key()

	# add another player
	Obs.observe !->
		return unless playerIds.get().length < App.users.count().get()
		Ui.item !->
			Ui.avatar(0, '#ccc')
			Dom.style color: '#ccc'
			Dom.text tr("Add player")
			Dom.onTap !->
				renderPlayerSelector playerIds.get(), 0, (chosen) !->
					players.set players.count().get(), chosen

	# winner
	Obs.observe !->
		return unless gameId.get() and players.count().get() > 1

		winner = Obs.create()
		Dom.div !->
			Dom.style marginTop: '30px'
			Dom.text tr("Winner:")

		Ui.item !->
			if winnerId = +winner.get()
				Dom.style color: 'inherit'
				Ui.avatar App.memberAvatar(winnerId)
				Dom.text App.userName(winnerId)
			else
				Dom.style color: '#ccc'
				Ui.avatar(0, '#ccc')
				Dom.text tr("Select winner")

			if players.count().get() > 1
				Dom.onTap !->
					nonPlayers = (+u for u of App.users.peek() when +u not in playerIds.get())
					log 'non players:', nonPlayers
					renderPlayerSelector nonPlayers, 0, (chosen) !->
						winner.set chosen

		Obs.observe !->
			if gameId.get() and players.count().get() > 1 and winner.get()
				Ui.bigButton tr("Add play"), !->
					Server.send 'addPlay', gameId.get(), playerIds.get(), winner.get()
					Page.nav '/'

renderPlaypage = (playId) !->
	play = Db.shared.ref 'plays', playId

	Comments.enable store: ['plays', playId, 'comments']
	if not game = Db.shared.ref 'collection', play.get('gameId')
		Dom.text tr("Game not found")
		return

	renderGameHeader game

	Dom.div !->
		Dom.style color: '#aaa', fontSize: '0.8em', margin: '5px 0', textAlign: 'center'
		Time.deltaText play.get 'time'

	Dom.div !->
		Dom.style marginTop: '20px'
		Dom.text tr("Players:")
	for playerId in play.get 'playerIds'
		Ui.item !->
			Dom.style Box: 'horizontal middle'

			Ui.avatar
				key: App.userAvatar playerId
				onTap: !-> App.showMemberInfo playerId

			Dom.div !->
				Dom.style Flex: 1
				Dom.text "#{App.users.get(playerId).name}"

	Dom.div !->
		Dom.style marginTop: '20px'
		Dom.text tr("Winner:")

	Ui.item !->
		Dom.style Box: 'horizontal middle'

		Ui.avatar
			key: App.userAvatar play.get 'winnerId'
			onTap: !-> App.showMemberInfo play.get 'winnerId'

		Dom.div !->
			Dom.style Flex: 1
			Dom.text "#{App.users.get(play.get 'winnerId').name}"

renderMainpage = !->
	Dom.div !->
		Dom.style Box: 'horizontal middle'
		Dom.div !->
			Dom.style Flex: 1, margin: '0 3px'
			Ui.bigButton "Add play", !-> Page.nav 'addPlay'
		Dom.div !->
			Dom.style Flex: 1, margin: '0 3px'
			Ui.bigButton "collection", !-> Page.nav 'collection'

	Obs.observe !->
		return unless Db.shared.get('plays')
		Dom.div !-> Dom.text "Played games:"

		Db.shared.iterate 'plays', (play) !->
			return unless game = Db.shared.get 'collection', (play.get('gameId'))
			Ui.item !->
				Dom.style Box: 'horizontal middle'

				renderIcon game.thumbnail

				Dom.div !->
					Dom.style Flex: 1
					Dom.text "#{game.name}"

				winnerId = +play.get 'winnerId'
				Ui.avatar
					key: App.userAvatar winnerId
					onTap: !-> App.showMemberInfo winnerId

				Dom.onTap !-> Page.nav play.key()
		, (play) -> -play.get('time')

sortModes = [
	{
		name: 'newest'
		orderFunc: (game) -> -game.get('addedTime')
	},
	{
		name: 'rating',
		orderFunc: (game) ->
			avg = getAverage game.ref('ratings')
			if avg?
				-avg
			else
				[0, -game.get('addedTime')]
	}
]

renderCollectionPage = !->
	ordering = Obs.create(0)

	if App.userIsAdmin()
		Ui.bigButton "add game", !->
			Modal.prompt "Enter BGG id", (id) !->
				Server.call 'addGame', id

	Dom.div !->
		Dom.style position: 'relative', margin: '10px'

		Comments.enable store: ['collection', 'comments']

		Page.setActions
			icon: 'sort'
			label: "sorted by " + sortModes[ordering.get()].name
			action: !-> ordering.modify (val) -> (val + 1) % sortModes.length

		Dom.div !->
			Dom.style fontSize: '0.8em', color: '#aaa', textAlign: 'center'
			Dom.text "sorted by: " + sortModes[ordering.get()].name

		Db.shared.iterate 'collection', (game) !->
			return unless game.get('name')
			Ui.item !->
				Dom.style Box: 'horizontal middle'
				renderIcon game.get('thumbnail')
				Dom.div !->
					Dom.style Flex: 1
					Dom.text "#{game.get('name')} (#{game.get('yearpublished')})"

				renderAverage game.ref('ratings')

				Dom.onTap !-> Page.nav ['collection', game.key()]
		, (game) -> sortModes[ordering.get()].orderFunc game

getAverage = (ratings, only) !->
	sum = 0
	count = 0
	ratings.iterate (rating) !->
		if only?
			return unless +rating.key() in only # skip those we aren't counting
		sum += +rating.get()
		count++

	if count
		return sum / count

renderAverage = (ratings, only) !->
	Dom.div !->
		Dom.style Box: 'horizontal middle', lineHeight: '25px', fontSize: '11pt'
		if (avg = getAverage ratings, only)?
			Dom.div !->
				Dom.style margin: '6px 3px 0'
				Dom.text Math.round(10*avg)/10
		Dom.div !->
			Icon.render
				data: 'star'
				size: '25'
				color: if avg? then '#ffaa00' else '#aaa'

renderStar = (nr, rating, rateFunc) !->
	Dom.span !->
		Icon.render
			data: if not rating? or nr > rating then 'star-outline' else 'star'
			size: '25'
			color: if not rating? then '#ccc' else '#ffaa00'
			onTap: !-> rateFunc? nr

renderStars = (rating, rateFunc) !->
	for i in [1..5]
		renderStar i, rating, rateFunc

renderGameHeader = (game) !->
	if thumbnail = game.get 'thumbnail'
		hiRes = Obs.create()
		Dom.div !->
			imgUrl = hiRes.get() ? thumbnail
			Dom.style margin: '0', display: 'block', height: '80%', maxHeight: '200px', position: 'relative'
			Dom.style backgroundImage: "url(#{imgUrl})", backgroundSize: 'cover', backgroundPosition: 'center'
			unless hiRes.get()?
				Dom.onTap !-> if image = game.get 'image' then hiRes.set image

			# overlay
			Dom.div !->
				Dom.style background: '-webkit-linear-gradient(top, rgba(0, 0, 0, 0) 0px, rgba(0, 0, 0, 0.6) 100%)', padding: '5px 10px', Box: 'horizontal bottom'
				Dom.style position: 'absolute', bottom: '0px', width: '100%', height: '50%', boxSizing: 'border-box'
				Dom.style color: '#eee'
				Dom.div !->
					Dom.style Flex: 1, fontSize: '15pt'
					Dom.text "#{game.get 'name'} (#{game.get('yearpublished')})"
				Dom.div !->
					Dom.text "More Info"
					Dom.onTap !-> App.openUrl game.get('url')

renderGamePage = (gameId) !->
	Comments.enable
		store: ['collection', gameId, 'comments']
		inline: true

	game = Db.shared.ref 'collection', gameId

	renderGameHeader game

	Ui.item !->
		Dom.style Box: 'horizontal middle'
		Dom.h2 !->
			Dom.style Flex: 1
			Dom.text "Ratings"
		Dom.div !->
			renderAverage game.ref 'ratings'

	Ui.item !->
		Dom.style Box: 'horizontal middle'
		Ui.avatar
			key: App.userAvatar()
			onTap: !-> App.showMemberInfo()
		Dom.div !->
			Dom.style Flex: 1, fontWeight: 'bold'
			Dom.text "Your rating"
		Dom.div !-> renderStars game.get('ratings', App.userId()), (nr) !->
			Server.sync 'rateGame', gameId, nr, !->
				game.set 'ratings', App.userId(), nr

	game.iterate 'ratings', (rating) !->
		userId = +rating.key()
		return if userId is App.userId() or App.userIsMock userId
		Ui.item !->
			Dom.style Box: 'horizontal middle'
			Ui.avatar
				key: App.userAvatar userId
				onTap: !-> App.showMemberInfo userId

			Dom.div !->
				Dom.style Flex: 1
				Dom.text App.userName userId

			Dom.div !-> renderStars rating.get()

