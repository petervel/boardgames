exports.render = !->
	pageName = Page.state.get(0)
	#return renderRankingsPage() if pageName is 'rankings'
	return renderGamePage(+pageName) if pageName
	renderGames()

sortModes = [
	{
		name: 'most recent'
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

renderGames = !->
	ordering = Obs.create(0)
	Dom.div !->
		Dom.style position: 'relative'

		if App.userIsAdmin()
			Dom.div !->
				Dom.style Box: 'horizontal middle'
				myForm = Form.input {text: 'Enter BGG id here'}
				Ui.button "Add", !->
					Server.call 'addGame', myForm.value()
					myForm.value('')

		Dom.div !->
			Dom.style Box: 'horizontal middle'
			Dom.div !->
				Dom.style color: '#aaa', fontSize: '0.9em', textAlign: 'right', Flex: 1, marginRight: '3px'
				Dom.text "sorting by " + sortModes[ordering.get()].name
			Icon.render
				data: 'sort'
				size: '26'
				color: '#aaa'
				onTap: !->
					ordering.modify (val) -> (val + 1) % sortModes.length

		Db.shared.iterate 'games', (game) !->
			return unless game.get('name')
			Ui.item !->
				Dom.style Box: 'horizontal middle'
				Dom.div !->
					Dom.style
						width: '50px'
						height: '30px'
						marginRight: '10px'
						borderRadius: '3px'
						background: "transparent url(#{game.get('thumbnail')}) no-repeat center center"
						backgroundSize: 'contain'
				Dom.div !->
					Dom.style Flex: 1
					Dom.text "#{game.get('name')} (#{game.get('yearpublished')})"

				Obs.observe !->
					if avg = getAverage game.ref('ratings')
						Dom.text Math.round(10*avg)/10
					Dom.div !->
						Icon.render
							data: 'star'
							size: '25'
							color: '#ffaa00'

				Dom.onTap !-> Page.nav game.key()
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

renderGamePage = (gameId) !->
	Comments.enable
		store: ['games', gameId, 'comments']

	game = Db.shared.ref 'games', gameId

	if thumbnail = game.get 'thumbnail'
		hiRes = Obs.create()
		Dom.div !->
			Dom.style margin: '0', display: 'block', height: '80%', maxHeight: '200px'
			imgUrl = hiRes.get() ? thumbnail
			Dom.style backgroundImage: "url(#{imgUrl})", backgroundSize: 'cover', backgroundPosition: 'center'
			unless hiRes.get()?
				Dom.onTap !-> if image = game.get 'image' then hiRes.set image

	Dom.div !->
		Dom.style width: '90%', margin: '20px auto', position: 'relative'

		Dom.h1 !->
			Dom.style textAlign: 'center'
			Dom.text game.get 'name'

		Dom.p !->
			Dom.style maxHeight: '100px', margin: '20px 0', overflow: 'auto'
			Dom.text game.get 'description'

		showStar = (nr, rating, mine=false) !->
			Dom.span !->
				Icon.render
					data: if not rating? or nr > rating then 'star-outline' else 'star'
					size: '25'
					color: if not rating? then '#ccc' else '#ffaa00'
					onTap: !->
						return unless mine
						Server.sync 'rateGame', gameId, nr, !->
							game.set 'ratings', App.userId(), nr
#-webkit-linear-gradient(top, rgba(0, 0, 0, 0) 0px, rgba(0, 0, 0, 0.6) 100%)
		renderRating = (rating, mine) !->
			for i in [1..5]
				showStar i, rating, mine

		Dom.div !->
			Dom.style Box: 'horizontal middle', _justifyContent: 'space-around'
			Dom.div !-> Dom.text "Your rating"
			Dom.div !-> renderRating game.get('ratings', App.userId()), true

		Dom.div !->
			Dom.style margin: '30px auto'

			foundOthers = Obs.create false
			Dom.div !->
				return unless foundOthers.get()
				Dom.style margin: '10px 0'
				Dom.text "Andere beoordelingen:"
			game.iterate 'ratings', (rating) !->
				userId = +rating.key()
				return if userId is App.userId() or App.userIsMock userId
				foundOthers.set true
				Dom.div !->
					Dom.style Box: 'horizontal middle'
					Ui.avatar
						key: App.userAvatar userId
						onTap: !-> App.showMemberInfo userId

					Dom.div !->
						Dom.style Flex: 1, marginLeft: '10px'
						Dom.text App.userName userId

					Dom.div !-> renderRating rating.get()
