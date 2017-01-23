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

	if App.userIsAdmin()
		toggleIt = Obs.create false
		Obs.observe !->
			Dom.div !->
				Dom.style
					position: 'relative'
					backgroundColor: App.colors().highlight
					color: App.colors().highlightText
					top: '2px'
					left: '2px'
					width: '40px'
					height: '40px'
					boxSizing: 'border-box'
					textAlign: 'center'
					lineHeight: '40px'
					fontSize: '24px'
					borderRadius: '50%'
					boxShadow: '3px 3px 8px 0px #ccc'
					zIndex: 2
				Dom.text "+"
				Dom.onTap !-> toggleIt.modify (v)->!v
			return unless toggleIt.get()
			Dom.div !->
				Dom.style Box: 'horizontal middle'
				myForm = Form.input {text: 'Enter BGG id here'}
				Ui.button "Add", !->
					Server.call 'addGame', myForm.value()
					myForm.value('')

	Dom.div !->
		Dom.style position: 'relative', margin: '10px'

		Dom.div !->
			Dom.style Box: 'horizontal middle'
			Dom.div !->
				Dom.style color: '#aaa', fontSize: '0.9em', textAlign: 'right', Flex: 1, marginRight: '3px'
				Dom.text "sorted by " + sortModes[ordering.get()].name
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

				renderAverage game.ref('ratings')

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

renderGamePage = (gameId) !->
	Comments.enable
		store: ['games', gameId, 'comments']
		inline: true

	game = Db.shared.ref 'games', gameId

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
